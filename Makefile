.PHONY: help
help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build the containers
	docker-compose build $(name)

.PHONY: up
up: ## Run all containers
	docker-compose up $(name)

.PHONY: down
down: ## Stop all containers
	docker-compose down

.PHONY: clean
clean: ## Stop all containers and clean volumes and local images
	docker-compose down -v --rmi local --remove-orphans	

.PHONY: ps
ps: ## Show status for all containers
	docker-compose ps

.PHONY: load_schema
load_schema: ## Load default schema on MySQL
	scripts/schema.sh

.PHONY: try_sql
try_sql: ## Execute read/write test SQL 
	scripts/try-sql.sh

.PHONY: discover
discover:
	docker-compose exec orchestrator ./orchestrator -c discover -i 172.20.0.200:3306

.PHONY: master_drop
master_drop:
	docker-compose exec ${n} iptables -A INPUT -p tcp --dport 3306 -j DROP

.PHONY: master_accept
master_accept:
	docker-compose exec ${n} iptables -D INPUT -p tcp --dport 3306 -j DROP