
set -euo pipefail
cd "$(dirname "$0")"

# [1/4] AC RACINE
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out racine/racine.key
chmod 400 racine/racine.key
openssl req -x509 -new -key racine/racine.key -sha384 -days 3650 \
  -subj "/C=BF/O=Universite TP/CN=Racine TP" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash" \
  -out racine/racine.crt

# [2/4] AC INTERMÉDIAIRE
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out inter/inter.key
chmod 400 inter/inter.key
openssl req -new -key inter/inter.key -subj "/C=BF/O=Universite TP/CN=Inter TP" -out inter/inter.csr
openssl ca -batch -notext -config racine.cnf -extensions ext_inter -days 1825 \
  -in inter/inter.csr -out inter/inter.crt

# [3/4] SERVEUR (www.tp.local)
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out serveur.key
chmod 400 serveur.key
openssl req -new -key serveur.key -subj "/CN=www.tp.local" \
  -addext "subjectAltName=DNS:www.tp.local,DNS:tp.local" -out serveur.csr
openssl ca -batch -notext -config inter.cnf -extensions ext_serveur -days 90 \
  -in serveur.csr -out serveur.crt

# [4/4] CLIENT (Alice) : le SAN vient de la section ext_client
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out alice.key
chmod 400 alice.key
openssl req -new -key alice.key -subj "/CN=alice@tp.local" -out alice.csr
openssl ca -batch -notext -config inter.cnf -extensions ext_client -days 90 \
  -in alice.csr -out alice.crt

# Contrôle final
openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt -verify_hostname www.tp.local serveur.crt
openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt -purpose sslclient alice.crt