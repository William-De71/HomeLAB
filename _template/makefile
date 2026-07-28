SHELL := /bin/bash

# Paramètres du service (image, dossier de données, port) : déclarés une seule
# fois dans service.mk, lui-même sourcé par le script d'installation. Un fichier
# manquant est une erreur, sans quoi `uninstall` s'exécuterait avec une image
# vide et ne supprimerait rien.
ifeq ("$(wildcard service.mk)","")
  $(error service.mk introuvable — il définit SERVICE_IMAGE, DATA_DIR et SERVICE_PORT)
endif
include service.mk

# TODO: nom du script d'installation après renommage
INSTALL_SCRIPT ?= ./install_service.sh

# Utilitaires partagés : dossier common/ à la racine du dépôt, avec repli sur
# une copie locale pour les clonages partiels.
UTILS_FILE := $(firstword $(wildcard ../common/utils.sh utils.sh))

# Charger la configuration générée par le script d'installation si présente
ifneq ("$(wildcard config.mk)","")
  include config.mk
  export INSTALL_DIR
endif

# Repli sur le dossier du makefile si config.mk est absent, pour éviter des
# commandes du type `cd ""` qui s'exécuteraient dans le mauvais répertoire.
INSTALL_DIR ?= $(CURDIR)
ifeq ($(strip $(INSTALL_DIR)),)
  INSTALL_DIR := $(CURDIR)
endif

.PHONY: all install update update-repo start stop clean logs uninstall purge-data

all: install

install:
	@$(INSTALL_SCRIPT) $(ARGS)

# Force la mise à jour des images, sans attendre le prochain passage de
# Watchtower. `up -d` ne recrée que les conteneurs dont l'image a changé.
update:
	@if [ ! -f "$(INSTALL_DIR)/docker-compose.yml" ]; then \
		echo "❌ $(INSTALL_DIR)/docker-compose.yml introuvable." >&2; \
		echo "   Lancez d'abord : make install" >&2; \
		exit 1; \
	fi
	@echo "⬇️  Récupération des dernières images Docker"
	@(cd "$(INSTALL_DIR)" && docker compose pull)
	@echo "🔄 Recréation des conteneurs dont l'image a changé"
	@(cd "$(INSTALL_DIR)" && docker compose up -d)
	@echo "🧹 Suppression des images devenues obsolètes"
	@docker image prune -f
	@echo "✅ Mise à jour terminée."
	@(cd "$(INSTALL_DIR)" && docker compose ps)

# Met à jour le dépôt Git (scripts d'installation), pas les images Docker.
update-repo:
	@echo "Mise à jour du dépôt HomeLAB"
	@if [ -z "$(UTILS_FILE)" ]; then \
		echo "❌ utils.sh introuvable (cherché dans ../common/ et .)." >&2; \
		exit 1; \
	fi
	@VERBOSE=true; source "$(UTILS_FILE)" && update_repo

start:
	@(cd "$(INSTALL_DIR)" && docker compose up -d)

stop:
	@(cd "$(INSTALL_DIR)" && docker compose down)

logs:
	@echo "Logs du service"
	@(cd "$(INSTALL_DIR)" && docker compose logs -f)

# Ne supprime que les images dangling (sans tag), et non toutes les images
# inutilisées de l'hôte comme le ferait `prune -a`.
clean:
	@echo "🧹 Suppression des images Docker sans tag (dangling)"
	@docker image prune -f

uninstall:
	@if [ -f "$(INSTALL_DIR)/docker-compose.yml" ]; then \
		echo "🛑 Arrêt et suppression des conteneurs Docker"; \
		(cd "$(INSTALL_DIR)" && docker compose down -v); \
	fi
	@if [ "$(INSTALL_DIR)" = "$(CURDIR)" ]; then \
		if [ -f "$(INSTALL_DIR)/docker-compose.yml" ]; then \
			echo "🧹 Suppression du fichier docker-compose.yml dans $(INSTALL_DIR)"; \
			rm -f "$(INSTALL_DIR)/docker-compose.yml"; \
		fi; \
	else \
		if [ -d "$(INSTALL_DIR)" ]; then \
			echo "🧹 Suppression du dossier d'installation $(INSTALL_DIR)"; \
			rm -rf "$(INSTALL_DIR)"; \
		fi; \
	fi
	@if [ -f "$(CURDIR)/config.mk" ]; then \
		echo "🧹 Suppression du fichier config.mk dans $(CURDIR)"; \
		rm -f "$(CURDIR)/config.mk"; \
	fi
	@echo "🧹 Suppression des images Docker du service"
	@docker image rm -f $(SERVICE_IMAGE) 2>/dev/null || true
	@echo "✅ Désinstallation terminée."
	@echo ""
	@echo "ℹ️  Les données sont conservées dans $(DATA_DIR)."
	@echo "    Pour les supprimer définitivement : make purge-data"

# Cible séparée et confirmée : la suppression des données persistantes est
# irréversible, elle ne doit jamais être un effet de bord de `uninstall`.
purge-data:
	@echo "⚠️  ATTENTION : cette action supprime définitivement $(DATA_DIR)"
	@read -rp "Tapez 'supprimer' pour confirmer : " reponse; \
	if [ "$$reponse" = "supprimer" ]; then \
		echo "🧹 Suppression de $(DATA_DIR)"; \
		sudo rm -rf "$(DATA_DIR)"; \
		echo "✅ Données supprimées."; \
	else \
		echo "❌ Annulé, aucune donnée supprimée."; \
	fi
