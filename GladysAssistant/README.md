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
git clone --no-checkout https://github.com/William-De71/HomeLAB.git
cd homeLAB

# 2. Activer sparse-checkout
git sparse-checkout init --cone

# 3. Choisir uniquement le dossier du service
git sparse-checkout set GladysAssistant
```

Vous aurez alors uniquement le contenu du dossier GladysAssistant dans votre répertoire local.

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

#### 📝 Afficher les logs

```bash
make logs
```

#### 🧹 Nettoyer (supprimer images Docker non utilisées)

```bash
make clean
```

#### 🗑️ Désinstaller le service

```bash
make uninstall
```

> ⚠️ **Note** : Si le dossier d’installation est identique au dossier du Makefile, seul le docker-compose.yml sera supprimé (sécurité pour éviter d’effacer vos sources).

## 🔧 Options du script

Les commandes make acceptent des variables pour personnaliser l’exécution :
* -h | --help : affiche une aide

```bash
make install ARGS="-h"
```

* -v | --verbose : active les logs détaillés pendant l'execution du script d'installation

```bash
make install ARGS="-v"
```
