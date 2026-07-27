---
title: Dossier template
layout: default
nav_order: 6
---

# Dossier `_template`
{: .no_toc }

Référence du dossier modèle fourni par le dépôt : ce qu'il contient, pourquoi
chaque garde-fou s'y trouve, et comment l'adapter à un nouveau service.
{: .fs-5 .fw-300 }

## Sommaire
{: .no_toc .text-delta }

1. TOC
{:toc}

---

{: .note }
> Cette page décrit le **contenu** du modèle. Pour la marche à suivre pas à pas,
> voir [Ajouter un service]({{ site.baseurl }}/contribuer/).

## À quoi il sert

Chaque service du dépôt suit la même structure : un script d'installation qui
génère un `docker-compose.yml`, un `makefile` qui pilote le cycle de vie, et un
`service.mk` qui centralise les paramètres. Le dossier `_template/` matérialise
cette structure pour éviter de la reconstruire — et de réintroduire des défauts
déjà corrigés — à chaque ajout.

Ce n'est **pas** un service installable : il contient des marqueurs `TODO` et des
valeurs d'exemple (`exemple/image:1.2.3`). Le préfixe `_` le distingue des
dossiers de service et le place en tête de listing.

## Contenu

| Fichier | Rôle |
|---|---|
| `service.mk` | Paramètres du service — **source unique**, partagée par le script et le makefile |
| `install_service.sh` | Script d'installation : chargement de `utils.sh`, options, génération du compose, vérifications, démarrage |
| `makefile` | Cycle de vie (`install`, `start`, `stop`, `logs`, `update`, `update-repo`, `clean`, `uninstall`, `purge-data`) |
| `README.md` | Documentation du service |
| `CHANGELOG.md` | Historique au format Keep a Changelog |
| `VERSION.md` | Version du script, lue par le script d'installation |
| `TEMPLATE.md` | Notice du modèle — **à supprimer** dans le service créé |

## Créer un service à partir du modèle

```bash
cp -r _template MonService
cd MonService
mv install_service.sh install_monservice.sh
rm TEMPLATE.md
grep -rn "TODO" .        # puis traiter chaque marqueur
```

Il reste ensuite à renseigner `service.mk` et à ajuster `INSTALL_SCRIPT` dans le
`makefile`. Les marqueurs `TODO` couvrent les valeurs à remplacer : image, dossier
de données, port, nom du service dans les messages et le compose.

## `service.mk` : le fichier lu des deux côtés

L'image, le dossier de données et le port sont nécessaires au script
d'installation **comme** au makefile. Ils sont donc déclarés une seule fois :

```make
SERVICE_IMAGE=exemple/image:1.2.3
DATA_DIR=/var/lib/monservice
SERVICE_PORT=8080
```

Le makefile l'`include`, le script le `source`.

{: .attention }
> Le fichier est lu par Make **et** par Bash : n'y mettez que des affectations
> `NOM=valeur`, sans espace autour du `=`, sans guillemets et sans référence à
> une autre variable. Un `NOM = valeur` casserait le `source` Bash ; des
> guillemets seraient conservés dans la valeur par Make, produisant des chemins
> du type `""/var/lib/monservice""`.

Les deux consommateurs échouent avec un message explicite si le fichier ou une
variable manque, plutôt que de s'exécuter avec une valeur vide — sans quoi
`make uninstall` lancerait un `docker image rm -f` sans argument.

{: .note }
> Sans ce partage, l'image serait déclarée des deux côtés. Une mise à jour d'un
> seul fichier suffirait à ce que `make uninstall` supprime une image différente
> de celle réellement installée.

## Points à ne pas retirer

Ces éléments répondent à des problèmes déjà rencontrés dans le dépôt. Leur
suppression réintroduirait un défaut connu :

| Élément | Ce qu'il évite |
|---|---|
| Résolution de `utils.sh` via `SCRIPT_DIR` | Script inutilisable depuis un autre répertoire ; repli prévu pour les clonages partiels |
| `validate_compose_file` avant lancement | Le compose vient d'un *heredoc* : une faute d'indentation YAML passerait inaperçue jusqu'au démarrage |
| Chemin du compose **en argument** de `check_container_exists` | Sinon la vérification porte sur le compose du répertoire courant |
| `set -euo pipefail` et chemins quotés | Erreurs silencieuses, chemins contenant des espaces |
| `docker image prune -f` **sans `-a`** | `-a` supprimerait les images des autres services du homelab |
| `purge-data` séparée et confirmée | Suppression de données en effet de bord d'un `uninstall` |
| `service.mk` comme déclaration unique | Désynchronisation entre le script et le makefile |

## Valider un service créé

```bash
cd MonService

# Syntaxe et bonnes pratiques (0 avertissement attendu)
shellcheck -x install_monservice.sh ../common/utils.sh

# Toutes les cibles parsent ?
for t in install update update-repo start stop clean logs uninstall purge-data; do
  printf '%-14s ' "$t"; make -n $t >/dev/null 2>&1 && echo OK || echo ECHEC
done
```

{: .astuce }
> `shellcheck -x` doit être lancé **depuis le dossier du service** pour que le
> chemin relatif `../common/utils.sh` se résolve. Depuis la racine du dépôt, il
> signalerait un faux positif `SC1091`.

Vérifiez enfin que le compose généré est valide :

```bash
docker compose -f "$INSTALL_DIR/docker-compose.yml" config -q && echo VALID
```

## Après la création

- [ ] `.gitignore` — ajouter `MonService/docker-compose.yml` et `MonService/config.mk`
- [ ] `README.md` racine — ajouter le service à la liste « Contenu »
- [ ] `docs/services/index.md` — ajouter la ligne au tableau
- [ ] `docs/services/monservice.md` — créer la page de documentation

{: .avertissement }
> N'ajoutez **pas** `service.mk` au `.gitignore` : contrairement à `config.mk`
> (généré à l'installation, propre à chaque machine), il fait partie des sources
> du service et doit être versionné.
