SHELL := /bin/bash

# Charger .env si présent
ifneq ("$(wildcard config.mk)","")
  include config.mk
  export INSTALL_DIR
endif

.PHONY: all install update start stop clean logs uninstall

all: install

install:
	@./install_gladys.sh $(ARGS)

update:
	@echo "Mise à jour de du script d'installation de Gladys Assistant"
	@# @source ./utils.sh && update_repo 

start:
	@(cd $(INSTALL_DIR) && docker compose up -d)

stop:
	@(cd $(INSTALL_DIR) && docker compose down)

logs:
	@echo "Logs de Gladys Assistant"
	@(cd $(INSTALL_DIR) && docker compose logs -f)

clean:
	@echo "Suppression des images Docker non utilisées"
	@docker image prune -a -f

uninstall:
	@if [ -f "$(INSTALL_DIR)/docker-compose.yml" ]; then \
		echo "🛑 Arrêt et suppression des conteneurs Docker"; \
		(cd $(INSTALL_DIR) && docker compose down -v); \
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
	fi; \

	@echo "🧹 Suppression des dossiers de données de Gladys Assistant dans /var/lib/gladysassistant";
	@sudo rm -rf /var/lib/gladysassistant; 
	@echo "🧹 Suppression des images Docker Gladys Assistant"; 
	@docker image prune -a -f; 
	@echo "Désinstallation de Gladys Assistant terminée."; 