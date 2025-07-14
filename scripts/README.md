# Scripts Directory

This directory contains utility scripts for the Kubernetes Cluster Info Collector project. All scripts are designed to be run from the project root directory.

## 📋 Script Overview

### 🚀 **Deployment & Setup**

#### `setup-hybrid.sh`
**Main development setup script with interactive menu and process management**
- **Purpose**: Complete setup for hybrid development mode (local binary + K8s services)
- **Features**: 6 enhanced development modes, auto port-forwarding, database verification, process management
- **Usage**: 
  ```bash
  ./scripts/setup-hybrid.sh [COMMAND]
  
  Commands:
    setup                 Run interactive setup (default)
    stop                  Stop all running collector and consumer processes
    stop-collector        Stop only collector processes  
    stop-consumer         Stop only consumer processes
    status                Show status of running processes
    help                  Show help message
  ```
- **Dependencies**: kubectl, docker
- **Key Features**:
  - Interactive mode selection
  - Automatic PostgreSQL deployment and health checks  
  - Port forwarding management
  - Database creation and verification
  - **NEW**: Process management for local development
  - **NEW**: Clean shutdown of collector/consumer processes
  - **NEW**: Status monitoring of running processes
  - Enhanced educational content for development workflows

#### `deploy.sh`
**Interactive deployment script with multiple options**
- **Purpose**: Deploy the collector with various configuration options
- **Features**: Multiple deployment modes, resource configuration
- **Usage**: `./scripts/deploy.sh`
- **Dependencies**: kubectl, helm (optional)

### 🧪 **Testing & Validation**

#### `test-api.sh`
**Comprehensive API endpoint testing**
- **Purpose**: Test all v2.0 API endpoints when the collector is running
- **Features**: Tests 9 resource types, health checks, Kafka stats, WebSocket connectivity
- **Usage**: `./scripts/test-api.sh`
- **Dependencies**: curl, nc (optional), python3 (optional for JSON parsing)
- **Environment Variables**:
  - `API_BASE_URL` (default: http://localhost:8081/api/v1)
  - `METRICS_URL` (default: http://localhost:8080/metrics)
  - `WS_URL` (default: ws://localhost:8082/api/v1/ws)

#### `test-hybrid-setup.sh`
**Standalone testing script for hybrid development verification**
- **Purpose**: Verify that hybrid development environment is working correctly
- **Features**: Port connectivity tests, service health checks, API validation
- **Usage**: `./scripts/test-hybrid-setup.sh`
- **Dependencies**: kubectl, curl

#### `quick-validate.sh`
**Quick validation of core functionality**
- **Purpose**: Fast validation of Swagger documentation and basic setup
- **Features**: Swagger v2.0 validation, endpoint count, feature detection
- **Usage**: `./scripts/quick-validate.sh`
- **Dependencies**: None (basic shell commands)

### 📚 **Documentation & API**

#### `view-api-docs.sh`
**Interactive API documentation viewer with 6 viewing options**
- **Purpose**: View Swagger/OpenAPI documentation in multiple formats
- **Features**: 6 viewing methods (Docker, NPX, static HTML, VS Code, online editor, terminal summary)
- **Usage**: `./scripts/view-api-docs.sh`
- **Dependencies**: Variable based on selected option (docker, node.js, python3, etc.)
- **Options**:
  1. Docker + Swagger UI (Recommended)
  2. NPX + HTTP Server (Node.js)
  3. Online Swagger Editor (Copy/Paste)
  4. VS Code Preview (Extension Required)
  5. Quick API Summary (Terminal View)
  6. Generate Static HTML (No Dependencies)

#### `validate-swagger.sh`
**Swagger/OpenAPI validation with multiple fallback methods**
- **Purpose**: Validate API documentation for syntax and completeness
- **Features**: Multiple validation tools, comprehensive error reporting
- **Usage**: `./scripts/validate-swagger.sh`
- **Dependencies**: Various (swagger-codegen, @apidevtools/swagger-parser, python3, etc.)

### 🔧 **Utilities**

#### `port-forward.sh`
**Standalone port forwarding management utility**
- **Purpose**: Manage Kubernetes port forwarding for development
- **Features**: Service discovery, services-only mode, start/stop/status commands
- **Usage**: `./scripts/port-forward.sh [start|stop|status] [namespace] [service-name]`
- **Dependencies**: kubectl

#### `cleanup-namespace.sh`
**Comprehensive namespace cleanup with finalizer removal**
- **Purpose**: Safely remove Kubernetes namespaces and handle stuck finalizers
- **Features**: Force pod deletion, finalizer removal, port-forward cleanup, dry-run mode
- **Usage**: `./scripts/cleanup-namespace.sh [namespace] [--force|--dry-run]`
- **Dependencies**: kubectl
- **Key Features**:
  - Removes finalizers from resources and namespaces
  - Force deletes stuck pods
  - Cleans up port-forward processes
  - Comprehensive resource scanning
  - Safe deletion with confirmation prompts

#### `namespace-functions.sh`
**Shared utility functions for namespace management**
- **Purpose**: Common functions sourced by other scripts
- **Features**: Namespace creation, service deployment, health checks
- **Usage**: Sourced by other scripts (`source ./scripts/namespace-functions.sh`)
- **Dependencies**: kubectl

## 🎯 **Common Usage Workflows**

### Development Setup
```bash
# Complete hybrid development setup
./scripts/setup-hybrid.sh

# Quick validation
./scripts/quick-validate.sh

# Test the setup
./scripts/test-hybrid-setup.sh
```

### API Development & Testing
```bash
# View API documentation
./scripts/view-api-docs.sh

# Validate API documentation
./scripts/validate-swagger.sh

# Test all API endpoints
./scripts/test-api.sh
```

### Deployment
```bash
# Interactive deployment
./scripts/deploy.sh

# Port forwarding for local access
./scripts/port-forward.sh start cluster-info-dev postgres
```

### Cleanup
```bash
# Clean up development namespace
./scripts/cleanup-namespace.sh cluster-info-dev

# Dry run to see what would be deleted
./scripts/cleanup-namespace.sh cluster-info-dev --dry-run

# Force cleanup without confirmation
./scripts/cleanup-namespace.sh cluster-info-dev --force
```

## 📝 **Script Dependencies**

### Required Tools
- **kubectl**: Required by most scripts for Kubernetes operations
- **docker**: Required for container-based operations
- **curl**: Required for API testing

### Optional Tools (Enhanced Features)
- **helm**: For Helm-based deployments
- **jq**: For better JSON formatting in outputs
- **python3**: For enhanced JSON parsing and validation
- **node.js/npm**: For certain documentation viewing options
- **nc (netcat)**: For network connectivity testing

## 🔧 **Environment Variables**

### API Testing
- `API_BASE_URL`: Base URL for API testing (default: http://localhost:8081/api/v1)
- `METRICS_URL`: Prometheus metrics URL (default: http://localhost:8080/metrics)
- `WS_URL`: WebSocket URL (default: ws://localhost:8082/api/v1/ws)

### General
- `NAMESPACE`: Override default Kubernetes namespace
- `LOG_LEVEL`: Set logging verbosity (debug, info, warn, error)

## 🚨 **Troubleshooting**

### Common Issues

#### "kubectl not found"
Ensure kubectl is installed and configured:
```bash
kubectl version --client
kubectl config current-context
```

#### "Permission denied"
Make scripts executable:
```bash
chmod +x scripts/*.sh
```

#### "Cannot connect to API"
Check if services are running and ports are forwarded:
```bash
./scripts/port-forward.sh status
./scripts/test-hybrid-setup.sh
```

#### "lookup kafka: no such host" in Hybrid Mode
When running hybrid development mode, you might encounter hostname resolution errors. This happens because the local binary tries to connect to `kafka` hostname but it's not resolvable.

**Quick Fix (Recommended):**
```bash
# Add kafka hostname to your hosts file
sudo bash -c 'echo "127.0.0.1 kafka" >> /etc/hosts'
```

**Why this works:**
- Port forwarding maps `localhost:9092` → `kafka:9092` in the cluster
- Adding `127.0.0.1 kafka` allows direct hostname resolution to localhost
- Simpler than managing environment variables for background processes

**Verify the fix:**
```bash
# Test hostname resolution
ping kafka
# Should resolve to 127.0.0.1

# Test Kafka connectivity
telnet kafka 9092
# Should connect successfully
```

### Script Execution Order
1. **Setup**: `setup-hybrid.sh` (sets up environment)
2. **Validate**: `quick-validate.sh` (basic validation)
3. **Test**: `test-hybrid-setup.sh` (verify setup)
4. **API Testing**: `test-api.sh` (test endpoints)

## 📋 **Maintenance**

### Adding New Scripts
1. Place in `scripts/` directory
2. Make executable: `chmod +x scripts/newscript.sh`
3. Add to this README
4. Update main project README if user-facing
5. Add to Makefile .PHONY if applicable

### Script Standards
- **Shebang**: Use `#!/bin/bash`
- **Error handling**: Use `set -e` for strict error handling
- **Documentation**: Include header comment explaining purpose
- **Dependencies**: Check for required tools at script start
- **Output**: Use consistent emoji and formatting for user feedback

## 🔗 **Integration**

These scripts integrate with:
- **Makefile**: Many scripts can be called via `make` targets
- **Documentation**: Referenced in main README.md and docs/
- **CI/CD**: Can be used in automated pipelines
- **Development Workflow**: Support local development and testing

---

**Total Scripts**: 10  
**Last Updated**: July 12, 2025  
**Maintainer**: Project Team

For questions or issues with these scripts, please refer to the main project documentation or create an issue in the project repository.
