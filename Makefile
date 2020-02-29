.PHONY: help
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build the containers
	docker build -t orchestrator:latest orchestrator/source; \
	docker-compose build $(name); \
	ln -fs ../orchestrator/source/resources/bin/orchestrator-client scripts/orchestrator-client

.PHONY: up
up: ## Run all containers
	docker-compose up $(name)

.PHONY: down
down: ## Stop all containers
	docker rm -f $$(docker ps -aq --filter name=replica*); \
	docker-compose down -v;

.PHONY: clean
clean: ## Stop all containers and clean volumes and local images
	docker rm -f $$(docker ps -aq --filter name=replica*); \
	docker-compose down -v --rmi local --remove-orphans	

.PHONY: ps
ps: ## Show status for all containers
	docker-compose ps

.PHONE: scale
scale: ## Up n MySQL replics
	scripts/scale.sh ${n}

.PHONY: load_schema
load_schema: ## Load default schema on MySQL
	scripts/schema.sh

.PHONY: try_sql
try_sql: ## Execute read/write SQL statements N times, e.g. "make try_sql n=1000"
	scripts/try-sql.sh ${n}

.PHONY: discover
discover: ## Run MySQL orchestrator cluster topology discovering process
	ORCHESTRATOR_API="http://127.0.0.1:80/api" scripts/orchestrator-client -c discover -i 172.20.0.200:3306

.PHONY: node_drop
node_drop: ## Add DROP rule in iptables in order to block MySQL instance
	docker exec -it ${n} iptables -A INPUT -p tcp --dport 3306 -j DROP

.PHONY: node_accept
node_accept: ## Remove DROP rule in iptables in order to return MySQL instance
	docker exec -it ${n} iptables -D INPUT -p tcp --dport 3306 -j DROP

.PHONY: node_delay
node_delay: ## Add delay to log replication
	docker exec -it ${n} mysql -e "STOP SLAVE; CHANGE MASTER TO MASTER_DELAY = ${s}; START SLAVE;"

.PHONY: node_prefer
node_prefer: ## Add prefer promotion rule to replica
	ORCHESTRATOR_API="http://127.0.0.1:80/api" scripts/orchestrator-client -c register-candidate -i ${fqdn} --promotion-rule prefer

.PHONY: orchestrator-client
orchestrator-client: ## Run orchestrator-client command
	ORCHESTRATOR_API="http://127.0.0.1:80/api" scripts/orchestrator-client ${c}