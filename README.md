# HomeLAB

Fichier docker-compose pour mon utilisation personnel

## Contenu

<!-- 
- <a href="affine"><img src="https://paper.pro/icons/mac/affine.png" alt="affine" height="35" align="top"/></a> [`Affine`](affine)
- <a href="nextcloud"><img src="https://avatars.githubusercontent.com/u/19211038?s=200&v=4" alt="nextcloud" height="30" align="top"/></a> [`Nextcloud`](nextcloud)
-->

## Prérequis

### Installation de Docker

Si Docker n'est pas encore installé sur votre machine, vous pouvez l'installer avec :

```bash
$ curl -sSL https://get.docker.com | sh
```

Ensuite, ajoutez votre utilisateur au groupe 'docker' pour exécuter les commandes Docker sans sudo :

```bash
$ sudo usermod -aG docker nom_utilisateur
```
*Remplacez `nom_utilisateur` par votre nom d'utilisateur Linux.*

Déconnectez-vous puis reconnectez-vous pour que la modification prenne effet.

Pour vérifier que Docker fonctionne correctement :

```bash
$ docker ps
```

Vous devriez voir une liste des containers qui tournent sur la machine. Comme vous venez d'installer Docker, cette liste doit être vide normalement.
```bash
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

### Installation de Docker Compose

1. **Vérification des prérequis** : Docker Engine doit être installé. Des droits administrateur (sudo) sont nécessaires.  
   *Note : le plugin Docker Compose est généralement installé avec le script ci-dessus.*

2. **Vérifiez l'installation de Docker Compose** :

```bash
docker compose version
```

Vous devriez obtenir une sortie similaire à :

```bash
Docker Compose version v2.39.1
```

3. **Installez Docker Compose selon votre système** :

* **Pour les distributions basées sur Debian (Ubuntu, Raspberry Pi OS, etc.) :**

```bash
$ sudo apt-get update
$ sudo apt-get install docker-compose-plugin
```

* **Pour Fedora :**

```bash
$ sudo dnf install docker-compose-plugin
```

* **Pour CentOS/RHEL :**

```bash
$ sudo yum install docker-compose-plugin
```

* **Pour Arch Linux :**

```bash
$ sudo pacman -S docker-compose
```

* **Pour macOS (avec Homebrew) :**

```bash
$ brew install docker-compose
```

* **Pour Windows :**

Docker Compose est inclus avec Docker Desktop. Téléchargez et installez Docker Desktop depuis [le site officiel](https://www.docker.com/products/docker-desktop/).

### Déploiement et gestion des applications

Lorsque vous avez terminé la configuration de vos services, volumes et réseaux dans Docker Compose, vous pouvez déployer et gérer vos applications multi-conteneurs efficacement.

#### Déploiement initial

Pour déployer votre application, placez-vous dans le répertoire où se trouve votre fichier `docker-compose.yml` puis exécutez :

```bash
docker compose up -d
```
Le paramètre `-d` (pour "detached") exécute les conteneurs en arrière-plan.

Cette commande va :
- Télécharger les images nécessaires (si besoin)
- Créer les conteneurs, réseaux et volumes définis dans votre fichier Docker Compose
- Démarrer tous les services

Pour voir les logs de démarrage en temps réel, vous pouvez utiliser :

```bash
docker compose up
```
(sans `-d`)

#### Gestion des conteneurs

Voici quelques commandes utiles pour la gestion de vos conteneurs :

* **Arrêter et supprimer tous les conteneurs, réseaux, images et volumes créés par Compose :**

```bash
docker compose down
```
> Ajoutez `-v` pour supprimer aussi les volumes :  
> `docker compose down -v`

* **Arrêter les services (sans les supprimer) :**

```bash
docker compose stop
```

* **Démarrer les services arrêtés :**

```bash
docker compose start
```

* **Redémarrer les services :**

```bash
docker compose restart
```

* **Afficher l’état des conteneurs :**

```bash
docker compose ps
```

* **Afficher les logs d’un service :**

```bash
docker compose logs <nom-du-service>
```
> Utilisez `-f` pour suivre les logs en temps réel :  
> `docker compose logs -f <nom-du-service>`

* **Mettre à jour les images et relancer les services :**

```bash
docker compose pull
docker compose up -d
```

* **Exécuter une commande dans un conteneur :**

```bash
docker compose exec <nom-du-service> <commande>
```
Pour plus de détails, consultez la [documentation officielle Docker Compose](https://docs.docker.com/compose/reference/).
