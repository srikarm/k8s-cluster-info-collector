# Usage Examples: Complete Feature Set (v2.0)

## Overview
This document provides comprehensive usage examples for **all implemented features** of the Kubernetes Cluster Info Collector v2.0, including Kafka-based architecture, Helm deployment, monitoring, alerting, API access, real-time streaming, and development workflows.

## 🚀 Quick Start Examples

### 1. Helm Deployment (Recommended)

#### Development Environment
```bash
# Quick development deployment
helm install dev-cluster-info helm/cluster-info-collector \
  --namespace cluster-info-dev \
  --create-namespace \
  --set collector.schedule="*/5 * * * *" \
  --set consumer.replicaCount=1 \
  --set consumer.autoscaling.enabled=false \
  --set postgresql.auth.password="devpassword"

# Check deployment status
kubectl get all -n cluster-info-dev
```

#### Production Environment
```bash
# Production deployment with auto-scaling
helm install prod-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace \
  --set collector.schedule="0 */1 * * *" \
  --set consumer.replicaCount=3 \
  --set consumer.autoscaling.enabled=true \
  --set consumer.autoscaling.maxReplicas=20 \
  --set postgresql.auth.password="secure-production-password" \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host="cluster-info.company.com"
```

#### External Dependencies
```bash
# Use existing Kafka and PostgreSQL
helm install external-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace \
  --set kafka.enabled=false \
  --set kafka.external.enabled=true \
  --set kafka.external.brokers="kafka-1.company.com:9092,kafka-2.company.com:9092" \
  --set postgresql.enabled=false \
  --set database.host="postgres.company.com" \
  --set database.password="external-db-password"
```

### 2. Docker Compose (Local Development)

```bash
# Start full stack
docker-compose up -d

# Check services
docker-compose ps

# View collector logs
docker-compose logs -f collector

# View consumer logs
docker-compose logs -f consumer

# Stop services
docker-compose down
```

### 3. Interactive Deployment Script

```bash
# Use the deployment script for guided setup
./deploy.sh

# Available options:
# 1) Development (minimal resources)
# 2) Production (full features, auto-scaling)
# 3) External dependencies (existing Kafka/PostgreSQL)
# 4) Custom values file
```

## 🔄 Kafka Architecture Examples

### Producer Configuration

```bash
# Configure collector as Kafka producer
export KAFKA_ENABLED=true
export KAFKA_BROKERS=localhost:9092
export KAFKA_TOPIC=cluster-info
export KAFKA_PARTITION=0

# Performance tuning
export KAFKA_BATCH_SIZE=16384
export KAFKA_LINGER_MS=100
export KAFKA_BUFFER_MEMORY=33554432

# Run collector (producer mode)
./k8s-cluster-info-collector
```

### Consumer Configuration

```bash
# Configure standalone consumer
export KAFKA_ENABLED=true
export KAFKA_BROKERS=localhost:9092
export KAFKA_TOPIC=cluster-info
export KAFKA_GROUP_ID=cluster-info-consumer

# Database connection for consumer
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=clusterinfo
export DB_PASSWORD=your_password
export DB_NAME=clusterinfo

# Run consumer service
./consumer
```

### Message Flow Monitoring

```bash
# Check Kafka topics
kubectl exec -it deployment/kafka -- kafka-topics.sh \
  --list --bootstrap-server localhost:9092

# Check consumer group status
kubectl exec -it deployment/kafka -- kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group cluster-info-consumer

# Monitor message production
kubectl logs -f deployment/cluster-info-collector | grep -i kafka

# Monitor message consumption
kubectl logs -f deployment/cluster-info-consumer | grep -i processed
```

### Scaling Consumers

```bash
# Scale consumer pods manually
kubectl scale deployment cluster-info-consumer --replicas=5

# Update HPA settings
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set consumer.autoscaling.maxReplicas=30 \
  --set consumer.autoscaling.targetCPUUtilizationPercentage=60

# Check HPA status
kubectl get hpa cluster-info-consumer
```

## 📊 Configuration Examples

### Legacy Mode (Direct PostgreSQL)

```bash
# Disable Kafka for legacy mode
export KAFKA_ENABLED=false

# Configure database connection
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=your_password
export DB_NAME=cluster_info
export DB_SSL_MODE=require

# One-shot collection (no service features)
export METRICS_ENABLED=false
export API_ENABLED=false
export STREAMING_ENABLED=false
export RETENTION_ENABLED=false

# Run collector
./k8s-cluster-info-collector
```

### Service Mode (With Features)

```bash
# Enable service features for long-running mode
export KAFKA_ENABLED=true
export METRICS_ENABLED=true
export API_ENABLED=true
export STREAMING_ENABLED=true
export RETENTION_ENABLED=true
export ALERTING_ENABLED=true

# Configure service endpoints
export METRICS_ADDRESS=:8080
export API_ADDRESS=:8081
export STREAMING_ADDRESS=:8082

# Configure retention
export RETENTION_MAX_AGE=168h        # 7 days
export RETENTION_MAX_SNAPSHOTS=100
export RETENTION_CLEANUP_INTERVAL=6h

# Run as service
./k8s-cluster-info-collector
```

### Helm Values Examples

#### Development values.yaml
```yaml
# values-dev.yaml
collector:
  schedule: "*/5 * * * *"
  mode: "cronjob"
  
consumer:
  replicaCount: 1
  autoscaling:
    enabled: false
    
postgresql:
  auth:
    password: "devpassword"
  primary:
    persistence:
      size: "1Gi"
      
kafka:
  persistence:
    size: "1Gi"
    
monitoring:
  serviceMonitor:
    enabled: false
```

#### Production values.yaml
```yaml
# values-prod.yaml
collector:
  schedule: "0 */1 * * *"
  mode: "cronjob"
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
      
consumer:
  replicaCount: 5
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 60
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
      
postgresql:
  auth:
    password: "super-secure-password"
  primary:
    persistence:
      size: "100Gi"
      storageClass: "fast-ssd"
    resources:
      requests:
        cpu: "500m"
        memory: "1Gi"
      limits:
        cpu: "2000m"
        memory: "4Gi"
        
kafka:
  persistence:
    size: "50Gi"
    storageClass: "fast-ssd"
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
      
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: cluster-info.company.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: cluster-info-tls
      hosts:
        - cluster-info.company.com
        
monitoring:
  serviceMonitor:
    enabled: true
    labels:
      prometheus: "monitoring"
```

#### External Dependencies values.yaml
```yaml
# values-external.yaml
kafka:
  enabled: false
  external:
    enabled: true
    brokers: "kafka-1.company.com:9092,kafka-2.company.com:9092,kafka-3.company.com:9092"
    
postgresql:
  enabled: false
  
database:
  host: "postgres.company.com"
  port: 5432
  username: "clusterinfo"
  password: "external-db-password"
  database: "clusterinfo"
  sslmode: "require"
```

## 📈 Monitoring & Metrics Examples

### Prometheus Metrics (Enhanced for v2.0)

#### Enable Metrics Collection
```bash
# Via environment variables
export METRICS_ENABLED=true
export METRICS_ADDRESS=:8080

# Via Helm deployment (automatically enabled)
helm install my-cluster-info helm/cluster-info-collector \
  --set monitoring.serviceMonitor.enabled=true
```

#### Available Metrics

**Collection Metrics:**
- `cluster_info_collections_total{status}` - Total collections by status (success/failure)
- `cluster_info_collection_duration_seconds` - Collection duration by resource type
- `cluster_info_resource_count{resource_type}` - Number of resources collected
- `cluster_info_collection_errors_total{type}` - Collection errors by type

**Kafka Metrics (v2.0):**
- `kafka_producer_messages_sent_total` - Messages sent to Kafka
- `kafka_producer_message_send_duration_seconds` - Message send duration
- `kafka_consumer_messages_consumed_total` - Messages consumed from Kafka
- `kafka_consumer_lag_total` - Consumer lag per partition
- `kafka_consumer_processing_duration_seconds` - Message processing time

**Database Metrics:**
- `cluster_info_database_operations_total{operation,status}` - Database operations
- `cluster_info_database_operation_duration_seconds{operation}` - Database operation duration
- `cluster_info_database_connections_active` - Active database connections

**Streaming Metrics:**
- `cluster_info_websocket_connections` - Active WebSocket connections
- `cluster_info_websocket_messages_sent_total` - Messages sent via WebSocket

#### Accessing Metrics
```bash
# Direct access
curl http://localhost:8080/metrics

# Via port-forward
kubectl port-forward service/my-cluster-info 8080:8080
curl http://localhost:8080/metrics

# Health check
curl http://localhost:8080/health
```

#### Prometheus Configuration
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cluster-info-collector'
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
            - cluster-info
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: .*cluster-info.*
    scrape_interval: 30s
    metrics_path: /metrics
```

#### ServiceMonitor for Prometheus Operator
```yaml
# Automatically created by Helm when monitoring.serviceMonitor.enabled=true
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cluster-info-collector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: cluster-info-collector
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### Grafana Dashboard Examples

#### Key Queries for Dashboards

**Collection Success Rate:**
```promql
rate(cluster_info_collections_total{status="success"}[5m]) / 
rate(cluster_info_collections_total[5m]) * 100
```

**Resources Collected Over Time:**
```promql
sum(cluster_info_resource_count) by (resource_type)
```

**Collection Duration 95th Percentile:**
```promql
histogram_quantile(0.95, 
  rate(cluster_info_collection_duration_seconds_bucket[5m])
)
```

**Kafka Message Production Rate:**
```promql
rate(kafka_producer_messages_sent_total[5m])
```

**Consumer Lag:**
```promql
sum(kafka_consumer_lag_total) by (topic, partition)
```

**Database Operation Duration:**
```promql
histogram_quantile(0.95,
  rate(cluster_info_database_operation_duration_seconds_bucket[5m])
) by (operation)
```

#### Dashboard Import
```bash
# Import pre-built dashboards
kubectl create configmap grafana-dashboards \
  --from-file=grafana/cluster-overview-dashboard.json \
  --from-file=grafana/alerts-dashboard.json \
  -n monitoring

# Or via Grafana API
curl -X POST \
  -H "Content-Type: application/json" \
  -d @grafana/cluster-overview-dashboard.json \
  http://admin:admin@grafana:3000/api/dashboards/db
```

## 🔔 Alerting Examples

### Alertmanager Integration

#### Enable Alerting
```bash
# Via environment variables
export ALERTING_ENABLED=true
export ALERTMANAGER_URL=http://alertmanager:9093
export ALERTING_COLLECTION_FAILURES=true
export ALERTING_RESOURCE_THRESHOLDS=true
export ALERTING_NODE_DOWN=true

# Via Helm (configure in values.yaml)
alerting:
  enabled: true
  alertmanagerUrl: "http://alertmanager.monitoring:9093"
  collectionFailures: true
  resourceThresholds: true
  nodeDown: true
```

#### Prometheus Alert Rules
```yaml
# cluster-info-alerts.yaml
groups:
  - name: cluster-info-collector
    rules:
      - alert: ClusterCollectionFailure
        expr: rate(cluster_info_collections_total{status="failure"}[5m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Cluster data collection failing"
          description: "Collection failures detected for {{ $labels.instance }}"

      - alert: KafkaConsumerLag
        expr: kafka_consumer_lag_total > 1000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High Kafka consumer lag"
          description: "Consumer lag is {{ $value }} messages"

      - alert: NodeNotReady
        expr: cluster_info_resource_count{resource_type="nodes"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "No ready nodes found"
          description: "Cluster has no ready nodes"

      - alert: DatabaseConnectionFailure
        expr: rate(cluster_info_database_operations_total{status="failure"}[5m]) > 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Database connection issues"
          description: "Database operations failing"
```

#### Alertmanager Configuration
```yaml
# alertmanager.yml
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: 'Cluster Info Collector Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

## 🌊 WebSocket Streaming Examples

### Enable Real-time Streaming

```bash
# Via environment variables
export STREAMING_ENABLED=true
export STREAMING_ADDRESS=:8082

# Via Helm deployment
helm install my-cluster-info helm/cluster-info-collector \
  --set streaming.enabled=true \
  --set streaming.port=8082
```

### JavaScript Client Example

```javascript
// Connect to WebSocket endpoint
const ws = new WebSocket('ws://localhost:8082/api/v1/ws');

ws.onopen = function(event) {
    console.log('Connected to cluster info stream');
};

ws.onmessage = function(event) {
    const message = JSON.parse(event.data);
    
    switch(message.type) {
        case 'cluster_update':
            handleClusterUpdate(message.data);
            break;
        case 'metrics_update':
            handleMetricsUpdate(message.data);
            break;
        case 'alert':
            handleAlert(message.data);
            break;
    }
};

function handleClusterUpdate(data) {
    console.log('Cluster update received:');
    console.log(`- Deployments: ${data.deployments.length}`);
    console.log(`- Pods: ${data.pods.length}`);
    console.log(`- Nodes: ${data.nodes.length}`);
    
    // Update UI with new data
    updateClusterDashboard(data);
}

function handleMetricsUpdate(metrics) {
    console.log('Metrics update:', metrics);
    updateMetricsDashboard(metrics);
}

function handleAlert(alert) {
    console.log('Alert received:', alert);
    showAlertNotification(alert);
}

ws.onerror = function(error) {
    console.error('WebSocket error:', error);
};

ws.onclose = function(event) {
    console.log('WebSocket connection closed');
    // Implement reconnection logic
    setTimeout(() => {
        connectWebSocket();
    }, 5000);
};
```

### Python Client Example

```python
import asyncio
import websockets
import json

async def handle_cluster_info():
    uri = "ws://localhost:8082/api/v1/ws"
    
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected to cluster info stream")
            
            async for message in websocket:
                data = json.loads(message)
                
                if data['type'] == 'cluster_update':
                    handle_cluster_update(data['data'])
                elif data['type'] == 'metrics_update':
                    handle_metrics_update(data['data'])
                elif data['type'] == 'alert':
                    handle_alert(data['data'])
                    
    except Exception as e:
        print(f"WebSocket error: {e}")

def handle_cluster_update(cluster_data):
    print(f"Cluster update received:")
    print(f"- Deployments: {len(cluster_data['deployments'])}")
    print(f"- Pods: {len(cluster_data['pods'])}")
    print(f"- Nodes: {len(cluster_data['nodes'])}")

def handle_metrics_update(metrics):
    print(f"Metrics update: {metrics}")

def handle_alert(alert):
    print(f"Alert: {alert}")

# Run the client
asyncio.run(handle_cluster_info())
```

## 🔗 REST API Examples

### Enable API Server

```bash
# Via environment variables
export API_ENABLED=true
export API_ADDRESS=:8081
export API_PREFIX=/api/v1

# Via Helm deployment (automatically enabled)
helm install my-cluster-info helm/cluster-info-collector \
  --set api.enabled=true \
  --set service.ports.api=8081
```

### API Endpoints Usage

#### Snapshots
```bash
# Get all snapshots
curl http://localhost:8081/api/v1/snapshots | jq .

# Get latest snapshot
curl http://localhost:8081/api/v1/snapshots/latest | jq .

# Get specific snapshot
curl http://localhost:8081/api/v1/snapshots/123 | jq .
```

#### Resources
```bash
# Get all deployments
curl http://localhost:8081/api/v1/deployments | jq .

# Get deployments with filters
curl "http://localhost:8081/api/v1/deployments?namespace=default&limit=10" | jq .

# Get all pods
curl http://localhost:8081/api/v1/pods | jq .

# Get pods on specific node
curl "http://localhost:8081/api/v1/pods?node=worker-1" | jq .

# Get all nodes
curl http://localhost:8081/api/v1/nodes | jq .

# Get services
curl http://localhost:8081/api/v1/services | jq .

# Get ingresses
curl http://localhost:8081/api/v1/ingresses | jq .
```

#### Statistics
```bash
# General statistics
curl http://localhost:8081/api/v1/stats | jq .

# Retention statistics
curl http://localhost:8081/api/v1/stats/retention | jq .

# Health check
curl http://localhost:8081/api/v1/health
```

### API Response Examples

#### Deployment Response
```json
{
  "deployments": [
    {
      "id": 1,
      "snapshot_id": 123,
      "name": "nginx-deployment",
      "namespace": "default",
      "replicas": 3,
      "ready_replicas": 3,
      "updated_replicas": 3,
      "available_replicas": 3,
      "labels": {
        "app": "nginx"
      },
      "annotations": {
        "deployment.kubernetes.io/revision": "1"
      },
      "created_time": "2024-01-01T12:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "per_page": 50
}
```

#### Statistics Response
```json
{
  "snapshot_count": 150,
  "latest_snapshot": {
    "id": 150,
    "timestamp": "2024-01-01T15:30:00Z",
    "resource_counts": {
      "deployments": 25,
      "pods": 75,
      "nodes": 3,
      "services": 30,
      "ingresses": 5
    }
  },
  "collection_stats": {
    "total_collections": 150,
    "successful_collections": 148,
    "failed_collections": 2,
    "average_duration_seconds": 12.5
  }
}
```

## 🗄️ Data Retention Examples

### Enable Data Retention

```bash
# Via environment variables
export RETENTION_ENABLED=true
export RETENTION_MAX_AGE=168h        # 7 days
export RETENTION_MAX_SNAPSHOTS=100   # Keep max 100 snapshots
export RETENTION_CLEANUP_INTERVAL=6h # Run cleanup every 6 hours

# Via Helm deployment
helm install my-cluster-info helm/cluster-info-collector \
  --set retention.enabled=true \
  --set retention.maxAge="168h" \
  --set retention.maxSnapshots=100 \
  --set retention.cleanupInterval="6h"
```

### Retention Statistics
```bash
# View retention stats via API
curl http://localhost:8081/api/v1/stats/retention | jq .

# Expected response:
{
  "policy": {
    "max_age_hours": 168,
    "max_snapshots": 100,
    "cleanup_interval_hours": 6
  },
  "current_stats": {
    "total_snapshots": 85,
    "oldest_snapshot_age_hours": 150,
    "disk_usage_mb": 2500
  },
  "last_cleanup": {
    "timestamp": "2024-01-01T12:00:00Z",
    "deleted_snapshots": 5,
    "freed_space_mb": 150
  }
}
```

### Manual Cleanup
```bash
# Trigger manual cleanup via API
curl -X POST http://localhost:8081/api/v1/retention/cleanup

# Or via kubectl (if running in cluster)
kubectl exec deployment/cluster-info-collector -- \
  sh -c 'curl -X POST http://localhost:8081/api/v1/retention/cleanup'
```

## 📊 Database Query Examples

### New Resource Types (v2.0)

The collector now gathers 9 comprehensive resource types:

### Services
- Service name, namespace, type
- Cluster IP and external IPs
- Port configurations
- Selectors and labels

### Ingresses
- Hostname rules and paths
- TLS configuration
- Backend service mappings
- Path types and routing rules

### ConfigMaps & Secrets
- Metadata and key information
- Data size tracking
- Reference relationships

### PersistentVolumes & PersistentVolumeClaims
- Storage capacity and usage
- Access modes and storage classes
- Binding relationships

### Advanced SQL Queries

```sql
-- Get all services and their ports
SELECT 
    s.name,
    s.namespace,
    s.type,
    s.cluster_ip,
    jsonb_pretty(s.data->'ports') as ports
FROM services s
WHERE s.snapshot_id = (SELECT MAX(id) FROM cluster_snapshots);

-- Get ingress rules with TLS information
SELECT 
    i.name,
    i.namespace,
    i.hosts,
    jsonb_pretty(i.data->'tls') as tls_config,
    jsonb_pretty(i.data->'rules') as routing_rules
FROM ingresses i
WHERE i.snapshot_id = (SELECT MAX(id) FROM cluster_snapshots);

-- Resource summary by type with trends
SELECT 
    'deployments' as resource_type,
    COUNT(*) as current_count,
    (SELECT COUNT(*) FROM deployments WHERE snapshot_id = (SELECT MAX(id) - 1 FROM cluster_snapshots)) as previous_count
FROM deployments 
WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
UNION ALL
SELECT 'pods', COUNT(*), 
    (SELECT COUNT(*) FROM pods WHERE snapshot_id = (SELECT MAX(id) - 1 FROM cluster_snapshots))
FROM pods WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
UNION ALL
SELECT 'nodes', COUNT(*),
    (SELECT COUNT(*) FROM nodes WHERE snapshot_id = (SELECT MAX(id) - 1 FROM cluster_snapshots))
FROM nodes WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots);

-- Pod resource utilization analysis
SELECT 
    p.name,
    p.namespace,
    p.node_name,
    (p.data->'containers'->0->'resources'->'requests'->>'cpu') as cpu_request,
    (p.data->'containers'->0->'resources'->'requests'->>'memory') as memory_request,
    p.restart_count,
    p.phase
FROM pods p
WHERE p.snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
    AND p.restart_count > 5
ORDER BY p.restart_count DESC;

-- Storage analysis
SELECT 
    pv.name,
    pv.capacity,
    pv.storage_class,
    pv.access_modes,
    pvc.name as claim_name,
    pvc.namespace as claim_namespace
FROM persistent_volumes pv
LEFT JOIN persistent_volume_claims pvc ON pv.name = pvc.volume_name
WHERE pv.snapshot_id = (SELECT MAX(id) FROM cluster_snapshots);

-- Deployment health check
SELECT 
    d.name,
    d.namespace,
    d.replicas,
    d.ready_replicas,
    CASE 
        WHEN d.ready_replicas = d.replicas THEN 'Healthy'
        WHEN d.ready_replicas = 0 THEN 'Critical'
        ELSE 'Warning'
    END as health_status,
    COUNT(p.id) as actual_pods
FROM deployments d
LEFT JOIN pods p ON d.name = p.deployment_name AND d.namespace = p.namespace
WHERE d.snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
GROUP BY d.id, d.name, d.namespace, d.replicas, d.ready_replicas
ORDER BY health_status, d.name;
```

## 🧪 Testing Examples

### Unit Testing

Run tests for specific packages:

```bash
# Test configuration loading
go test ./internal/config -v

# Test Kafka integration
go test ./internal/kafka -v

# Test data models
go test ./internal/models -v

# Test logger setup
go test ./internal/logger -v

# Run all tests
go test ./... -v

# Run tests with coverage
go test ./... -cover

# Specific test patterns
go test ./... -run TestKafka -v
go test ./... -run TestProducer -v
```

### Integration Testing

Run integration tests (requires database and Kubernetes cluster):

```bash
# Set up test environment
export DB_HOST=localhost
export DB_USER=postgres
export DB_PASSWORD=test123
export KAFKA_ENABLED=true
export KAFKA_BROKERS=localhost:9092

# Run integration tests
go test -v ./integration_test.go

# Skip integration tests in CI
go test -short ./...

# Test with race condition detection
go test -race ./...
```

### Load Testing

```bash
# Test Kafka throughput
for i in {1..100}; do
  ./k8s-cluster-info-collector &
done

# Monitor consumer performance
kubectl top pods -n cluster-info

# Check Kafka metrics
kubectl exec -it deployment/kafka -- kafka-run-class.sh kafka.tools.ConsumerPerformance \
  --bootstrap-server localhost:9092 \
  --topic cluster-info \
  --messages 1000
```

## 🔧 Development Examples

### Adding New Resource Types

The modular architecture makes it easy to extend the collector:

1. **Add new models** to `internal/models/cluster.go`
2. **Add collection logic** to `internal/collector/collector.go`  
3. **Add database schema** to `internal/database/database.go`
4. **Add storage logic** to `internal/store/store.go`
5. **Update ClusterInfo struct** to include new resources
6. **Add Kafka serialization** (if using Kafka mode)
7. **Add tests** for new functionality

### Example: Adding ConfigMaps

```go
// 1. Add to models (internal/models/cluster.go)
type ConfigMapInfo struct {
    Name        string            `json:"name"`
    Namespace   string            `json:"namespace"`
    CreatedTime time.Time         `json:"created_time"`
    Data        map[string]string `json:"data"`
    Labels      map[string]string `json:"labels"`
}

// 2. Update ClusterInfo
type ClusterInfo struct {
    // ...existing fields
    ConfigMaps []ConfigMapInfo `json:"configmaps"`
}

// 3. Add collector method (internal/collector/collector.go)
func (c *ClusterCollector) collectConfigMaps(ctx context.Context) ([]models.ConfigMapInfo, error) {
    configmaps, err := c.client.CoreV1().ConfigMaps("").List(ctx, metav1.ListOptions{})
    if err != nil {
        return nil, fmt.Errorf("failed to list configmaps: %w", err)
    }
    
    var configMapInfos []models.ConfigMapInfo
    for _, cm := range configmaps.Items {
        configMapInfos = append(configMapInfos, models.ConfigMapInfo{
            Name:        cm.Name,
            Namespace:   cm.Namespace,
            CreatedTime: cm.CreationTimestamp.Time,
            Data:        cm.Data,
            Labels:      cm.Labels,
        })
    }
    
    return configMapInfos, nil
}

// 4. Add database table (internal/database/database.go)
const createConfigMapsTable = `
CREATE TABLE IF NOT EXISTS configmaps (
    id SERIAL PRIMARY KEY,
    snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    namespace VARCHAR(255) NOT NULL,
    created_time TIMESTAMP NOT NULL,
    data JSONB NOT NULL,
    labels JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);`

// 5. Add storage method (internal/store/store.go)
func (s *Store) storeConfigMaps(tx *sql.Tx, snapshotID int, configmaps []models.ConfigMapInfo) error {
    stmt, err := tx.Prepare(`
        INSERT INTO configmaps (snapshot_id, name, namespace, created_time, data, labels)
        VALUES ($1, $2, $3, $4, $5, $6)
    `)
    if err != nil {
        return fmt.Errorf("failed to prepare configmaps statement: %w", err)
    }
    defer stmt.Close()
    
    for _, cm := range configmaps {
        dataJSON, _ := json.Marshal(cm.Data)
        labelsJSON, _ := json.Marshal(cm.Labels)
        
        _, err := stmt.Exec(snapshotID, cm.Name, cm.Namespace, cm.CreatedTime, dataJSON, labelsJSON)
        if err != nil {
            return fmt.Errorf("failed to insert configmap %s: %w", cm.Name, err)
        }
    }
    
    return nil
}
```

### Local Development with Docker Compose

```bash
# Start development environment
docker-compose up -d kafka postgres

# Build and run collector locally
export KAFKA_ENABLED=true
export KAFKA_BROKERS=localhost:9092
export DB_HOST=localhost
go run main.go

# Run consumer locally
export KAFKA_ENABLED=true
export KAFKA_BROKERS=localhost:9092
export DB_HOST=localhost
go run cmd/consumer/main.go

# View logs
docker-compose logs -f
```

### Custom Helm Values for Development

```yaml
# values-local.yaml
collector:
  schedule: "*/2 * * * *"  # Every 2 minutes for testing
  image:
    repository: "local/cluster-info-collector"
    tag: "dev"
    pullPolicy: "Never"  # Use local image
    
consumer:
  replicaCount: 1
  image:
    repository: "local/cluster-info-consumer"
    tag: "dev"
    pullPolicy: "Never"
  autoscaling:
    enabled: false
    
postgresql:
  auth:
    password: "devpassword"
  primary:
    persistence:
      enabled: false  # Use memory for development
      
kafka:
  persistence:
    enabled: false  # Use memory for development
    
# Enable debug logging
config:
  logLevel: "debug"
  logFormat: "text"
```

```bash
# Deploy for local development
helm install dev-cluster-info helm/cluster-info-collector \
  -f values-local.yaml \
  --namespace cluster-info-dev \
  --create-namespace
```

This modular architecture makes it easy to extend the collector with new resource types while maintaining clean separation of concerns and supporting both legacy and Kafka-based architectures.

## 🚨 Troubleshooting Examples

### Common Issues and Solutions

#### Collection Failures

**Symptom:** Collections failing with authentication errors
```bash
# Check RBAC permissions
kubectl auth can-i list pods --as=system:serviceaccount:cluster-info:cluster-info-collector
kubectl auth can-i list deployments --as=system:serviceaccount:cluster-info:cluster-info-collector

# Check service account
kubectl get serviceaccounts -n cluster-info
kubectl describe serviceaccount cluster-info-collector -n cluster-info

# Check cluster role binding
kubectl get clusterrolebindings | grep cluster-info
kubectl describe clusterrolebinding cluster-info-collector
```

**Solution:** Ensure proper RBAC configuration:
```bash
# Apply RBAC from Helm chart
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set rbac.create=true

# Or manually apply RBAC
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-info-collector
rules:
- apiGroups: [""]
  resources: ["pods", "nodes", "services", "configmaps", "secrets", "persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
EOF
```

#### Kafka Connectivity Issues

**Symptom:** Kafka producer/consumer connection failures
```bash
# Check Kafka pod status
kubectl get pods -l app=kafka -n cluster-info

# Check Kafka logs
kubectl logs -l app=kafka -n cluster-info

# Test Kafka connectivity from collector pod
kubectl exec deployment/cluster-info-collector -- \
  nc -zv kafka-service 9092

# Test topic existence
kubectl exec deployment/cluster-info-collector -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka-service:9092 --list
```

**Solution:** Fix Kafka connectivity:
```bash
# Create topic manually if needed
kubectl exec deployment/cluster-info-collector -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka-service:9092 \
  --create --topic cluster-info --partitions 3 --replication-factor 1

# Check Kafka configuration
helm get values my-cluster-info | grep -A 10 kafka

# Update Kafka brokers configuration
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set kafka.brokers="kafka-service:9092"
```

#### Database Connection Issues

**Symptom:** Database connection failures
```bash
# Check PostgreSQL pod status
kubectl get pods -l app=postgresql -n cluster-info

# Check database logs
kubectl logs -l app=postgresql -n cluster-info

# Test database connectivity
kubectl exec deployment/cluster-info-collector -- \
  psql -h postgresql-service -U postgres -d cluster_info -c "SELECT 1;"
```

**Solution:** Fix database connectivity:
```bash
# Check database configuration
helm get values my-cluster-info | grep -A 10 postgresql

# Update database connection string
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set postgresql.auth.database="cluster_info" \
  --set postgresql.auth.username="postgres"

# Reset database password if needed
kubectl delete secret my-cluster-info-postgresql
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set postgresql.auth.password="newpassword"
```

#### Consumer Lag Issues

**Symptom:** High consumer lag in Kafka
```bash
# Check consumer group lag
kubectl exec deployment/kafka -- \
  /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group cluster-info-consumer

# Check consumer metrics
curl http://cluster-info-consumer:8080/metrics | grep kafka_consumer_lag
```

**Solution:** Scale consumers or optimize processing:
```bash
# Scale up consumers
kubectl scale deployment cluster-info-consumer --replicas=3

# Or use HPA to auto-scale
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set consumer.autoscaling.enabled=true \
  --set consumer.autoscaling.minReplicas=2 \
  --set consumer.autoscaling.maxReplicas=10 \
  --set consumer.autoscaling.targetCPUUtilizationPercentage=70
```

#### Memory/CPU Issues

**Symptom:** OOMKilled or high CPU usage
```bash
# Check resource usage
kubectl top pods -n cluster-info

# Check resource limits
kubectl describe pod -l app=cluster-info-collector -n cluster-info

# Check memory usage over time
kubectl exec deployment/cluster-info-collector -- cat /proc/meminfo
```

**Solution:** Adjust resource limits:
```bash
# Increase memory limits
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set collector.resources.limits.memory="1Gi" \
  --set collector.resources.requests.memory="512Mi" \
  --set consumer.resources.limits.memory="1Gi" \
  --set consumer.resources.requests.memory="512Mi"

# Enable collection frequency adjustment
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set collector.schedule="*/10 * * * *"  # Every 10 minutes instead of 5
```

### Debug Mode

Enable debug logging for detailed troubleshooting:

```bash
# Via environment variables
export LOG_LEVEL=debug
export LOG_FORMAT=json

# Via Helm deployment
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set config.logLevel="debug" \
  --set config.logFormat="json"

# View debug logs
kubectl logs -f deployment/cluster-info-collector -n cluster-info
kubectl logs -f deployment/cluster-info-consumer -n cluster-info
```

### Performance Tuning

#### Collection Optimization
```bash
# Reduce collection frequency for large clusters
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set collector.schedule="*/15 * * * *"  # Every 15 minutes

# Enable resource type filtering
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set collector.resourceTypes="deployments,pods,nodes,services"

# Adjust database connection pool
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set postgresql.primary.extendedConfiguration.max_connections="200" \
  --set postgresql.primary.extendedConfiguration.shared_buffers="256MB"
```

#### Kafka Optimization
```bash
# Increase Kafka partitions for better parallelism
kubectl exec deployment/kafka -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --alter --topic cluster-info --partitions 6

# Optimize producer settings
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set kafka.producer.batchSize=16384 \
  --set kafka.producer.lingerMs=5 \
  --set kafka.producer.compressionType="snappy"

# Optimize consumer settings
helm upgrade my-cluster-info helm/cluster-info-collector \
  --set kafka.consumer.fetchMinBytes=1024 \
  --set kafka.consumer.fetchMaxWait=500
```

## 🔄 Migration Examples

### Legacy to Kafka Architecture Migration

#### Step 1: Deploy v2.0 with Kafka Disabled
```bash
# Deploy v2.0 in legacy mode first
helm install migration-cluster-info helm/cluster-info-collector \
  --set kafka.enabled=false \
  --set collector.image.tag="v2.0.0" \
  --namespace cluster-info-migration \
  --create-namespace
```

#### Step 2: Verify Data Collection
```bash
# Check that data is being collected normally
kubectl logs deployment/migration-cluster-info -n cluster-info-migration

# Verify database has data
kubectl exec deployment/migration-cluster-info -n cluster-info-migration -- \
  psql -h postgresql -U postgres -d cluster_info \
  -c "SELECT COUNT(*) FROM cluster_snapshots;"
```

#### Step 3: Enable Kafka Components
```bash
# Add Kafka components
helm upgrade migration-cluster-info helm/cluster-info-collector \
  --set kafka.enabled=true \
  --set kafka.internal=true \
  --namespace cluster-info-migration
```

#### Step 4: Switch to Kafka Mode
```bash
# Enable Kafka for collector
helm upgrade migration-cluster-info helm/cluster-info-collector \
  --set collector.kafka.enabled=true \
  --set consumer.enabled=true \
  --namespace cluster-info-migration
```

#### Step 5: Validate Kafka Pipeline
```bash
# Check that messages are being produced
kubectl exec deployment/kafka -n cluster-info-migration -- \
  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic cluster-info --from-beginning --max-messages 5

# Check consumer is processing messages
kubectl logs deployment/migration-cluster-info-consumer -n cluster-info-migration

# Verify both collection methods are working
kubectl exec deployment/migration-cluster-info -n cluster-info-migration -- \
  psql -h postgresql -U postgres -d cluster_info \
  -c "SELECT id, timestamp, kafka_processed FROM cluster_snapshots ORDER BY id DESC LIMIT 5;"
```

### Database Schema Migration

If upgrading from v1.x to v2.0, run database migrations:

```bash
# Backup existing database
kubectl exec deployment/postgresql -n cluster-info -- \
  pg_dump -U postgres cluster_info > backup-$(date +%Y%m%d).sql

# Apply v2.0 schema changes
kubectl exec deployment/migration-cluster-info -n cluster-info-migration -- \
  ./migrate-database.sh

# Or manually apply new tables
kubectl exec deployment/postgresql -n cluster-info-migration -- \
  psql -U postgres -d cluster_info -c "
    ALTER TABLE cluster_snapshots ADD COLUMN IF NOT EXISTS kafka_processed BOOLEAN DEFAULT FALSE;
    
    CREATE TABLE IF NOT EXISTS services (
        id SERIAL PRIMARY KEY,
        snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        namespace VARCHAR(255) NOT NULL,
        type VARCHAR(50) NOT NULL,
        cluster_ip VARCHAR(45),
        external_ips TEXT[],
        data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Add other new tables as needed
    CREATE TABLE IF NOT EXISTS ingresses (...);
    CREATE TABLE IF NOT EXISTS configmaps (...);
    -- etc.
  "
```

### Configuration Migration

#### v1.x Configuration
```yaml
# Old config.yaml
database:
  host: localhost
  port: 5432
  user: postgres
  password: secret
  database: cluster_info

collection:
  interval: 300s
  
api:
  enabled: true
  port: 8080
```

#### v2.0 Configuration
```yaml
# New values.yaml for Helm
postgresql:
  auth:
    database: "cluster_info"
    username: "postgres"
    password: "secret"

collector:
  schedule: "*/5 * * * *"  # Cron syntax instead of interval
  kafka:
    enabled: true           # New Kafka mode

consumer:                   # New consumer component
  enabled: true
  replicaCount: 2

kafka:                      # New Kafka configuration
  enabled: true
  internal: true

api:
  enabled: true
  service:
    port: 8081             # Default port changed

monitoring:                 # New monitoring options
  serviceMonitor:
    enabled: true

retention:                  # New retention policies
  enabled: true
  maxAge: "168h"
  maxSnapshots: 100
```

### Rollback Plan

If migration fails, rollback to v1.x:

```bash
# Scale down v2.0 deployment
kubectl scale deployment migration-cluster-info --replicas=0 -n cluster-info-migration

# Restore v1.x deployment
helm install rollback-cluster-info helm/cluster-info-collector \
  --version 1.0.0 \
  --set kafka.enabled=false \
  --namespace cluster-info \
  --create-namespace

# Restore database from backup if needed
kubectl exec deployment/postgresql -n cluster-info -- \
  psql -U postgres -d cluster_info < backup-$(date +%Y%m%d).sql

# Verify rollback
kubectl logs deployment/rollback-cluster-info -n cluster-info
```

## 📈 Production Deployment Checklist

### Pre-deployment
- [ ] Resource requirements calculated based on cluster size
- [ ] Network policies configured for security
- [ ] Storage classes configured for persistence
- [ ] Monitoring and alerting rules configured
- [ ] Backup strategy implemented
- [ ] RBAC permissions reviewed

### Deployment
- [ ] Use production-ready Helm values
- [ ] Enable resource limits and requests
- [ ] Configure horizontal pod autoscaling
- [ ] Enable data retention policies
- [ ] Configure persistent storage
- [ ] Set up TLS/SSL certificates

### Post-deployment
- [ ] Verify all components are running
- [ ] Test data collection and storage
- [ ] Validate API endpoints
- [ ] Check metrics and monitoring
- [ ] Test alerting rules
- [ ] Perform backup/restore test
- [ ] Document access procedures
- [ ] Set up log rotation

### Maintenance
- [ ] Regular backup verification
- [ ] Monitor resource usage trends
- [ ] Review and update retention policies
- [ ] Security patches and updates
- [ ] Performance optimization
- [ ] Capacity planning reviews

This comprehensive guide covers all aspects of using the Kubernetes Cluster Info Collector v2.0, from basic deployment to advanced production configurations. The examples progress from simple setups to complex enterprise deployments with full monitoring, alerting, and data streaming capabilities.
