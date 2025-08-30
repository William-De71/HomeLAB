#!/usr/bin/env bash

set -euo pipefail

script_version="0.0.1" # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="wderen"
readonly script_created="2025-08-27"
readonly run_as_root=-1 # run_as_root: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root

# ========================
# Configuration
# ========================
if [ ! -f ./utils.sh ]; then
  echo "❌ Fichier utils.sh introuvable dans le dossier courant." >&2
  exit 1
fi
source ./utils.sh

# ========================
# Variables globales
# ========================
VERBOSE=false
INSTALL_DIR=""
DOCKER_LOGGING_MAX_SIZE="10m"
DOCKER_LOGGING_MAX_FILE="3"
IP_LOCALE=""


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
        echo -e "${RED}❌ Option inconnue : $1${RESET}" >&2
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
    image: gladysassistant/gladys:v4
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
    logging:
      driver: "json-file"
      options:
        max-size: ${DOCKER_LOGGING_MAX_SIZE:?DOCKER_LOGGING_MAX_SIZE not set}
        max-file: ${DOCKER_LOGGING_MAX_FILE:?DOCKER_LOGGING_MAX_FILE not set}
  
  watchtower:
    image: containrrr/watchtower
    restart: unless-stopped
    container_name: watchtower
    command: --cleanup --include-restarting
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    logging:
      options:
        max-size: ${DOCKER_LOGGING_MAX_SIZE:?DOCKER_LOGGING_MAX_SIZE not set}
        max-file: ${DOCKER_LOGGING_MAX_FILE:?DOCKER_LOGGING_MAX_FILE not set}
        
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

  # Vérification des conflits de conteneurs
  check_container_exists ${INSTALL_DIR}/docker-compose.yml

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

  sleep 10 # attente que Gladys démarre

  if curl -k --silent --head http://$IP_LOCALE | grep "HTTP/1.1 200" >/dev/null; then
    log_success "🎉 Gladys Assistant est prêt et accessible à l'adresse suivante: http://$IP_LOCALE"

    read -p "👉 Voulez-vous ouvrir Gladys Assistant dans votre navigateur ? [o/N] " reponse

    if [[ "$reponse" =~ ^[oOyY]$ ]]; then
      if command -v xdg-open > /dev/null; then
        xdg-open "http://$IP_LOCALE" >/dev/null 2>&1 &
      elif command -v open > /dev/null; then
        open "http://$IP_LOCALE" >/dev/null 2>&1 &   # macOS
      elif command -v start > /dev/null; then
        start "http://$IP_LOCALE" >/dev/null 2>&1 &  # Windows (Git Bash, Cygwin)
      else
        echo "Impossible de détecter une commande pour ouvrir le navigateur automatiquement."
      fi
    fi
    
  else
    log_error "⚠️ Impossible d’accéder à Gladys. Vérifiez les logs de vos conteneurs."
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
