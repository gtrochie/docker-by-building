.DEFAULT_GOAL := help
IMAGE := freelanceforge
TAG   := dev

help: ## Show this help
	@echo "Docker By Building — shortcuts (each wraps a real docker command)"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "You need Docker installed and running: 'docker version' should work."

build: ## Build the app image  (docker build)
	docker build -t $(IMAGE):$(TAG) .

run: ## Run it, publish port 8000  (docker run)
	docker run --rm -p 8000:8000 --name ff $(IMAGE):$(TAG)

sh: ## Open a shell in a running container  (docker exec)
	docker exec -it ff sh

up: ## Start the full stack  (docker compose up)
	docker compose up --build

down: ## Stop the stack + remove volumes  (docker compose down -v)
	docker compose down -v

logs: ## Follow stack logs
	docker compose logs -f

ps: ## List running containers
	docker ps

clean: ## Remove the built image
	-docker rmi $(IMAGE):$(TAG)

prune: ## Reclaim space: stopped containers, unused images/networks
	docker system prune -f

.PHONY: help build run sh up down logs ps clean prune
