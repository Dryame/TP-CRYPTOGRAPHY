#!/usr/bin/env bash
# Étape 1 : préparer les fichiers que nginx va lire.
# Usage : ./scripts/etape1_preparer.sh   (demandera le mot de passe sudo)
set -euo pipefail

TP3="$(cd "$(dirname "$0")/.." && pwd)"          # dossier tp3/
PKI="$(cd "$TP3/../tp2" && pwd)"                 # dossier tp2/ (la PKI)
TLS=/etc/nginx/tls                               # dossier lu par nginx
[ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"   # sudo seulement si on n'est pas root

# 1) Chaîne du serveur = son certificat + l'intermédiaire (JAMAIS la racine)
rm -f "$TP3/serveur_chaine.crt"
cat "$PKI/serveur.crt" "$PKI/inter/inter.crt" > "$TP3/serveur_chaine.crt"

# 2) Copier les fichiers dans le dossier de nginx
$SUDO mkdir -p "$TLS"
$SUDO install -m 600 "$PKI/serveur.key" "$TLS/serveur.key"        # clé : lisible par root seul
$SUDO install -m 644 "$TP3/serveur_chaine.crt" "$PKI/racine/racine.crt" "$PKI/crls.pem" "$TLS/"

# 3) Faire connaître le nom du serveur de labo (une seule fois)
grep -q "www.tp.local" /etc/hosts || echo "127.0.0.1 www.tp.local" | $SUDO tee -a /etc/hosts > /dev/null

echo "Fichiers prêts dans $TLS :"
$SUDO ls -l "$TLS"
