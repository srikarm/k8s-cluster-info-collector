# Local Development & Deployment Guide

This guide covers enhanced local development and deployment options for the K8s Cluster Info Collector v2.0, with automatic port forwarding and improved local access.

## Quick Start

### 1. Enhanced Setup Script

The `test-setup.sh` script now provides comprehensive deployment options with automatic port forwarding:

```bash
./test-setup.sh
```

Select option **3. Development Setup** for enhanced local development with:
- Local binary execution or Kubernetes deployment
- Automatic port forwarding for local access
- Environment variable configuration
- Docker Compose integration

### 2. Development Mode Options

When selecting development setup, you have 6 options:

1. **Local Legacy Mode** (KAFKA_ENABLED=false) - Binary + Local services
2. **Local Kafka Mode** (KAFKA_ENABLED=true) - Binary + Local services  
3. **Hybrid Legacy Mode** (KAFKA_ENABLED=false) - Binary + K8s services
4. **Hybrid Kafka Mode** (KAFKA_ENABLED=true) - Binary + K8s services
5. **Kubernetes Legacy Mode** - K8s deployment with auto port-forward
6. **Kubernetes Kafka Mode** - K8s deployment with auto port-forward

## Local Binary Development

### Prerequisites

For local binary execution, you'll need supporting services:

```bash
# Start services with Docker Compose
docker-compose -f docker-compose.dev.yml up -d

# For Kafka mode (all services)
docker-compose -f docker-compose.dev.yml up -d

# For Legacy mode (PostgreSQL only)
docker-compose -f docker-compose.dev.yml up -d postgres
```

### Environment Configuration

The setup script creates `.env.local` with appropriate settings:

```bash
# Source the environment
source .env.local

# Run the collector
./bin/collector
```

### Local Service Endpoints

- **Metrics**: http://localhost:8080/metrics
- **Health**: http://localhost:8080/health  
- **API**: http://localhost:8081/api/v1/health
- **WebSocket**: ws://localhost:8082/api/v1/ws
- **PostgreSQL**: localhost:5432 (user: clusterinfo, pass: devpassword)
- **Kafka**: localhost:9092 (Kafka mode only)

## Hybrid Development (Local Binary + K8s Services)

### Overview

Hybrid development mode combines the best of both worlds:
- **Local Binary**: Fast iteration without Docker rebuilds
- **K8s Services**: Production-like PostgreSQL and Kafka services

This mode is ideal for development as it provides:
- Fast compile-test cycles
- Easy debugging with local tools
- Real service dependencies
- Service isolation from other developers

### Setup Process

The setup automatically:
1. **Deploys Services**: PostgreSQL (and Kafka if enabled) to Kubernetes
2. **Port Forwarding**: Maps K8s services to localhost ports
3. **Environment Config**: Creates `.env.hybrid` with correct connection strings
4. **Binary Build**: Compiles local collector binary
5. **🆕 Data Collection**: Runs collector for 30 seconds to populate database
6. **🆕 API Testing**: Verifies all endpoints are working
7. **🆕 Database Verification**: Shows collected cluster data statistics

### Enhanced Features (v2.0)

The hybrid setup now provides a complete, ready-to-use development environment:

#### **Automatic Data Population**
- Collector runs automatically during setup to collect initial cluster data
- Database is populated with real pods, nodes, deployments, etc.
- No more empty database - you get actual data to work with immediately

#### **Complete API Testing**
- All endpoints tested during setup: health, metrics, cluster status
- Verifies the full data pipeline is working
- Shows sample API responses for immediate feedback

#### **Comprehensive Test Suite**
```bash
# Test your complete setup anytime   ./scripts/test-hybrid-setup.sh
```

#### **Correct Environment Variables**
Uses the actual environment variable names expected by the application:
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `METRICS_ENABLED`, `API_ENABLED`, `STREAMING_ENABLED`
- `LOG_LEVEL`, `LOG_FORMAT`, `RETENTION_ENABLED`

### Service Deployment Options

#### **Legacy Mode (PostgreSQL only)**
```bash
./test-setup.sh
# Select 3. Development Setup
# Select 3. Hybrid Legacy Mode
```

#### **Kafka Mode (PostgreSQL + Kafka)**
```bash
./test-setup.sh
# Select 3. Development Setup  
# Select 4. Hybrid Kafka Mode
```

### Service Management

#### **Automatic Service Deployment**
- Uses Helm charts when available
- Falls back to minimal YAML deployments
- **Automatically creates namespaces** with proper labels and annotations
- Creates services in `cluster-info-dev` namespace with development labels
- Automatically sets up port forwarding
- Includes health checks and service validation

#### **Port Forwarding**
- **PostgreSQL**: localhost:5432
- **Kafka**: localhost:9092 (Kafka mode)
- **Zookeeper**: localhost:2181 (Kafka mode)

#### **Manual Port Forward Management**
```bash
# Start services port forwarding
./port-forward.sh services start

# Stop services port forwarding  
./port-forward.sh services stop

# Check services status
./port-forward.sh services status

# Custom namespace/service
./port-forward.sh services start cluster-info-dev postgres
```

### Local Binary Development

#### **Environment Configuration**
The setup creates `.env.hybrid` with all necessary environment variables:

```bash
# Source the environment
source .env.hybrid

# Run the collector
./bin/collector
```

#### **Development Workflow**
1. **Code Changes**: Edit Go source code
2. **Quick Build**: `go build -o bin/collector main.go`
3. **Test**: `./bin/collector`
4. **Debug**: Use any Go debugging tools locally

#### **Local Endpoints**
- **Metrics**: http://localhost:8080/metrics
- **API**: http://localhost:8081/api/v1/health  
- **WebSocket**: ws://localhost:8082/api/v1/ws

### Benefits

#### **Development Speed**
- No Docker image rebuilds required
- Instant code changes reflection
- Native Go debugging support
- Fast compile times

#### **Production Similarity**
- Real PostgreSQL database
- Real Kafka message queues  
- Service networking similar to production
- Database persistence across restarts

#### **Developer Isolation**
- Each developer gets own namespace
- Services don't conflict between developers
- Easy cleanup with namespace deletion
- Independent scaling and configuration

### Troubleshooting

#### **Service Connection Issues**
```bash
# Check if services are running
kubectl get all -n cluster-info-dev

# Check port forwarding
./port-forward.sh services status

# Test database connection
psql -h localhost -p 5432 -U clusterinfo -d clusterinfo
```

#### **Binary Connection Issues**
```bash
# Verify environment
source .env.hybrid && env | grep -E "(DATABASE|KAFKA)"

# Test with verbose logging
LOG_LEVEL=debug ./bin/collector
```

#### **Service Logs**
```bash
# PostgreSQL logs
kubectl logs -l app=postgres -n cluster-info-dev

# Kafka logs (if enabled)
kubectl logs -l app=kafka -n cluster-info-dev
```

### Cleanup

#### **Stop Everything**
```bash
# Stop local binary (Ctrl+C)
# Stop port forwarding
./port-forward.sh services stop

# Delete services (optional)
kubectl delete namespace cluster-info-dev
```

## Namespace Management

### Automatic Namespace Creation

The enhanced setup script automatically manages namespaces with proper labeling:

#### **Development Namespaces**
- **Name**: `cluster-info-dev` (hybrid and K8s development modes)
- **Labels**: 
  - `app.kubernetes.io/component=development`
  - `app.kubernetes.io/part-of=k8s-cluster-info-collector`
- **Description**: Automatically applied via annotations

#### **Production Namespaces**
- **Name**: `cluster-info` (production deployments)
- **Labels**: Applied based on Helm chart values
- **RBAC**: Includes proper ClusterRole and ClusterRoleBinding

#### **Namespace Information**
```bash
# View namespace details
kubectl describe namespace cluster-info-dev

# Check resources in namespace
kubectl get all -n cluster-info-dev

# View namespace labels
kubectl get namespace cluster-info-dev --show-labels
```

#### **Namespace Cleanup**
```bash
# Remove development environment
kubectl delete namespace cluster-info-dev

# Remove production environment
kubectl delete namespace cluster-info
```

### Benefits of Managed Namespaces

- **Isolation**: Each environment is completely isolated
- **Labeling**: Consistent labeling for resource organization
- **RBAC**: Proper permissions per namespace
- **Easy Cleanup**: Single command removes entire environment
- **Resource Quotas**: Can be applied per namespace for resource management

This hybrid approach provides the perfect balance between development speed and production similarity, making it ideal for feature development and testing.

## Kubernetes Development with Auto Port-Forward

### Features

- Automatic namespace creation (`cluster-info-dev`)
- Intelligent service detection
- Automatic port forwarding setup
- Real-time connectivity testing
- Background process management

### Deployment Process

1. **Deploy to Kubernetes**: Script handles image building, loading, and deployment
2. **Auto Port-Forward**: Automatically sets up port forwarding on ports 8080, 8081, 8082
3. **Connectivity Test**: Validates all endpoints are accessible
4. **Process Management**: Tracks port-forward PIDs for easy cleanup

### Access Your Services

Once deployed, all services are immediately accessible via:

```bash
# Health check
curl http://localhost:8081/api/v1/health

# Metrics
curl http://localhost:8080/metrics

# WebSocket (requires wscat: npm install -g wscat)
wscat -c ws://localhost:8082/api/v1/ws
```

## Port Forward Management

### Dedicated Port Forward Utility

Use the standalone `port-forward.sh` script for advanced port forward management:

```bash
# Start port forwarding
./port-forward.sh start

# Start for specific namespace/service
./port-forward.sh start cluster-info-dev dev-cluster-info

# Check status
./port-forward.sh status

# Stop port forwarding
./port-forward.sh stop

# Restart port forwarding
./port-forward.sh restart

# Test connectivity only
./port-forward.sh test
```

### Automatic Features

- **Conflict Resolution**: Automatically kills existing port forwards on target ports
- **Service Discovery**: Detects available services in the namespace
- **Health Checking**: Tests connectivity to all endpoints
- **Process Tracking**: Saves PIDs for reliable cleanup
- **Log Management**: Manages port-forward logs in `/tmp/`

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Kill existing port forwards
   ./port-forward.sh stop
   # Or manually
   pkill -f 'kubectl.*port-forward'
   ```

2. **Service Not Found**
   ```bash
   # Check available services
   kubectl get services -n cluster-info-dev
   # Use correct service name
   ./port-forward.sh start cluster-info-dev <actual-service-name>
   ```

3. **Pods Not Ready**
   ```bash
   # Check pod status
   kubectl get pods -n cluster-info-dev
   # View logs
   kubectl logs -l app=k8s-cluster-info-collector -n cluster-info-dev
   ```

### Debugging Commands

```bash
# Check all deployments
kubectl get all -n cluster-info-dev

# View collector logs
kubectl logs -f deployment/dev-cluster-info -n cluster-info-dev

# Check port forward processes
ps aux | grep port-forward

# Test specific endpoints
curl -v http://localhost:8081/api/v1/health
curl -v http://localhost:8080/metrics
```

## Production Considerations

### Environment Variables

The setup respects these environment variables:
- `KAFKA_ENABLED`: Controls deployment mode (true/false)
- Service endpoints automatically configured based on mode

### Namespace Management

- **Development**: Uses `cluster-info-dev` namespace
- **Production**: Uses configurable namespace via Helm
- **Cleanup**: `kubectl delete namespace cluster-info-dev`

### Service Discovery

The setup automatically detects:
- Cluster type (kind, minikube, others)
- Available services in target namespace
- Service port configurations
- Health check endpoints

## Integration with Other Tools

### API Documentation

```bash
# View interactive API docs
./view-api-docs.sh

# Validate Swagger spec
./validate-swagger.sh
```

### Monitoring

```bash
# Prometheus metrics
curl http://localhost:8080/metrics

# Application health
curl http://localhost:8081/api/v1/health

# Cluster status
curl http://localhost:8081/api/v1/cluster/status
```

### Development Workflow

1. **Code Changes**: Edit source code
2. **Local Test**: Run with local binary mode
3. **Integration Test**: Deploy to Kubernetes development mode
4. **Verify**: Use automatic port forwarding to test all endpoints
5. **Production Deploy**: Use production Helm deployment

This enhanced setup eliminates the need for manual port forwarding and provides a seamless local development experience with automatic service discovery and connectivity testing.
