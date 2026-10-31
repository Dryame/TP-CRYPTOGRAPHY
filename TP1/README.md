# TP 1 – Chiffrement authentifié et dérivation de clés


`coffre.py` est un mini-coffre de fichiers : il chiffre des données avec un mot de passe, en assemblant des briques éprouvées (Argon2id, HKDF-SHA256, AES-GCM). Ce document décrit, dans l'ordre, les commandes utilisées, ce qu'elles font et le résultat attendu.


## 1. Arborescence du dépôt

```
TP1/
├── coffre.py              module du coffre (étapes 1, 2 et 4)
├── tests/
│   └── test_coffre.py     tests pytest (étape 3)
├── pytest.ini             configuration de pytest
├── requirements.txt       dépendances Python
├── compte_rendu/          rapport et résultats des tests
├── .gitignore             fichiers exclus du dépôt
└── README.md
```


Toutes les commandes se lancent **depuis le dossier `TP1/`** (celui qui contient `coffre.py`).

---

## 2. Mise en place

### 2.1 Créer l'arborescence

- **Commande** :
  ```bash
  mkdir -p TP1/tests TP1/compte_rendu
  cd TP1
  touch coffre.py tests/test_coffre.py requirements.txt README.md compte_rendu/.gitkeep

  ```
- **Fonction** : `mkdir -p` crée le projet et ses sous-dossiers ; `cd` s'y place ; `touch` crée les fichiers vides. Le fichier `.gitkeep` permet à Git de suivre un dossier vide.

- **Résultat** : les dossiers `tests/` et `compte_rendu/` et les fichiers ci-dessus existent.

### 2.2 Déclarer les dépendances

- **Commande** :
  ```bash
  cat > requirements.txt <<'EOF'
  cryptography
  argon2-cffi
  pytest
  EOF
  ```
- **Fonction** : écrit la liste des bibliothèques nécessaires.
  - `cryptography` : AES-GCM et HKDF ;
  - `argon2-cffi` : dérivation Argon2id ;
  - `pytest` : exécution des tests.


### 2.3 Configurer pytest

- **Commande** :
  ```bash
  cat > pytest.ini <<'EOF'
  [pytest]
  pythonpath = .
  testpaths = tests
  EOF
  ```
- **Fonction** : `pythonpath = .` permet aux tests (dans `tests/`) d'importer `coffre.py` (à la racine) ; `testpaths = tests` indique où chercher les tests.


### 2.4 Créer et activer l'environnement virtuel

- **Commande** :
  ```bash
  python3 -m venv ~/ec1
  source ~/ec1/bin/activate
  ```

- **Fonction** : crée un environnement Python isolé, puis l'active. Les paquets installés ne touchent pas le Python du système.
- **Résultat** : l'invite du terminal est précédée du nom de l'environnement, par exemple `(ec1)`.


### 2.5 Installer les dépendances

- **Commande** : `python -m pip install -r requirements.txt`
- **Fonction** : installe tous les paquets listés. `python -m pip` garantit l'installation dans le Python **actif**.
- **Vérification** : `python -m pip list | grep -iE "argon2|cryptography|pytest"` affiche les trois paquets.



## 3. Exécution par étape

### Étape 1 – Dérivation des clés

- **Commande** : `python coffre.py`
- **Fonction** : lance la démonstration du module. Pour deux sels aléatoires, il dérive la clé maîtresse (Argon2id) et la sous-clé (HKDF), mesure la durée, puis vérifie qu'un même sel redonne la même clé.
- **Résultat attendu** :
  - une durée d'environ 0,5 s par dérivation (réglée avec les paramètres `T` et `M` du fichier) ;
  - `Même sel, deux calculs identiques : True`.
- **Attention** : le programme affiche les clés dérivées ; ne les recopie pas dans un rapport.

### Étape 2 – Chiffrer et déchiffrer

- **Commande** :
  ```bash
  python -c "
  import coffre
  f = coffre.chiffrer('mdp-de-demo', 'note.txt', b'Bonjour')
  print(len(f), f[:4])
  print(coffre.dechiffrer('mdp-de-demo', 'note.txt', f))"
  ```

- **Fonction** : chiffre le texte `Bonjour` avec un mot de passe de démonstration et le nom `note.txt` (données associées), affiche la taille et l'identifiant du fichier obtenu, puis le déchiffre.
- **Résultat attendu** : `67 b'CFR1'` puis `b'Bonjour'`. La taille se décompose en 44 octets d'en-tête et 23 octets de chiffré : 7 octets de données et 16 octets d’étiquette d’authentification.

### Étape 3 – Tests de sécurité

- **Commande** : `pytest`
- **Fonction** : exécute tous les tests du dossier `tests/` et affiche un point par test réussi.
- **Commande détaillée** : `pytest -v`
- **Fonction** : affiche le nom de chaque test et son résultat, ce qui permet d'associer un test à une propriété de sécurité.
- **Résultat attendu** : six tests `PASSED`, puis `6 passed`.
- **Enregistrer le résultat** :
  ```bash
  pytest -v | tee compte_rendu/resultat_tests.txt
  ```
  - `|` envoie l'affichage de pytest à `tee` ;
  - `tee` l'affiche **et** l'écrit dans le fichier indiqué ;
  - le dernier argument doit être un **nom de fichier** : donner seulement le dossier provoque `Is a directory`.

| Test | Propriété vérifiée |

| `test_aller_retour` | Correction : on retrouve les données |
| `test_deux_chiffrements_differents` | Chiffrement probabiliste (sel et nonce neufs) |
| `test_mauvais_mot_de_passe` | Authentification de la clé (`InvalidTag`) |
| `test_octet_modifie` | Intégrité (`InvalidTag`) |
| `test_nom_echange` | Liaison au contexte par les données associées (`InvalidTag`) |
| `test_rechiffrement` | Changement de mot de passe (étape 4) |

### Étape 4 – Évolution et changement de mot de passe

- **Commande de test** : `pytest -v -k rechiffrement`
- **Fonction** : `-k` ne lance que les tests dont le nom contient `rechiffrement`.
- **Résultat attendu** : `test_rechiffrement PASSED`.
- **Commande de démonstration** :
  ```bash
  python -c "
  import coffre
  f = coffre.chiffrer('ancien', 'note.txt', b'Bonjour')
  g = coffre.rechiffrer('ancien', 'nouveau', 'note.txt', f)
  print(coffre.dechiffrer('nouveau', 'note.txt', g))
  try:
      coffre.dechiffrer('ancien', 'note.txt', g)
  except Exception as e:
      print(type(e).__name__)"
  ```
- **Fonction** : change le mot de passe d'un fichier, puis vérifie que le nouveau fonctionne et que l'ancien est refusé.
- **Résultat attendu** : `b'Bonjour'` puis `InvalidTag`.




## 5. Contrôles avant de rendre

| Commande | Fonction | Résultat attendu |

| `git status` |              Montre ce qui n'est pas encore enregistré | `nothing to commit, working tree clean` |
| `git ls-files` |             Liste les fichiers suivis par Git | uniquement les fichiers du projet |
| `git log --oneline` |   Liste les commits | trois commits |
| `grep -rIn "PRIVATE KEY" $(git ls-files)` | Cherche une clé privée dans les fichiers suivis | aucun affichage |


## 6. Réponses aux questions de réflexion

1. Pourquoi le sel est-il stocké en clair ? Il est indispensable pour redériver la même clé et n’a pas besoin d’être secret : son seul but est de garantir l'unicité du résultat de la dérivation.

2. Pourquoi 96 bits aléatoires suffisent-ils pour le nonce ? Le danger n’existe que si un même nonce est employé avec une même clé. Or le sel est neuf à chaque fichier, ce qui génère une clé de chiffrement différente à chaque fois.

3. Et si le nom du fichier n’était pas dans les données associées ? Un attaquant pourrait renommer ou échanger deux fichiers chiffrés avec le même mot de passe sans que le déchiffrement ne le détecte.

4. Pourquoi authentifier l’en-tête ? Il contient les paramètres Argon2id, le sel et le nonce : les authentifier lie le fichier à ces valeurs précises et empêche de les modifier sans détection.

5. Pourquoi ne pas afficher la cause précise d’un échec ? Distinguer « mauvais mot de passe », « fichier altéré » ou « format inconnu » fournirait à un attaquant un oracle pour tester des fichiers forgés et déduire des informations. 


## 7.Sécurité

- Aucune clé ni aucun mot de passe réel dans le dépôt ni dans le compte rendu.
- Les mots de passe visibles dans les exemples et les tests sont des valeurs de démonstration.
- Le fichier `.gitignore` exclut les environnements virtuels, les caches Python et les fichiers de secrets (`*.key`, `*.pem`, `.env`).
