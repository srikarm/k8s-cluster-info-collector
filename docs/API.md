# API Documentation v2.0

This directory contains comprehensive API documentation for the Kubernetes Cluster Info Collector v2.0 REST API.

## 🆕 What's New in v2.0

- **9 Resource Types**: Complete coverage of Kubernetes resources
- **Kafka Integration**: Real-time streaming with producer-consumer architecture
- **Enhanced Monitoring**: Prometheus metrics and Kafka statistics
- **WebSocket Streaming**: Real-time cluster data updates
- **Data Retention**: Automated cleanup with configurable policies
- **Health Checks**: Component-specific health monitoring

## 📖 Swagger/OpenAPI Documentation

### Files
- **`swagger.yaml`**: Complete OpenAPI 3.0.3 specification with all v2.0 endpoints, schemas, and examples

### API Overview
The REST API provides access to:
- **Snapshots**: Historical cluster state snapshots with 9 resource types
- **Resources**: Kubernetes resource information (Deployments, Pods, Nodes, Services, Ingresses, ConfigMaps, Secrets, PersistentVolumes, PersistentVolumeClaims)
- **Statistics**: Cluster statistics, Kafka metrics, and retention information
- **Health**: Enhanced health checks with component status
- **Streaming**: Real-time WebSocket data streaming with message types
- **Metrics**: Prometheus-format metrics for monitoring
- **Retention**: Data cleanup and retention management

## 🚀 Viewing the Documentation

### Option 1: Swagger UI (Recommended)

#### Using Docker
```bash
# Serve Swagger UI with the API documentation
docker run -p 8080:8080 \
  -e SWAGGER_JSON=/app/swagger.yaml \
  -v $(pwd)/swagger.yaml:/app/swagger.yaml \
  swaggerapi/swagger-ui

# Open in browser: http://localhost:8080
```

#### Using NPX (Node.js)
```bash
# Install and run swagger-ui-serve
npx swagger-ui-serve swagger.yaml

# Open the provided URL in your browser
```

### Option 2: Swagger Editor
```bash
# Use the online editor
# 1. Go to https://editor.swagger.io/
# 2. Copy and paste the contents of swagger.yaml
# 3. View the interactive documentation
```

### Option 3: VS Code Extension
```bash
# Install the "Swagger Viewer" extension in VS Code
# Open swagger.yaml and use Ctrl+Shift+P -> "Swagger: Preview"
```

## 🔗 API Endpoints Summary

### Base URL
- **Local Development**: `http://localhost:8081/api/v1`
- **Production**: `https://your-domain.com/api/v1`

### Core Endpoints

#### Snapshots
```bash
GET /snapshots                 # List all snapshots
GET /snapshots/{id}            # Get specific snapshot
GET /snapshots/latest          # Get latest snapshot
```

#### Resources
```bash
GET /deployments              # List deployments
GET /pods                     # List pods
GET /nodes                    # List nodes
GET /services                 # List services
GET /ingresses                # List ingresses
GET /configmaps               # List ConfigMaps
GET /secrets                  # List Secrets
GET /persistent-volumes       # List PersistentVolumes
GET /persistent-volume-claims # List PVCs
```

#### Statistics & Health
```bash
GET /stats                    # General statistics
GET /stats/retention          # Retention statistics
GET /health                   # Health check
```

#### Streaming
```bash
GET /ws                       # WebSocket connection
```

## 🔗 Quick API Reference

### Base URL
```
http://localhost:8081/api/v1
```

### Core Endpoints

#### Snapshots & Historical Data
- `GET /snapshots` - List cluster snapshots
- `GET /snapshots/latest` - Get latest snapshot
- `GET /snapshots/{id}` - Get specific snapshot

#### Kubernetes Resources (9 Types)
- `GET /deployments` - List deployments
- `GET /pods` - List pods  
- `GET /nodes` - List nodes
- `GET /services` - List services *(v2.0)*
- `GET /ingresses` - List ingresses *(v2.0)*
- `GET /configmaps` - List configmaps *(v2.0)*
- `GET /secrets` - List secrets *(v2.0)*
- `GET /persistent-volumes` - List persistent volumes *(v2.0)*
- `GET /persistent-volume-claims` - List PVCs *(v2.0)*

#### Monitoring & Statistics
- `GET /metrics` - Prometheus metrics *(v2.0)*
- `GET /stats` - General statistics
- `GET /stats/kafka` - Kafka statistics *(v2.0)*
- `GET /stats/retention` - Retention statistics

#### Management
- `POST /retention/cleanup` - Manual cleanup *(v2.0)*
- `GET /health` - Enhanced health check *(v2.0)*

#### Real-time Streaming
- `WebSocket /ws` - Real-time data streaming *(v2.0)*

### Query Parameters
- `?limit=N` - Limit number of results
- `?namespace=ns` - Filter by namespace
- `?node=name` - Filter by node name

### Response Formats
- **JSON**: All REST endpoints
- **text/plain**: `/metrics` endpoint (Prometheus format)
- **WebSocket JSON**: Real-time streaming messages

## 📋 Query Parameters

### Common Parameters
- **`limit`**: Maximum number of results (1-1000, default: 100)
- **`namespace`**: Filter by namespace (for namespaced resources)

### Examples
```bash
# Get latest 50 snapshots
curl "http://localhost:8081/api/v1/snapshots?limit=50"

# Get pods in kube-system namespace
curl "http://localhost:8081/api/v1/pods?namespace=kube-system"

# Get first 10 deployments
curl "http://localhost:8081/api/v1/deployments?limit=10"
```

## 📊 Response Formats

### Standard List Response
```json
{
  "data": [...],
  "count": 42
}
```

### Snapshot Summary Response
```json
{
  "snapshots": [
    {
      "id": 123,
      "timestamp": "2025-01-15T10:30:00Z",
      "deployments": 15,
      "pods": 45,
      "nodes": 3,
      "services": 20,
      "ingresses": 5,
      "configmaps": 25,
      "secrets": 30,
      "persistent_volumes": 10,
      "persistent_volume_claims": 8
    }
  ],
  "count": 1
}
```

### Error Response
```json
{
  "error": "Resource not found"
}
```

## 🌊 WebSocket Streaming

### Connection
```javascript
const ws = new WebSocket('ws://localhost:8082/api/v1/ws');
```

### Message Types
1. **`cluster_update`**: Complete cluster data update
2. **`metrics_update`**: Metrics data update
3. **`alert`**: Alert notifications

### Example Message
```json
{
  "type": "cluster_update",
  "timestamp": "2025-01-15T12:00:00Z",
  "data": {
    "deployments": [...],
    "pods": [...],
    "nodes": [...]
  }
}
```

## 🧪 Testing the API

### Using cURL
```bash
# Health check
curl http://localhost:8081/api/v1/health

# Get latest cluster snapshot
curl http://localhost:8081/api/v1/snapshots/latest

# Get all deployments with pretty formatting
curl http://localhost:8081/api/v1/deployments | jq .

# Get statistics
curl http://localhost:8081/api/v1/stats | jq .
```

### Using HTTPie
```bash
# Install HTTPie: pip install httpie

# Health check
http GET localhost:8081/api/v1/health

# Get pods in specific namespace
http GET localhost:8081/api/v1/pods namespace==kube-system

# Get retention statistics
http GET localhost:8081/api/v1/stats/retention
```

### Using Postman
1. Import the OpenAPI specification (`swagger.yaml`)
2. Postman will automatically generate a collection with all endpoints
3. Set the base URL to `http://localhost:8081/api/v1`
4. Test the endpoints

## 🔒 Authentication & Security

- **Authentication**: None required (read-only API)
- **CORS**: Enabled for all origins
- **Rate Limiting**: Not implemented
- **HTTPS**: Recommended for production deployments

## 📝 API Versioning

- **Current Version**: v1
- **Base Path**: `/api/v1`
- **Content-Type**: `application/json`
- **Character Encoding**: UTF-8

## 🐛 Error Handling

### HTTP Status Codes
- **200**: Success
- **302**: Redirect (for `/snapshots/latest`)
- **400**: Bad Request (invalid parameters)
- **404**: Not Found (resource doesn't exist)
- **500**: Internal Server Error
- **503**: Service Unavailable (database/streaming issues)

### Error Response Format
All errors return JSON with an `error` field:
```json
{
  "error": "Description of what went wrong"
}
```

## 📈 Performance Considerations

### Recommended Practices
- Use `limit` parameter to control response size
- Use `namespace` filtering when possible
- Cache responses on the client side when appropriate
- Use WebSocket streaming for real-time updates instead of polling

### Default Limits
- **Snapshots**: 50 per request (max: 1000)
- **Resources**: 100 per request (max: 1000)
- **Database timeout**: 30 seconds
- **Request timeout**: 60 seconds

## 🔧 Configuration

The API server configuration is controlled by environment variables:

```bash
API_ENABLED=true              # Enable REST API server
API_ADDRESS=:8081             # API server address
API_PREFIX=/api/v1            # API URL prefix
STREAMING_ENABLED=true        # Enable WebSocket streaming
STREAMING_ADDRESS=:8082       # WebSocket server address
```

## 📚 Additional Resources

- **[Main README](../README.md)**: Complete application documentation
- **[Usage Examples](../USAGE_EXAMPLES.md)**: Comprehensive usage examples
- **[Grafana Setup](../grafana/README.md)**: Dashboard setup and configuration
- **OpenAPI Specification**: Official OpenAPI 3.0.3 documentation

---

**Need help?** Check the troubleshooting section in the main README or open an issue on GitHub.
