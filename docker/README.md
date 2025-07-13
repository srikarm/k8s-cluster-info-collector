# Docker Compose Configurations

This directory contains Docker Compose configurations optimized for local development with minimal resource usage.

## Files

- `docker-compose.yml` - Production-like setup with all services
- `docker-compose.dev.yml` - Lightweight development environment

## Kafka Image Optimization

### Before
- **Images**: `confluentinc/cp-kafka:7.4.0`, `confluentinc/cp-zookeeper:7.4.0`
- **Size**: ~1.5GB total (Confluent Platform includes enterprise features)
- **Memory**: No limits, typically uses 1GB+ each

### After  
- **Images**: `apache/kafka:2.8.2-scala_2.13`, `apache/zookeeper:3.8.3`
- **Size**: ~400MB total (Apache official images, minimal footprint)
- **Memory**: Limited to 512MB Kafka + 256MB Zookeeper
- **CPU**: Limited to 0.5 cores Kafka + 0.2 cores Zookeeper

## Development Optimizations

### Kafka Settings
- `KAFKA_LOG_RETENTION_HOURS: 1` - Fast log cleanup for dev
- `KAFKA_HEAP_OPTS: "-Xmx256M -Xms128M"` - Minimal memory usage
- `KAFKA_LOG_RETENTION_BYTES: 1073741824` - 1GB max log size
- Single partition/replica setup for minimal overhead

### Zookeeper Settings
- `ZOO_SNAP_RETAIN_COUNT: 3` - Keep only 3 snapshots
- `ZOO_PURGE_INTERVAL: 1` - Cleanup every hour
- `ZOO_MAX_CLIENT_CNXNS: 60` - Reasonable connection limit

## Resource Usage Comparison

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| **Image Size** | ~1.5GB | ~400MB | ~73% |
| **Memory Usage** | ~2GB+ | ~768MB | ~62% |
| **CPU Usage** | Unlimited | 0.7 cores | Limited |
| **Startup Time** | ~60s | ~30s | ~50% |

## Usage

### Development Environment
```bash
# Start lightweight development stack
docker-compose -f docker-compose.dev.yml up -d

# Logs
docker-compose -f docker-compose.dev.yml logs -f kafka zookeeper
```

### Production-like Environment
```bash
# Start full stack with monitoring
docker-compose up -d

# Scale if needed
docker-compose up -d --scale collector=2
```

## Health Checks

Both configurations include health checks:
- **Kafka**: Topic listing via bootstrap server
- **Zookeeper**: Status check via netcat

## Networking

Services communicate via Docker networks:
- `cluster-info-net` (docker-compose.yml)
- Default bridge network (docker-compose.dev.yml)

## Persistence

PostgreSQL data is persisted via Docker volumes to survive container restarts.
