---
title: Prérequis
layout: default
nav_order: 2
---

# Prérequis
{: .no_toc }

## Sommaire
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Résumé

| Outil | Rôle | Vérification |
|---|---|---|
| Docker Engine | Exécution des conteneurs | `docker ps` |
| Docker Compose v2 | Orchestration multi-conteneurs | `docker compose version` |
| `git` | Clonage du dépôt | `git --version` |
| `make` | Exécution des cibles du makefile | `make --version` |
| `curl`, `ip`, `awk`, `grep` | Utilisés par les scripts | généralement déjà présents |

Les scripts vérifient eux-mêmes ces dépendances au démarrage et s'arrêtent avec
un message explicite si l'une manque.

## Installation de Docker

Si Docker n'est pas encore installé :

```bash
curl -sSL https://get.docker.com | sh
```

{: .note }
> Ce script installe également le plugin Docker Compose v2. Une étape séparée
> n'est en général pas nécessaire.

### Exécuter Docker sans sudo

Ajoutez votre utilisateur au groupe `docker` :

```bash
sudo usermod -aG docker $USER
```

Puis **déconnectez-vous et reconnectez-vous** pour que la modification prenne
effet (ou lancez `newgrp docker` pour la session courante).

Vérification :

```bash
docker ps
```

Vous devriez obtenir une liste vide, sans erreur de permission :

```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

{: .avertissement }
> Si vous obtenez `permission denied while trying to connect to the Docker
> daemon socket`, la modification du groupe n'est pas encore active : la
> reconnexion est bien nécessaire.

### Activer Docker au démarrage

```bash
sudo systemctl enable --now docker
```

## Vérifier Docker Compose

```bash
docker compose version
```

Sortie attendue (v2 ou supérieur) :

```
Docker Compose version v2.39.1
```

{: .attention }
> Attention à la syntaxe : `docker compose` (v2, sous-commande) et non
> `docker-compose` (v1, binaire séparé et désormais obsolète). Les scripts de
> ce dépôt utilisent la v2.

### Installation manuelle du plugin

Si `docker compose version` échoue, installez le plugin selon votre
distribution :

<div class="code-example" markdown="1">

**Debian / Ubuntu / Raspberry Pi OS**
```bash
sudo apt-get update && sudo apt-get install docker-compose-plugin
```

**Fedora**
```bash
sudo dnf install docker-compose-plugin
```

**CentOS / RHEL**
```bash
sudo yum install docker-compose-plugin
```

**Arch Linux**
```bash
sudo pacman -S docker-compose
```

**macOS (Homebrew)**
```bash
brew install docker-compose
```

</div>

Sur **Windows**, Docker Compose est inclus dans
[Docker Desktop](https://www.docker.com/products/docker-desktop/).

## Commandes Docker Compose utiles

Ces commandes sont encapsulées par les cibles `make` de chaque service, mais
restent utiles pour du diagnostic manuel.

| Action | Commande |
|---|---|
| Démarrer en arrière-plan | `docker compose up -d` |
| Démarrer au premier plan (voir les logs) | `docker compose up` |
| Arrêter et supprimer les conteneurs | `docker compose down` |
| Arrêter sans supprimer | `docker compose stop` |
| Afficher l'état | `docker compose ps` |
| Suivre les logs | `docker compose logs -f` |
| Logs d'un service précis | `docker compose logs -f <service>` |
| Mettre à jour les images | `docker compose pull && docker compose up -d` |
| Exécuter une commande dans un conteneur | `docker compose exec <service> <commande>` |
| Valider la syntaxe du fichier | `docker compose config -q` |

{: .attention }
> `docker compose down -v` supprime aussi les **volumes**, donc les données du
> service. À manipuler avec précaution.

## Étape suivante

Une fois les prérequis en place, consultez
[Architecture]({{ site.baseurl }}/architecture/) pour comprendre la structure du
dépôt, ou allez directement à l'installation de
[Gladys Assistant]({{ site.baseurl }}/services/gladys/).
