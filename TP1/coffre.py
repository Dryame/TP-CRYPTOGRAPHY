import os
import time

from argon2.low_level import Type, hash_secret_raw
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF


id_fichier = b"CFR1"
taille_sel = 16
taille_nonce = 12
taille_entete = 44


T, M, P = 36, 64 * 1024, 4


def cle_maitresse(mot_de_passe: str, sel: bytes, t=T, m=M, p=P):

    if not mot_de_passe:
        raise ValueError("mot de passe vide")

    if len(sel) != taille_sel:
        raise ValueError(f"le sel doit faire {taille_sel} octets")

    return hash_secret_raw(
        secret=mot_de_passe.encode("utf-8"),
        salt=sel,
        time_cost=t,
        memory_cost=m,
        parallelism=p,
        hash_len=32,
        type=Type.ID,
    )


def sous_cle(maitresse, usage):

    if len(maitresse) != 32:
        raise ValueError("la clé maîtresse doit faire 32 octets")

    return HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=None,
        info=b"coffre-v1|" + usage,
    ).derive(maitresse)


def chiffrer(mdp, nom, donnees):
    sel = os.urandom(taille_sel)
    nonce = os.urandom(taille_nonce)

    entete = (id_fichier + T.to_bytes(4, "big") + M.to_bytes(4, "big") + P.to_bytes(4, "big") + sel + nonce)

    cle = sous_cle(cle_maitresse(mdp, sel), b"chiffrement")
    donnees_associees = entete + nom.encode("utf-8")
    chiffre = AESGCM(cle).encrypt(nonce, donnees, donnees_associees)

    return entete + chiffre


def dechiffrer(mdp, nom, fichier):
    
    if len(fichier) < taille_entete:
        raise ValueError("fichier trop court")

    entete = fichier[:taille_entete]
    chiffre = fichier[taille_entete:]

    if entete[:4] != id_fichier:
        raise ValueError("format de fichier inconnu")

    t = int.from_bytes(entete[4:8], "big")
    m = int.from_bytes(entete[8:12], "big")
    p = int.from_bytes(entete[12:16], "big")

    sel = entete[16:32]
    nonce = entete[32:44]
    cle = sous_cle(cle_maitresse(mdp, sel, t, m, p), b"chiffrement")
    donnees_associees = entete + nom.encode("utf-8")
    return AESGCM(cle).decrypt(nonce, chiffre, donnees_associees)


def rechiffrer(ancien_mdp, nouveau_mdp, nom, fichier):
    donnees = dechiffrer(ancien_mdp, nom, fichier)
    return chiffrer(nouveau_mdp, nom, donnees)


if __name__ == "__main__":

    mdp = "mot-de-passe"
    
    for i in (1, 2):
        sel = os.urandom(taille_sel)

        debut = time.perf_counter()
        maitresse = cle_maitresse(mdp, sel)
        duree = time.perf_counter() - debut

        sous = sous_cle(maitresse, b"chiffrement")

        print(f"--- Dérivation {i} ---")
        print(f"Sel            : {sel.hex()}")
        print(f"Clé maîtresse  : {maitresse.hex()}")
        print(f"Sous-clé       : {sous.hex()}")
        print(f"Durée          : {duree:.3f} s (cible : ~0,5 s)")


    sel_fixe = os.urandom(taille_sel)
    a = cle_maitresse(mdp, sel_fixe)
    b = cle_maitresse(mdp, sel_fixe)
    print("--- Vérification ---")
    print(f"Même sel, deux calculs identiques : {a == b}")