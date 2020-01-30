.PHONY: help
help: ## This help
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
try_sql: ## Execute read/write SQL statements N times 
	scripts/try-sql.sh ${n}

.PHONY: discover
discover: ## Run MySQL orchestrator cluster topology discovering process
	docker-compose exec orchestrator ./orchestrator -c discover -i 172.20.0.200:3306

.PHONY: node_drop
node_drop: ## Add DROP rule in iptables in order to block MySQL instance
	docker-compose exec ${n} iptables -A INPUT -p tcp --dport 3306 -j DROP

.PHONY: node_accept
node_accept: ## Remove DROP rule in iptables in order to return MySQL instance
	docker-compose exec ${n} iptables -D INPUT -p tcp --dport 3306 -j DROP

.PHONY: node_prefer
node_prefer:
	docker-compose exec orchestrator orchestrator-client -c register-candidate -i ${fqdn} --promotion-rule prefer