# Template de service Docker

Dossier modèle à copier pour ajouter un nouveau service au dépôt. Il reprend la
structure, les conventions et les garde-fous déjà en place dans les services
existants, pour éviter de repartir d'une page blanche à chaque ajout.

> Ce dossier n'est **pas** un service installable : il contient des marqueurs
> `TODO` et des valeurs d'exemple (`exemple/image:1.2.3`). Il n'est ni installé,
> ni testé par les cibles `make` des autres services.

## Contenu

| Fichier | Rôle |
|---|---|
| `service.mk` | Paramètres du service (`SERVICE_IMAGE`, `DATA_DIR`, `SERVICE_PORT`) — **source unique**, partagée par le script et le makefile |
| `install_service.sh` | Script d'installation : chargement de `utils.sh`, parsing des options, génération du compose, vérifications puis démarrage |
| `makefile` | Cycle de vie du service (`install`, `start`, `stop`, `logs`, `update`, `update-repo`, `clean`, `uninstall`, `purge-data`) |
| `README.md` | Documentation du service |
| `CHANGELOG.md` | Historique au format Keep a Changelog |
| `VERSION.md` | Version du script, lue par le script d'installation |
| `TEMPLATE.md` | Ce fichier — à supprimer dans le service créé |

## Utilisation

```bash
# 1. Copier le template sous le nom du nouveau service
cp -r _template MonService
cd MonService

# 2. Renommer le script d'installation
mv install_service.sh install_monservice.sh

# 3. Supprimer la notice du template
rm TEMPLATE.md

# 4. Traiter tous les marqueurs restants
grep -rn "TODO" .
```

Puis renseigner `service.mk` (image, dossier de données, port) et ajuster
`INSTALL_SCRIPT` dans le `makefile`.

## `service.mk` : le fichier lu des deux côtés

`SERVICE_IMAGE`, `DATA_DIR` et `SERVICE_PORT` sont déclarées **une seule fois**,
dans `service.mk` : le makefile l'`include`, le script d'installation le `source`.
Sans ce partage, une image mise à jour d'un seul côté conduirait `make uninstall`
à supprimer une image différente de celle réellement installée.

{: .attention }
> Le fichier étant lu par Make **et** par Bash, il doit rester dans le
> sous-ensemble de syntaxe commun aux deux : affectations `NOM=valeur` sans
> espace autour du `=`, sans guillemets, sans référence à une autre variable.
> Un `NOM = valeur` casserait le `source` Bash ; des guillemets seraient
> conservés dans la valeur par Make.

Les deux consommateurs échouent avec un message explicite si le fichier est
absent ou s'il manque une variable, plutôt que de s'exécuter avec une valeur vide.

## Points à ne pas retirer

Ces éléments répondent à des problèmes déjà rencontrés dans le dépôt :

- Le bloc de résolution de `utils.sh` relatif au script (`SCRIPT_DIR`), avec repli
  sur une copie locale pour les clonages partiels.
- `validate_compose_file` avant tout lancement : le compose étant produit par un
  *heredoc*, une faute d'indentation YAML passerait sinon inaperçue.
- `check_container_exists` avec le chemin du compose **en argument**, pour ne pas
  interroger le compose du répertoire courant.
- `set -euo pipefail` et le quotage systématique des chemins.
- `docker image prune -f` **sans `-a`**, qui supprimerait les images des autres
  services du homelab.
- `purge-data` comme cible séparée et confirmée, jamais un effet de bord de
  `uninstall`.
- `service.mk` comme déclaration unique de l'image et du dossier de données : ne
  pas réintroduire ces valeurs en dur dans le script ou le makefile.

## Après la création du service

À faire une fois le service opérationnel :

- [ ] `.gitignore` — ajouter `MonService/docker-compose.yml` et `MonService/config.mk`
- [ ] `README.md` racine — ajouter le service à la liste « Contenu »
- [ ] `docs/services/index.md` — ajouter la ligne au tableau
- [ ] `docs/services/monservice.md` — créer la page de documentation

## Validation

```bash
# Syntaxe et bonnes pratiques (0 avertissement attendu)
cd MonService
shellcheck -x install_monservice.sh ../common/utils.sh

# Toutes les cibles parsent ?
for t in install update update-repo start stop clean logs uninstall purge-data; do
  printf '%-14s ' "$t"; make -n $t >/dev/null 2>&1 && echo OK || echo ECHEC
done
```

La checklist détaillée, avec les conventions et l'aide-mémoire des pièges
rencontrés, se trouve dans [`docs/contribuer.md`](../docs/contribuer.md).
