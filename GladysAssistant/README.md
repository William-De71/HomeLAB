# <a href="gladysassistant"><img src="https://gladysassistant.com/en/img/external/github-gladys-logo.png" alt="gladysassistant" height="30" align="top"/></a> Gladys Assistant

## 🎯 Objectif

Mettre en place une instance Gladys Assistant **auto-hébergée**.

Ce script a pour but de simplifier le déploiement et la gestion du service Docker Gladys Assistant sur votre machine.  
Il automatise plusieurs étapes : installation, lancement, arrêt, nettoyage et configuration.  
Un système de logs colorés est inclus pour un retour visuel clair.

--- 

## 📥 Clonage du dépôt GladysAssistant

Le dépôt contient plusieurs services, vous pouvez cloner **uniquement le dossier de ce service** pour éviter de télécharger tout le dépôt.

### Étapes :

```bash
# 1. Cloner le dépôt sans extraire les fichiers
git clone --filter=blob:none --sparse https://github.com/William-De71/HomeLAB.git
cd HomeLAB

# 2. Choisir le dossier du service + les utilitaires partagés
git sparse-checkout set common GladysAssistant
```

Vous aurez alors uniquement les dossiers `GladysAssistant` et `common` dans votre répertoire local.

> ⚠️ **N'oubliez pas `common`** : les fonctions partagées (`common/utils.sh`) y sont
> stockées et le script d'installation en a besoin pour fonctionner.

## ⚙️ Utilisation du script

Toutes les actions se font via le Makefile.
Celui-ci appelle automatiquement le script interne et gère les options nécessaires.

### 📌 Commandes disponibles

#### Installer le service

```bash
make install
```

Le script :

* Crée le dossier d’installation
* Lance les conteneurs avec docker compose
* Affiche l’adresse locale du service une fois prêt. Le script propose automatiquement d’ouvrir l’URL dans votre navigateur par défaut.

#### Démarrer le service

```bash
make start
```

#### 🛑 Arrêter le service

```bash
make stop
```

#### ⬆️ Forcer la mise à jour des images

```bash
make update
```

Récupère les dernières images, recrée les conteneurs concernés, puis supprime les images devenues obsolètes. Utile pour ne pas attendre le prochain passage de Watchtower.

> Seuls les conteneurs dont l'image a réellement changé sont recréés — les autres ne sont pas redémarrés. Les données de `/var/lib/gladysassistant` ne sont pas affectées.

#### 🔄 Mettre à jour les scripts d'installation

```bash
make update-repo
```

Effectue un `git pull --rebase` sur le dépôt HomeLAB (met à jour les scripts, pas les images Docker).

#### 📝 Afficher les logs

```bash
make logs
```

#### 🧹 Nettoyer (supprimer les images Docker sans tag)

```bash
make clean
```

> Seules les images *dangling* (sans tag) sont supprimées, pour ne pas toucher aux images des autres services du homelab.

#### 🗑️ Désinstaller le service

```bash
make uninstall
```

Arrête les conteneurs, supprime le `docker-compose.yml`, le `config.mk` et l'image Gladys.

> ⚠️ **Note** : Si le dossier d’installation est identique au dossier du Makefile, seul le docker-compose.yml sera supprimé (sécurité pour éviter d’effacer vos sources).
>
> 💾 **Les données sont conservées** : la base SQLite dans `/var/lib/gladysassistant` n'est pas touchée par `make uninstall`.

#### 💥 Supprimer définitivement les données

```bash
make purge-data
```

> ⚠️ **Irréversible** : supprime `/var/lib/gladysassistant` (appareils, scénarios, historique). Une confirmation explicite est demandée.

## 🔧 Options du script

Les commandes make acceptent des variables pour personnaliser l’exécution :

* `-h` | `--help` : affiche l'aide

```bash
make install ARGS="-h"
```

* `-v` | `--verbose` : active les logs détaillés pendant l'exécution du script d'installation

```bash
make install ARGS="-v"
```

## 🎛️ Personnaliser l'installation

Les paramètres du service sont regroupés dans `service.mk` :

```make
GLADYS_IMAGE=gladysassistant/gladys:v4
WATCHTOWER_IMAGE=nickfedor/watchtower:latest
DATA_DIR=/var/lib/gladysassistant
SERVER_PORT=80
```

Ce fichier est la **source unique** de ces valeurs : le `makefile` l'inclut et
`install_gladys.sh` le source. Une modification se propage donc au `docker-compose.yml`
généré comme aux cibles `make uninstall` et `make purge-data`.

> ⚠️ Le fichier est lu par Make **et** par Bash : n'y mettez que des affectations
> `NOM=valeur`, sans espace autour du `=` et sans guillemets.
>
> 💾 Changer `DATA_DIR` sur une installation existante ne déplace **pas** les
> données : déplacez d'abord le dossier, sinon Gladys repartira sur une base vide.

## 🔒 Notes sur la configuration générée

Le `docker-compose.yml` généré suit la configuration recommandée par Gladys Assistant :

| Choix | Raison |
|---|---|
| Paramètres dans `service.mk` | Images, dossier de données et port déclarés une seule fois, partagés par le script d'installation et le makefile. |
| `privileged: true` + `/dev:/dev` | Requis par Gladys pour l'accès aux périphériques matériels (dongles Zigbee/Z-Wave, Bluetooth) sans avoir à déclarer chaque device. |
| `network_mode: host` | Requis pour la découverte des objets connectés (mDNS, SSDP, broadcast UDP). |
| Montage de `docker.sock` | Requis par Gladys pour gérer ses conteneurs d'extensions (Zigbee2MQTT, MQTT…). |
| Watchtower en `--label-enable` | Ne met à jour **que** les conteneurs portant le label `com.centurylinklabs.watchtower.enable=true`, donc pas les autres services du homelab. |
| Images épinglées | `gladysassistant/gladys:v4` plutôt que `latest`, pour des installations reproductibles. |
