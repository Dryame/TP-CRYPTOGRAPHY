#!/usr/bin/env bash
# pki_tp2.sh : vérifie que la PKI du TP 2 est prête (prérequis du TP 3).
# Il faut : racine, intermédiaire, serveur, Alice REVOQUÉE et crls.pem.
# Si quelque chose manque, on reconstruit tout (étapes 1, 2-4 et 6 du TP 2).
set -euo pipefail
cd "$(dirname "$0")/../../tp2"          # dossier tp2/, voisin de tp3/

# Tout est déjà là : on ne touche à rien
if [ -f serveur.crt ] && [ -f serveur.key ] && [ -f crls.pem ] && [ -f inter/inter.crt ]; then
  echo "PKI du TP 2 déjà prête."
  exit 0
fi

echo "PKI du TP 2 incomplète : reconstruction."

# Étape 1 du TP 2 : repartir de zéro et recréer l'arborescence
rm -rf racine inter *.key *.csr *.crt crls.pem
for d in racine inter; do
  mkdir -p $d/certs $d/crl $d/newcerts
  touch $d/index.txt
done
echo 1000 > racine/serial; echo 1000 > racine/crlnumber
echo 2000 > inter/serial;  echo 2000 > inter/crlnumber

# Étapes 2 à 4 du TP 2 : racine, intermédiaire, serveur, Alice
bash ./pki.sh

# Étape 6 du TP 2 : révoquer Alice et publier les CRL
openssl ca -config inter.cnf -revoke alice.crt -crl_reason keyCompromise
openssl ca -config inter.cnf  -gencrl -out inter/crl/inter.crl
openssl ca -config racine.cnf -gencrl -out racine/crl/racine.crl
cat inter/crl/inter.crl racine/crl/racine.crl > crls.pem
echo "PKI du TP 2 prête."
