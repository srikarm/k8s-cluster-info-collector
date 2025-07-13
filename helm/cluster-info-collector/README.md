# Kubernetes Cluster Info Collector Helm Chart

This Helm chart deploys the Kubernetes Cluster Info Collector application with modern KRaft-based Kafka architecture for collecting and storing cluster information.

## Architecture

The application consists of:
- **Collector**: ```

```bash
helm install prod-cluster-info helm/cluster-info-collector -f values-prod.yaml
```

### Kafka UI Monitoring Setup

```yaml
# values-kafka-ui.yaml
kafkaUI:
  enabled: true
  service:
    type: ClusterIP
    port: 8080
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: kafka-ui.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: kafka-ui-tls
        hosts:
          - kafka-ui.example.com
  resources:
    requests:
      cpu: "100m"
      memory: "256Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"
```

```bash
helm install cluster-info helm/cluster-info-collector -f values-kafka-ui.yaml
```

### External Services Setup cluster information and publishes to Kafka (runs as CronJob or Deployment)
- **Consumer**: Consumes messages from Kafka and stores data in PostgreSQL
- **PostgreSQL**: Database for storing cluster information
- **Kafka**: Message queue using KRaft mode (no Zookeeper required) for decoupling collector and storage operations

## Features

- **KRaft Mode Kafka**: Modern Kafka deployment without Zookeeper dependency
- **Kafka UI**: Optional web-based Kafka monitoring and management interface
- **External Services Support**: Use existing PostgreSQL and Kafka instances
- **Flexible Deployment**: CronJob, Deployment, or both modes for the collector
- **Monitoring**: Built-in Prometheus metrics and alerting support
- **API & Streaming**: Optional REST API and WebSocket streaming endpoints

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (for embedded PostgreSQL persistence)

## Installing the Chart

### Basic Installation

```bash
helm install my-cluster-info helm/cluster-info-collector
```

### Installation with Custom Values

```bash
helm install my-cluster-info helm/cluster-info-collector \
  --set collector.schedule="*/10 * * * *" \
  --set consumer.replicas=3 \
  --set postgresql.auth.password=mysecretpassword
```

### Installation with External Dependencies

If you want to use external Kafka and PostgreSQL:

```bash
helm install my-cluster-info helm/cluster-info-collector \
  --set kafka.enabled=false \
  --set postgresql.enabled=false \
  --set externalKafka.brokers="kafka-broker1:9092,kafka-broker2:9092" \
  --set externalPostgresql.host=my-postgres-host \
  --set externalPostgresql.database=clusterinfo \
  --set externalPostgresql.username=postgres \
  --set externalPostgresql.password=mypassword
```

### Installation with KRaft Mode (Default)

The chart now uses KRaft mode Kafka by default (no Zookeeper required):

```bash
helm install my-cluster-info helm/cluster-info-collector \
  --set kafka.mode=kraft \
  --set kafka.zookeeper.enabled=false
```

## Uninstalling the Chart

```bash
helm uninstall my-cluster-info
```

## Configuration

### Collector Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `collector.enabled` | Enable collector deployment | `true` |
| `collector.mode` | Deployment mode: "cronjob" or "deployment" | `"cronjob"` |
| `collector.schedule` | CronJob schedule (only if mode=cronjob) | `"0 */6 * * *"` |
| `collector.image.repository` | Collector image repository | `"cluster-info-collector"` |
| `collector.image.tag` | Collector image tag | `"latest"` |
| `collector.resources.requests.cpu` | CPU request | `"100m"` |
| `collector.resources.requests.memory` | Memory request | `"128Mi"` |
| `collector.resources.limits.cpu` | CPU limit | `"500m"` |
| `collector.resources.limits.memory` | Memory limit | `"512Mi"` |

### Consumer Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `consumer.enabled` | Enable consumer deployment | `true` |
| `consumer.replicas` | Number of consumer replicas | `2` |
| `consumer.image.repository` | Consumer image repository | `"cluster-info-consumer"` |
| `consumer.image.tag` | Consumer image tag | `"latest"` |
| `consumer.autoscaling.enabled` | Enable HPA for consumer | `true` |
| `consumer.autoscaling.minReplicas` | Minimum replicas | `2` |
| `consumer.autoscaling.maxReplicas` | Maximum replicas | `10` |
| `consumer.autoscaling.targetCPUUtilizationPercentage` | Target CPU for scaling | `70` |

### Kafka Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kafka.enabled` | Deploy Kafka as subchart | `true` |
| `kafka.external.enabled` | Use external Kafka | `false` |
| `kafka.external.brokers` | External Kafka brokers | `""` |
| `kafka.topic` | Kafka topic name | `"cluster-info"` |
| `kafka.partitions` | Number of topic partitions | `3` |
| `kafka.replicationFactor` | Topic replication factor | `1` |

### Kafka UI Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kafkaUI.enabled` | Enable Kafka UI deployment | `false` |
| `kafkaUI.image.repository` | Kafka UI image repository | `"provectuslabs/kafka-ui"` |
| `kafkaUI.image.tag` | Kafka UI image tag | `"latest"` |
| `kafkaUI.service.type` | Kafka UI service type | `"ClusterIP"` |
| `kafkaUI.service.port` | Kafka UI service port | `8080` |
| `kafkaUI.resources.requests.cpu` | CPU request | `"100m"` |
| `kafkaUI.resources.requests.memory` | Memory request | `"128Mi"` |
| `kafkaUI.resources.limits.cpu` | CPU limit | `"500m"` |
| `kafkaUI.resources.limits.memory` | Memory limit | `"512Mi"` |
| `kafkaUI.ingress.enabled` | Enable Kafka UI ingress | `false` |
| `kafkaUI.ingress.hosts` | Kafka UI ingress hosts | `[{host: kafka-ui.local, paths: [{path: /, pathType: Prefix}]}]` |

### PostgreSQL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Deploy PostgreSQL as subchart | `true` |
| `postgresql.auth.username` | PostgreSQL username | `"clusterinfo"` |
| `postgresql.auth.database` | PostgreSQL database name | `"clusterinfo"` |
| `postgresql.auth.password` | PostgreSQL password | `"changeme"` |
| `database.host` | External PostgreSQL host (if postgresql.enabled=false) | `""` |
| `database.port` | External PostgreSQL port | `5432` |
| `database.sslmode` | PostgreSQL SSL mode | `"require"` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `"ClusterIP"` |
| `service.ports.api` | API service port | `8080` |
| `service.ports.metrics` | Metrics service port | `9090` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts configuration | `[]` |
| `ingress.tls` | Ingress TLS configuration | `[]` |

### Monitoring Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `monitoring.enabled` | Enable monitoring | `true` |
| `monitoring.serviceMonitor.enabled` | Create ServiceMonitor for Prometheus | `false` |
| `monitoring.serviceMonitor.labels` | ServiceMonitor labels | `{}` |
| `monitoring.serviceMonitor.interval` | Scrape interval | `"30s"` |

## Examples

### Development Setup

```yaml
# values-dev.yaml
collector:
  schedule: "*/5 * * * *"  # Run every 5 minutes
  
consumer:
  replicas: 1
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
```

```bash
helm install dev-cluster-info helm/cluster-info-collector -f values-dev.yaml
```

### Production Setup

```yaml
# values-prod.yaml
collector:
  schedule: "0 */1 * * *"  # Run every hour
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"

consumer:
  replicas: 5
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
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: cluster-info.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: cluster-info-tls
      hosts:
        - cluster-info.example.com

monitoring:
  serviceMonitor:
    enabled: true
    labels:
      prometheus: "monitoring"
```

```bash
helm install prod-cluster-info helm/cluster-info-collector -f values-prod.yaml
```

### External Dependencies Setup

```yaml
# values-external.yaml
kafka:
  enabled: false
  external:
    enabled: true
    brokers: "kafka-1.example.com:9092,kafka-2.example.com:9092,kafka-3.example.com:9092"

postgresql:
  enabled: false

database:
  host: "postgres.example.com"
  port: 5432
  username: "clusterinfo"
  password: "external-db-password"
  database: "clusterinfo"
  sslmode: "require"
```

```bash
helm install external-cluster-info helm/cluster-info-collector -f values-external.yaml
```

## Monitoring and Observability

### Prometheus Metrics

The application exposes metrics on `/metrics` endpoint:

- `cluster_info_collection_duration_seconds` - Time taken to collect cluster information
- `cluster_info_messages_produced_total` - Total number of messages sent to Kafka
- `cluster_info_messages_consumed_total` - Total number of messages consumed from Kafka
- `cluster_info_database_operations_total` - Total number of database operations

### Grafana Dashboards

Pre-built Grafana dashboards are available in the `grafana/` directory:

1. `cluster-overview-dashboard.json` - Overall cluster health and metrics
2. `alerts-dashboard.json` - Alert definitions and status

### Log Aggregation

Application logs are structured JSON and can be collected using Fluentd, Fluent Bit, or similar:

```json
{
  "level": "info",
  "timestamp": "2024-01-01T12:00:00Z",
  "component": "collector",
  "message": "Successfully collected cluster information",
  "duration_ms": 1234,
  "nodes_count": 10,
  "pods_count": 150
}
```

## Troubleshooting

### Common Issues

1. **Collector not running**: Check if CronJob is scheduled correctly
   ```bash
   kubectl get cronjobs
   kubectl describe cronjob cluster-info-collector
   ```

2. **Consumer not processing messages**: Check Kafka connectivity
   ```bash
   kubectl logs deployment/cluster-info-consumer
   kubectl exec -it deployment/cluster-info-consumer -- kafkacat -b kafka:9092 -L
   ```

3. **Database connection issues**: Verify PostgreSQL credentials
   ```bash
   kubectl logs deployment/cluster-info-consumer | grep -i "database\|postgres"
   ```

4. **High memory usage**: Adjust resource limits or check for memory leaks
   ```bash
   kubectl top pods
   kubectl describe pod <pod-name>
   ```

### Debugging Commands

```bash
# Check all resources
kubectl get all -l app.kubernetes.io/instance=my-cluster-info

# View collector logs
kubectl logs cronjob/cluster-info-collector

# View consumer logs
kubectl logs deployment/cluster-info-consumer -f

# Check Kafka topics
kubectl exec -it deployment/kafka -- kafka-topics.sh --list --bootstrap-server localhost:9092

# Connect to PostgreSQL
kubectl exec -it deployment/postgresql -- psql -U clusterinfo -d clusterinfo

# Port forward for local access
kubectl port-forward service/cluster-info-collector 8080:8080
```

## Upgrading

### Minor Version Upgrades

```bash
helm upgrade my-cluster-info helm/cluster-info-collector
```

### Major Version Upgrades

Check the changelog for breaking changes before upgrading:

```bash
helm upgrade my-cluster-info helm/cluster-info-collector --version 2.0.0
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `helm lint` and `helm template`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
