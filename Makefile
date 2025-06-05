.PHONY: help build up down logs clean test setup dev prod status

# Variables
COMPOSE_FILE = docker-compose.yml
DOCKER_COMPOSE = docker-compose
PROJECT_NAME = chatbot

# Couleurs pour l'affichage
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

# Affichage de l'aide par défaut
help: ## Affiche l'aide
	@echo "$(GREEN)ChatBot Juridique - Commandes disponibles:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# DÉVELOPPEMENT LOCAL

setup: ## Configuration initiale du projet
	@echo "$(GREEN)Configuration initiale du projet...$(NC)"
	@echo "$(YELLOW)Création des environnements virtuels...$(NC)"
	cd vectorisation && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
	cd api && python3 -m venv env && source env/bin/activate && pip install -r requirements.txt
	cd kiwix-package && python3 -m venv env && source env/bin/activate && pip install -r requirements.txt
	@echo "$(GREEN)Configuration terminée!$(NC)"

setup-frontend: ## Installation des dépendances frontend
	@echo "$(GREEN)Installation des dépendances frontend...$(NC)"
	cd legal-chatbot-front/front-noemie && npm install
	@echo "$(GREEN)Frontend configuré!$(NC)"

dev: ## Lance l'environnement de développement
	@echo "$(GREEN)Démarrage en mode développement...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up --build

dev-d: ## Lance l'environnement de développement en arrière-plan
	@echo "$(GREEN)🔧 Démarrage en mode développement (détaché)...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d --build

# PRODUCTION

prod: ## Lance l'environnement de production
	@echo "$(GREEN)Démarrage en mode production...$(NC)"
	$(DOCKER_COMPOSE) -f $(INFRA_COMPOSE_FILE) up -d --build

prod-logs: ## Affiche les logs de production
	$(DOCKER_COMPOSE) -f $(INFRA_COMPOSE_FILE) logs -f

# GESTION DES SERVICES

build: ## Construit toutes les images Docker
	@echo "$(GREEN)Construction des images Docker...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) build

up: ## Démarre tous les services
	@echo "$(GREEN)Démarrage des services...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d

down: ## Arrête tous les services
	@echo "$(YELLOW)Arrêt des services...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down

restart: ## Redémarre tous les services
	@echo "$(YELLOW)Redémarrage des services...$(NC)"
	$(MAKE) down
	$(MAKE) up

# SERVICES INDIVIDUELS

mongo: ## Lance uniquement MongoDB
	@echo "$(GREEN)Démarrage de MongoDB...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d mongo

api: ## Lance uniquement l'API
	@echo "$(GREEN)Démarrage de l'API...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d api

frontend: ## Lance uniquement le frontend
	@echo "$(GREEN)️Démarrage du frontend...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d frontend

vectorisation: ## Lance le processus de vectorisation
	@echo "$(GREEN)Démarrage de la vectorisation...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up vectorisation

scraping: ## Lance le scraping Kiwix
	@echo "$(GREEN)Démarrage du scraping...$(NC)"
	cd kiwix-package && source env/bin/activate && python main.py

# LOGS ET MONITORING

logs: ## Affiche les logs de tous les services
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f

logs-api: ## Affiche les logs de l'API
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f api

logs-frontend: ## Affiche les logs du frontend
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f frontend

logs-vectorisation: ## Affiche les logs de la vectorisation
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f vectorisation

logs-mongo: ## Affiche les logs de MongoDB
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f mongo

status: ## Affiche le statut des services
	@echo "$(GREEN)Statut des services:$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) ps

# TESTS

test: ## Lance tous les tests
	@echo "$(GREEN)Exécution des tests...$(NC)"
	$(MAKE) test-vectorisation
	$(MAKE) test-api

test-vectorisation: ## Tests de la vectorisation
	@echo "$(GREEN)Tests de vectorisation...$(NC)"
	cd vectorisation && source venv/bin/activate && python test_content_verification.py

test-api: ## Tests de l'API
	@echo "$(GREEN)Tests de l'API...$(NC)"
	cd api && source env/bin/activate && python test_api.py

test-integration: ## Tests d'intégration complets
	@echo "$(GREEN)Tests d'intégration...$(NC)"
	$(MAKE) up
	sleep 30
	curl -f http://localhost:8000/ || exit 1
	curl -f http://localhost:3000/ || exit 1
	@echo "$(GREEN)Tests d'intégration réussis!$(NC)"

# MAINTENANCE

clean: ## Nettoie les ressources Docker
	@echo "$(YELLOW)Nettoyage des ressources Docker...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down -v --remove-orphans
	docker system prune -f
	docker volume prune -f

clean-all: ## Nettoyage complet (images, conteneurs, volumes)
	@echo "$(RED)Nettoyage complet...$(NC)"
	$(MAKE) clean
	docker image prune -a -f
	docker builder prune -f

reset-db: ## Remet à zéro la base de données
	@echo "$(YELLOW)Remise à zéro de la base de données...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down -v
	docker volume rm $(PROJECT_NAME)_mongo-data 2>/dev/null || true
	$(MAKE) mongo

# UTILITAIRES

shell-mongo: ## Accès au shell MongoDB
	@echo "$(GREEN)Connexion à MongoDB...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) exec mongo mongosh -u admin -p password --authenticationDatabase admin

shell-api: ## Accès au shell de l'API
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) exec api bash

shell-vectorisation: ## Accès au shell de vectorisation
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) exec vectorisation bash

backup-db: ## Sauvegarde de la base de données
	@echo "$(GREEN)Sauvegarde de la base de données...$(NC)"
	mkdir -p backup
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) exec mongo mongodump --host localhost --port 27017 -u admin -p password --authenticationDatabase admin --out /tmp/backup
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) cp mongo:/tmp/backup ./backup/$(shell date +%Y%m%d_%H%M%S)

restore-db: ## Restaure la base de données (BACKUP_DIR requis)
	@if [ -z "$(BACKUP_DIR)" ]; then echo "$(RED)Veuillez spécifier BACKUP_DIR=path/to/backup$(NC)"; exit 1; fi
	@echo "$(GREEN)Restauration de la base de données...$(NC)"
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) cp $(BACKUP_DIR) mongo:/tmp/restore
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) exec mongo mongorestore --host localhost --port 27017 -u admin -p password --authenticationDatabase admin /tmp/restore

# INFORMATIONS

info: ## Affiche les informations du projet
	@echo "$(GREEN)Informations du projet:$(NC)"
	@echo "Nom du projet: $(PROJECT_NAME)"
	@echo "Services disponibles:"
	@echo "  - Frontend: http://localhost:3000"
	@echo "  - API: http://localhost:8000"
	@echo "  - MongoDB: localhost:27017"
	@echo ""
	@echo "Fichiers de configuration:"
	@echo "  - Développement: $(COMPOSE_FILE)"

urls: ## Affiche les URLs des services
	@echo "$(GREEN)URLs des services:$(NC)"
	@echo "Frontend: http://localhost:3000"
	@echo "API: http://localhost:8000"
	@echo "API Health: http://localhost:8000/health"
	@echo "API Docs: http://localhost:8000/docs"

# Par défaut, affiche l'aide
.DEFAULT_GOAL := help
