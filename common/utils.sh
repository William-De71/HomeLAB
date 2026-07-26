#!/usr/bin/env bash

# ========================
# Couleurs pour les logs
# ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m' # No Color

# FUNCTION: log
# DESC: function to log messages with timestamp and level (INFO, WARN, ERROR, SUCCESS).
# ARGS: level, message
# OUTS: outputs formatted log message
# RETS: None
log() {
  local level="$1"
  local msg="$2"

  # INFO n'est affiché qu'en mode verbeux ; les autres niveaux sont toujours
  # visibles, sans quoi un script qui sort en erreur ne dirait rien à l'utilisateur.
  if [ "$level" = "INFO" ] && [ "${VERBOSE:-false}" != "true" ]; then
    return 0
  fi

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  case "$level" in
    INFO)     echo -e "[$timestamp] [${CYAN}INFO${RESET}]  $msg" ;;
    WARN)     echo -e "[$timestamp] [${YELLOW}WARN${RESET}]  $msg" ;;
    ERROR)    echo -e "[$timestamp] [${RED}ERROR${RESET}] $msg" 1>&2 ;;
    SUCCESS)  echo -e "[$timestamp] [${GREEN}SUCCESS${RESET}] $msg" ;;
    *)        echo -e "[$timestamp] [$level] $msg" ;;
  esac
}

log_success() { log "SUCCESS" "$1"; }
log_info()  { log "INFO"  "$1"; }
log_warn()  { log "WARN"  "$1"; }
log_error() { log "ERROR" "$1"; }

# FUNCTION: command_exists
# DESC: Verifies if a command exists in the system.
# ARGS: command name
# OUTS: None
# RETS: Returns 0 if command exists, 1 otherwise.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# FUNCTION: check_dependencies
# DESC: Verifies that all required dependencies are installed before proceeding.
# ARGS: None
# OUTS: Prints missing dependencies if any are not found.
# RETS: returns 1 if any dependencies are missing.
check_dependencies() {
  local dependencies=("docker" "git" "ip" "awk" "grep" "head" "cut" "curl")
  local missing_deps=()
  for cmd in "${dependencies[@]}"; do
    if ! command_exists "$cmd"; then
      missing_deps+=("$cmd")
    fi
  done
  if [ ${#missing_deps[@]} -ne 0 ]; then
    log_error "Les dépendances suivantes sont manquantes : ${missing_deps[*]}"
    log_info "Veuillez les installer avant de continuer."
    exit 1
  fi
}

# FUNCTION: check_docker_running
# DESC: Verifies that Docker is installed and the daemon is running.
# ARGS: None
# OUTS: None
# RETS: returns 1 if Docker is not running.
check_docker_running() {
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker ne semble pas être en cours d'exécution. Veuillez démarrer Docker et réessayer."
    exit 1
  fi
}

# FUNCTION: check_docker_compose
# DESC: Verifies that Docker Compose is installed (either v1 or v2).
# ARGS: None
# OUTS: None
# RETS: returns 1 if Docker Compose is not found.
check_docker_compose() {
  if ! command_exists "docker-compose" && ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose n'est pas installé. Veuillez l'installer et réessayer."
    exit 1
  fi
}

# FUNCTION: validate_compose_file
# DESC: Verifies that the generated docker-compose file is syntactically valid.
# ARGS: $1: path to the docker-compose file
# OUTS: Prints the compose error output if validation fails.
# RETS: Exits with error if the file is invalid.
validate_compose_file() {
  local compose_file="$1"

  if [ ! -f "$compose_file" ]; then
    log_error "Le fichier $compose_file n'existe pas."
    exit 1
  fi

  log_info "Validation de la syntaxe de $compose_file"
  local compose_output
  if ! compose_output=$(docker compose -f "$compose_file" config -q 2>&1); then
    log_error "Le fichier $compose_file est invalide :"
    echo "$compose_output" >&2
    exit 1
  fi
  log_info "Syntaxe du fichier docker-compose valide."
}

# FUNCTION: check_container_exists
# DESC: Verifies that no Docker containers defined in the docker-compose file already exist.
# ARGS: $1: path to the docker-compose file
# OUTS: Prints error and exits if any container already exists.
# RETS: Exits with error if a container conflict is found.
check_container_exists() {
  # Vérifie qu’un argument a été fourni
  if [[ $# -lt 1 ]]; then
    log_error "Usage: check_container_exists <docker-compose-file.yml>"
    exit 1
  fi

  local compose_file="$1"

  # Vérifier que le fichier docker-compose existe
  if [ ! -f "$compose_file" ]; then
    log_error "Le fichier $compose_file n'existe pas."
    exit 1
  fi

  # Récupérer les noms de conteneurs déclarés, en interrogeant bien le fichier
  # passé en argument (et non le compose du répertoire courant).
  local existing_containers container_names
  existing_containers=$(docker ps -a --format '{{.Names}}')
  container_names=$(docker compose -f "$compose_file" config --format json \
    | grep -oP '"container_name":\s*"\K[^"]+')

  local cname
  while IFS= read -r cname; do
    [ -z "$cname" ] && continue
    log_info "🔍 Vérification du conteneur: $cname"

    if grep -qx "$cname" <<< "$existing_containers"; then
      log_error "⚠️  Le conteneur '${cname}' existe déjà. Arrêt..."
      exit 1
    fi
  done <<< "$container_names"

  log_info "Aucun conflit détecté, lancement..."
}

# FUNCTION: generate_config_mk
# DESC: Generates a config.mk file with the specified installation directory.
# ARGS: install_dir
# OUTS: outputs config.mk file
# RETS: None
generate_config_mk() {
  local install_dir="$1"
  # local domain="$2"

  log_info "Génération du fichier config.mk"
  # Pas de guillemets autour de la valeur : Make les traiterait comme faisant
  # partie du chemin, produisant des commandes du type `cd ""/path""`.
  cat > config.mk <<EOF
# Fichier de configuration généré automatiquement
INSTALL_DIR := ${install_dir}
EOF
  log_success "Fichier config.mk généré avec succès."
}

# FUNCTION: update_repo
# DESC: updates the current Git repository by pulling the latest changes.
# ARGS: None
# OUTS: None
# RETS: None
update_repo() {
  # rev-parse fonctionne depuis n'importe quel sous-dossier du dépôt, contrairement
  # à un test sur la présence de .git dans le répertoire courant.
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    log_error "Ce n’est pas un dépôt Git."
    exit 1
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"

  log_info "Mise à jour du dépôt $repo_root..."
  git -C "$repo_root" pull --rebase || {
    log_error "Échec de la mise à jour du dépôt."
    exit 1
  }
  log_success "Mise à jour terminée."
}

