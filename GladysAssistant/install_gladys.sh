#!/usr/bin/env bash

set -euo pipefail

script_version="0.0.1" # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="wderen"
readonly script_created="2025-08-27"

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
  echo "   git sparse-checkout set common GladysAssistant" >&2
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

# Images épinglées pour garder des installations reproductibles.
GLADYS_IMAGE="gladysassistant/gladys:v4"
WATCHTOWER_IMAGE="nickfedor/watchtower:latest"

# Durée maximale d'attente du démarrage de Gladys (secondes).
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

# FUNCTION: parse_parameters
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
# DESC: Prompts the user for the Gladys docker compose installation directory and validates the input.
# ARGS: None
# OUTS: Sets INSTALL_DIR variable and creates the directory if it does not exist.
# RETS: None
function ask_install_dir() {
  read -rp "📂 Entrez le chemin pour le ficher docker compose de Gladys (ex: /opt/gladys) : " INSTALL_DIR

  INSTALL_DIR="$(echo "$INSTALL_DIR" | xargs)"
  INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
  
  if [ -z "$INSTALL_DIR" ]; then
    log_warn "Le chemin d'installation est vide, utilisation du dossier du script."
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

  log_info "Détection de l'adresse IP locale..."
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
# DESC: Generates the docker-compose.yml file for Gladys and Watchtower in the installation directory.
# ARGS: None (uses global INSTALL_DIR, DOCKER_LOGGING_MAX_SIZE, DOCKER_LOGGING_MAX_FILE)
# OUTS: Creates/overwrites $INSTALL_DIR/docker-compose.yml
# RETS: None
function generate_docker_compose() {
  log_info "Génération du docker-compose.yml dans $INSTALL_DIR"

  cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
services:
  gladys:
    image: ${GLADYS_IMAGE:?GLADYS_IMAGE not set}
    container_name: gladys
    restart: unless-stopped
    privileged: true
    network_mode: host
    cgroup: host
    environment:
      NODE_ENV: production
      SQLITE_FILE_PATH: /var/lib/gladysassistant/gladys-production.db
      SERVER_PORT: 80
      TZ: Europe/Paris
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/gladysassistant:/var/lib/gladysassistant
      - /dev:/dev
      - /run/udev:/run/udev:ro
    labels:
      com.centurylinklabs.watchtower.enable: "true"
    logging:
      driver: "json-file"
      options:
        max-size: ${DOCKER_LOGGING_MAX_SIZE:?DOCKER_LOGGING_MAX_SIZE not set}
        max-file: "${DOCKER_LOGGING_MAX_FILE:?DOCKER_LOGGING_MAX_FILE not set}"

  watchtower:
    image: ${WATCHTOWER_IMAGE:?WATCHTOWER_IMAGE not set}
    container_name: watchtower
    restart: unless-stopped
    # --label-enable : ne met à jour que les conteneurs explicitement labellisés,
    # pour ne pas toucher aux autres services du homelab.
    command: --cleanup --include-restarting --label-enable
    environment:
      TZ: Europe/Paris
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    logging:
      driver: "json-file"
      options:
        max-size: ${DOCKER_LOGGING_MAX_SIZE:?DOCKER_LOGGING_MAX_SIZE not set}
        max-file: "${DOCKER_LOGGING_MAX_FILE:?DOCKER_LOGGING_MAX_FILE not set}"
EOF

  log_success "docker-compose.yml généré dans $INSTALL_DIR"
}


# FUNCTION: start_stack
# DESC: Check if Docker and Docker Compose are installed and running, then starts the Gladys stack using docker-compose.
# ARGS: None (uses global INSTALL_DIR)
# OUTS: Starts Docker containers for Gladys and Watchtower.
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

# FUNCTION: test_gladys_access
# DESC: Checks if Gladys Assistant is accessible via the detected local IP address.
# ARGS: None (uses global IP_LOCALE)
# OUTS: Prints success or error message based on accessibility.
# RETS: None 
function test_gladys_access() {
  log_info "🌐 Test d'accès à Gladys Assistant"

  local url="http://${IP_LOCALE}"
  local elapsed=0
  local http_code=""
  local ready=false

  # Attente active : Gladys peut mettre plusieurs dizaines de secondes à répondre
  # au premier démarrage (migrations SQLite).
  echo -n "⏳ Attente du démarrage de Gladys "
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
    log_error "⚠️ Impossible d’accéder à Gladys après ${STARTUP_TIMEOUT}s (dernier code HTTP : ${http_code})."
    log_error "Vérifiez les logs avec : cd \"$INSTALL_DIR\" && docker compose logs -f"
    return 1
  fi

  log_success "🎉 Gladys Assistant est prêt et accessible à l'adresse suivante: $url"

  local reponse
  read -rp "👉 Voulez-vous ouvrir Gladys Assistant dans votre navigateur ? [o/N] " reponse

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

  log_info "Démarrage de l'installation de Gladys Assistant."
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

  # étapes de configuration des certificats et docker-compose
  get_ip
  generate_docker_compose

  # Vérification et démarrage des containers
  start_stack

  # Tests d'accès à Gladys
  test_gladys_access
}

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi
