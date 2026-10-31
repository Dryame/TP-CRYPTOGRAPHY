


import pytest
from cryptography.exceptions import InvalidTag

from coffre import chiffrer, dechiffrer, rechiffrer


mdp = "yameogo"
nom = "rapport.txt"
donnees = b"Apprendre la cryptographie, c'est fascinant."


def test_aller_retour():
    fichier = chiffrer(mdp, nom, donnees)
    assert dechiffrer(mdp, nom, fichier) == donnees


def test_deux_chiffrements_differents():
    assert chiffrer(mdp, nom, donnees) != chiffrer(mdp, nom, donnees)


def test_mauvais_mot_de_passe():
    fichier = chiffrer(mdp, nom, donnees)
    with pytest.raises(InvalidTag):
        dechiffrer("autre-mot-de-passe", nom, fichier)


def test_octet_modifie():
    fichier = bytearray(chiffrer(mdp, nom, donnees))
    fichier[50] ^= 1
    with pytest.raises(InvalidTag):
        dechiffrer(mdp, nom, bytes(fichier))


def test_nom_echange():
    fichier = chiffrer(mdp, "a.txt", donnees)
    with pytest.raises(InvalidTag):
        dechiffrer(mdp, "b.txt", fichier)


def test_rechiffrement():
    fichier = chiffrer(mdp, nom, donnees)
    nouveau = rechiffrer(mdp, "nouveau-mdp", nom, fichier)
    assert dechiffrer("nouveau-mdp", nom, nouveau) == donnees
    with pytest.raises(InvalidTag):
        dechiffrer(mdp, nom, nouveau)