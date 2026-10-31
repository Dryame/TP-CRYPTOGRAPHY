#!/usr/bin/env bash
# renouveler.sh : renouvelle le certificat du serveur s'il expire dans moins de 30 jours.
#
# Usage :  sudo ./renouveler.sh            (renouvelle seulement si nécessaire)
#          sudo ./renouveler.sh --force    (renouvelle dans tous les cas)
#
# Référence : les fichiers DÉPLOYÉS dans /etc/nginx/tls (c'est ce que nginx sert).
set -euo pipefail
umask 077                                   # fichiers créés lisibles par root seul

# --- Réglages ---------------------------------------------------------------
SEUIL_JOURS=30                              # on renouvelle sous ce seuil
DUREE_JOURS=90                              # durée du nouveau certificat
TLS=/etc/nginx/tls                          # dossier lu par nginx
TP3="$(cd "$(dirname "$0")/.." && pwd)"
PKI="$(cd "$TP3/../tp2" && pwd)"
SAUVEGARDES="$TP3/sauvegardes"

[ "$(id -u)" -eq 0 ] || { echo "À lancer avec sudo." >&2; exit 1; }
log() { echo "$(date '+%F %T') $*"; }
cd "$PKI"

# --- Faut-il renouveler ? ---------------------------------------------------
# -checkend N : réussit si le certificat est encore valable dans N secondes
if [ "${1:-}" != "--force" ] \
   && openssl x509 -in "$TLS/serveur_chaine.crt" -noout -checkend $((SEUIL_JOURS * 86400)) > /dev/null; then
  log "Certificat valable encore plus de $SEUIL_JOURS jours : rien à faire."
  exit 0
fi
log "Renouvellement du certificat du serveur."

# --- 1. Nouvelle clé et nouvelle demande (dans un dossier temporaire) -------
NOUVEAU="$(mktemp -d)"
trap 'rm -rf "$NOUVEAU"' EXIT
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$NOUVEAU/serveur.key"
openssl req -new -key "$NOUVEAU/serveur.key" -subj "/CN=www.tp.local" \
  -addext "subjectAltName=DNS:www.tp.local,DNS:tp.local" -out "$NOUVEAU/serveur.csr"

# --- 2. L'intermédiaire signe la demande ------------------------------------
# L'annexe B n'autorise qu'un certificat par nom : on lève cette limite pour renouveler
echo "unique_subject = no" > inter/index.txt.attr
openssl ca -batch -notext -config inter.cnf -extensions ext_serveur -days "$DUREE_JOURS" \
  -in "$NOUVEAU/serveur.csr" -out "$NOUVEAU/serveur.crt"

# --- 3. Vérifier la chaîne AVANT de déployer (le script s'arrête si échec) --
openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt \
  -verify_hostname www.tp.local "$NOUVEAU/serveur.crt"
cat "$NOUVEAU/serveur.crt" inter/inter.crt > "$NOUVEAU/serveur_chaine.crt"

# --- 4. Garder l'ancien certificat pour pouvoir revenir en arrière ----------
SAUV="$SAUVEGARDES/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SAUV"
cp -p "$TLS/serveur.key" "$TLS/serveur_chaine.crt" "$SAUV/"
log "Ancien certificat sauvegardé dans $SAUV"

retour_arriere() {
  install -m 600 "$SAUV/serveur.key" "$TLS/serveur.key"
  install -m 644 "$SAUV/serveur_chaine.crt" "$TLS/serveur_chaine.crt"
  log "Retour arrière effectué : ancien certificat remis en place."
}

# --- 5. Installer, tester la configuration, recharger sans coupure ----------
install -m 600 "$NOUVEAU/serveur.key" "$TLS/serveur.key"
install -m 644 "$NOUVEAU/serveur_chaine.crt" "$TLS/serveur_chaine.crt"

if nginx -t; then
  systemctl reload nginx 2>/dev/null || nginx -s reload
  log "nginx rechargé : nouveau certificat en service."
else
  retour_arriere
  exit 1
fi

# L'utilisateur doit pouvoir continuer à utiliser la PKI (fichiers modifiés par openssl ca)
chown -R --reference="$PKI/inter.cnf" "$PKI/inter"
