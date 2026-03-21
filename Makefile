# ============================================================
# Makefile — n8n Platform
# ============================================================

.PHONY: dev dev-down dev-logs dev-reset help

DEV_COMPOSE = docker compose -f docker-compose.yml -f docker-compose.dev.yml

## Lance le stack en développement local
dev:
	@[ -f .env ] || (echo "Création de .env depuis .env.dev..." && cp .env.dev .env)
	$(DEV_COMPOSE) up -d
	@echo ""
	@echo "Stack démarré :"
	@echo "  n8n      → http://localhost:5678"
	@echo "  gateway  → http://localhost:5001"
	@echo "  postgres → localhost:5432"

## Arrête le stack
dev-down:
	$(DEV_COMPOSE) down

## Affiche les logs en temps réel
dev-logs:
	$(DEV_COMPOSE) logs -f

## Reset complet — supprime tous les volumes (repart de zéro)
dev-reset:
	$(DEV_COMPOSE) down -v
	@echo "Volumes supprimés. Lance 'make dev' pour repartir de zéro."

## Affiche l'aide
help:
	@echo "Commandes disponibles :"
	@echo "  make dev        Lance le stack local"
	@echo "  make dev-down   Arrête le stack"
	@echo "  make dev-logs   Affiche les logs"
	@echo "  make dev-reset  Reset complet (supprime les volumes)"
