#!/usr/bin/env bash
# Étape 2 : installer la configuration nginx, tester la syntaxe, recharger.
set -euo pipefail

TP3="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"

# 1) Installer la configuration dans le dossier lu par nginx
$SUDO cp "$TP3/nginx/tp.local.conf" /etc/nginx/conf.d/tp.local.conf

# 2) Tester la syntaxe (le script s'arrête ici si elle est fausse)
$SUDO nginx -t

# 3) Recharger sans coupure ; si nginx ne tourne pas encore, le démarrer
$SUDO systemctl reload nginx 2>/dev/null \
  || $SUDO nginx -s reload 2>/dev/null \
  || $SUDO nginx
echo "nginx est actif avec la nouvelle configuration."
