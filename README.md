# Kubernetes Cluster Info Collector

A comprehensive Kubernetes monitoring and data collection platform with **Kafka-based architecture** for scalable, enterprise-grade cluster information collection, real-time streaming, alerting, and operational excellence.


## 🎯 **NEW: Unified API, Consumer/Collector Split, and Robust Tooling**

**Major Update**: The platform now features a unified REST API under `/api/v1` (served by the consumer), a clear split between collector (producer) and consumer (API + DB writer), robust port-forwarding and documentation scripts, and a comprehensive OpenAPI 3.0.3 spec.


### 🏗️ **Architecture Evolution**

**Before (v1.0)**: `Collector → PostgreSQL` (direct write)

**Now (v2.0)**: `Collector → Kafka → Consumer (API) → PostgreSQL` (decoupled, scalable)


### ✨ **What's New**
- 🔄 **Kafka Integration**: Reliable message queuing with Sarama client
- ⚙️ **Producer-Consumer Pattern**: Scalable, fault-tolerant data processing
- 🚀 **Helm Chart**: Complete Kubernetes deployment automation
- 🛡️ **Unified REST API**: All endpoints under `/api/v1` (served by consumer)
- 🧩 **Consumer/Collector Split**: Collector (producer) and Consumer (API+DB) are separate, scalable services
- 📜 **OpenAPI 3.0.3 Spec**: Full API spec in `docs/swagger.yaml`
- 🛠️ **Robust Scripts**: `scripts/port-forward.sh` (port-forward manager), `scripts/view-api-docs.sh` (API docs viewer), and more
- 🧪 **Improved Testing**: End-to-end and hybrid test scripts
- 🏷️ **Version/Commit in API**: `/api/v1/version` returns build version and commit hash

### Hybrid Development Mode Issues

#### Kafka Hostname Resolution Error
If you encounter `dial tcp: lookup kafka: no such host` errors when running the collector in hybrid development mode, you can resolve this by adding a hosts file entry:

**Quick Fix:**
```bash
# Add kafka hostname to your hosts file
sudo bash -c 'echo "127.0.0.1 kafka" >> /etc/hosts'
```

**Why this works:**
- The hybrid setup uses port forwarding (`kubectl port-forward service/kafka 9092:9092`) 
- Port forwarding maps `localhost:9092` → `kafka:9092` in the cluster
- Adding `127.0.0.1 kafka` to `/etc/hosts` allows the local binary to resolve the `kafka` hostname directly to localhost
- This is simpler than complex environment variable management for background processes

**Alternative solutions:**
- Use `KAFKA_BROKERS=localhost:9092` in your environment configuration
- Ensure environment variables are properly passed to background processes in scripts

#### Verifying the Fix
```bash
# Test hostname resolution
ping kafka
# Should resolve to 127.0.0.1

# Check port forwarding is active
kubectl get pods -n cluster-info-dev
kubectl port-forward service/kafka 9092:9092 -n cluster-info-dev &

# Test connectivity
telnet kafka 9092
# Should connect successfully
```

## 📚 Documentation

### 📖 **Comprehensive Documentation Library** **Docker Compose**: Multi-service local development setup
- 📊 **Auto-scaling**: HPA support for consumer pods
- 🔐 **Enterprise Security**: RBAC, ServiceAccount, secret management
- 📈 **Production Ready**: Resource limits, persistence, monitoring integration

## 🚀 Features

### Core Data Collection
- **9 Resource Types**: Deployments, Pods, Nodes, Services, Ingresses, ConfigMaps, Secrets, PersistentVolumes, PersistentVolumeClaims
- **Rich Metadata**: Resource specifications, status, labels, annotations, owner references
- **Historical Tracking**: Time-series data with automatic snapshots
- **Performance Metrics**: Resource usage, capacity, and allocation tracking

### Enterprise Features
- **🔔 Alerting**: Alertmanager integration with configurable alert types
- **📊 Dashboards**: Pre-built Grafana dashboards for monitoring and troubleshooting
- **🌊 Real-time Streaming**: WebSocket support for live data updates
- **🔗 REST API**: Complete API for querying and integration
- **🗄️ Data Retention**: Automatic cleanup with configurable policies
- **📈 Metrics**: 15+ Prometheus metrics for observability

### Kafka Architecture Features
- **📨 Message Durability**: Persistent message storage with configurable retention
- **🔄 Consumer Groups**: Automatic load balancing and fault tolerance
- **📊 Horizontal Scaling**: Scale consumer pods independently based on load
- **🔌 External Support**: Connect to existing Kafka and PostgreSQL instances
- **⚡ Async Processing**: Non-blocking data collection with reliable delivery

### Operational Excellence
- **🏗️ Modular Architecture**: 12+ focused packages with clear separation of concerns
- **🧪 Testing**: Unit tests, integration tests, and validation framework
- **⚙️ Configuration**: Environment variables with validation and defaults
- **📝 Logging**: Structured JSON logging with configurable levels
- **🚦 Health Checks**: Kubernetes-ready liveness and readiness probes
- **🎭 Helm Deployment**: Production-ready Kubernetes deployment automation

## 📋 Quick Start

### 🚀 **Option 1: Helm Deployment (Recommended)**

#### Basic Kubernetes Deployment
```bash
# Clone and navigate
git clone <repository>
cd k8s-cluster-info-collector

# Quick development deployment
./scripts/deploy.sh
# Choose option 1 for development setup with minimal resources

# Or direct Helm install
helm install my-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace
```

#### Production Deployment
```bash
# Production setup with auto-scaling and ingress
helm install my-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace \
  --set collector.schedule="0 */1 * * *" \
  --set consumer.replicas=3 \
  --set consumer.autoscaling.enabled=true \
  --set postgresql.auth.password="secure-password" \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host="cluster-info.example.com"
```

#### External Dependencies
```bash
# Use external Kafka and PostgreSQL
helm install my-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace \
  --set kafka.enabled=false \
  --set kafka.external.enabled=true \
  --set kafka.external.brokers="kafka-1:9092,kafka-2:9092" \
  --set postgresql.enabled=false \
  --set database.host="postgres.example.com" \
  --set database.password="db-password"
```

### 🐳 **Option 2: Docker Compose (Local Development)**

```bash
# Start full stack with Kafka and PostgreSQL
cd docker && docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f collector
docker-compose logs -f consumer
```

### 📦 **Option 3: Traditional Build & Deploy**

#### Legacy Mode (Direct PostgreSQL, No Kafka)
```bash
# Build
go build -o k8s-cluster-info-collector

# Configure environment (disable Kafka)
export KAFKA_ENABLED=false
export DB_HOST=localhost
export DB_PASSWORD=your_password

# Run one-shot collection
./k8s-cluster-info-collector
```

#### Service Mode (With Features)
```bash
# Enable service features to run as long-running service
export METRICS_ENABLED=true
export RETENTION_ENABLED=true
export API_ENABLED=true
export ALERTING_ENABLED=true
export STREAMING_ENABLED=true

# Runs as persistent service
./k8s-cluster-info-collector
```

### 🔍 **Verify Deployment**

```bash
# Check Helm deployment
kubectl get all -n cluster-info
kubectl logs -f deployment/my-cluster-info-consumer -n cluster-info

# Access services (port-forward if needed)
kubectl port-forward service/my-cluster-info 8080:8080 -n cluster-info

# Check endpoints
curl http://localhost:8080/health      # Health check
curl http://localhost:8080/metrics     # Prometheus metrics
curl http://localhost:8081/api/v1/     # REST API (if API enabled)
```

**Note**: When using Helm deployment, the application automatically runs in **Kafka mode** with producer-consumer architecture. For traditional deployment, you can choose between **Kafka mode** or **legacy direct-write mode**.

## 🏗️ Architecture

### 🔄 **Dual Architecture Support**

The collector supports both **legacy direct-write** and **modern Kafka-based** architectures:

#### **Legacy Architecture (v1.0)**
```
┌─────────────────┐    ┌─────────────┐    ┌──────────────┐
│   Kubernetes    │    │  Collector  │    │ PostgreSQL   │
│    Cluster      │───▶│             │───▶│   Database   │
│                 │    │             │    │              │
└─────────────────┘    └─────────────┘    └──────────────┘
```

#### **Kafka Architecture (v2.0 - Recommended)**
```
┌─────────────────┐    ┌─────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Kubernetes    │    │  Collector  │    │    Kafka     │    │   Consumer   │    │ PostgreSQL   │
│    Cluster      │───▶│  (Producer) │───▶│   Message    │───▶│   Service    │───▶│   Database   │
│                 │    │             │    │    Queue     │    │ (Auto-scale) │    │              │
└─────────────────┘    └─────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

### 🎭 **Kafka Architecture Benefits**

#### **Producer (Collector)**
- **Decoupled Collection**: Collector only focuses on gathering data
- **Resilient Publishing**: Kafka handles message persistence and delivery
- **Non-blocking**: Collection continues even if consumer is down
- **Flexible Scheduling**: Run as CronJob or continuous Deployment

#### **Message Queue (Kafka)**
- **Durability**: Messages persisted until successfully processed
- **Scalability**: Multiple partitions for parallel processing
- **Reliability**: Replication and leader election
- **Ordering**: Guaranteed message ordering per partition

#### **Consumer Service**
- **Horizontal Scaling**: Multiple consumer instances with auto-scaling
- **Load Balancing**: Consumer group coordination
- **Fault Tolerance**: Automatic failover and offset management
- **Backpressure Handling**: Process messages at optimal rate

k8s-cluster-info-collector/

### 📦 **Modular Design**

The application follows a clean, modular architecture with focused packages and clear separation of concerns:

```
k8s-cluster-info-collector/
├── main.go                    # Collector entry point
├── cmd/
│   └── consumer/              # Standalone consumer service (serves API)
├── internal/
│   ├── app/                   # Application orchestration & lifecycle
│   ├── collector/             # Kubernetes resource collection
│   ├── kafka/                 # Kafka producer & consumer logic
│   ├── config/                # Configuration management
│   ├── database/              # Database connection and schema
│   ├── kubernetes/            # Kubernetes client wrapper
│   ├── logger/                # Structured logging setup
│   ├── models/                # Data structures and models
│   ├── store/                 # Data persistence layer
│   ├── metrics/               # Prometheus metrics collection
│   ├── retention/             # Data retention management
│   ├── api/                   # REST API server (all endpoints under /api/v1)
│   ├── alerting/              # Alertmanager integration
│   └── streaming/             # WebSocket hub
├── scripts/                   # Utility scripts (port-forward, API docs, test, deploy)
├── helm/                      # Kubernetes deployment charts
│   └── cluster-info-collector/
├── manifests/                 # Kubernetes YAML manifests
│   ├── k8s-job.yaml
│   ├── k8s-cronjob.yaml
│   └── postgres.yaml
├── grafana/                   # Pre-built dashboards
├── docs/                      # Additional documentation
│   └── swagger.yaml           # OpenAPI 3.0.3 API spec
└── docker/
    ├── docker-compose.yml
    └── docker-compose.dev.yml
```

### 🔧 **Key Architecture Benefits**

#### 1. **Separation of Concerns**
- **Configuration**: Isolated in `config/` with environment validation
- **Data Access**: Database operations contained in `database/` and `store/`
- **Kubernetes Integration**: Wrapped in `kubernetes/` and `collector/`
- **Message Processing**: Kafka operations in dedicated `kafka/` package
- **Feature Modules**: Each enterprise feature (API, streaming, alerting) in dedicated packages

#### 2. **Enterprise Scalability**
- **Horizontal Consumer Scaling**: Scale data processing independently
- **Kubernetes-native**: Designed for cloud-native deployment
- **Resource Optimization**: Configurable resource limits and requests
- **Auto-scaling**: HPA support based on CPU/memory metrics
- **External Dependencies**: Support for managed Kafka and PostgreSQL services

#### 3. **Operational Excellence**
- **Health Monitoring**: Comprehensive health checks and readiness probes
- **Observability**: Structured logging, metrics, and distributed tracing ready
- **Graceful Shutdown**: Proper cleanup with signal handling
- **Configuration Flexibility**: Environment-based configuration with validation
- **Security**: RBAC integration and secret management

#### 4. **Development Experience**
- **Testability**: Each package unit testable with clear interfaces
- **Maintainability**: Changes isolated to specific packages
- **Documentation**: Comprehensive guides and examples
- **Local Development**: Docker Compose setup for full stack testing

## 📊 Data Collection & Storage

### Resource Types Collected

| Resource Type | Information Collected |
|---------------|---------------------|
| **Deployments** | Replicas, status, strategy, conditions, labels, annotations |
| **Pods** | Phase, node placement, resource usage, restart counts, container statuses |
| **Nodes** | Capacity, allocatable resources, OS info, Kubernetes version, ready status |
| **Services** | Type, ports, selectors, endpoints, load balancer status |
| **Ingresses** | Rules, hosts, paths, TLS configuration, backend services |
| **ConfigMaps** | Keys, data size, binary data indicators |
| **Secrets** | Type, keys, data size (values encrypted) |
| **PersistentVolumes** | Capacity, access modes, storage class, status, claim bindings |
| **PersistentVolumeClaims** | Requested capacity, status, bound volume information |

### Database Schema
```sql
-- Core snapshot tracking
CREATE TABLE cluster_snapshots (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cluster_name VARCHAR(255),
    metadata JSONB
);

-- Individual resource tables with foreign keys
CREATE TABLE deployments (
    id SERIAL PRIMARY KEY,
    snapshot_id INTEGER REFERENCES cluster_snapshots(id),
    name VARCHAR(255),
    namespace VARCHAR(255),
    replicas INTEGER,
    ready_replicas INTEGER,
    -- ... additional columns
    created_time TIMESTAMP,
    labels JSONB,
    annotations JSONB
);
-- Similar structure for pods, nodes, services, etc.
```

## 📚 Documentation

### 📖 Complete Documentation Index
All detailed documentation is organized in the [`docs/`](docs/) folder:

**[📋 Documentation Index](docs/INDEX.md)** - Complete navigation guide organized by user type and topic

### 🎯 Quick Links by User Type

#### **👨‍💻 For Developers**
- **[Local Development Setup](docs/LOCAL_DEVELOPMENT.md)** - Development environment and workflow
- **[Hybrid Development Guide](docs/ENHANCED_HYBRID_SETUP.md)** - Local binary + K8s services (recommended)
- **[Latest Enhancements](docs/HYBRID_ENHANCEMENT_SUMMARY.md)** - Recent improvements and features

#### **🚀 For DevOps Engineers**  
- **[Deployment Modes](docs/DEPLOYMENT_MODES.md)** - Production configuration and environment variables
- **[Kafka Integration](docs/KAFKA_INTEGRATION.md)** - Streaming architecture and configuration
- **[Namespace Management](docs/NAMESPACE_MANAGEMENT.md)** - Kubernetes best practices

#### **🔧 For API Users**
- **[API Reference](docs/API.md)** - Complete endpoint documentation
- **[Usage Examples](docs/USAGE_EXAMPLES.md)** - Step-by-step deployment examples
- **[Swagger Troubleshooting](docs/SWAGGER_TROUBLESHOOTING.md)** - API documentation issues

#### **🐛 For Troubleshooting**
- **[Service Existence Checks](docs/SERVICE_EXISTENCE_CHECKS.md)** - Service deployment optimization
- **[Namespace Fix Guide](docs/COMPREHENSIVE_NAMESPACE_FIX.md)** - Namespace conflict resolution
- **[Cleanup Guide](docs/CLEANUP_SUMMARY.md)** - Project organization and maintenance


### 🛠️ Interactive Documentation & Utility Scripts
```bash
# View API documentation (Swagger UI, VS Code, HTML, etc.)
./scripts/view-api-docs.sh

# Validate OpenAPI/Swagger spec
./scripts/validate-swagger.sh

# Manage port-forwarding for all services and endpoints
./scripts/port-forward.sh [start|stop|status|test]

# Setup hybrid development environment
./scripts/setup-hybrid.sh

# Test complete system (hybrid mode)
./scripts/test-hybrid-setup.sh
```

## ⚙️ Configuration

### Environment Variables

#### Database Configuration
```bash
DB_HOST=localhost              # Database host
DB_PORT=5432                  # Database port
DB_USER=postgres              # Database username
DB_PASSWORD=your_password     # Database password
DB_NAME=cluster_info          # Database name
DB_SSL_MODE=disable           # SSL mode (disable/require)
```

#### Feature Toggles
```bash
# Metrics and Monitoring
METRICS_ENABLED=true          # Enable Prometheus metrics
METRICS_ADDRESS=:8080         # Metrics server address

# Data Retention
RETENTION_ENABLED=true        # Enable automatic cleanup
RETENTION_MAX_AGE=168h        # Max age (7 days)
RETENTION_MAX_SNAPSHOTS=100   # Max snapshots to keep
RETENTION_CLEANUP_INTERVAL=6h # Cleanup frequency

# REST API
API_ENABLED=true              # Enable REST API server
API_ADDRESS=:8081             # API server address
API_PREFIX=/api/v1            # API URL prefix

# Alerting
ALERTING_ENABLED=false        # Enable Alertmanager integration
ALERTMANAGER_URL=http://localhost:9093
ALERTING_COLLECTION_FAILURES=true
ALERTING_RESOURCE_THRESHOLDS=true
ALERTING_NODE_DOWN=true

# WebSocket Streaming
STREAMING_ENABLED=false       # Enable real-time streaming
STREAMING_ADDRESS=:8082       # WebSocket server address
```

#### Logging Configuration
```bash
LOG_LEVEL=info               # debug, info, warn, error
LOG_FORMAT=json              # json or text
```

### Configuration Modes

#### **Service Mode vs One-Shot Mode**
```bash
# Service Mode (runs continuously) - enabled when ANY feature is active:
export API_ENABLED=true          # REST API server
export METRICS_ENABLED=true      # Prometheus metrics server
export STREAMING_ENABLED=true    # WebSocket streaming
export RETENTION_ENABLED=true    # Background data cleanup
export KAFKA_ENABLED=true        # Kafka integration

# One-Shot Mode (collect and exit) - when ALL features disabled:
export API_ENABLED=false
export METRICS_ENABLED=false  
export STREAMING_ENABLED=false
export RETENTION_ENABLED=false
export KAFKA_ENABLED=false
```

#### **Kafka vs Legacy Mode**
```bash
# Kafka Mode (recommended for production)
export KAFKA_ENABLED=true
export KAFKA_BROKERS=kafka:9092
export KAFKA_TOPIC=cluster-info

# Legacy Mode (direct database writes)
export KAFKA_ENABLED=false
# Database configuration required
```

## 🔔 Alerting

### Alertmanager Integration
The collector integrates with Alertmanager to provide automated alerting:

#### Alert Types
- **ClusterCollectionFailure**: When data collection fails
- **NodeNotReady**: When cluster nodes are not ready
- **HighResourceCount**: When resource counts exceed thresholds
- **DatabaseConnectionFailure**: When database connectivity fails

#### Configuration
```bash
export ALERTING_ENABLED=true
export ALERTMANAGER_URL=http://localhost:9093
export ALERTING_COLLECTION_FAILURES=true
export ALERTING_RESOURCE_THRESHOLDS=true
export ALERTING_NODE_DOWN=true
```

#### Prometheus Rules Example
```yaml
groups:
  - name: k8s-cluster-info-collector
    rules:
      - alert: ClusterCollectionFailure
        expr: rate(cluster_info_collections_total{status="failure"}[5m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Cluster data collection failing"
          description: "Collection failures detected"
```

## 📊 Monitoring & Dashboards

### Prometheus Metrics
```bash
# Collection metrics
cluster_info_collections_total{status}
cluster_info_collection_duration_seconds
cluster_info_resource_count{resource_type}

# Database metrics
cluster_info_database_operation_duration_seconds{operation}

# Streaming metrics
cluster_info_websocket_connections

# Kafka metrics (if enabled)
kafka_producer_messages_sent_total
kafka_consumer_messages_consumed_total
kafka_consumer_lag_total
```

### Grafana Dashboards
Pre-built dashboards included in `grafana/` directory:

#### 1. Cluster Overview Dashboard
- Collection success rates and duration
- Resource counts over time
- Database performance metrics
- WebSocket connection tracking

#### 2. Alerts Dashboard
- Active alerts from Alertmanager
- Node readiness status
- Resource threshold violations
- Collection failure timeline

#### Installation
```bash
# Import via Grafana UI
# Copy content from grafana/*.json files

# Or via API
curl -X POST \
  -H "Content-Type: application/json" \
  -d @grafana/cluster-overview-dashboard.json \
  http://admin:admin@localhost:3000/api/dashboards/db
```

## 🌊 Real-time Streaming

### WebSocket Support
Real-time data streaming for live monitoring:

```javascript
// Connect to WebSocket
const ws = new WebSocket('ws://localhost:8082/api/v1/ws');

ws.onmessage = function(event) {
    const message = JSON.parse(event.data);
    
    switch(message.type) {
        case 'cluster_update':
            // Handle cluster data updates
            console.log('Deployments:', message.data.deployments.length);
            break;
        case 'metrics_update':
            // Handle metrics updates
            break;
        case 'alert':
            // Handle alert notifications
            break;
    }
};
```

## 🔗 REST API

### API Documentation
Complete **Swagger/OpenAPI 3.0.3** documentation is available:
- **Specification**: [`docs/swagger.yaml`](docs/swagger.yaml)
- **Documentation Guide**: [`docs/API.md`](docs/API.md)

#### View Interactive Docs
```bash
# Easy way: Use the provided script (6 viewing options)
./scripts/view-api-docs.sh

# Option 1: Docker + Swagger UI (Recommended)
# Option 2: NPX + HTTP Server (Node.js)
# Option 3: Online Swagger Editor (Copy/Paste)
# Option 4: VS Code Preview (Extension Required)
# Option 5: Quick API Summary (Terminal View)
# Option 6: Generate Static HTML (No Dependencies)

# Or manually with Docker
docker run -p 8080:8080 \
  -e SWAGGER_JSON=/app/swagger.yaml \
  -v $(pwd)/docs/swagger.yaml:/app/swagger.yaml \
  swaggerapi/swagger-ui

# Open http://localhost:8080 in your browser

# Validate documentation
./scripts/validate-swagger.sh
```


### Available Endpoints (Unified under `/api/v1`)

#### Snapshots
- `GET /api/v1/snapshots` - List all snapshots
- `GET /api/v1/snapshots/latest` - Get latest snapshot
- `GET /api/v1/snapshots/{id}` - Get specific snapshot

#### Resources
- `GET /api/v1/deployments` - List deployments
- `GET /api/v1/pods` - List pods
- `GET /api/v1/nodes` - List nodes
- `GET /api/v1/services` - List services
- `GET /api/v1/ingresses` - List ingresses
- `GET /api/v1/configmaps` - List ConfigMaps
- `GET /api/v1/secrets` - List Secrets
- `GET /api/v1/persistent-volumes` - List PersistentVolumes
- `GET /api/v1/persistent-volume-claims` - List PVCs

#### Statistics & Health
- `GET /api/v1/stats` - General statistics
- `GET /api/v1/stats/retention` - Retention statistics
- `GET /api/v1/health` - API health check
- `GET /api/v1/version` - API version and commit hash


### OpenAPI Specification & Documentation

- **OpenAPI/Swagger Spec:** See [`docs/swagger.yaml`](docs/swagger.yaml)
- **Swagger UI:** Use `./scripts/view-api-docs.sh` to view and interact with the API docs in your browser or VS Code.
- **Updating the Spec:** Edit `docs/swagger.yaml` and re-run the script to validate or view changes.

### Example API Usage
```bash
# Get latest cluster snapshot
curl http://localhost:8081/api/v1/snapshots/latest

# Get all pods
curl http://localhost:8081/api/v1/pods | jq .

# Get cluster statistics
curl http://localhost:8081/api/v1/stats | jq .

# Get API version and commit
curl http://localhost:8081/api/v1/version
```
# Get API version and commit
curl http://localhost:8081/api/v1/version
```

## 🗄️ Data Retention

### Automatic Cleanup
Configurable data retention policies:

```bash
# Enable retention
export RETENTION_ENABLED=true
export RETENTION_MAX_AGE=168h        # Keep data for 7 days
export RETENTION_MAX_SNAPSHOTS=100   # Keep max 100 snapshots
export RETENTION_CLEANUP_INTERVAL=6h # Run cleanup every 6 hours
```

### Retention Statistics
```bash
# View retention stats
curl http://localhost:8081/api/v1/stats/retention
```

## 🚀 Deployment Options

### 🎭 **1. Helm Deployment (Recommended)**
```bash
# Quick start
helm install my-cluster-info helm/cluster-info-collector --namespace cluster-info

# Production with custom values  
helm install my-cluster-info helm/cluster-info-collector -f production-values.yaml
```

### 🐳 **2. Docker Compose**
```bash
# Full stack development
cd docker && docker-compose up -d
```

### ⚡ **3. Kubernetes Manifests**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-cluster-info-collector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: k8s-cluster-info-collector
  template:
    metadata:
      labels:
        app: k8s-cluster-info-collector
    spec:
      serviceAccountName: cluster-info-collector
      containers:
      - name: collector
        image: k8s-cluster-info-collector:latest
        env:
        - name: DB_HOST
          value: "postgres-service"
        - name: METRICS_ENABLED
          value: "true"
        - name: API_ENABLED
          value: "true"
        - name: RETENTION_ENABLED
          value: "true"
        - name: KAFKA_ENABLED
          value: "true"
        ports:
        - containerPort: 8080  # Metrics
        - containerPort: 8081  # API
        - containerPort: 8082  # WebSocket
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
        readinessProbe:
          httpGet:
            path: /api/v1/health
            port: 8081
```

## 🧪 Testing

### Unit Tests
```bash
# Run all tests
go test ./...

# Test specific packages
go test ./internal/config
go test ./internal/models
go test ./internal/logger

# Test with coverage
go test ./... -cover

# Verbose testing
go test -v ./...
```

### Integration Tests
```bash
# Run integration tests (requires database and Kubernetes cluster)
go test -v ./integration_test.go
```

### Validation
```bash
# Build verification
go build -o k8s-cluster-info-collector

# Check dependencies
go mod verify
go mod tidy

# Code quality
go vet ./...
go fmt ./...
```

## 🔧 Development

### Prerequisites
- Go 1.21+
- PostgreSQL 12+
- Kubernetes cluster access
- Docker (optional)
- Helm 3.0+ (for chart deployment)

### Local Development
```bash
# Install dependencies
go mod download

# Run with development settings
export LOG_LEVEL=debug
export METRICS_ENABLED=true
export API_ENABLED=true

# Start local development
./k8s-cluster-info-collector
```

### Adding New Resource Types
1. Define model in `internal/models/cluster.go`
2. Add collection logic in `internal/collector/collector.go`
3. Update database schema in `internal/database/database.go`
4. Add storage logic in `internal/store/store.go`
5. Update API endpoints in `internal/api/api.go`
6. Add Kafka serialization (if using Kafka mode)

## 🚨 Troubleshooting

### Common Issues

#### Application Behavior
**Issue**: Application exits immediately instead of running as service
**Solution**: Enable at least one service feature:
```bash
export API_ENABLED=true          # Enable to run as service
export METRICS_ENABLED=true      # Enable to run as service
export STREAMING_ENABLED=true    # Enable to run as service
export RETENTION_ENABLED=true    # Enable to run as service
export KAFKA_ENABLED=true        # Enable to run as service
```

#### Database Connection
```bash
# Test database connectivity
export LOG_LEVEL=debug
export DB_SSL_MODE=disable

# Check connection string
echo "postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=$DB_SSL_MODE"
```

#### Kubernetes Access
```bash
# Verify cluster access
kubectl auth can-i get pods --as=system:serviceaccount:default:cluster-info-collector

# Check service account permissions
kubectl describe clusterrolebinding cluster-info-collector
```

#### Kafka Issues (Kafka Mode)
```bash
# Check Kafka connectivity
kubectl exec -it deployment/kafka -- kafka-topics.sh --list --bootstrap-server localhost:9092

# Check consumer lag
kubectl exec -it deployment/kafka -- kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --group cluster-info-consumer
```

#### Port Conflicts
```bash
# Check port usage
netstat -tlnp | grep :8080
netstat -tlnp | grep :8081
netstat -tlnp | grep :8082
```

### Health Monitoring
```bash
# Check all services
curl http://localhost:8080/health      # Metrics server
curl http://localhost:8081/api/v1/health  # API server

# Verify metrics
curl http://localhost:8080/metrics | grep cluster_info

# Use provided test scripts
./scripts/test-api.sh                          # Test all API endpoints
./scripts/setup-hybrid.sh                      # Validate cluster setup
```

### Additional Troubleshooting Resources
- **[Deployment Modes Guide](docs/DEPLOYMENT_MODES.md)** - Environment variable configuration and mode switching
- **[Swagger Documentation Issues](docs/SWAGGER_TROUBLESHOOTING.md)** - API documentation viewing problems
- **[Complete Usage Examples](docs/USAGE_EXAMPLES.md)** - Step-by-step deployment and configuration examples

## 📈 Performance

### Optimization Tips
- Use appropriate `RETENTION_MAX_SNAPSHOTS` for your storage capacity
- Adjust `RETENTION_CLEANUP_INTERVAL` based on data volume
- Monitor database size with retention statistics
- Use connection pooling for high-throughput scenarios
- Scale consumer pods independently in Kafka mode

### Scaling Considerations
- **Legacy Mode**: Single instance recommended (avoids data duplication)
- **Kafka Mode**: Scale consumers horizontally for higher throughput
- Database can be scaled independently
- API server supports multiple concurrent connections
- WebSocket hub handles multiple streaming clients

## 🎯 Production Checklist

- [ ] Database configured with SSL
- [ ] Service accounts and RBAC configured
- [ ] Resource limits set in Kubernetes deployment
- [ ] Monitoring and alerting configured
- [ ] Log aggregation setup
- [ ] Backup strategy for database
- [ ] Network policies configured
- [ ] Security scanning completed
- [ ] Kafka topics created with appropriate partitions (if using Kafka)
- [ ] Consumer auto-scaling configured (if using Kafka)
- [ ] Dead letter queue configured for failed messages (if using Kafka)

## 📋 Implementation Status

### ✅ Completed Features
- [x] **Core Data Collection** - 9 resource types with rich metadata
- [x] **Dual Architecture Support** - Both legacy and Kafka-based modes
- [x] **Kafka Integration** - Producer-consumer architecture with IBM Sarama
- [x] **Helm Chart Deployment** - Complete Kubernetes deployment automation
- [x] **Modular Architecture** - 12+ focused packages with clear separation
- [x] **Database Storage** - PostgreSQL with proper schema and indexing
- [x] **Prometheus Metrics** - 20+ metrics for comprehensive monitoring
- [x] **Health Endpoints** - Kubernetes-ready probes
- [x] **Unit Testing** - Package-level tests with coverage
- [x] **Integration Testing** - End-to-end validation framework
- [x] **Data Retention** - Automatic cleanup with configurable policies
- [x] **REST API** - Complete API with all resource endpoints
- [x] **Alerting** - Alertmanager integration with multiple alert types
- [x] **Grafana Dashboards** - Production-ready monitoring dashboards
- [x] **WebSocket Streaming** - Real-time data streaming with connection management
- [x] **Configuration Management** - Environment-based with validation
- [x] **Docker Compose Setup** - Multi-service development environment
- [x] **Auto-scaling Support** - HPA for consumer pods in Kafka mode
- [x] **External Dependencies** - Support for managed Kafka and PostgreSQL services
- [x] **Documentation** - Comprehensive guides and examples

### 🚀 Enterprise Ready

The Kubernetes Cluster Info Collector is now a **complete monitoring and alerting platform** with:

- **Dual Architecture**: Support for both legacy direct-write and modern Kafka-based architectures
- **Production-grade architecture** with modular, testable components
- **Kubernetes-native deployment** with comprehensive Helm chart
- **Horizontal scaling** with auto-scaling consumer pods (Kafka mode)
- **Real-time capabilities** with WebSocket streaming and alerting
- **Comprehensive observability** with metrics, logs, and dashboards
- **Operational excellence** with health checks, retention, and graceful shutdown
- **Enterprise integration** with Alertmanager, Grafana, and Prometheus
- **Flexible deployment** supporting on-premises, cloud, and hybrid environments

## � Documentation

### 📖 **Comprehensive Documentation Library**

Detailed documentation is available in the `docs/` directory:

#### **Core Documentation**
- **[API Documentation](docs/API.md)** - Complete REST API reference with v2.0 endpoints, schemas, and examples
- **[Local Development Guide](docs/LOCAL_DEVELOPMENT.md)** - Enhanced local setup with automatic port forwarding and development environments
- **[Usage Examples](docs/USAGE_EXAMPLES.md)** - Comprehensive usage examples for all features including Helm deployment, Kafka integration, monitoring, and development workflows
- **[Deployment Modes](docs/DEPLOYMENT_MODES.md)** - Architecture guide for Legacy vs Kafka deployment modes with environment variable configuration
- **[Kafka Integration](docs/KAFKA_INTEGRATION.md)** - Kafka architecture, configuration, and producer-consumer pattern implementation

#### **Implementation Guides**
- **[Implementation Summary](docs/IMPLEMENTATION_SUMMARY.md)** - Complete overview of Kafka integration and Helm deployment implementation
- **[Documentation Consolidation](docs/DOCUMENTATION_CONSOLIDATION.md)** - Documentation organization and structure guide

#### **Troubleshooting & Fixes**
- **[Swagger Troubleshooting](docs/SWAGGER_TROUBLESHOOTING.md)** - Common Swagger documentation issues and solutions
- **[Swagger Fixes Complete](docs/SWAGGER_FIXES_COMPLETE.md)** - Complete guide to Swagger v2.0 fixes and enhancements
- **[YAML Conversion Fixes](docs/YAML_CONVERSION_FIXES.md)** - Solutions for YAML to JSON conversion issues in documentation tools

### 🛠️ **Utility Scripts**

#### **Documentation & Validation**
- **`./scripts/view-api-docs.sh`** - Interactive API documentation viewer with 6 viewing options (Docker, NPX, static HTML, etc.)
- **`./scripts/validate-swagger.sh`** - Swagger/OpenAPI validation with multiple fallback methods

#### **Development & Testing**
- **`./scripts/setup-hybrid.sh`** - Interactive setup and deployment with 6 enhanced development modes (local, hybrid, K8s) and auto port-forwarding
- **`./scripts/test-hybrid-setup.sh`** - Standalone testing script for hybrid development verification  
- **`./scripts/port-forward.sh`** - Standalone port forwarding management utility with service discovery and services-only mode
- **`./scripts/test-api.sh`** - API endpoint testing script
- **`./scripts/deploy.sh`** - Interactive deployment script with multiple options
- **`./scripts/quick-validate.sh`** - Quick validation of core functionality

#### **Monitoring & Dashboards**
- **`grafana/`** - Pre-built Grafana dashboards for cluster monitoring and alerting
- **`helm/`** - Complete Helm chart with production-ready deployment configurations

### 🎯 **Quick Documentation Access**

```bash
# View API documentation interactively
./view-api-docs.sh

# Validate your setup
./scripts/setup-hybrid.sh

# Check Swagger documentation
./validate-swagger.sh

# Test API endpoints
./test-api.sh

# Quick validation
./quick-validate.sh
```

### 📋 **Documentation Standards**

All documentation follows consistent formatting:
- ✅ **Complete examples** with copy-paste commands
- 🎯 **Use case specific** guides for different scenarios
- 🔧 **Troubleshooting sections** with common issues and solutions
- 📊 **Architecture diagrams** and flow charts
- 🚀 **Production considerations** and best practices

### 🔍 **Finding Specific Information**

| Need | Documentation File | Quick Access |
|------|-------------------|--------------|
| **API Reference** | `docs/API.md` | `./view-api-docs.sh` |
| **Deployment Guide** | `docs/USAGE_EXAMPLES.md` | `./deploy.sh` |
| **Architecture Details** | `docs/DEPLOYMENT_MODES.md` | `docs/KAFKA_INTEGRATION.md` |
| **Troubleshooting** | `docs/SWAGGER_TROUBLESHOOTING.md` | `./validate-swagger.sh` |
| **Setup Validation** | `docs/USAGE_EXAMPLES.md` | `./scripts/setup-hybrid.sh` |

## �📄 License

This project is open source and available under the MIT License.

---

**Ready for production deployment with enterprise-grade monitoring, alerting, real-time streaming, and flexible Kafka-based architecture! 🚀**
