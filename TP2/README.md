# TP 2 – Construire une infrastructure de gestion de clés (OpenSSL)

Ce projet construit une **PKI** (infrastructure à clé publique) avec OpenSSL :
une AC racine, une AC intermédiaire, un certificat serveur, un certificat client,
puis la validation de la chaîne et la révocation d'un certificat.

---

## 1. Ce que fait le projet

        racine.key ──signe──►  racine.crt   (auto-signé : c'est l'ancre de confiance)
                                   │ signe
                                   ▼
        inter.key ──CSR──►     inter.crt    (AC intermédiaire, ne signe que des feuilles)
                                   │ signe
                         ┌─────────┴─────────┐
                         ▼                   ▼
                   serveur.crt           alice.crt
                 (www.tp.local)       (alice@tp.local)


AC racine | P-384 | 10 ans | Signe uniquement l'intermédiaire et sa propre CRL 
AC intermédiaire | P-256 | 5 ans | Signe les certificats serveur et client 
Serveur `www.tp.local` | P-256 | 90 jours | Usage « serveur TLS » 
Client `alice@tp.local` | P-256 | 90 jours | Usage « client TLS » 


- Toutes les commandes se lancent **depuis le dossier `TP2/`**, car les fichiers
  `.cnf` utilisent des chemins relatifs (`dir = ./racine`).

---

## 3. Fichiers du projet

| Fichier | Rôle |

| `racine.cnf` | Configuration de l'AC racine : chemins de sa base, de sa clé, de son certificat, algorithme de hachage, et section d'extensions `ext_inter` appliquée à l'intermédiaire |
| `inter.cnf` | Configuration de l'AC intermédiaire : même principe, avec les sections `ext_serveur` et `ext_client` |
| `pki.sh` | Script qui exécute les étapes 2 à 4 dans l'ordre et s'arrête à la première erreur |
| `.gitignore` | Contient `*.key` pour ne jamais publier une clé privée |
| `compte_rendu/` | Rapport du TP |

Les `.cnf` ne s'« exécutent » pas : OpenSSL les lit seulement quand on lance
`openssl ca -config ...`. Les commandes `genpkey`, `req` et `verify` n'en ont pas besoin.

### Arborescence obtenue à la fin

```
TP2/
├── racine.cnf  inter.cnf  pki.sh  README.md  .gitignore
├── compte_rendu/
├── serveur.key  serveur.csr  serveur.crt
├── alice.key    alice.csr    alice.crt
├── ex.key       ex.csr       ex.crt          ← test www.example.com (étape 5)
├── crls.pem                                  ← CRL de l'intermédiaire + de la racine
├── racine/
│   ├── racine.key  racine.crt
│   ├── index.txt  serial  crlnumber          ← base de l'AC (+ fichiers .old, .attr)
│   ├── newcerts/  certs/  crl/racine.crl
└── inter/
    ├── inter.key  inter.csr  inter.crt
    ├── index.txt  serial  crlnumber
    └── newcerts/  certs/  crl/inter.crl
```

---

## 4. Exécution 

```bash
chmod +x pki.sh      # rend le script exécutable
./pki.sh             # étapes 2 à 4 
```

Résultat attendu à la fin :

```
serveur.crt: OK
alice.crt: OK
```

## 5. Déroulement pas à pas

Pour chaque étape : ce qui se passe, la commande à lancer, comment l'exécuter et le résultat attendu. Tout se lance depuis le dossier `TP2/`, dans l'ordre des étapes.

### Étape 1 – Préparer les autorités

- **Ce qui se passe** : pour la racine et pour l'intermédiaire, on crée les dossiers `certs/`, `crl/` et `newcerts/`, un registre `index.txt` vide (liste des certificats émis) et deux compteurs : `serial` (prochain numéro de certificat) et `crlnumber` (prochain numéro de CRL).

- **Pourquoi** : `openssl ca` lit cette base pour signer mais ne la crée pas. Sans elle, la signature échoue (`./racine/newcerts: No such file or directory`).

- **Valeurs de départ** : 1000 pour la racine, 2000 pour l'intermédiaire, afin de distinguer les numéros des deux autorités. OpenSSL les lit en **hexadécimal** (`2000` vaut 8192 en décimal).

- **Commande** :
  bash
  mkdir -p racine/{certs,crl,newcerts} inter/{certs,crl,newcerts}
  touch racine/index.txt inter/index.txt
  echo 1000 | tee racine/serial racine/crlnumber > /dev/null
  echo 2000 | tee inter/serial inter/crlnumber > /dev/null
  
- **Exécution** : copier le bloc dans le terminal, une seule fois, avant `./pki.sh`.
- **Résultat attendu** : aucun message. Pour contrôler : `ls racine inter` doit montrer `certs`, `crl`, `newcerts`, `index.txt`, `serial` et `crlnumber` dans chaque dossier.



### Étape 2 – AC racine

- **Ce qui se passe** : le script génère la clé privée de la racine (courbe P-384, en lecture seule), puis un certificat **auto-signé** valable 10 ans. 

- **Pourquoi émetteur = sujet** : la racine est auto-signée, personne n'est au-dessus d'elle. Sa confiance vient de son installation volontaire dans le magasin de confiance 

- **Commande** : `./pki.sh` (section `[1/4]` du script)

- **Exécution** : après l'étape 1. Le script enchaîne les étapes 2, 3 et 4 en une seule exécution.

- **Résultat attendu** : les fichiers `racine/racine.key` et `racine/racine.crt`.



### Étape 3 – AC intermédiaire

- **Ce qui se passe** : l'intermédiaire génère sa propre clé (P-256) et une **demande de certificat** (CSR). La racine la signe pour 5 ans

- **Côté base** : le certificat reçoit le numéro de série 1000 et une ligne est ajoutée à `racine/index.txt`.

- **Commande** : `./pki.sh` (section `[2/4]`)

- **Exécution** : même exécution que l'étape 2.

- **Résultat attendu** : le fichier `inter/inter.crt`, et dans le terminal `Signature ok` puis `Write out database with 1 new entries`.

- **Consulter le résultat** : `openssl x509 -in inter/inter.crt -noout -subject -issuer -dates -ext basicConstraints,nameConstraints`
  - `issuer` = `Racine TP`, `subject` = `Inter TP` ;
  - `CA:TRUE, pathlen:0` ;
  - noms permis : `DNS:.tp.local`, `DNS:tp.local`, `email:tp.local`.



### Étape 4 – Certificats de serveur et de client

- **Ce qui se passe** : le serveur et Alice génèrent **chacun leur propre clé** et leur CSR (seule la CSR, publique, est envoyée à l'AC). L'**intermédiaire** signe les deux pour 90 jours.

- **Serveur** : nom `www.tp.local`, noms alternatifs `www.tp.local` et `tp.local`, usage `serverAuth`, numéro de série 2000.

- **Alice** : nom `alice@tp.local`, usage `clientAuth`, numéro de série 2001. Sa CSR ne contient pas de nom alternatif : la section `ext_client` ajoute déjà son adresse.

- **Commande** : `./pki.sh` (sections `[3/4]` et `[4/4]`)

- **Exécution** : même exécution que les étapes 2 et 3.

- **Résultat attendu** : les fichiers `serveur.crt` et `alice.crt`, puis, à la fin du script, `serveur.crt: OK` et `alice.crt: OK`.
- **Consulter le résultat** : `openssl x509 -in serveur.crt -noout -subject -issuer -dates -ext subjectAltName,extendedKeyUsage` (remplacer `serveur.crt` par `alice.crt` pour le client).



### Étape 5 – Valider la chaîne

- **Ce qui se passe** : quatre vérifications. L'ancre de confiance est la racine ; l'intermédiaire est fourni comme maillon de la chaîne.
  - le serveur avec son bon nom ;
  - le serveur avec un mauvais nom ;
  - Alice utilisée comme client TLS ;
  - un certificat demandé pour `www.example.com`, signé par l'intermédiaire puis vérifié.

- **Pourquoi l'AC peut signer `www.example.com`** : `openssl ca` ne fait que signer, il ne relit pas les `nameConstraints` de son propre certificat. Ces contraintes sont appliquées par celui qui **valide** la chaîne (le client). Le certificat existe, mais aucun client ne l'acceptera : `www.example.com` est hors du domaine `tp.local`.

- **Commande** :
  ```bash
  CHAINE="-CAfile racine/racine.crt -untrusted inter/inter.crt"
  openssl verify $CHAINE -verify_hostname www.tp.local serveur.crt
  openssl verify $CHAINE -verify_hostname autre.example serveur.crt
  openssl verify $CHAINE -purpose sslclient alice.crt

  ```
  Puis, pour le certificat `www.example.com` :
  ```bash
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out ex.key && chmod 400 ex.key
  openssl req -new -key ex.key -subj "/CN=www.example.com" \
    -addext "subjectAltName=DNS:www.example.com" -out ex.csr
  openssl ca -batch -notext -config inter.cnf -extensions ext_serveur -days 90 \
    -in ex.csr -out ex.crt
  openssl verify $CHAINE ex.crt
  ```

- **Exécution** : après `./pki.sh`, dans le même terminal (la variable `CHAINE` est définie par la première ligne). Les échecs sont **voulus**.
- **Résultat attendu** :

| Vérification | Résultat |

| Bon nom | `serveur.crt: OK` |
| Mauvais nom | `error 62 ... hostname mismatch` |
| Alice, usage client | `alice.crt: OK` |
| `www.example.com` | `error 47 ... permitted subtree violation` |



### Étape 6 – Révoquer un certificat

- **Ce qui se passe** : on suppose la clé d'Alice compromise. Son certificat est révoqué avec la raison `keyCompromise`. On publie ensuite la CRL de l'intermédiaire et celle de la racine, puis on les réunit dans `crls.pem`.

- **Vérification** : Alice est re-vérifiée avec le contrôle des CRL de **tous** les niveaux de la chaîne (d'où les deux CRL), puis on affiche le contenu de la CRL de l'intermédiaire.

- **Commande** :
  ```bash
  openssl ca -config inter.cnf -revoke alice.crt -crl_reason keyCompromise
  openssl ca -config inter.cnf  -gencrl -out inter/crl/inter.crl
  openssl ca -config racine.cnf -gencrl -out racine/crl/racine.crl
  cat inter/crl/inter.crl racine/crl/racine.crl > crls.pem
  openssl verify -crl_check_all -CRLfile crls.pem $CHAINE alice.crt
  openssl crl -in inter/crl/inter.crl -noout -text
  ```
- **Exécution** : après l'étape 5, dans le même terminal (la variable `CHAINE` doit être encore définie). Ne lancer la révocation **qu'une seule fois** : une deuxième fois, OpenSSL signale que le certificat est déjà révoqué.
- **Résultat attendu** :
  - `Revoking Certificate 2001.` ;
  - `error 23 ... certificate revoked` (échec voulu) ;
  - dans la CRL : numéro de série `2001`, raison `Key Compromise`, et `Next Update` à 7 jours.
- **Fichier produit** : `crls.pem`, réutilisé au TP 3.



### Étape 7 – Automatiser (`pki.sh`)

- **Ce qui se passe** : `pki.sh` regroupe les étapes 2 à 4 (racine, intermédiaire, serveur, client).

- **Commande** : `./pki.sh`

- **Exécution** : après l'étape 1, depuis `TP2/`. Si le fichier n'est pas exécutable : `chmod +x pki.sh` (une seule fois).

- **Résultat attendu** : `serveur.crt: OK`, `alice.crt: OK`, puis `PKI créée avec succès.`

- **Relancer le script** : les clés sont en lecture seule et les bases déjà remplies. Il faut d'abord tout nettoyer avec `rm -rf racine inter *.key *.csr *.crt crls.pem`, refaire l'étape 1, puis `./pki.sh`.


## 7. Questions de réflexion

### 1. Pourquoi la clé de la racine doit-elle rester hors ligne ? Que faire si l'intermédiaire est compromis ? Et la racine ?

Pour prévenir tout compromis irréversible de l'ensemble de la chaîne de confiance par une intrusion réseau car La racine est l'ancre de confiance.

Intermédiaire compromis : Révoquer l'intermédiaire auprès de l'AC racine et publier une nouvelle CRL signée par la racine.
Racine compromise : toute la hiérarchie est perdue. Il faut Reconstruire entièrement la PKI et redistribuer la nouvelle ancre de confiance à tous les clients.


### 2. À quoi sert `pathlen:0` sur l'intermédiaire ? Quel risque si on l'oublie ?

`pathlen:0` interdit à l'intermédiaire de créer des AC filles : il ne peut signer que des
certificats finaux. 
L'intermédiaire pourrait émettre une sous-autorité non maîtrisée capable de délivrer des certificats frauduleux.


### 3. Pourquoi la clé privée du serveur est-elle générée par le serveur et non par l'AC ?

Pour assurer la non-séquestration de la clé et garantir que le serveur est le seul et unique détenteur de son secret.


### 4. Le CN et le SAN contiennent tous deux `www.tp.local`. Lequel les clients modernes vérifient-ils ?

Le champ ** Subject Alternative Name**. Dès qu'un SAN est présent, les clients modernes (navigateurs, `curl`, OpenSSL)
ignorent le CN. Le CN est conservé pour la lisibilité et la compatibilité.


### 5. Quelles sont les limites des CRL ? Comparer avec OCSP et les certificats très courts.


**CRL** 
Sa latence de mise à jour et sa taille croissante qui ralentit le chargement par les clients.

**OCSP** 
Il permet d'interroger en direct l'état de révocation d'un certificat unique sans télécharger une liste complète.

**Certificats très courts** 
L'expiration remplace la révocation : une clé volée devient inutile en quelques jours, Exige une **automatisation** complète du renouvellement

### 6. Politique de certification minimale (dix lignes)

1. Demandeurs : membres du personnel et étudiants de la filière, ainsi que les serveurs du domaine `tp.local`.
2. Demande : par CSR transmise à l'administrateur de la PKI ; la clé privée est générée par le demandeur et ne quitte jamais sa machine.
3. Identité : vérifiée en personne ou par courriel institutionnel ; le nom demandé doit appartenir à `tp.local`.
4. Noms : le SAN est contrôlé par l'AC avant signature (pas de recopie aveugle en production).
5. Durées : racine 10 ans, intermédiaire 5 ans, certificats serveur et client 90 jours.
6. Algorithmes : ECDSA P-384 pour la racine, P-256 pour les autres ; SHA-384 / SHA-256.
7. Racine : conservée hors ligne, utilisée seulement pour signer l'intermédiaire et publier sa CRL.
8. Révocation : sous 24 h en cas de compromission ou de départ du titulaire ; CRL republiée au moins tous les 7 jours.
9. Protection des clés : clés privées en lecture seule pour leur propriétaire, jamais dans un dépôt de code ni dans un rapport.
10. Traçabilité : chaque émission et chaque révocation est enregistrée (`index.txt`, copies dans `newcerts/`).


## 9. Sécurité et livrable

- Toutes les clés sont en `chmod 400` ; `.gitignore` contient `*.key`.
- Les clés ne sont **pas chiffrées par mot de passe** dans cette version. Pour un usage réel, chiffrer
  chaque clé (`-aes256` à la création, `-passin` à l'utilisation) et fournir le mot de passe par une variable
  d'environnement, jamais dans un fichier du dépôt.
- **À rendre** : `pki.sh`, `racine.cnf`, `inter.cnf`, les certificats publics
  (`racine/racine.crt`, `inter/inter.crt`, `serveur.crt`, `alice.crt`, `crls.pem`) et le rapport.
- **Ne jamais rendre** : aucun fichier `*.key`.
- Pour contrôler : `grep -rl "PRIVATE KEY" <dossier_à_rendre>` ne doit rien afficher.
