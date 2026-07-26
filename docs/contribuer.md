---
title: Ajouter un service
layout: default
nav_order: 5
---

# Ajouter un service
{: .no_toc }

Checklist pour intégrer un nouveau service Docker au dépôt en respectant les
conventions existantes.
{: .fs-5 .fw-300 }

## Sommaire
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## 1. Créer la structure

```bash
mkdir MonService
cd MonService
```

Fichiers attendus :

```
MonService/
├── install.sh        # script d'installation
├── makefile          # cycle de vie
├── README.md         # doc du service
├── CHANGELOG.md      # format Keep a Changelog
└── VERSION.md        # version du script (ex: 0.0.1)
```

{: .astuce }
> Le plus simple est de partir de `GladysAssistant/` comme modèle :
> `cp GladysAssistant/{makefile,CHANGELOG.md,VERSION.md} MonService/`

## 2. Charger les utilitaires partagés

En tête du script d'installation, reprenez ce bloc à l'identique — il résout
`utils.sh` relativement au script et gère le repli en clonage partiel :

```bash
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
  echo "   git sparse-checkout set common MonService" >&2
  exit 1
fi

# shellcheck source=../common/utils.sh
source "$UTILS_FILE"
```

## 3. Respecter le flux d'installation

Reprenez l'ordre des étapes, qui place les vérifications avant les actions :

```bash
function main() {
  parse_params "$@"

  check_dependencies          # outils requis présents ?
  ask_install_dir             # où installer ?
  generate_config_mk "$INSTALL_DIR"
  generate_docker_compose     # produire la configuration

  start_stack                 # valide, vérifie les conflits, puis démarre
}
```

Et dans `start_stack` :

```bash
function start_stack() {
  check_docker_compose
  check_docker_running
  validate_compose_file "${INSTALL_DIR}/docker-compose.yml"   # ← indispensable
  check_container_exists "${INSTALL_DIR}/docker-compose.yml"

  log_info "Démarrage des containers..."
  (cd "$INSTALL_DIR" && docker compose up -d)
}
```

{: .attention }
> N'omettez pas `validate_compose_file`. Le compose étant produit par un
> *heredoc*, une simple faute d'indentation YAML passerait inaperçue jusqu'au
> lancement. Cette validation a déjà permis d'attraper un `services:` manquant
> et un saut de ligne avalé par une substitution de commande.

## 4. Écrire le makefile

Cibles minimales attendues, pour rester cohérent entre services :

```makefile
SHELL := /bin/bash

MONSERVICE_IMAGE ?= exemple/image:1.2.3
DATA_DIR ?= /var/lib/monservice

UTILS_FILE := $(firstword $(wildcard ../common/utils.sh utils.sh))

ifneq ("$(wildcard config.mk)","")
  include config.mk
  export INSTALL_DIR
endif

INSTALL_DIR ?= $(CURDIR)
ifeq ($(strip $(INSTALL_DIR)),)
  INSTALL_DIR := $(CURDIR)
endif

.PHONY: all install update update-repo start stop clean logs uninstall purge-data
```

| Cible | Doit faire |
|---|---|
| `install` | Appeler le script avec `$(ARGS)` |
| `start` / `stop` | `docker compose up -d` / `down` |
| `logs` | `docker compose logs -f` |
| `update` | `pull` + `up -d` + `prune -f` (images Docker) |
| `update-repo` | `update_repo` depuis `utils.sh` (dépôt Git) |
| `clean` | `docker image prune -f` — **sans `-a`** |
| `uninstall` | Arrêter et nettoyer, **sans toucher aux données** |
| `purge-data` | Supprimer les données, **avec confirmation** |

## 5. Conventions à respecter

### Sécurité et robustesse

- `set -euo pipefail` en tête de script.
- Toujours **quoter** les variables de chemin : `"$INSTALL_DIR"`.
- **Épingler** les images (`image:1.2.3`), jamais `latest` pour un service.
- Ne jamais utiliser `docker image prune -a` : cela supprimerait les images des
  autres services du homelab.
- Toute suppression de données doit être une cible séparée et confirmée.
- Si le service doit être mis à jour par Watchtower, ajoutez-lui le label
  `com.centurylinklabs.watchtower.enable: "true"`.

### Journalisation

Utilisez les fonctions de `common/utils.sh` plutôt que `echo` :

```bash
log_info "Message de détail (visible avec --verbose)"
log_warn "Avertissement (toujours visible)"
log_error "Erreur (toujours visible, sur stderr)"
log_success "Succès (toujours visible)"
```

### Documentation des fonctions

```bash
# FUNCTION: nom_fonction
# DESC: Ce que fait la fonction.
# ARGS: $1: description de l'argument
# OUTS: Effets de bord (fichiers créés, variables modifiées)
# RETS: Codes de retour / conditions de sortie
function nom_fonction() {
```

## 6. Mettre à jour le `.gitignore`

Les artefacts générés doivent être exclus, **par service** :

```gitignore
MonService/docker-compose.yml
MonService/config.mk
```

{: .note }
> Les patterns sont volontairement nominatifs plutôt que globaux
> (`docker-compose.yml` seul). Ainsi, un service dont le compose serait écrit à
> la main resterait versionné, sans exclusion silencieuse.

## 7. Valider avant de committer

```bash
# Syntaxe et bonnes pratiques (0 avertissement attendu)
cd MonService
shellcheck -x install.sh ../common/utils.sh

# Toutes les cibles parsent ?
for t in install update update-repo start stop clean logs uninstall purge-data; do
  printf '%-14s ' "$t"; make -n $t >/dev/null 2>&1 && echo OK || echo ECHEC
done
```

Testez aussi le compose généré :

```bash
docker compose -f "$INSTALL_DIR/docker-compose.yml" config -q && echo VALID
```

{: .astuce }
> `shellcheck -x` doit être lancé **depuis le dossier du service** pour que le
> chemin relatif `../common/utils.sh` se résolve. Depuis la racine du dépôt, il
> signalerait un faux positif `SC1091`.

## 8. Mettre à jour la documentation

- [ ] `README.md` du service
- [ ] `CHANGELOG.md` du service (section `[Unreleased]`)
- [ ] `README.md` racine — ajouter le service à la liste « Contenu »
- [ ] `docs/services/index.md` — ajouter la ligne au tableau
- [ ] `docs/services/monservice.md` — créer la page

Pour la page de documentation, reprenez l'en-tête suivant :

```yaml
---
title: Mon Service
layout: default
parent: Services
nav_order: 2
---
```

## Aide-mémoire des pièges rencontrés

Erreurs déjà corrigées dans ce dépôt, à ne pas reproduire :

| Piège | Conséquence |
|---|---|
| `services:` oublié dans le heredoc | Compose invalide, échec au lancement |
| `$(...)` autour d'un bloc multiligne | Saut de ligne final supprimé → YAML cassé |
| Guillemets dans `config.mk` | Make produit `cd ""/chemin""` |
| `$1` utilisé après `shift` | Message d'erreur désignant la mauvaise option |
| `VERBOSE` non défini avant `source utils.sh` | `unbound variable` sous `set -u` |
| Test sur `.git` dans le répertoire courant | Échoue depuis un sous-dossier ; utiliser `git rev-parse --show-toplevel` |
| `docker compose config` sans `-f` | Lit le compose du répertoire courant, pas celui visé |
| `log_error` conditionné à `--verbose` | Script qui échoue sans afficher de cause |
