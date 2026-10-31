#!/usr/bin/env bash
# Étape 3 (préparation) : émettre le certificat client de Bob.
# Le certificat d'Alice a été révoqué au TP 2, il faut donc un autre client valide.
set -euo pipefail
cd "$(dirname "$0")/../../tp2"          # dossier de la PKI

# La section ext_client_bob doit exister dans inter.cnf
grep -q "ext_client_bob" inter.cnf || { echo "Section ext_client_bob absente de inter.cnf" >&2; exit 1; }

# Clé de Bob, puis sa demande de certificat
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out bob.key
chmod 400 bob.key
openssl req -new -key bob.key -subj "/CN=bob@tp.local" -out bob.csr

# L'intermédiaire signe
openssl ca -batch -notext -config inter.cnf -extensions ext_client_bob -days 90 \
  -in bob.csr -out bob.crt

# Chaîne de Bob (son certificat + l'intermédiaire) : le client doit la présenter
# au serveur, qui ne connaît que la racine
cat bob.crt inter/inter.crt > bob_chaine.crt

openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt -purpose sslclient bob.crt
