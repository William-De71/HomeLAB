# ============================================================================
# Paramètres du service — source unique de vérité.
#
# Ce fichier est à la fois inclus par le makefile et sourcé par le script
# d'installation. Il doit donc rester dans le sous-ensemble de syntaxe commun
# à Make et à Bash :
#
#   - affectations `NOM=valeur` uniquement, SANS espace autour du `=` ;
#   - pas de guillemets (Make les garderait dans la valeur) ;
#   - pas de référence à une autre variable, ni de substitution ;
#   - commentaires `#` en début de ligne.
#
# Toute autre construction casserait l'un des deux consommateurs.
# ============================================================================

# TODO: image du service, épinglée sur un tag explicite (jamais `latest`).
SERVICE_IMAGE=exemple/image:1.2.3

# TODO: dossier de données persistantes du service sur l'hôte.
DATA_DIR=/var/lib/monservice

# TODO: port exposé par le service sur l'hôte (utilisé par le test d'accès).
SERVICE_PORT=8080
