#!/usr/bin/env python3
"""surveiller.py : affiche les jours restants de chaque certificat d'un dossier.

Usage :  python3 surveiller.py DOSSIER
Code de sortie (pour un outil de supervision) :
    0 = tout est OK
    1 = au moins une ALERTE   (moins de 30 jours)
    2 = au moins un CRITIQUE  (moins de 7 jours, ou erreur)
"""
import sys
from datetime import datetime, timezone
from pathlib import Path

from cryptography import x509

SEUIL_ALERTE = 30      # jours
SEUIL_CRITIQUE = 7     # jours


def niveau(jours):
    """Donne le nom du niveau et son code de sortie selon les jours restants."""
    if jours < SEUIL_CRITIQUE:
        return "CRITIQUE", 2
    if jours < SEUIL_ALERTE:
        return "ALERTE", 1
    return "OK", 0


def lire_certificats(fichier):
    """Lit tous les certificats d'un fichier PEM (liste vide si ce n'en est pas un)."""
    try:
        return x509.load_pem_x509_certificates(fichier.read_bytes())
    except (ValueError, OSError):
        return []          # clé privée, CRL, texte... : on ignore


def date_de_fin(certificat):
    """Date d'expiration du certificat (avec fuseau UTC)."""
    try:
        return certificat.not_valid_after_utc                 # cryptography >= 42
    except AttributeError:
        return certificat.not_valid_after.replace(tzinfo=timezone.utc)


def main():
    if len(sys.argv) != 2:
        print("Usage : python3 surveiller.py DOSSIER")
        return 2
    dossier = Path(sys.argv[1])
    if not dossier.is_dir():
        print(f"Dossier introuvable : {dossier}")
        return 2

    maintenant = datetime.now(timezone.utc)
    pire = 0               # le pire niveau rencontré : c'est le code de sortie
    trouves = 0

    for fichier in sorted(dossier.iterdir()):
        for certificat in lire_certificats(fichier):
            trouves += 1
            jours = (date_de_fin(certificat) - maintenant).days
            nom, code = niveau(jours)
            pire = max(pire, code)
            sujet = certificat.subject.rfc4514_string()
            print(f"{nom:<9} {jours:>5} jours  {fichier.name}  ({sujet})")

    if trouves == 0:
        print("Aucun certificat trouvé.")
        return 2
    return pire


if __name__ == "__main__":
    sys.exit(main())
