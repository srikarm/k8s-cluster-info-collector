# Makefile for Kafka-enabled Cluster Info Collector

.PHONY: build build-collector build-consumer run-collector run-consumer test clean docker-build docker-up docker-down docker-push docker-logs dev-setup dev-clean kafka-topics kafka-consumer-groups kafka-describe-group db-connect deploy-postgres deploy-collector deploy-cronjob deploy-all kind-load minikube-load status logs psql show-tables show-snapshots dashboard build-dashboard help helm-lint helm-template helm-install helm-install-dev helm-install-prod helm-upgrade helm-uninstall helm-status helm-package helm-deps helm-values helm-test deploy-helm deploy-helm-dev deploy-helm-prod

# Variables
IMAGE_NAME = cluster-info-collector
CONSUMER_IMAGE_NAME = cluster-info-consumer
IMAGE_TAG = latest
DOCKER_REGISTRY ?= localhost:5000

# Helm variables
HELM_CHART_PATH = helm/cluster-info-collector
HELM_RELEASE_NAME ?= cluster-info-collector
HELM_NAMESPACE ?= cluster-info
HELM_VALUES_FILE ?= values.yaml

# Build targets
build: build-collector build-consumer

build-collector:
	@echo "Building collector..."
	go mod tidy
	CGO_ENABLED=0 go build -a -installsuffix cgo -o bin/cluster-info-collector ./main.go

build-consumer:
	@echo "Building consumer..."
	go mod tidy
	CGO_ENABLED=0 go build -a -installsuffix cgo -o bin/consumer ./cmd/consumer

# Run targets
run-collector:
	@echo "Running collector..."
	./bin/cluster-info-collector

run-consumer:
	@echo "Running consumer..."
	./bin/consumer

# Test
test:
	go test ./...

# Clean
clean:
	rm -rf bin/
	kubectl delete -f manifests/k8s-cronjob.yaml --ignore-not-found=true
	kubectl delete -f manifests/k8s-job.yaml --ignore-not-found=true
	kubectl delete -f manifests/postgres.yaml --ignore-not-found=true

# Docker targets
docker-build:
	@echo "Building Docker images..."
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	docker build -f Dockerfile.consumer -t $(CONSUMER_IMAGE_NAME):$(IMAGE_TAG) .

docker-push: docker-build
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	docker tag $(CONSUMER_IMAGE_NAME):$(IMAGE_TAG) $(DOCKER_REGISTRY)/$(CONSUMER_IMAGE_NAME):$(IMAGE_TAG)
	docker push $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(DOCKER_REGISTRY)/$(CONSUMER_IMAGE_NAME):$(IMAGE_TAG)

docker-up:
	@echo "Starting services with Docker Compose..."
	cd docker && docker-compose up -d

docker-down:
	@echo "Stopping services..."
	cd docker && docker-compose down

docker-logs:
	@echo "Viewing logs..."
	cd docker && docker-compose logs -f

# Development
dev-setup:
	@echo "Setting up development environment..."
	@echo "Starting Kafka and PostgreSQL..."
	cd docker && docker-compose up -d postgres kafka zookeeper
	@echo "Waiting for services to be ready..."
	sleep 30

dev-clean:
	@echo "Cleaning up development environment..."
	cd docker && docker-compose down -v

# Kafka management
kafka-topics:
	@echo "Listing Kafka topics..."
	docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092

kafka-consumer-groups:
	@echo "Listing consumer groups..."
	docker exec -it kafka kafka-consumer-groups --list --bootstrap-server localhost:9092

kafka-describe-group:
	@echo "Describing cluster-info-consumer group..."
	docker exec -it kafka kafka-consumer-groups --describe --group cluster-info-consumer --bootstrap-server localhost:9092

# Database management
db-connect:
	@echo "Connecting to PostgreSQL..."
	docker exec -it postgres psql -U postgres -d cluster_info

# Legacy Kubernetes deployment (deprecated - use Kafka version)
deploy-postgres:
	kubectl apply -f manifests/postgres.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	kubectl wait --for=condition=Ready pod -l app=postgres --timeout=300s

deploy-collector:
	kubectl apply -f manifests/k8s-job.yaml

deploy-cronjob:
	kubectl apply -f manifests/k8s-cronjob.yaml

deploy-all: deploy-postgres deploy-collector deploy-cronjob

# Kind cluster support
kind-load: docker-build
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG)
	kind load docker-image $(CONSUMER_IMAGE_NAME):$(IMAGE_TAG)

# Helm chart management
helm-lint:
	@echo "Linting Helm chart..."
	helm lint $(HELM_CHART_PATH)

helm-template:
	@echo "Templating Helm chart..."
	helm template $(HELM_RELEASE_NAME) $(HELM_CHART_PATH) \
		--namespace $(HELM_NAMESPACE) \
		--values $(HELM_CHART_PATH)/$(HELM_VALUES_FILE)

helm-deps:
	@echo "Updating Helm dependencies..."
	helm dependency update $(HELM_CHART_PATH)

helm-package:
	@echo "Packaging Helm chart..."
	helm package $(HELM_CHART_PATH)

helm-install: helm-deps
	@echo "Installing Helm chart..."
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_PATH) \
		--namespace $(HELM_NAMESPACE) \
		--create-namespace \
		--values $(HELM_CHART_PATH)/$(HELM_VALUES_FILE) \
		--set image.tag=$(IMAGE_TAG) \
		--set consumer.image.tag=$(IMAGE_TAG)

helm-install-dev: helm-deps
	@echo "Installing Helm chart for development..."
	helm install $(HELM_RELEASE_NAME)-dev $(HELM_CHART_PATH) \
		--namespace $(HELM_NAMESPACE)-dev \
		--create-namespace \
		--values $(HELM_CHART_PATH)/$(HELM_VALUES_FILE) \
		--set image.tag=$(IMAGE_TAG) \
		--set consumer.image.tag=$(IMAGE_TAG) \
		--set postgresql.auth.password="dev-password" \
		--set kafka.enabled=true

helm-install-prod: helm-deps
	@echo "Installing Helm chart for production..."
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_PATH) \
		--namespace $(HELM_NAMESPACE) \
		--create-namespace \
		--values $(HELM_CHART_PATH)/$(HELM_VALUES_FILE) \
		--set image.tag=$(IMAGE_TAG) \
		--set consumer.image.tag=$(IMAGE_TAG) \
		--set collector.schedule="0 */1 * * *" \
		--set consumer.replicas=3 \
		--set consumer.autoscaling.enabled=true

helm-upgrade:
	@echo "Upgrading Helm release..."
	helm upgrade $(HELM_RELEASE_NAME) $(HELM_CHART_PATH) \
		--namespace $(HELM_NAMESPACE) \
		--values $(HELM_CHART_PATH)/$(HELM_VALUES_FILE) \
		--set image.tag=$(IMAGE_TAG) \
		--set consumer.image.tag=$(IMAGE_TAG)

helm-uninstall:
	@echo "Uninstalling Helm release..."
	helm uninstall $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE)

helm-status:
	@echo "Checking Helm release status..."
	helm status $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE)

helm-values:
	@echo "Getting Helm values..."
	helm get values $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE)

helm-test: helm-deps helm-lint helm-template
	@echo "Running Helm chart tests..."
	@echo "✅ Helm chart validation completed successfully!"

# Combined targets
deploy-helm: docker-build helm-install
	@echo "Built Docker images and deployed with Helm!"

deploy-helm-dev: docker-build helm-install-dev
	@echo "Built Docker images and deployed development environment with Helm!"

deploy-helm-prod: docker-build helm-install-prod
	@echo "Built Docker images and deployed production environment with Helm!"

# Help
help:
	@echo "Available commands:"
	@echo "  build              - Build both collector and consumer"
	@echo "  build-collector    - Build only the collector"
	@echo "  build-consumer     - Build only the consumer"
	@echo "  run-collector      - Run the collector"
	@echo "  run-consumer       - Run the consumer"
	@echo "  test               - Run tests"
	@echo "  clean              - Clean build artifacts"
	@echo ""
	@echo "Docker commands:"
	@echo "  docker-build       - Build Docker images"
	@echo "  docker-push        - Push Docker images to registry"
	@echo "  docker-up          - Start all services with Docker Compose"
	@echo "  docker-down        - Stop all services"
	@echo "  docker-logs        - View logs from all services"
	@echo ""
	@echo "Development commands:"
	@echo "  dev-setup          - Start Kafka and PostgreSQL for development"
	@echo "  dev-clean          - Clean up development environment"
	@echo ""
	@echo "Kafka commands:"
	@echo "  kafka-topics       - List Kafka topics"
	@echo "  kafka-consumer-groups - List consumer groups"
	@echo "  kafka-describe-group  - Describe cluster-info-consumer group"
	@echo ""
	@echo "Database commands:"
	@echo "  db-connect         - Connect to PostgreSQL database"
	@echo ""
	@echo "Kubernetes commands (legacy):"
	@echo "  deploy-postgres    - Deploy PostgreSQL"
	@echo "  deploy-collector   - Deploy collector job"
	@echo "  deploy-cronjob     - Deploy collector cronjob"
	@echo "  deploy-all         - Deploy all components"
	@echo ""
	@echo "Kind cluster:"
	@echo "  kind-load          - Load images into kind cluster"
	@echo ""
	@echo "Helm commands:"
	@echo "  helm-lint          - Lint Helm chart"
	@echo "  helm-template      - Template Helm chart (dry run)"
	@echo "  helm-test          - Run comprehensive Helm chart tests"
	@echo "  helm-deps          - Update Helm dependencies"
	@echo "  helm-package       - Package Helm chart"
	@echo "  helm-install       - Install Helm chart"
	@echo "  helm-install-dev   - Install Helm chart for development"
	@echo "  helm-install-prod  - Install Helm chart for production"
	@echo "  helm-upgrade       - Upgrade Helm release"
	@echo "  helm-uninstall     - Uninstall Helm release"
	@echo "  helm-status        - Check Helm release status"
	@echo "  helm-values        - Get Helm release values"
	@echo ""
	@echo "Combined deployment:"
	@echo "  deploy-helm        - Build images and deploy with Helm"
	@echo "  deploy-helm-dev    - Build images and deploy development environment"
	@echo "  deploy-helm-prod   - Build images and deploy production environment"

# Build and load image into minikube (if using minikube)
minikube-load: docker-build
	minikube image load $(IMAGE_NAME):$(IMAGE_TAG)

# Check job status
status:
	@echo "=== Job Status ==="
	kubectl get jobs
	@echo ""
	@echo "=== CronJob Status ==="
	kubectl get cronjobs
	@echo ""
	@echo "=== Pod Status ==="
	kubectl get pods -l job-name=cluster-info-collector
	@echo ""
	@echo "=== PostgreSQL Status ==="
	kubectl get pods -l app=postgres

# View logs
logs:
	kubectl logs -l job-name=cluster-info-collector --tail=100

# Connect to PostgreSQL for debugging
psql:
	kubectl exec -it deployment/postgres -- psql -U postgres -d cluster_info

# Show database tables
show-tables:
	kubectl exec -it deployment/postgres -- psql -U postgres -d cluster_info -c "\dt"

# Show recent cluster snapshots
show-snapshots:
	kubectl exec -it deployment/postgres -- psql -U postgres -d cluster_info -c "SELECT id, timestamp, jsonb_pretty(data->'deployments'->0) as sample_deployment FROM cluster_snapshots ORDER BY timestamp DESC LIMIT 5;"

# Build and run dashboard API
dashboard:
	go run cmd/dashboard/main.go

# Build dashboard binary
build-dashboard:
	go build -o dashboard cmd/dashboard/main.go
