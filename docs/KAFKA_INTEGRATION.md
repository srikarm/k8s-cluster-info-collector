# Kafka Integration Guide

## Overview

The Kubernetes Cluster Info Collector has been refactored to use Apache Kafka as a message queue between data collection and storage. This decouples the collector from the database and provides better scalability and reliability.

## Architecture

```
┌─────────────────┐    ┌─────────────┐    ┌──────────────┐    ┌────────────┐
│   Kubernetes    │    │  Collector  │    │    Kafka     │    │  Consumer  │    ┌──────────────┐
│    Cluster      │───▶│  (Producer) │───▶│   Message    │───▶│ (Database  │───▶│ PostgreSQL   │
│                 │    │             │    │    Queue     │    │  Writer)   │    │   Database   │
└─────────────────┘    └─────────────┘    └──────────────┘    └────────────┘    └──────────────┘
```

### Components

1. **Collector (Producer)**: Collects data from Kubernetes cluster and sends it to Kafka
2. **Kafka**: Message queue for reliable data transmission
3. **Consumer**: Reads data from Kafka and stores it in PostgreSQL
4. **PostgreSQL**: Data storage

## Configuration

### Environment Variables

#### Kafka Configuration
- `KAFKA_ENABLED`: Enable/disable Kafka integration (default: false)
- `KAFKA_BROKERS`: Comma-separated list of Kafka brokers (default: localhost:9092)
- `KAFKA_TOPIC`: Kafka topic name (default: cluster-info)
- `KAFKA_PARTITION`: Kafka partition (default: 0)

#### Database Configuration (Consumer only)
- `DB_HOST`: Database host (default: localhost)
- `DB_PORT`: Database port (default: 5432)
- `DB_USER`: Database username (default: postgres)
- `DB_PASSWORD`: Database password
- `DB_NAME`: Database name (default: postgres)
- `DB_SSL_MODE`: SSL mode (default: disable)

## Deployment

### Using Docker Compose

1. **Start the infrastructure**:
   ```bash
   docker-compose up -d
   ```

   This will start:
   - PostgreSQL database
   - Kafka with Zookeeper
   - Collector service (producer)
   - Consumer service

2. **View logs**:
   ```bash
   # Collector logs
   docker-compose logs -f collector
   
   # Consumer logs
   docker-compose logs -f consumer
   
   # Kafka logs
   docker-compose logs -f kafka
   ```

### Kubernetes Deployment

#### Collector Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-info-collector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-info-collector
  template:
    metadata:
      labels:
        app: cluster-info-collector
    spec:
      containers:
      - name: collector
        image: cluster-info-collector:latest
        env:
        - name: KAFKA_ENABLED
          value: "true"
        - name: KAFKA_BROKERS
          value: "kafka-service:9092"
        - name: KAFKA_TOPIC
          value: "cluster-info"
```

#### Consumer Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-info-consumer
spec:
  replicas: 2  # Can scale horizontally
  selector:
    matchLabels:
      app: cluster-info-consumer
  template:
    metadata:
      labels:
        app: cluster-info-consumer
    spec:
      containers:
      - name: consumer
        image: cluster-info-consumer:latest
        env:
        - name: KAFKA_ENABLED
          value: "true"
        - name: KAFKA_BROKERS
          value: "kafka-service:9092"
        - name: KAFKA_TOPIC
          value: "cluster-info"
        - name: DB_HOST
          value: "postgres-service"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
```

## Benefits

### Scalability
- **Multiple Consumers**: Can run multiple consumer instances for parallel processing
- **High Throughput**: Kafka handles high message throughput efficiently
- **Load Balancing**: Kafka consumer groups provide automatic load balancing

### Reliability
- **Message Persistence**: Kafka stores messages durably
- **Fault Tolerance**: If consumers fail, messages remain in Kafka
- **Retry Logic**: Built-in retry mechanisms for failed message processing

### Monitoring
- **Kafka Metrics**: Monitor message lag, throughput, and consumer health
- **Consumer Groups**: Track consumer group status and partition assignments

## Monitoring

### Kafka Consumer Lag
Monitor consumer lag to ensure consumers are keeping up with message production:

```bash
# Check consumer group status
kafka-consumer-groups --bootstrap-server localhost:9092 --group cluster-info-consumer --describe
```

### Application Logs
Both collector and consumer services provide structured logging:

```json
{
  "level": "info",
  "msg": "Cluster info sent to Kafka",
  "topic": "cluster-info",
  "partition": 0,
  "offset": 12345,
  "timestamp": "2025-01-10T10:30:00Z",
  "size": 1024000
}
```

## Troubleshooting

### Common Issues

1. **Kafka Connection Errors**
   - Verify Kafka brokers are accessible
   - Check network connectivity
   - Ensure correct broker addresses

2. **Consumer Lag**
   - Scale up consumer instances
   - Check database connection performance
   - Monitor resource usage

3. **Message Processing Errors**
   - Check consumer logs for specific errors
   - Verify database schema compatibility
   - Monitor PostgreSQL performance

### Development Mode

For local development without Kafka:
```bash
# Set KAFKA_ENABLED=false to use direct database storage (legacy mode)
export KAFKA_ENABLED=false
```

Note: Legacy mode is deprecated and may be removed in future versions.

## Migration from Direct Storage

To migrate from the old direct storage approach:

1. Deploy Kafka infrastructure
2. Update collector configuration to enable Kafka
3. Deploy consumer services
4. Verify data flow through Kafka
5. Remove direct database dependencies from collector

## Performance Tuning

### Kafka Configuration
- Adjust batch size for better throughput
- Configure appropriate retention policies
- Tune consumer fetch settings

### Consumer Configuration
- Adjust database connection pool size
- Configure consumer group session timeouts
- Optimize batch processing sizes

For more details, see the main README.md file.
