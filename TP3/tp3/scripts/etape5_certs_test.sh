#!/usr/bin/env bash
# Étape 5 (préparation) : remplir certs_test/ avec des certificats de durées différentes
# pour tester surveiller.py : 90 jours (OK), 20 jours (ALERTE), 5 jours (CRITIQUE).
# Seuls les certificats (publics) sont gardés : aucune clé dans certs_test/.
set -euo pipefail

TP3="$(cd "$(dirname "$0")/.." && pwd)"
PKI="$(cd "$TP3/../tp2" && pwd)"
TEST="$TP3/certs_test"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TEST"
cd "$PKI"

# Un même nom peut avoir plusieurs certificats (utile aussi pour le renouvellement)
echo "unique_subject = no" > inter/index.txt.attr

# emettre <nom> <jours> : clé jetable + demande + signature par l'intermédiaire
emettre() {
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$TMP/$1.key"
  openssl req -new -key "$TMP/$1.key" -subj "/CN=$1.tp.local" \
    -addext "subjectAltName=DNS:$1.tp.local" -out "$TMP/$1.csr"
  openssl ca -batch -notext -config inter.cnf -extensions ext_serveur -days "$2" \
    -in "$TMP/$1.csr" -out "$TEST/$1.crt"
}

emettre court 5        # expire dans 5 jours   -> CRITIQUE
emettre moyen 20       # expire dans 20 jours  -> ALERTE
cp serveur.crt "$TEST/serveur.crt"             # 90 jours -> OK

echo "Certificats de test prêts dans $TEST"
