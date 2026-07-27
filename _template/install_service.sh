#!/usr/bin/env bash

# ============================================================================
# TEMPLATE de script d'installation d'un service Docker.
#
# Pour créer un nouveau service :
#   cp -r _template MonService
#   cd MonService
#   mv install_service.sh install_monservice.sh
#   grep -rn "TODO" .          # puis traiter chaque marqueur
#
# Voir la checklist complète dans docs/contribuer.md
# ============================================================================

set -euo pipefail

script_version="0.0.1" # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="wderen"
readonly script_created="TODO-AAAA-MM-JJ" # TODO: date de création du script

# ========================
# Configuration
# ========================
# Résolution relative au script, et non au répertoire courant : le script reste
# lançable depuis n'importe où. On accepte aussi une copie locale de utils.sh
# pour les clonages partiels ne contenant pas le dossier common/.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UTILS_FILE=""
for candidate in "$SCRIPT_DIR/../common/utils.sh" "$SCRIPT_DIR/utils.sh"; do
  if [ -f "$candidate" ]; then
    UTILS_FILE="$candidate"
    break
  fi
done

if [ -z "$UTILS_FILE" ]; then
  echo "❌ Fichier utils.sh introuvable (cherché dans ../common/ et $SCRIPT_DIR)." >&2
  echo "   En cas de clonage partiel, incluez le dossier common/ :" >&2
  # TODO: remplacer MonService par le nom du dossier du service
  echo "   git sparse-checkout set common MonService" >&2
  exit 1
fi

# shellcheck source=../common/utils.sh
source "$UTILS_FILE"

# ========================
# Variables globales
# ========================
VERBOSE=false
INSTALL_DIR=""
DOCKER_LOGGING_MAX_SIZE="10m"
DOCKER_LOGGING_MAX_FILE="3"
IP_LOCALE=""

# Paramètres du service (SERVICE_IMAGE, DATA_DIR, SERVICE_PORT) : déclarés une
# seule fois dans service.mk, lui-même inclus par le makefile. Les deux
# consommateurs partagent ainsi la même image, évitant qu'un `make uninstall`
# ne cible une image différente de celle installée.
SERVICE_CONF="$SCRIPT_DIR/service.mk"
if [ ! -f "$SERVICE_CONF" ]; then
  echo "❌ Fichier service.mk introuvable dans $SCRIPT_DIR." >&2
  echo "   Il définit SERVICE_IMAGE, DATA_DIR et SERVICE_PORT." >&2
  exit 1
fi

# shellcheck source=service.mk
source "$SERVICE_CONF"

# Sous `set -u`, une variable absente du fichier ne serait détectée qu'au moment
# de son usage — on échoue ici, avec un message qui nomme la variable fautive.
for required in SERVICE_IMAGE DATA_DIR SERVICE_PORT; do
  if [ -z "${!required:-}" ]; then
    echo "❌ Variable $required non définie dans $SERVICE_CONF." >&2
    exit 1
  fi
done

# Durée maximale d'attente du démarrage du service (secondes).
STARTUP_TIMEOUT=60


# FUNCTION: print_usage
# DESC: Displays usage information and available script options to the user.
# ARGS: None
# OUTS: Prints usage instructions to standard output.
# RETS: None
function print_usage() {
    cat << EOF
Usage:
  -h|--help                  Displays this help
  -v|--verbose               Displays verbose output
EOF
}

# FUNCTION: parse_params
# DESC: Parses command-line arguments and sets corresponding variables for script options.
# ARGS: $@ (optional): List of arguments passed to the script.
# OUTS: Sets variables indicating which options and parameters were provided.
# RETS: None
function parse_params() {
  local param
  while [[ $# -gt 0 ]]; do
    param="$1"
    shift
    case $param in
      -h | --help)
        print_usage
        exit 0
        ;;
      -v | --verbose)
        VERBOSE=true
        ;;
      *)
        echo -e "${RED}❌ Option inconnue : $param${RESET}" >&2
        print_usage
        exit 1
        ;;
    esac
  done
}

# FUNCTION: ask_install_dir
# DESC: Prompts the user for the docker compose installation directory and validates the input.
# ARGS: None
# OUTS: Sets INSTALL_DIR variable and creates the directory if it does not exist.
# RETS: None
function ask_install_dir() {
  # TODO: adapter le nom du service et le chemin d'exemple.
  read -rp "📂 Entrez le chemin pour le fichier docker compose de MonService (ex: /opt/monservice) : " INSTALL_DIR

  INSTALL_DIR="$(echo "$INSTALL_DIR" | xargs)"
  INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

  if [ -z "$INSTALL_DIR" ]; then
    log_warn "Le chemin d'installation est vide, utilisation du dossier du script."
    INSTALL_DIR="$SCRIPT_DIR"
  fi

  echo "$INSTALL_DIR" | grep -qE '^/' || {
    log_error "Le chemin doit être absolu (commencer par /)."
    exit 1
  }

  if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
  fi

  log_info "Dossier d'installation configuré : $INSTALL_DIR"
}

# FUNCTION: get_ip
# DESC: Detects the active network interface and retrieves the local IP address.
# ARGS: None
# OUTS: Sets IP_LOCALE variable with the detected IP address.
# RETS: Returns 1 if no physical network interface is detected.
function get_ip() {

  log_info "🔍 Détection de l'interface réseau active..."

  local interface
  interface=$(ip -o link show | awk -F': ' '/state UP/ {print $2}' \
    | grep -Ev 'lo|docker|veth|virbr|br-|vmnet|tun' \
    | head -n 1)

  if [ -n "$interface" ]; then
      local ip_physique
      ip_physique=$(ip -4 addr show "$interface" | awk '/inet / {print $2}' | cut -d/ -f1)
      log_info "Interface active détectée : $interface"
      log_info "Adresse IP locale : $ip_physique"
      IP_LOCALE="$ip_physique"
  else
      log_warn "Aucune interface réseau physique détectée. Vérifiez votre connexion réseau."
      return 1
  fi
}

# FUNCTION: generate_docker_compose
# DESC: Generates the docker-compose.yml file for the service in the installation directory.
# ARGS: None (uses global INSTALL_DIR, DOCKER_LOGGING_MAX_SIZE, DOCKER_LOGGING_MAX_FILE)
# OUTS: Creates/overwrites $INSTALL_DIR/docker-compose.yml
# RETS: None
function generate_docker_compose() {
  log_info "Génération du docker-compose.yml dans $INSTALL_DIR"

  # Attention : `services:` doit bien figurer dans le heredoc, et les variables
  # interpolées utilisent la forme ${VAR:?msg} pour échouer tôt si elles sont vides.
  # TODO: décrire ici les services, volumes et ports réellement nécessaires.
  cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
services:
  monservice:
    image: ${SERVICE_IMAGE:?SERVICE_IMAGE not set}
    container_name: monservice
    restart: unless-stopped
    ports:
      - "${SERVICE_PORT:?SERVICE_PORT not set}:8080"
    environment:
      TZ: Europe/Paris
    volumes:
      - ${DATA_DIR:?DATA_DIR not set}:/data
    labels:
      # À conserver uniquement si le service doit être mis à jour par Watchtower.
      com.centurylinklabs.watchtower.enable: "true"
    logging:
      driver: "json-file"
      options:
        max-size: ${DOCKER_LOGGING_MAX_SIZE:?DOCKER_LOGGING_MAX_SIZE not set}
        max-file: "${DOCKER_LOGGING_MAX_FILE:?DOCKER_LOGGING_MAX_FILE not set}"
EOF

  log_success "docker-compose.yml généré dans $INSTALL_DIR"
}

# FUNCTION: start_stack
# DESC: Check if Docker and Docker Compose are installed and running, then starts the stack using docker-compose.
# ARGS: None (uses global INSTALL_DIR)
# OUTS: Starts the Docker containers of the service.
# RETS: Exits with error if Docker or Docker Compose are not installed/running.
function start_stack() {
  # Vérification de la présence de Docker et Docker Compose
  check_docker_compose

  # Vérification si Docker est en cours d'exécution
  check_docker_running

  # Validation de la syntaxe du fichier généré avant toute tentative de lancement
  validate_compose_file "${INSTALL_DIR}/docker-compose.yml"

  # Vérification des conflits de conteneurs
  check_container_exists "${INSTALL_DIR}/docker-compose.yml"

  # Lancement des containers
  log_info "Démarrage des containers..."
  (cd "$INSTALL_DIR" && docker compose up -d)
}

# FUNCTION: test_service_access
# DESC: Checks if the service is accessible via the detected local IP address.
# ARGS: None (uses global IP_LOCALE, SERVICE_PORT, STARTUP_TIMEOUT)
# OUTS: Prints success or error message based on accessibility.
# RETS: Returns 1 if the service is unreachable before the timeout.
function test_service_access() {
  log_info "🌐 Test d'accès au service"

  local url="http://${IP_LOCALE}:${SERVICE_PORT}"
  local elapsed=0
  local http_code=""
  local ready=false

  # Attente active : un premier démarrage (migrations, initialisation) peut
  # prendre plusieurs dizaines de secondes avant que le service ne réponde.
  echo -n "⏳ Attente du démarrage du service "
  while [ "$elapsed" -lt "$STARTUP_TIMEOUT" ]; do
    http_code=$(curl -k --silent --show-error --output /dev/null \
      --max-time 5 --write-out '%{http_code}' "$url" 2>/dev/null || echo "000")

    # Tout code 2xx/3xx signifie que le serveur répond (redirection incluse).
    if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
      ready=true
      break
    fi

    echo -n "."
    sleep 3
    elapsed=$((elapsed + 3))
  done
  echo

  if [ "$ready" != "true" ]; then
    log_error "⚠️ Impossible d'accéder au service après ${STARTUP_TIMEOUT}s (dernier code HTTP : ${http_code})."
    log_error "Vérifiez les logs avec : cd \"$INSTALL_DIR\" && docker compose logs -f"
    return 1
  fi

  log_success "🎉 Le service est prêt et accessible à l'adresse suivante: $url"

  local reponse
  read -rp "👉 Voulez-vous ouvrir le service dans votre navigateur ? [o/N] " reponse

  if [[ "$reponse" =~ ^[oOyY]$ ]]; then
    if command_exists xdg-open; then
      xdg-open "$url" >/dev/null 2>&1 &
    elif command_exists open; then
      open "$url" >/dev/null 2>&1 &   # macOS
    elif command_exists start; then
      start "$url" >/dev/null 2>&1 &  # Windows (Git Bash, Cygwin)
    else
      log_warn "Impossible de détecter une commande pour ouvrir le navigateur automatiquement."
    fi
  fi
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
# RETS: None
function main() {
  parse_params "$@"

  # TODO: adapter le nom du service dans le message de démarrage.
  log_info "Démarrage de l'installation de MonService."
  log_info "Auteur : ${script_author}"
  log_info "Date de création : ${script_created}"
  if [ -f VERSION.md ]; then
    local file_version
    file_version=$(head -n 1 VERSION.md | xargs)
    if [[ $file_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      script_version="$file_version"
    fi
  fi
  log_info "Version du script : ${script_version}"

  # Vérification des dépendances
  check_dependencies

  # Étapes de l'installation
  ask_install_dir

  # génération du fichier .mk
  generate_config_mk "$INSTALL_DIR"

  # étapes de configuration du docker-compose
  get_ip
  generate_docker_compose

  # Vérification et démarrage des containers
  start_stack

  # Test d'accès au service
  test_service_access
}

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi
