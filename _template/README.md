# MonService

<!--
TODO: remplacer « MonService » partout, ainsi que les chemins et le nom du
script d'installation. Supprimer ce commentaire une fois le README adapté.
-->

## 🎯 Objectif

Mettre en place une instance MonService **auto-hébergée**.

Ce script a pour but de simplifier le déploiement et la gestion du service Docker
MonService sur votre machine.
Il automatise plusieurs étapes : installation, lancement, arrêt, nettoyage et
configuration. Un système de logs colorés est inclus pour un retour visuel clair.

---

## 📥 Clonage du dépôt

Le dépôt contient plusieurs services, vous pouvez cloner **uniquement le dossier de ce service** pour éviter de télécharger tout le dépôt.

### Étapes :

```bash
# 1. Cloner le dépôt sans extraire les fichiers
git clone --filter=blob:none --sparse https://github.com/William-De71/HomeLAB.git
cd HomeLAB

# 2. Choisir le dossier du service + les utilitaires partagés
git sparse-checkout set common MonService
```

Vous aurez alors uniquement les dossiers `MonService` et `common` dans votre répertoire local.

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

* Crée le dossier d'installation
* Génère le `docker-compose.yml`
* Lance les conteneurs avec docker compose
* Affiche l'adresse locale du service une fois prêt, et propose de l'ouvrir dans le navigateur

#### ▶️ Démarrer le service

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

Récupère les dernières images, recrée les conteneurs concernés, puis supprime les images devenues obsolètes.

> Seuls les conteneurs dont l'image a réellement changé sont recréés — les autres ne sont pas redémarrés.

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

Arrête les conteneurs, supprime le `docker-compose.yml`, le `config.mk` et l'image du service.

> ⚠️ **Note** : Si le dossier d'installation est identique au dossier du Makefile, seul le `docker-compose.yml` sera supprimé (sécurité pour éviter d'effacer vos sources).
>
> 💾 **Les données sont conservées** : le contenu de `DATA_DIR` n'est pas touché par `make uninstall`.

#### 💥 Supprimer définitivement les données

```bash
make purge-data
```

> ⚠️ **Irréversible** : supprime le dossier de données du service. Une confirmation explicite est demandée.

## 🔧 Options du script

Les commandes make acceptent des variables pour personnaliser l'exécution :

* `-h` | `--help` : affiche l'aide

```bash
make install ARGS="-h"
```

* `-v` | `--verbose` : active les logs détaillés pendant l'exécution du script d'installation

```bash
make install ARGS="-v"
```

## 🔒 Notes sur la configuration générée

<!-- TODO: documenter ici les choix de configuration propres au service. -->

| Choix | Raison |
|---|---|
| Paramètres dans `service.mk` | L'image, le dossier de données et le port sont déclarés une seule fois, puis partagés par le script d'installation et le makefile. |
| Images épinglées | `exemple/image:1.2.3` plutôt que `latest`, pour des installations reproductibles. |
| Watchtower en `--label-enable` | Le label `com.centurylinklabs.watchtower.enable` est à conserver uniquement si ce service doit être mis à jour automatiquement. |
