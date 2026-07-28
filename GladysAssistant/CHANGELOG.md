![Changelog v0.0.1](https://img.shields.io/badge/CHANGELOG-v0.0.1-green) 
# CHANGELOG
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Security
- Watchtower limité aux conteneurs labellisés (`--label-enable`) pour ne plus
  mettre à jour l'ensemble des conteneurs de l'hôte

### Added
- `service.mk` : déclaration unique des paramètres du service (`GLADYS_IMAGE`,
  `WATCHTOWER_IMAGE`, `DATA_DIR`, `SERVER_PORT`), inclus par le `makefile` et
  sourcé par `install_gladys.sh`. Le `makefile` et le script échouent avec un
  message explicite si le fichier ou une variable manque
- Cible `make update` forçant la mise à jour des images Docker (`pull` +
  recréation des conteneurs concernés + nettoyage des images obsolètes), sans
  attendre le prochain passage de Watchtower
- Validation de la syntaxe du `docker-compose.yml` généré avant lancement
  (`validate_compose_file`)
- Cible `make purge-data` avec confirmation explicite pour la suppression des
  données persistantes
- Images Docker épinglées via les variables `GLADYS_IMAGE` / `WATCHTOWER_IMAGE`

### Changed
- `GLADYS_IMAGE` et `DATA_DIR` ne sont plus déclarées à la fois dans le
  `makefile` et dans `install_gladys.sh` : une mise à jour d'un seul des deux
  fichiers pouvait conduire `make uninstall` à supprimer une image différente de
  celle réellement installée. Les valeurs viennent désormais de `service.mk`
- `DATA_DIR` et `SERVER_PORT` remplacent les chemins et le port codés en dur dans
  le `docker-compose.yml` généré (le fichier produit reste identique à valeurs
  par défaut inchangées)
- `utils.sh` déplacé vers `common/utils.sh` à la racine du dépôt pour être
  partagé entre services ; repli sur une copie locale si `common/` est absent
  (clonage partiel). Le sparse-checkout documenté devient
  `git sparse-checkout set common GladysAssistant`
- `utils.sh` résolu relativement au script et non au répertoire courant :
  `install_gladys.sh` est désormais lançable depuis n'importe où
- `update_repo` utilise `git rev-parse --show-toplevel` au lieu d'un test sur
  `.git` dans le répertoire courant, qui échouait depuis un dossier de service
- **`make update` change de sémantique** : il met désormais à jour les images
  Docker. La mise à jour du dépôt Git est déplacée vers `make update-repo`
  (l'appel, auparavant commenté, était de plus non fonctionnel)
- `make uninstall` ne supprime plus les données de `/var/lib/gladysassistant`
  sans confirmation (déplacé vers `make purge-data`)
- `make clean` ne supprime plus que les images sans tag au lieu de toutes les
  images inutilisées de l'hôte
- Test d'accès à Gladys : attente active avec délai configurable et acceptation
  des codes HTTP 2xx/3xx, au lieu d'un `sleep 10` suivi d'un test strict sur
  `HTTP/1.1 200`
- `config.mk` généré avec `:=` et sans guillemets, qui produisaient des chemins
  malformés dans les commandes Make
- Les niveaux WARN/ERROR/SUCCESS sont toujours affichés ; seul INFO reste
  conditionné à `--verbose`
- Migration de `containrrr/watchtower` (non maintenu) vers `nickfedor/watchtower`
- `.gitignore` restreint aux artefacts réellement générés, par service

### Fixed
- `check_container_exists` interrogeait le compose du répertoire courant au lieu
  du fichier passé en argument
- Message d'option inconnue affichant l'argument suivant au lieu de l'option
  fautive (`$1` après `shift`)
- Chemins non quotés (`$IP_LOCALE`, `$INSTALL_DIR`) dans plusieurs commandes

### Removed
- Dépendance à `yq`, remplacée par `docker compose config --format json`
- `temp.sh`, template de 933 lignes non utilisé
- Variable `run_as_root` déclarée et jamais utilisée

## [0.0.1] - 2025-08-27
### Added
- Implement 'install_gladys.sh script'
- Implement 'utils.sh' script
- Implement 'makefile'
