#!/usr/bin/env bash
# Étape 4 : vérifier la configuration (TLS 1.1 refusé, suites acceptées en TLS 1.2).
# À lancer uniquement sur son propre serveur de laboratoire.
set -uo pipefail

TP3="$(cd "$(dirname "$0")/.." && pwd)"
SORTIE="$TP3/captures"
mkdir -p "$SORTIE"

{
  echo "=== 1. TLS 1.1 : doit être REFUSÉ"
  # SECLEVEL=0 : sans cela, openssl refuse TLS 1.1 de son côté et ne teste pas le serveur
  openssl s_client -connect www.tp.local:443 -tls1_1 -cipher 'DEFAULT:@SECLEVEL=0' \
    -brief < /dev/null 2>&1 | head -5
  echo
  echo "=== 2. Suites acceptées (nmap)"
  nmap --script ssl-enum-ciphers -p 443 www.tp.local
} | tee "$SORTIE/etape4_verification.txt"
