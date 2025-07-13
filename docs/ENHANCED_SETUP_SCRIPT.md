# Enhanced test-setup.sh - Interactive Setup & Deployment Tool

## Overview

The `test-setup.sh` script has been enhanced from a validation-only tool to a **comprehensive interactive setup and deployment solution** that can validate your environment AND deploy the Kubernetes Cluster Info Collector based on your selections.

## 🚀 New Capabilities

### **Interactive Menu System**
- **Option 1**: 🐳 Legacy Mode (Direct Database Storage)
- **Option 2**: 🌊 Kafka Mode (v2.0 - Recommended for Production)
- **Option 3**: 📋 Development Setup
- **Option 4**: 🔍 Validation Only (No Deployment)
- **Option 5**: ❌ Exit

### **Automated Deployment**
- Validates environment first
- Executes deployment based on user choice
- Provides status monitoring and verification steps

## 📋 Usage

### Basic Usage
```bash
# Interactive mode
./test-setup.sh

# The script will:
# 1. Validate kubectl, Docker, and cluster connectivity
# 2. Check RBAC permissions for all 9 resource types
# 3. Show current cluster status
# 4. Present deployment options menu
# 5. Execute selected deployment
# 6. Provide verification steps
```

## 🔧 Deployment Options Details

### **Option 1: Legacy Mode (Direct Database Storage)**

**What it does:**
- Sets `KAFKA_ENABLED=false`
- Builds Docker image using Makefile
- Loads image to cluster (kind/minikube detection)
- Deploys PostgreSQL database
- Deploys collector as single pod
- Shows status and verification steps

**Requirements:**
- Makefile (uses `make docker-build`, `make deploy-postgres`, etc.)
- Docker for image building
- Kubernetes cluster with sufficient permissions

**Process:**
```bash
📦 Building Docker image...
🔄 Loading image to cluster...
🗄️  Deploying PostgreSQL...
⏳ Waiting for PostgreSQL to be ready...
🚀 Deploying collector...
📊 Checking deployment status...
✅ Legacy mode deployment completed!
```

### **Option 2: Kafka Mode (Production)**

**What it does:**
- Uses Helm chart for deployment
- Offers 4 sub-configurations:
  1. **Development**: Minimal resources, single replicas
  2. **Production**: Auto-scaling, high availability
  3. **External Dependencies**: Use existing Kafka/PostgreSQL
  4. **Custom**: User-specified values file

**Requirements:**
- Helm 3.0+
- `helm/cluster-info-collector/` chart directory
- Kubernetes cluster with sufficient resources

**Process:**
```bash
✅ Helm is available
📋 Available deployment configurations:
1. Development (minimal resources, single replicas)
2. Production (auto-scaling, high availability)
3. External dependencies (use existing Kafka/PostgreSQL)
4. Custom (specify your own values)

Select configuration (1-4): 
```

#### Configuration Examples:

**Development:**
```bash
helm install my-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace \
  --set collector.schedule="*/5 * * * *" \
  --set consumer.replicaCount=1 \
  --set consumer.autoscaling.enabled=false \
  --set postgresql.auth.password="devpassword"
```

**Production:**
```bash
helm install my-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace \
  --set collector.schedule="0 */1 * * *" \
  --set consumer.replicas=3 \
  --set consumer.autoscaling.enabled=true \
  --set postgresql.auth.password="$(openssl rand -base64 32)" \
  --set ingress.enabled=true
```

**External Dependencies:**
```bash
# Prompts for:
# - Kafka brokers (comma-separated)
# - PostgreSQL host
# - PostgreSQL password

helm install my-cluster-info helm/cluster-info-collector \
  --namespace cluster-info \
  --create-namespace \
  --set kafka.enabled=false \
  --set kafka.external.enabled=true \
  --set kafka.external.brokers="$kafka_brokers" \
  --set postgresql.enabled=false \
  --set database.host="$postgres_host" \
  --set database.password="$postgres_password"
```

### **Option 3: Development Setup**

**What it does:**
- Sets up local development environment
- Builds application locally
- Runs tests and integration tests
- Configures environment variables

**Process:**
```bash
🔧 Development options:
1. Legacy mode (KAFKA_ENABLED=false)
2. Kafka mode (KAFKA_ENABLED=true)

Select mode (1-2): 
📦 Building application...
🧪 Running tests...
🔍 Running integration tests...
✅ Development environment setup completed!
```

### **Option 4: Validation Only**

**What it does:**
- Performs all validation checks
- Shows cluster status
- Provides verification steps
- **Does not deploy anything**

**Use cases:**
- Pre-deployment validation
- Troubleshooting existing deployments
- Checking cluster capabilities

## 🔍 Validation Features

### **RBAC Permission Checking**
Tests all 18 required permissions for 9 resource types:
- get/list pods
- get/list deployments  
- get/list nodes
- get/list services
- get/list ingresses
- get/list configmaps
- get/list secrets
- get/list persistentvolumes
- get/list persistentvolumeclaims

### **Cluster Status Overview**
Shows current resource counts for all 9 v2.0 resource types.

### **Environment Validation**
- kubectl connectivity
- Docker availability
- Helm availability (for Kafka mode)
- Required files (Makefile, Helm chart, manifests)

## 📊 Verification Steps

After deployment, the script provides comprehensive verification steps:

### **For Kubernetes Deployments**
```bash
📊 Check deployment status:
   kubectl get all -n cluster-info

📋 Access services (port-forward):
   kubectl port-forward service/my-cluster-info 8080:8080 -n cluster-info
   kubectl port-forward service/my-cluster-info 8081:8081 -n cluster-info
```

### **For All Deployments**
```bash
🔗 API Health Check:
   curl http://localhost:8081/api/v1/health

📈 Metrics Check:
   curl http://localhost:8080/metrics

🌐 WebSocket Test:
   wscat -c ws://localhost:8082/api/v1/ws

📚 View API Documentation:
   ./view-api-docs.sh

✅ Validate Swagger Documentation:
   ./validate-swagger.sh

🧪 Test API Endpoints:
   ./test-api.sh
```

## 🛠️ Error Handling

### **Missing Dependencies**
- **No kubectl**: Script exits with error
- **No Docker**: Warns but continues (manual image building required)
- **No Helm**: Kafka mode unavailable, suggests installation
- **No Makefile**: Falls back to manual deployment using manifests

### **RBAC Issues**
- Lists missing permissions
- Suggests solutions (cluster-admin, RBAC setup, Helm chart usage)
- Continues with deployment (warnings only)

### **Deployment Failures**
- Each step is validated
- Clear error messages provided
- Fallback options suggested

## 🎯 Best Practices

### **Development Workflow**
```bash
# 1. Validate environment
./test-setup.sh  # Choose option 4

# 2. Setup development
./test-setup.sh  # Choose option 3

# 3. Deploy to cluster  
./test-setup.sh  # Choose option 1 or 2
```

### **Production Deployment**
```bash
# 1. Validate cluster
./test-setup.sh  # Choose option 4

# 2. Deploy with Kafka mode
./test-setup.sh  # Choose option 2, then option 2 (production)
```

### **Troubleshooting**
```bash
# Check current status
./test-setup.sh  # Choose option 4

# View detailed verification
./test-api.sh
./validate-swagger.sh
```

## 🚀 Benefits of Enhanced Script

1. **One-Stop Solution**: Validation + Deployment in single tool
2. **Interactive**: User-friendly menu system
3. **Flexible**: Multiple deployment modes and configurations
4. **Robust**: Comprehensive error handling and fallbacks
5. **Educational**: Shows exact commands and provides verification steps
6. **Production-Ready**: Includes production-grade Helm deployments

## 📋 Migration from Old Script

**Old script** (validation only):
```bash
./test-setup.sh  # Shows info, no deployment
```

**New script** (interactive):
```bash
./test-setup.sh  # Interactive menu with deployment options
# Choose option 4 for old behavior (validation only)
```

The enhanced script is **fully backward compatible** - selecting option 4 provides the same validation-only behavior as the original script.
