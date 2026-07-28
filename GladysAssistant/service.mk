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

# Images épinglées pour garder des installations reproductibles.
GLADYS_IMAGE=gladysassistant/gladys:v4
WATCHTOWER_IMAGE=nickfedor/watchtower:latest

# Dossier de données persistantes de Gladys sur l'hôte (base SQLite, sauvegardes).
DATA_DIR=/var/lib/gladysassistant

# Port d'écoute de Gladys. `network_mode: host` étant utilisé, ce port est
# directement celui de l'hôte : il sert aussi au test d'accès en fin d'installation.
SERVER_PORT=80
