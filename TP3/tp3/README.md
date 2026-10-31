# TP 3 – Déployer un canal sécurisé et gérer les certificats

**Module EC1 – Ingénierie de la cryptographie** · Année universitaire 2026–2027

Serveur HTTPS `www.tp.local` en TLS 1.2/1.3 avec authentification mutuelle (mTLS), contrôle de la révocation par CRL, supervision des expirations et renouvellement automatique avec retour arrière. Le TP réutilise la PKI du TP 2.

## Sommaire

1. [Contenu du dépôt](#1-contenu-du-dépôt)
2. [Prérequis](#2-prérequis)
3. [Exécution étape par étape](#3-exécution-étape-par-étape)
4. [Dépannage](#4-dépannage)
5. [Questions de réflexion](#5-questions-de-réflexion)
6. [Règles de sécurité](#6-règles-de-sécurité)

---

## 1. Contenu du dépôt

- **Configuration** : `nginx/tp.local.conf`

- **Scripts** (`scripts/`)
  - `pki_tp2.sh` : étape 0, PKI du TP 2
  - `etape1_preparer.sh` : étape 1, fichiers pour nginx
  - `etape2_nginx.sh` : étape 2, configuration nginx
  - `etape3_bob.sh`, `etape3_observer.sh` : étape 3, client Bob et poignée de main
  - `etape4_verifier.sh` : étape 4, TLS 1.1 et suites (nmap)
  - `etape5_certs_test.sh`, `surveiller.py` : étape 5, supervision
  - `renouveler.sh` : étape 6, renouvellement

- **Données** : `certs_test/` (certificats publics), `captures/` (résultats des tests), `sauvegardes/` (ignoré par git)

- **Documents** : `compte_rendu/` (Word), `README.md`

- **Dépendance** : les dossiers `tp2/` (PKI, clés privées, hors dépôt) et `tp3/` (ce dépôt) doivent être **voisins**

## 2. Prérequis

- Linux ou WSL avec `sudo`, OpenSSL 3, nginx, nmap, curl, tcpdump, tshark
- Python 3.10+ et `cryptography`
- Dans `tp2/` : `racine.cnf`, `inter.cnf` avec la section `[ ext_client_bob ]`, `pki.sh`

```bash
sudo apt install nginx nmap curl openssl tcpdump tshark
pip install cryptography
grep -n ext_client_bob ../tp2/inter.cnf     # doit afficher [ ext_client_bob ]
```

## 3. Exécution étape par étape

Toutes les commandes se lancent depuis **`tp3/`** :

```bash
cd "$HOME/DEVOIR -CRYPTO-2A/TP3/tp3"
chmod +x scripts/* ../tp2/pki.sh
```

### Étape 0 – PKI du TP 2
- `bash scripts/pki_tp2.sh`

- Ne fait rien si la PKI est complète ; sinon **efface et reconstruit** `tp2/`
- Attendu : `PKI du TP 2 prête.`


### Étape 1 – Préparer les fichiers
- `./scripts/etpe1_preparer.sh`

- Chaîne `serveur_chaine.crt` (sans la racine), installation dans `/etc/nginx/tls` (clé en 600, fichiers publics en 644), entrée `/etc/hosts`
- Attendu : `serveur.key` en `-rw-------`


### Étape 2 – Configurer nginx
- `./scripts/etape2_nginx.sh`

- Copie la configuration, teste (`nginx -t`), recharge
- Attendu : `syntax is ok`, `test is successful`
- Contrôle : `sudo ss -tlnp | grep :443`


### Étape 3 – Poignée de main
- `./scripts/etape3_bob.sh` puis `./scripts/etape3_observer.sh`

- Attendu : Bob `Bonjour CN=bob@tp.local` ; sans certificat `400 No required SSL certificate` ; Alice `400 The SSL certificate error`
- Pour prouver la révocation, Alice doit présenter une chaîne complète :

  ```bash
  cd ../tp2 && cat alice.crt inter/inter.crt > alice_chaine.crt && cd ../tp3
  ```
  puis utiliser `--cert alice_chaine.crt` dans `etape3_observer.sh`
- Capture réseau (deux terminaux) :

  ```bash
  sudo tcpdump -i lo -U -w /tmp/handshake.pcapng port 443     # terminal 1
  ./scripts/etape3_observer.sh                                # terminal 2
  sudo cp /tmp/handshake.pcapng captures/ && sudo chown "$USER": captures/handshake.pcapng
  tshark -r captures/handshake.pcapng -Y "tls.handshake.type == 1 or tls.handshake.type == 2"
  ```


### Étape 4 – Vérifier la configuration
- `./scripts/etape4_verifier.sh`

- Attendu : TLS 1.1 refusé (alerte 70) ; TLS 1.2 : 3 suites ECDHE avec GCM ou ChaCha20 ; TLS 1.3 : 3 suites AEAD


### Étape 5 – Superviser les expirations
- `./scripts/etape5_certs_test.sh` puis `python3 scripts/surveiller.py certs_test` puis `echo "Code de sortie : $?"`

- Attendu : `court` CRITIQUE, `moyen` ALERTE, `serveur` OK ; code de sortie **2**

### Étape 6 – Renouveler automatiquement
- `sudo ./scripts/renouveler.sh` (rien à faire si plus de 30 jours) puis `sudo ./scripts/renouveler.sh --force`

- Contrôle : `openssl x509 -in /etc/nginx/tls/serveur_chaine.crt -noout -serial -enddate` et `ls sauvegardes/`
- Cron (table de **root**, ligne sans `#`, chemin entre guillemets) :
  ```
  0 3 * * * "/home/UTILISATEUR/DEVOIR -CRYPTO-2A/TP3/tp3/scripts/renouveler.sh" >> /var/log/renouveler.log 2>&1
  ```
  Vérification : `sudo crontab -l | grep renouveler` ; sous WSL : `sudo service cron start`
- Retour arrière : ajouter `directive_invalide;` dans `/etc/nginx/conf.d/tp.local.conf`, lancer `sudo ./scripts/renouveler.sh --force` (attendu : « Retour arrière effectué »), puis restaurer la configuration et recharger nginx


## 4. Dépannage

- **`Section ext_client_bob absente`** : ajouter la section à `tp2/inter.cnf`
- **Tous les clients refusés** : CRL expirée (7 jours) ; régénérer les CRL, reconstituer `crls.pem`, recharger nginx
- **nmap liste des suites CBC** : `ssl_ciphers` absente ; l'ajouter, relancer l'étape 2





## 5. Questions de réflexion

Q1. Pourquoi le serveur ne doit-il pas envoyer le certificat racine ?

C'est inutile et non sécurisé, car le client doit déjà posséder cette ancre de confiance dans son magasin local.


Q2. Quel est l'intérêt de désactiver les tickets de session lorsque les clés de tickets ne sont pas renouvelées ?

- **Principe** : un ticket contient l'état de la session (en TLS 1.2, le secret maître), chiffré par une clé de ticket détenue par le serveur. Le client le renvoie pour reprendre la session sans nouvelle poignée de main complète.

Parce qu'une clé de ticket compromise permettrait de déchiffrer a posteriori le trafic passé, rompant la confidentialité persistante.


### Q3. Que garantit HSTS et contre quelle attaque protège-t-il ?

Garantie : Il ordonne au navigateur d'utiliser exclusivement des connexions HTTPS sécurisées pour ce domaine.
Attaque contrée :  Contre les attaques de rétrogradation de protocole (SSL stripping) et d'interception de requêtes HTTP initiales.

### Q4. Que changent des certificats de 100 jours (2027) puis 47 jours (2029) pour un renouvellement manuel ?

Fréquence : on passe d'environ un renouvellement par an à un renouvellement tous les 30 à 60 jours par certificat. Avec 47 jours de validité et un renouvellement avant les 30 derniers jours, cela fait environ 8 à 12 opérations par an et par certificat, multipliées par le nombre de certificats.
impact : Elle rend la gestion manuelle intenable et impose l'automatisation intégrale du renouvellement et du déploiement.-
Bénéfice : des durées courtes réduisent la fenêtre d'exploitation d'une clé volée et l'importance de la révocation.

### Q5. Chaîne incomplète : pourquoi certains clients acceptent-ils le certificat et d'autres non ?

Parce que certains navigateurs téléchargent les certificats intermédiaires manquants via l'extension AIA ou leur propre cache.
Clients qui acceptent : ceux qui ont l'intermédiaire en cache (vu lors d'une visite antérieure ou fourni avec le navigateur), ou qui le téléchargent grâce à l'extension *Authority Information Access* du certificat.
Clients qui refusent : OpenSSL, curl, de nombreux clients Java ou embarqués, qui n'utilisent que ce que le serveur envoie (erreur `unable to get local issuer certificate`).


### Q6. Que faire si la clé privée du serveur a fuité ?

1. Contenir : isoler ou arrêter le service si nécessaire ; conserver les journaux pour l'enquête.

2. Révoquer le certificat concerné (le numéro de série figure dans `inter/index.txt`) :
   ```bash
   openssl ca -config inter.cnf -revoke serveur.crt -crl_reason keyCompromise
   ```
3. Republier les CRL (`-gencrl` pour l'intermédiaire, puis `cat` dans `crls.pem`) et recharger nginx, car nginx ne lit la CRL qu'au rechargement.

4. Générer une nouvelle paire de clés** (jamais réutiliser la clé compromise), faire signer un nouveau certificat, vérifier la chaîne, déployer (`renouveler.sh --force`), puis tester avec Bob.

5. Détruire** l'ancienne clé partout, y compris dans `sauvegardes/`, qui conserve l'ancienne clé privée à chaque renouvellement.

6. Analyser la cause (droits, accès, sauvegardes, poste compromis) et la corriger, sinon la nouvelle clé sera exposée de la même façon.

7. Mesurer l'impact : grâce à ECDHE, la clé du serveur ne sert qu'à **s'authentifier** ; les sessions passées ne sont donc pas déchiffrables. Le risque est l'**usurpation** du serveur tant que le certificat n'est pas révoqué et que les clients ne consultent pas la CRL

8. Informer les personnes concernées et surveiller les connexions suspectes.

## 6. Règles de sécurité

- Aucune clé privée ni mot de passe dans le dépôt ou le compte rendu (`.gitignore` : `*.key`, `*.csr`, `*.pcapng`, `sauvegardes/`)
- Domaines `*.tp.local` uniquement, sur sa propre machine
- Aucun algorithme inventé : OpenSSL, nginx, `cryptography`
- Avant le premier commit : `git status` ne doit lister aucun fichier `.key`
