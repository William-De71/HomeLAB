---
title: Gladys Assistant
layout: default
parent: Services
nav_order: 1
---

# Gladys Assistant
{: .no_toc }

Instance [Gladys Assistant](https://gladysassistant.com/) auto-hébergée, avec
mises à jour automatiques via Watchtower.
{: .fs-5 .fw-300 }

## Sommaire
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Ce que fait le script

`install_gladys.sh` automatise l'ensemble du déploiement :

1. vérifie les dépendances et l'état du démon Docker ;
2. demande le répertoire d'installation et génère `config.mk` ;
3. détecte l'adresse IP locale de la machine ;
4. génère le `docker-compose.yml` (Gladys + Watchtower) ;
5. **valide la syntaxe** du fichier généré ;
6. vérifie l'absence de conflit de noms de conteneurs ;
7. démarre la stack et attend que Gladys réponde ;
8. propose d'ouvrir l'interface dans le navigateur.

## Installation

### 1. Récupérer le service

```bash
git clone --filter=blob:none --sparse https://github.com/William-De71/HomeLAB.git
cd HomeLAB
git sparse-checkout set common GladysAssistant
cd GladysAssistant
```

{: .avertissement }
> Le dossier `common` est indispensable : il contient `utils.sh`, dont le script
> d'installation a besoin. Sans lui, le script s'arrête en indiquant la commande
> à utiliser.

### 2. Lancer l'installation

```bash
make install
```

Le script demande le répertoire du fichier compose :

```
📂 Entrez le chemin pour le ficher docker compose de Gladys (ex: /opt/gladys) :
```

- Le chemin doit être **absolu**.
- Laisser vide utilise le dossier du script.
- Le dossier est créé s'il n'existe pas.

En fin d'installation, l'adresse d'accès est affichée :

```
🎉 Gladys Assistant est prêt et accessible à l'adresse suivante: http://192.168.0.103
👉 Voulez-vous ouvrir Gladys Assistant dans votre navigateur ? [o/N]
```

### Options disponibles

Les options se passent via la variable `ARGS` :

| Option | Effet |
|---|---|
| `-h`, `--help` | Affiche l'aide |
| `-v`, `--verbose` | Affiche le détail des étapes |

```bash
make install ARGS="-v"
```

## Commandes de gestion

| Commande | Effet |
|---|---|
| `make install` | Installation initiale (régénère le compose) |
| `make start` | Démarrer les conteneurs |
| `make stop` | Arrêter et supprimer les conteneurs |
| `make logs` | Suivre les logs en temps réel |
| `make update` | Forcer la mise à jour des **images Docker** |
| `make update-repo` | Mettre à jour les **scripts** du dépôt (`git pull`) |
| `make clean` | Supprimer les images sans tag |
| `make uninstall` | Désinstaller le service (**données conservées**) |
| `make purge-data` | Supprimer définitivement les données (confirmation requise) |

## Mises à jour

Deux mécanismes coexistent.

### Automatique — Watchtower

Le conteneur Watchtower surveille et met à jour les images en arrière-plan. Il
est configuré avec `--label-enable`, ce qui signifie qu'il ne met à jour **que**
les conteneurs portant le label suivant :

```yaml
labels:
  com.centurylinklabs.watchtower.enable: "true"
```

{: .note }
> Sans cette option, Watchtower mettrait à jour **tous** les conteneurs de la
> machine, y compris ceux appartenant à d'autres services du homelab. Le label
> restreint son action à Gladys.

### Manuelle — `make update`

Pour ne pas attendre le prochain passage de Watchtower :

```bash
make update
```

Enchaîne quatre étapes :

1. `docker compose pull` — récupère les dernières images ;
2. `docker compose up -d` — recrée **uniquement** les conteneurs dont l'image a
   changé ;
3. `docker image prune -f` — supprime les images devenues obsolètes ;
4. `docker compose ps` — affiche l'état final.

{: .astuce }
> Les données de `/var/lib/gladysassistant` ne sont jamais affectées par une mise
> à jour d'image. Les conteneurs dont l'image n'a pas changé ne sont pas
> redémarrés.

L'image est épinglée sur `gladysassistant/gladys:v4` : vous recevez les
correctifs de la branche `v4.x` sans saut de version majeure involontaire.

## Personnaliser l'installation

Les paramètres du service sont regroupés dans `GladysAssistant/service.mk` :

```make
GLADYS_IMAGE=gladysassistant/gladys:v4
WATCHTOWER_IMAGE=nickfedor/watchtower:latest
DATA_DIR=/var/lib/gladysassistant
SERVER_PORT=80
```

Ce fichier est la **source unique** de ces valeurs : le `makefile` l'inclut et
`install_gladys.sh` le source. Modifier une ligne suffit donc à la propager au
`docker-compose.yml` généré comme aux cibles `make uninstall` et `make purge-data`.

{: .attention }
> Le fichier est lu par Make **et** par Bash : n'y mettez que des affectations
> `NOM=valeur`, sans espace autour du `=` et sans guillemets.

{: .note }
> Après modification, régénérez le compose avec `make install` (ou éditez
> directement le `docker-compose.yml` déjà installé). Changer `DATA_DIR` sur une
> installation existante ne déplace **pas** les données : déplacez d'abord le
> dossier, sinon Gladys repartira sur une base vide.

## Configuration générée

Le `docker-compose.yml` produit contient deux services :

```yaml
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
    labels:
      com.centurylinklabs.watchtower.enable: "true"
    logging:
      driver: "json-file"
      options:
        max-size: 10m
        max-file: "3"

  watchtower:
    image: nickfedor/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    command: --cleanup --include-restarting --label-enable
    environment:
      TZ: Europe/Paris
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

### Justification des choix

| Paramètre | Raison |
|---|---|
| `privileged: true` + `/dev:/dev` | Requis par Gladys pour accéder aux périphériques matériels (dongles Zigbee/Z-Wave, Bluetooth) sans déclarer chaque device individuellement. |
| `network_mode: host` | Requis pour la découverte des objets connectés (mDNS, SSDP, broadcast UDP), qui ne traverse pas un réseau Docker bridge. |
| `/var/run/docker.sock` | Requis par Gladys pour gérer ses conteneurs d'extensions (Zigbee2MQTT, MQTT…). |
| `cgroup: host` | Nécessaire au bon fonctionnement de Gladys en mode host. |
| `restart: unless-stopped` | Redémarrage automatique après un reboot de la machine. |
| `logging` limité | Plafonne les logs à 3 fichiers de 10 Mo, pour éviter de remplir le disque. |
| Image épinglée `v4` | Installations reproductibles, pas de saut de version majeure. |

{: .attention }
> **À propos du mode privilégié.** La combinaison `privileged: true`,
> `network_mode: host` et l'accès à `docker.sock` donne au conteneur un accès
> très large à la machine hôte. C'est la configuration recommandée par Gladys
> pour l'accès matériel, et elle est assumée ici. Elle implique de faire
> confiance à l'image utilisée — d'où l'intérêt de l'épinglage de version.

### Emplacement des données

| Chemin | Contenu |
|---|---|
| `/var/lib/gladysassistant/` | Base SQLite, sauvegardes, fichiers de l'instance |
| `$INSTALL_DIR/docker-compose.yml` | Configuration générée |
| `$INSTALL_DIR/config.mk` | Chemin d'installation, lu par le makefile |

## Désinstallation

### Conserver les données

```bash
make uninstall
```

Arrête les conteneurs, puis supprime le `docker-compose.yml`, le `config.mk` et
l'image Gladys. **Les données de `/var/lib/gladysassistant` sont conservées**, ce
qui permet de réinstaller sans rien perdre.

{: .note }
> Si le répertoire d'installation est le dossier du makefile, seul le
> `docker-compose.yml` est supprimé — une protection pour ne pas effacer les
> sources du dépôt.

### Supprimer aussi les données

```bash
make purge-data
```

{: .attention }
> **Irréversible.** Supprime `/var/lib/gladysassistant` : appareils, scénarios,
> historique et sauvegardes. Une confirmation explicite est demandée — il faut
> taper le mot `supprimer`.

## Dépannage

### Le script s'arrête : dépendance manquante

```
Les dépendances suivantes sont manquantes : curl
```

Installez l'outil signalé. Les dépendances requises sont `docker`, `git`, `ip`,
`awk`, `grep`, `head`, `cut` et `curl`.

### `utils.sh introuvable`

```
❌ Fichier utils.sh introuvable (cherché dans ../common/ et …)
```

Le dossier `common/` n'a pas été récupéré. Corrigez le périmètre du clonage :

```bash
git sparse-checkout set common GladysAssistant
```

### Un conteneur existe déjà

```
⚠️  Le conteneur 'gladys' existe déjà. Arrêt...
```

Le script refuse d'écraser une instance existante. Selon votre intention :

```bash
docker rm -f gladys        # supprimer l'ancien conteneur
# ou
make stop                  # arrêter proprement la stack existante
```

### Gladys ne répond pas après l'installation

```
⚠️ Impossible d’accéder à Gladys après 60s (dernier code HTTP : 000).
```

Le script attend jusqu'à 60 secondes. Au premier démarrage, les migrations de la
base peuvent prendre plus longtemps. Consultez les logs :

```bash
make logs
```

Si le port 80 est déjà utilisé par un autre service (Gladys étant en
`network_mode: host`, il ne peut pas être remappé) :

```bash
sudo ss -tlnp | grep ':80'
```

### Le fichier compose généré est invalide

```
Le fichier …/docker-compose.yml est invalide :
```

Le message de Docker suit. Cela indique une erreur dans le *heredoc* du script
plutôt qu'un problème de votre côté — la validation intervient précisément pour
détecter ce cas avant le lancement.

### Vérifier l'état de la stack

```bash
cd "$(grep -oP 'INSTALL_DIR := \K.*' config.mk)"
docker compose ps
docker compose logs --tail 50
```

## Références

- [Documentation officielle Gladys Assistant](https://gladysassistant.com/docs/)
- [`GladysAssistant/README.md`](https://github.com/William-De71/HomeLAB/blob/main/GladysAssistant/README.md)
- [`CHANGELOG.md`](https://github.com/William-De71/HomeLAB/blob/main/GladysAssistant/CHANGELOG.md)
