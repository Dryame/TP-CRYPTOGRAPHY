#!/usr/bin/env bash
# Étape 3 : observer la poignée de main TLS. Les résultats sont gardés dans captures/.
set -uo pipefail                        # pas de -e : certains tests doivent échouer

TP3="$(cd "$(dirname "$0")/.." && pwd)"
PKI="$(cd "$TP3/../tp2" && pwd)"
SORTIE="$TP3/captures"
mkdir -p "$SORTIE"
cd "$PKI"

SERVEUR=(-connect www.tp.local:443 -servername www.tp.local -CAfile racine/racine.crt)
REQUETE=$'GET / HTTP/1.1\r\nHost: www.tp.local\r\nConnection: close\r\n\r\n'

{
  echo "=== 1. Client valide (Bob) : attendu 'Bonjour CN=bob@tp.local'"
  echo "$REQUETE" | openssl s_client "${SERVEUR[@]}" -ign_eof -verify_hostname www.tp.local \
    -cert bob.crt -key bob.key -cert_chain inter/inter.crt -brief 2>&1
  echo
  echo "=== 2. Sans certificat client : attendu 400 (No required SSL certificate)"
  echo "$REQUETE" | openssl s_client "${SERVEUR[@]}" -ign_eof -brief 2>&1
  echo
  echo "=== 3. Avec curl (Bob)"
  curl -sS --cacert racine/racine.crt --cert bob_chaine.crt --key bob.key https://www.tp.local/ 2>&1
  echo
  echo "=== 4. Certificat révoqué (Alice) : attendu 400 (SSL certificate error)"
cat alice.crt inter/inter.crt > alice_chaine.crt
  curl -sS --cacert racine/racine.crt --cert alice_chaine.crt --key alice.key https://www.tp.local/ 2>&1
}