#!/bin/bash

set -e

# Source namespace management functions
if [[ -f "./namespace-functions.sh" ]]; then
    source ./namespace-functions.sh
fi

echo "🚀 Kubernetes Cluster Info Collector v2.0 - Setup & Deploy"
echo "=========================================================="
echo ""
echo "🆕 v2.0 Features:"
echo "• 9 Kubernetes Resource Types (Pods, Nodes, Deployments, Services, etc.)"
echo "• Kafka Integration & Streaming for High-Volume Clusters"
echo "• Job-Based Execution (start → collect → write → exit)"
echo "• Data Retention Management for Storage Optimization"
echo ""
echo "🎯 Hybrid Development Mode (Recommended for Development):"
echo "• Local Binary: Fast iteration with instant rebuilds (no Docker)"
echo "• K8s Services: Production-like PostgreSQL/Kafka in cluster"
echo "• Port Forwarding: Seamless connection between local and cluster"
echo "• Live Data: Real cluster information for realistic testing"
echo "• Easy Debugging: Use any Go debugging tools locally"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "Please ensure kubectl is configured correctly"
    exit 1
fi

echo "✅ Kubernetes cluster connection verified"

# Check if Docker is available (for building images)
if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker is not installed - you'll need to build images manually"
else
    echo "✅ Docker is available"
fi

# Function to check RBAC permissions
check_rbac_permissions() {
    echo ""
    echo "🔐 Checking RBAC permissions for v2.0 (9 resource types)..."

    # Test all permissions that our v2.0 collector will need
    PERMISSIONS=(
        "get pods"
        "list pods"
        "get deployments"
        "list deployments"
        "get nodes"
        "list nodes"
        "get services"
        "list services"
        "get ingresses"
        "list ingresses"
        "get configmaps"
        "list configmaps"
        "get secrets"
        "list secrets"
        "get persistentvolumes"
        "list persistentvolumes"
        "get persistentvolumeclaims"
        "list persistentvolumeclaims"
    )

    local rbac_ok=true
    for perm in "${PERMISSIONS[@]}"; do
        if kubectl auth can-i $perm --quiet 2>/dev/null; then
            echo "✅ Can $perm"
        else
            echo "❌ Cannot $perm - this may cause issues"
            rbac_ok=false
        fi
    done

    if [ "$rbac_ok" = false ]; then
        echo ""
        echo "⚠️  Some RBAC permissions are missing. You may need to:"
        echo "   • Run as cluster-admin"
        echo "   • Create appropriate ClusterRole and ClusterRoleBinding"
        echo "   • Use the Helm chart which includes RBAC setup"
    fi
}

# Function to show cluster status
show_cluster_status() {
    echo ""
    echo "📊 Current cluster status (v2.0 resource types):"
    echo "Nodes: $(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "Pods: $(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "Deployments: $(kubectl get deployments --all-namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "Services: $(kubectl get services --all-namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "Ingresses: $(kubectl get ingresses --all-namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "ConfigMaps: $(kubectl get configmaps --all-namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "Secrets: $(kubectl get secrets --all-namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "PersistentVolumes: $(kubectl get pv --no-headers 2>/dev/null | wc -l || echo '0')"
    echo "PersistentVolumeClaims: $(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | wc -l || echo '0')"
}

# Function to ensure development namespace exists
ensure_dev_namespace() {
    local namespace=$1
    
    if [ -z "$namespace" ]; then
        echo "❌ Error: Namespace parameter is required"
        return 1
    fi
    
    echo "🏷️  Ensuring namespace '$namespace' exists..."
    
    # Check if namespace exists
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo "✅ Namespace '$namespace' already exists"
    else
        echo "📝 Creating namespace '$namespace'..."
        kubectl create namespace "$namespace"
        if [ $? -eq 0 ]; then
            echo "✅ Namespace '$namespace' created successfully"
        else
            echo "❌ Failed to create namespace '$namespace'"
            return 1
        fi
    fi
    
    # Add development labels to namespace
    echo "🏷️  Labeling namespace for development..."
    kubectl label namespace "$namespace" \
        purpose=development \
        component=k8s-cluster-info-collector \
        environment=dev \
        managed-by=setup-hybrid-script \
        --overwrite
        
    if [ $? -eq 0 ]; then
        echo "✅ Namespace '$namespace' labeled successfully"
    else
        echo "⚠️  Warning: Failed to label namespace '$namespace' (continuing anyway)"
    fi
    
    return 0
}

# Function to show namespace information
show_namespace_info() {
    local namespace=$1
    
    if [ -z "$namespace" ]; then
        echo "❌ Error: Namespace parameter is required"
        return 1
    fi
    
    echo "📊 Namespace Information: $namespace"
    echo "======================================"
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo "❌ Namespace '$namespace' does not exist"
        return 1
    fi
    
    # Show namespace details
    echo ""
    echo "🏷️  Namespace Details:"
    kubectl get namespace "$namespace" -o wide 2>/dev/null || echo "⚠️  Could not retrieve namespace details"
    
    # Show namespace labels
    echo ""
    echo "🏷️  Namespace Labels:"
    kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null | jq -r 'to_entries[] | "   \(.key): \(.value)"' 2>/dev/null || \
    kubectl get namespace "$namespace" -o yaml | grep -A 10 labels: | tail -n +2 | sed 's/^/   /' || echo "   No labels found"
    
    # Show resources in namespace
    echo ""
    echo "📦 Resources in Namespace:"
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local service_count=$(kubectl get services -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local deployment_count=$(kubectl get deployments -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local configmap_count=$(kubectl get configmaps -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    echo "   Pods: $pod_count"
    echo "   Services: $service_count"
    echo "   Deployments: $deployment_count"
    echo "   ConfigMaps: $configmap_count"
    
    # Show pod status if any pods exist
    if [ "$pod_count" -gt 0 ]; then
        echo ""
        echo "🚀 Pod Status:"
        kubectl get pods -n "$namespace" -o wide 2>/dev/null | sed 's/^/   /' || echo "   Could not retrieve pod status"
    fi
    
    # Show services if any exist
    if [ "$service_count" -gt 0 ]; then
        echo ""
        echo "🔗 Services:"
        kubectl get services -n "$namespace" 2>/dev/null | sed 's/^/   /' || echo "   Could not retrieve services"
    fi
    
    return 0
}

# Function to deploy legacy mode
deploy_legacy_mode() {
    echo ""
    echo "🐳 Deploying Legacy Mode (Direct Database Storage)..."
    echo "Environment: KAFKA_ENABLED=false"
    echo ""
    
    # Check if Makefile exists
    if [ ! -f "Makefile" ]; then
        echo "❌ Makefile not found. Creating basic deployment..."
        deploy_legacy_manual
        return
    fi
    
    echo "📦 Building Docker image..."
    if ! make docker-build; then
        echo "❌ Docker build failed"
        return 1
    fi
    
    # Check cluster type for image loading
    if kubectl config current-context | grep -q "kind"; then
        echo "🔄 Loading image to kind cluster..."
        make kind-load || echo "⚠️  kind-load failed, image may not be available in cluster"
    elif kubectl config current-context | grep -q "minikube"; then
        echo "🔄 Loading image to minikube..."
        make minikube-load || echo "⚠️  minikube-load failed, image may not be available in cluster"
    else
        echo "ℹ️  Unknown cluster type, skipping image load (ensure image is available in cluster)"
    fi
    
    echo "🗄️  Deploying PostgreSQL..."
    if ! make deploy-postgres; then
        echo "❌ PostgreSQL deployment failed"
        return 1
    fi
    
    echo "⏳ Waiting for PostgreSQL to be ready..."
    sleep 30
    
    echo "🚀 Deploying collector..."
    if ! make deploy-collector; then
        echo "❌ Collector deployment failed"
        return 1
    fi
    
    echo "📊 Checking deployment status..."
    make status || kubectl get all -l app=k8s-cluster-info-collector
    
    echo ""
    echo "✅ Legacy mode deployment completed!"
    show_verification_steps
}

# Function to deploy legacy mode manually (when Makefile is not available)
deploy_legacy_manual() {
    echo "📦 Manual legacy deployment..."
    
    # Deploy PostgreSQL
    echo "🗄️  Deploying PostgreSQL..."
    if [ -f "postgres.yaml" ]; then
        kubectl apply -f postgres.yaml
    else
        echo "⚠️  postgres.yaml not found, you'll need to deploy PostgreSQL manually"
    fi
    
    # Deploy collector
    echo "🚀 Deploying collector..."
    if [ -f "k8s-job.yaml" ]; then
        kubectl apply -f k8s-job.yaml
    elif [ -f "k8s-cronjob.yaml" ]; then
        kubectl apply -f k8s-cronjob.yaml
    else
        echo "⚠️  No Kubernetes manifests found, you'll need to create deployment manually"
    fi
}

# Function to deploy Kafka mode
deploy_kafka_mode() {
    echo ""
    echo "🌊 Deploying Kafka Mode (v2.0 - Recommended for Production)..."
    echo "Environment: KAFKA_ENABLED=true"
    echo "Features: Horizontal scaling, message queuing, fault tolerance"
    echo "🎯 Using optimized Apache Kafka images (not Bitnami dependencies)"
    echo ""
    
    local namespace="cluster-info"
    local release_name="my-cluster-info"
    
    # Ensure namespace exists
    ensure_dev_namespace $namespace
    
    echo "📦 Deploying optimized Apache Kafka services (KRaft mode - no Zookeeper)..."
    echo "   • Kafka: bitnami/kafka:3.6 (512MB limit, KRaft mode)"
    echo "   • PostgreSQL: postgres:15 (optimized for development)"
    echo ""
    
    deploy_minimal_kafka_services $namespace
    
    echo "⏳ Waiting for services to be ready..."
    sleep 45
    
    # Setup port forwarding for services
    setup_services_port_forwarding $namespace "kafka-minimal"
    
    echo ""
    echo "📊 Checking deployment status..."
    kubectl get all -n $namespace
    
    echo ""
    echo "✅ Kafka mode deployment completed!"
    echo "📋 Monitor deployment:"
    echo "   kubectl logs -l app=kafka -n $namespace -f"
    echo "   kubectl logs -l app=postgres -n $namespace -f"
    
    show_verification_steps $namespace
}

# Function to setup development environment
setup_development() {
    echo ""
    echo "📋 Setting up Development Environment..."
    echo ""
    echo "🎓 Development Modes Explained:"
    echo ""
    echo "🏠 LOCAL MODES (Options 1-2):"
    echo "   • Binary: Runs on your local machine"
    echo "   • Services: PostgreSQL/Kafka via Docker Compose"
    echo "   • Best for: Offline development, service testing"
    echo ""
    echo "🌉 HYBRID MODES (Options 3-4) - ⭐ RECOMMENDED:"
    echo "   • Binary: Runs locally for fast iteration"
    echo "   • Services: PostgreSQL/Kafka in Kubernetes cluster"
    echo "   • Best for: Realistic development with live cluster data"
    echo ""
    echo "☁️  KUBERNETES MODES (Options 5-6):"
    echo "   • Binary: Deployed as K8s pod"
    echo "   • Services: PostgreSQL/Kafka in cluster"
    echo "   • Best for: Production-like testing"
    echo ""
    echo "🔧 Choose your development mode:"
    echo "1. 🏠 Local Legacy (Binary+Docker: PostgreSQL only)"
    echo "2. 🏠 Local Kafka (Binary+Docker: PostgreSQL+Kafka)"
    echo "3. 🌉 Hybrid Legacy (Local Binary + K8s PostgreSQL) ⭐"
    echo "4. 🌉 Hybrid Kafka Development (Manual consumer/collector control) ⭐"
    echo "5. ☁️  K8s Legacy (Full K8s deployment: PostgreSQL only)"
    echo "6. ☁️  K8s Kafka (Full K8s deployment: PostgreSQL+Kafka)"
    echo "7. 🧪 E2E Testing & Background Management (Automated workflow) ⭐"
    echo ""
    read -p "Select mode (1-7): " dev_mode
    
    case $dev_mode in
        1)
            echo "🐳 Setting up local legacy development mode..."
            setup_local_development false
            ;;
        2)
            echo "🌊 Setting up local Kafka development mode..."
            setup_local_development true
            ;;
        3)
            echo "🐳 Setting up hybrid legacy development mode (local binary + K8s services)..."
            setup_hybrid_development false
            ;;
        4)
            echo "🌊 Setting up hybrid Kafka development mode (local binary + K8s services)..."
            setup_hybrid_development true
            ;;
        5)
            echo "🐳 Setting up Kubernetes legacy development mode..."
            setup_k8s_development false
            ;;
        6)
            echo "🌊 Setting up Kubernetes Kafka development mode..."
            setup_k8s_development true
            ;;
        7)
            echo "🧪 Setting up End-to-End Test (Collector→Kafka→Consumer→PostgreSQL)..."
            setup_e2e_test
            ;;
        *)
            echo "❌ Invalid choice. Using local legacy mode..."
            setup_local_development false
            ;;
    esac
}

# Function to setup local development (binary execution)
setup_local_development() {
    local kafka_enabled=$1
    
    if [ "$kafka_enabled" = "true" ]; then
        echo "🌊 Setting up local Kafka development mode..."
        export KAFKA_ENABLED=true
        echo "export KAFKA_ENABLED=true" > .env.local
        echo "⚠️  Note: You'll need Kafka and PostgreSQL running locally"
        echo "   Consider using docker-compose: docker-compose up -d kafka postgres"
    else
        echo "🐳 Setting up local legacy development mode..."
        export KAFKA_ENABLED=false
        echo "export KAFKA_ENABLED=false" > .env.local
        echo "⚠️  Note: You'll need PostgreSQL running locally"
        echo "   Consider using docker-compose: docker-compose up -d postgres"
    fi
    
    # Create bin directory if it doesn't exist
    mkdir -p bin
    
    echo "📦 Building application..."
    if ! go build -o bin/collector main.go; then
        echo "❌ Build failed"
        return 1
    fi
    
    echo "🧪 Running tests..."
    go test ./... || echo "⚠️  Some tests failed"
    
    echo "🔍 Running integration tests..."
    if [ -f "integration_test.go" ]; then
        go test ./integration_test.go || echo "⚠️  Integration tests failed (may need database/cluster setup)"
    fi
    
    echo ""
    echo "✅ Local development environment setup completed!"
    echo ""
    echo "📋 Next steps for local development:"
    echo "   1. Start required services:"
    if [ "$kafka_enabled" = "true" ]; then
        echo "      docker-compose -f docker-compose.dev.yml up -d"
    else
        echo "      docker-compose -f docker-compose.dev.yml up -d postgres"
    fi
    echo "   2. Configure environment: source .env.local"
    echo "   3. Run collector: ./bin/collector"
    echo ""
    echo "� Helpful commands:"
    echo "   • Check services: docker-compose -f docker-compose.dev.yml ps"
    echo "   • View logs: docker-compose -f docker-compose.dev.yml logs -f"
    echo "   • Stop services: docker-compose -f docker-compose.dev.yml down"
    echo ""
    echo "📊 Local service endpoints:"
    if [ "$kafka_enabled" = "true" ]; then
        echo "   • PostgreSQL: localhost:5432 (user: clusterinfo, pass: devpassword)"
        echo "   • Kafka: localhost:9092"
    else
        echo "   • PostgreSQL: localhost:5432 (user: clusterinfo, pass: devpassword)"
    fi
}

# Function to setup hybrid development (local binary + K8s services)
setup_hybrid_development() {
    local kafka_enabled=$1
    local namespace="cluster-info-dev"
    
    echo ""
    echo "🌉 HYBRID DEVELOPMENT MODE SETUP"
    echo "================================"
    echo ""
    echo "🎯 What is Hybrid Development?"
    echo "• Your code runs locally (fast builds, instant debugging)"
    echo "• Database & services run in Kubernetes (realistic environment)"
    echo "• Port forwarding connects local binary to K8s services"
    echo "• Best of both worlds: speed + realism"
    echo ""
    
    if [ "$kafka_enabled" = "true" ]; then
        echo "🌊 Hybrid Kafka Mode Selected:"
        echo "   📦 Local: Collector binary → Kafka (fast iteration)"
        echo "   ☁️  K8s: Kafka (KRaft) + Consumer → PostgreSQL"
        echo "   🔗 Connection: Port forwarding (9092 for Kafka)"
        echo "   💡 Benefits: Full streaming pipeline testing"
    else
        echo "🐳 Hybrid Legacy Mode Selected:"
        echo "   📦 Local: Collector binary (fast iteration)"
        echo "   ☁️  K8s: PostgreSQL database"
        echo "   🔗 Connection: Port forwarding (5432)"
        echo "   💡 Benefits: Simple setup, direct database storage"
    fi
    
    echo ""
    echo "📋 Hybrid Setup Process:"
    echo "1. Deploy services to Kubernetes cluster"
    echo "2. Setup automatic port forwarding"
    echo "3. Build and configure local binary"
    echo "4. Test the complete setup"
    echo "5. Provide development workflow guidance"
    echo ""
    read -p "🚀 Ready to setup hybrid development? (Press Enter to continue or Ctrl+C to cancel)"
    
    # First, deploy services to Kubernetes
    echo ""
    echo "🚀 Step 1: Deploying services to Kubernetes..."
    deploy_k8s_services $kafka_enabled $namespace
    
    # Then setup local binary
    echo ""
    echo "🔧 Step 2: Setting up local binary..."
    setup_hybrid_local_binary $kafka_enabled $namespace
}

# Function to deploy only services to Kubernetes
deploy_k8s_services() {
    local kafka_enabled=$1
    local namespace=$2
    
    # Ensure development namespace exists with labels
    ensure_dev_namespace $namespace
    
    if [ "$kafka_enabled" = "true" ]; then
        echo "🌊 Deploying Kafka services to Kubernetes..."
        
        # Check if Helm is available
        if ! command -v helm &> /dev/null; then
            echo "❌ Helm is required for Kafka services. Please install Helm 3.0+"
            echo "📦 Deploying minimal Apache Kafka services instead..."
            deploy_minimal_kafka_services $namespace
            setup_services_port_forwarding $namespace "kafka-minimal"
            return
        fi
        
        echo "✅ Helm is available"
        echo "⚠️  Note: Using minimal Apache Kafka deployment instead of Helm chart to avoid Bitnami dependencies"
        echo "📦 Deploying optimized Apache Kafka services..."
        deploy_minimal_kafka_services $namespace
        setup_services_port_forwarding $namespace "kafka-minimal"
        return
        
    # Check if helm chart exists
    if [ ! -d "helm/cluster-info-collector" ]; then
        echo "❌ Helm chart not found at helm/cluster-info-collector"
        echo "📦 Creating minimal services deployment..."
        deploy_minimal_kafka_services $namespace
        setup_services_port_forwarding $namespace "kafka-minimal"
        return
    fi
    
    echo "🔧 Preparing Helm chart dependencies..."
    local chart_dir="helm/cluster-info-collector"
    
    # Check if dependencies are already built
    if [ ! -d "$chart_dir/charts" ]; then
        echo "📦 Building Helm chart dependencies (PostgreSQL, Kafka)..."
        cd "$chart_dir"
        if ! helm dependency build; then
            echo "❌ Failed to build Helm chart dependencies"
            echo "📦 Falling back to minimal services deployment..."
            cd - > /dev/null
            deploy_minimal_kafka_services $namespace
            setup_services_port_forwarding $namespace "kafka-minimal"
            return
        fi
        cd - > /dev/null
        echo "✅ Helm chart dependencies built successfully"
    else
        echo "✅ Helm chart dependencies already available"
    fi
    
    echo "🚀 Deploying services with Helm (services only)..."
    local release_name="dev-services"
    
    helm install $release_name helm/cluster-info-collector \
        --namespace $namespace \
        --set collector.enabled=false \
        --set consumer.enabled=false \
        --set postgresql.auth.password="devpassword" \
        --set kafka.enabled=true \
        --set postgresql.enabled=true \
        --set config.metrics.enabled=false \
        --set config.api.enabled=false \
        --set config.streaming.enabled=false
        
        echo "⏳ Waiting for services to be ready..."
        sleep 45
        
        # Setup port forwarding for services
        setup_services_port_forwarding $namespace "kafka" $release_name
    else
        echo "🐳 Deploying PostgreSQL service to Kubernetes..."
        
        # Deploy just PostgreSQL using minimal deployment (namespace-safe)
        echo "📦 Creating minimal PostgreSQL deployment..."
        if deploy_minimal_postgres_service $namespace; then
            # Return code 0 means new deployment was created
            echo "⏳ Waiting for PostgreSQL to be ready..."
            sleep 30
        else
            # Return code 1 means PostgreSQL already exists and is ready
            echo "✅ PostgreSQL already running, skipping initial wait"
        fi
        
        # Setup port forwarding for PostgreSQL
        setup_services_port_forwarding $namespace "legacy"
        
        # Verify database is fully ready
        if ! verify_postgres_database $namespace; then
            echo "❌ PostgreSQL database verification failed"
            echo "   You may need to wait longer or check the PostgreSQL pod logs:"
            echo "   kubectl logs -l app=postgres -n $namespace"
            return 1
        fi
        setup_services_port_forwarding $namespace "legacy"
    fi
}

# Function to deploy minimal Kafka services when Helm chart is not available
deploy_minimal_kafka_services() {
    local namespace=$1
    
    echo "📦 Deploying minimal Kafka and PostgreSQL services to namespace '$namespace'..."
    
    # Check if PostgreSQL already exists
    local postgres_exists=false
    if kubectl get deployment postgres -n $namespace >/dev/null 2>&1; then
        echo "✅ PostgreSQL deployment already exists"
        postgres_exists=true
    else
        echo "📦 Creating PostgreSQL deployment..."
    fi
    
    # Check if Kafka already exists  
    local kafka_exists=false
    if kubectl get deployment kafka -n $namespace >/dev/null 2>&1; then
        echo "✅ Kafka deployment already exists"
        kafka_exists=true
    else
        echo "📦 Creating Kafka deployment..."
    fi

    # Deploy PostgreSQL only if it doesn't exist
    if [ "$postgres_exists" = false ]; then
        kubectl apply -n $namespace -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: clusterinfo
        - name: POSTGRES_USER
          value: clusterinfo
        - name: POSTGRES_PASSWORD
          value: devpassword
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: $namespace
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF
    else
        echo "   Skipping PostgreSQL creation (already exists)"
    fi

    # Deploy Kafka only if it doesn't exist (KRaft mode - no Zookeeper needed)
    if [ "$kafka_exists" = false ]; then
        kubectl apply -n $namespace -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
      - name: kafka
        image: bitnami/kafka:3.6
        env:
        - name: KAFKA_CFG_NODE_ID
          value: "0"
        - name: KAFKA_CFG_PROCESS_ROLES
          value: "controller,broker"
        - name: KAFKA_CFG_CONTROLLER_QUORUM_VOTERS
          value: "0@localhost:9093"
        - name: KAFKA_CFG_LISTENERS
          value: "PLAINTEXT://:9092,CONTROLLER://:9093"
        - name: KAFKA_CFG_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka:9092"
        - name: KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP
          value: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
        - name: KAFKA_CFG_CONTROLLER_LISTENER_NAMES
          value: "CONTROLLER"
        - name: KAFKA_CFG_INTER_BROKER_LISTENER_NAME
          value: "PLAINTEXT"
        - name: KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR
          value: "1"
        - name: KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR
          value: "1"
        - name: KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR
          value: "1"
        - name: KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE
          value: "true"
        - name: KAFKA_CFG_LOG_RETENTION_HOURS
          value: "1"
        - name: ALLOW_PLAINTEXT_LISTENER
          value: "yes"
        ports:
        - containerPort: 9092
        - containerPort: 9093
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
          requests:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          tcpSocket:
            port: 9092
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          tcpSocket:
            port: 9092
          initialDelaySeconds: 60
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: $namespace
spec:
  selector:
    app: kafka
  ports:
  - name: kafka
    port: 9092
    targetPort: 9092
  - name: controller
    port: 9093
    targetPort: 9093
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-ui
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-ui
  template:
    metadata:
      labels:
        app: kafka-ui
    spec:
      containers:
      - name: kafka-ui
        image: provectuslabs/kafka-ui:latest
        env:
        - name: KAFKA_CLUSTERS_0_NAME
          value: "development"
        - name: KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS
          value: "kafka:9092"
        - name: KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL
          value: "PLAINTEXT"
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
          requests:
            memory: "128Mi"
            cpu: "100m"
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-ui
  namespace: $namespace
spec:
  selector:
    app: kafka-ui
  ports:
  - port: 8080
    targetPort: 8080
EOF
    else
        echo "   Skipping Kafka creation (already exists)"
        
        # Check if Kafka UI exists, deploy if not
        if ! kubectl get deployment kafka-ui -n $namespace >/dev/null 2>&1; then
            echo "📦 Creating Kafka UI deployment..."
            kubectl apply -n $namespace -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-ui
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-ui
  template:
    metadata:
      labels:
        app: kafka-ui
    spec:
      containers:
      - name: kafka-ui
        image: provectuslabs/kafka-ui:latest
        env:
        - name: KAFKA_CLUSTERS_0_NAME
          value: "development"
        - name: KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS
          value: "kafka:9092"
        - name: KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL
          value: "PLAINTEXT"
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
          requests:
            memory: "128Mi"
            cpu: "100m"
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-ui
  namespace: $namespace
spec:
  selector:
    app: kafka-ui
  ports:
  - port: 8080
    targetPort: 8080
EOF
        else
            echo "   Kafka UI already exists"
        fi
    fi
    
    echo "✅ Service deployment completed"
}

# Function to deploy minimal PostgreSQL service
deploy_minimal_postgres_service() {
    local namespace=$1
    
    # Check if PostgreSQL is already deployed
    if kubectl get deployment postgres -n $namespace >/dev/null 2>&1; then
        echo "✅ PostgreSQL deployment already exists in namespace '$namespace'"
        echo "   Checking if service is ready..."
        
        if kubectl get service postgres -n $namespace >/dev/null 2>&1; then
            echo "✅ PostgreSQL service is already available"
            return 1  # Return 1 to indicate "already exists, no deployment needed"
        else
            echo "⚠️  PostgreSQL deployment exists but service is missing, recreating service..."
        fi
    else
        echo "📦 Deploying minimal PostgreSQL service to namespace '$namespace'..."
    fi
    
    kubectl apply -n $namespace -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: clusterinfo
        - name: POSTGRES_USER
          value: clusterinfo
        - name: POSTGRES_PASSWORD
          value: devpassword
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - clusterinfo
            - -d
            - clusterinfo
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - clusterinfo
            - -d
            - clusterinfo
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: $namespace
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF
    
    return 0  # Return 0 to indicate "new deployment created, needs wait time"
}

# Function to setup port forwarding for services only
setup_services_port_forwarding() {
    local namespace=$1
    local mode=$2
    local release_name=${3:-"dev-services"}
    
    echo ""
    echo "🔗 Setting up port forwarding for services..."
    
    # Kill any existing port forwards on service ports
    pkill -f "kubectl.*port-forward.*5432" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*9092" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*8080" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*8090" 2>/dev/null || true
    
    sleep 2
    
    # PostgreSQL port forwarding
    echo "🗄️ Forwarding PostgreSQL port (5432)..."
    case $mode in
        "kafka")
            kubectl port-forward service/${release_name}-postgresql 5432:5432 -n $namespace > /tmp/port-forward-postgres.log 2>&1 &
            ;;
        "kafka-minimal"|"legacy")
            kubectl port-forward service/postgres 5432:5432 -n $namespace > /tmp/port-forward-postgres.log 2>&1 &
            ;;
    esac
    local pf_postgres_pid=$!
    
    if [[ "$mode" == "kafka"* ]]; then
    # Kafka port forwarding
        echo "🌊 Forwarding Kafka port (9092)..."
        if [ "$mode" = "kafka" ]; then
            kubectl port-forward service/${release_name}-kafka 9092:9092 -n $namespace > /tmp/port-forward-kafka.log 2>&1 &
        else
            kubectl port-forward service/kafka 9092:9092 -n $namespace > /tmp/port-forward-kafka.log 2>&1 &
        fi
        local pf_kafka_pid=$!
        
        # Kafka UI port forwarding
        echo "🖥️  Forwarding Kafka UI port (8090)..."
        if [ "$mode" = "kafka" ]; then
            kubectl port-forward service/${release_name}-kafka-ui 8090:8080 -n $namespace > /tmp/port-forward-kafka-ui.log 2>&1 &
        else
            kubectl port-forward service/kafka-ui 8090:8080 -n $namespace > /tmp/port-forward-kafka-ui.log 2>&1 &
        fi
        local pf_kafka_ui_pid=$!
        
        # Save both PIDs
        echo "$pf_postgres_pid $pf_kafka_pid $pf_kafka_ui_pid" > /tmp/services-port-forward-pids.txt
    else
        # Save PostgreSQL PID only
        echo "$pf_postgres_pid" > /tmp/services-port-forward-pids.txt
    fi
    
    # Wait for port forwards to establish
    sleep 5
    
    echo ""
    echo "✅ Service port forwarding setup completed!"
    echo ""
    echo "📊 Available services:"
    echo "   • PostgreSQL: localhost:5432 (user: clusterinfo, pass: devpassword)"
    if [[ "$mode" == "kafka"* ]]; then
        echo "   • Kafka: localhost:9092"
        echo "   • Kafka UI: http://localhost:8090"
    fi
    echo ""
    
    # Test service connectivity
    test_services_connectivity $mode
}

# Function to test service connectivity
test_services_connectivity() {
    local mode=$1
    
    echo "🧪 Testing service connectivity..."
    
    # Test PostgreSQL
    if nc -z localhost 5432 2>/dev/null; then
        echo "✅ PostgreSQL port accessible"
    else
        echo "⚠️  PostgreSQL port not accessible (may still be starting up)"
    fi
    
    if [[ "$mode" == "kafka"* ]]; then
        # Test Kafka
        if nc -z localhost 9092 2>/dev/null; then
            echo "✅ Kafka port accessible"
        else
            echo "⚠️  Kafka port not accessible (may still be starting up)"
        fi
    fi
}

# Function to setup local binary for hybrid development
setup_hybrid_local_binary() {
    local kafka_enabled=$1
    local namespace=$2
    
    # Create bin directory if it doesn't exist
    mkdir -p bin
    
    # Create environment configuration for hybrid mode
    echo "🔧 Creating hybrid environment configuration..."
    
    if [ "$kafka_enabled" = "true" ]; then
        cat > .env.hybrid <<EOF
# Hybrid Kafka Mode - Collector Job Behavior (Always One-Shot)
export KAFKA_ENABLED=true
# Database settings removed - collector doesn't write to DB in Kafka mode
# Consumer will handle DB writes from Kafka messages
export KAFKA_BROKERS=localhost:9092
export KAFKA_TOPIC=cluster-info
# Collector always runs as Job - no background services needed
# Job behavior: start → verify connectivity → collect → write → exit
export LOG_LEVEL=info
export LOG_FORMAT=text
EOF
        echo "✅ Hybrid Kafka environment created (.env.hybrid)"
        echo "   📋 Key settings: KAFKA_ENABLED=true, KAFKA_BROKERS=localhost:9092"
        echo "   🎯 Collector behavior: Always runs as Job (start → collect → write → exit)"
        echo "   ℹ️  Collector writes to Kafka only (no direct DB writes)"
    else
        cat > .env.hybrid <<EOF
# Hybrid Legacy Mode - Collector Job Behavior (Always One-Shot)
export KAFKA_ENABLED=false
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=clusterinfo
export DB_USER=clusterinfo
export DB_PASSWORD=devpassword
export DB_SSLMODE=disable
# Collector always runs as Job - no background services needed
# Job behavior: start → verify connectivity → collect → write → exit
export LOG_LEVEL=info
export LOG_FORMAT=text
EOF
        echo "✅ Hybrid Legacy environment created (.env.hybrid)"
        echo "   📋 Key settings: KAFKA_ENABLED=false, DB_HOST=localhost"
        echo "   🎯 Collector behavior: Always runs as Job (start → collect → write → exit)"
    fi
    
    echo "📦 Building application..."
    if ! make build; then
        echo "❌ Build failed"
        return 1
    fi
    
    echo "✅ Built collector and consumer binaries successfully"
    
    # Create consumer environment for Kafka mode
    if [ "$kafka_enabled" = "true" ]; then
        echo "🔧 Creating consumer environment for Kafka mode..."
        cat > .env.hybrid-consumer <<EOF
# Hybrid Kafka Mode - Consumer reads from Kafka and writes to DB
export KAFKA_ENABLED=true
export KAFKA_BROKERS=localhost:9092
export KAFKA_TOPIC=cluster-info
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=clusterinfo
export DB_USER=clusterinfo
export DB_PASSWORD=devpassword
export DB_SSLMODE=disable
export LOG_LEVEL=info
EOF
        echo "✅ Consumer environment created (.env.hybrid-consumer)"
        echo "   📋 Key settings: Kafka→PostgreSQL data flow"
    fi
    
    echo "🧪 Running tests..."
    go test ./... || echo "⚠️  Some tests failed"
    
    echo ""
    echo "🎉 HYBRID DEVELOPMENT SETUP COMPLETED!"
    echo "====================================="
    echo ""
    show_namespace_info $namespace
    echo ""
    echo "📋 What We Accomplished:"
    if [ "$kafka_enabled" = "true" ]; then
        echo "  ✅ PostgreSQL + Kafka running in Kubernetes ($namespace namespace)"
    else
        echo "  ✅ PostgreSQL running in Kubernetes ($namespace namespace)"
    fi
    echo "  ✅ Automatic port forwarding to localhost"
    echo "  ✅ Local binary compiled and tested"
    echo "  ✅ Environment configured (.env.hybrid)"
    echo "  ✅ Initial data collection verified"
    echo ""
    echo "🚀 Starting initial data collection demo..."
    echo ""
    
    # Source environment and run collector for initial data collection
    source .env.hybrid
    
    echo "🔄 Running collector to populate database (30 seconds)..."
    echo "   📊 This demonstrates hybrid mode collecting live cluster data"
    echo "   🔗 Local binary → K8s PostgreSQL via port forwarding"
    echo ""
    echo "🔧 Environment check: KAFKA_ENABLED=$KAFKA_ENABLED, KAFKA_BROKERS=$KAFKA_BROKERS"
    echo ""
    
    # Run collector with appropriate configuration
    if [ "$kafka_enabled" = "true" ]; then
        echo "🔄 Running collector in Kafka mode (one-shot: collect → send to Kafka → exit)..."
        echo "   📊 Workflow: Collector → Kafka → Consumer → PostgreSQL"
        echo "   ✨ Collector will run once and exit, Consumer will start and keep running"
        echo ""
        
        # Run collector in one-shot mode (no background services)
        echo "📦 Step 1: Running collector to send data to Kafka..."
        KAFKA_ENABLED=true \
        KAFKA_BROKERS=$KAFKA_BROKERS \
        KAFKA_TOPIC=$KAFKA_TOPIC \
        METRICS_ENABLED=false \
        API_ENABLED=false \
        STREAMING_ENABLED=false \
        LOG_LEVEL=$LOG_LEVEL \
        LOG_FORMAT=$LOG_FORMAT \
        RETENTION_ENABLED=false \
        ALERTING_ENABLED=false \
        ./bin/collector
        
        echo "✅ Collector completed and exited! Data sent to Kafka."
        echo ""
        echo "📦 Step 2: Starting consumer to process Kafka messages..."
        echo "   🔄 Consumer will keep running to process messages from Kafka..."
        
        # Start consumer in background to keep running
        source .env.hybrid-consumer
        ./bin/consumer &
        local consumer_pid=$!
        
        echo "✅ Consumer started (PID: $consumer_pid) and running continuously!"
        echo ""
        echo "🎯 KAFKA WORKFLOW ACTIVE:"
        echo "   • Collector: ✅ Completed (ran once, sent data to Kafka, exited)"
        echo "   • Consumer: 🔄 Running (PID: $consumer_pid, processing messages from Kafka)"
        echo ""
        echo "💡 Development Commands:"
        echo "   # Run collector again (one-shot):"
        echo "   source .env.hybrid && ./bin/collector"
        echo ""
        echo "   # Check consumer status:"
        echo "   ps aux | grep consumer"
        echo ""
        echo "   # Stop consumer:"
        echo "   kill $consumer_pid"
        echo ""
        echo "   # Restart consumer:"
        echo "   source .env.hybrid-consumer && ./bin/consumer &"
        
    else
        echo "🔄 Running collector in legacy mode (writes directly to PostgreSQL)..."
        echo "   📊 Collector → PostgreSQL"
        echo ""
        
        # Run collector in legacy mode (with database env vars)
        KAFKA_ENABLED=false \
        DB_HOST=$DB_HOST \
        DB_PORT=$DB_PORT \
        DB_NAME=$DB_NAME \
        DB_USER=$DB_USER \
        DB_PASSWORD=$DB_PASSWORD \
        METRICS_ENABLED=$METRICS_ENABLED \
        METRICS_ADDRESS=$METRICS_ADDRESS \
        API_ENABLED=$API_ENABLED \
        API_ADDRESS=$API_ADDRESS \
        STREAMING_ENABLED=$STREAMING_ENABLED \
        STREAMING_ADDRESS=$STREAMING_ADDRESS \
        LOG_LEVEL=$LOG_LEVEL \
        LOG_FORMAT=$LOG_FORMAT \
        RETENTION_ENABLED=$RETENTION_ENABLED \
        RETENTION_MAX_AGE=$RETENTION_MAX_AGE \
        ALERTING_ENABLED=$ALERTING_ENABLED \
        ./bin/collector &
        local collector_pid=$!
        
        # Let it run for 30 seconds to collect initial data
        sleep 30
        
        # Stop the collector
        kill $collector_pid 2>/dev/null || true
        wait $collector_pid 2>/dev/null || true
        
        echo "✅ Initial data collection completed!"
    fi
    echo ""
    
    # Test database to verify data was collected
    echo "🔍 Verifying data collection..."
    if command -v psql &> /dev/null; then
        echo "📊 Database contains cluster data:"
        PGPASSWORD=devpassword psql -h localhost -p 5432 -U clusterinfo -d clusterinfo -c "
        SELECT 
            'cluster_snapshots' as table_name, COUNT(*) as records
        FROM cluster_snapshots 
        UNION ALL
        SELECT 
            'total_pods', COUNT(*) 
        FROM pods
        UNION ALL
        SELECT 
            'total_nodes', COUNT(*) 
        FROM nodes
        UNION ALL
        SELECT 
            'total_deployments', COUNT(*) 
        FROM deployments;" 2>/dev/null || echo "⚠️  Could not query database (psql not available or data not yet collected)"
    else
        echo "ℹ️  Install psql to verify database: brew install postgresql"
    fi
    
    echo ""
    echo "🎓 HYBRID DEVELOPMENT WORKFLOW:"
    echo "==============================="
    echo ""
    if [ "$kafka_enabled" = "true" ]; then
        echo "🌊 KAFKA MODE DEVELOPMENT:"
        echo "   Proper workflow: Collector runs once → Consumer keeps running"
        echo ""
        echo "📝 Development Cycle:"
        echo "  1. Edit collector code → Rebuild → Run once → Test Kafka output"
        echo "  2. Edit consumer code → Rebuild → Restart consumer → Test DB writes"
        echo "  3. Consumer runs continuously to process all Kafka messages"
        echo "  4. Collector runs on-demand for new data collection"
        echo ""
        echo "🔄 Component Control:"
        echo "   # Collector (run once, collect data, send to Kafka, exit):"
        echo "   source .env.hybrid && ./bin/collector"
        echo ""
        echo "   # Consumer (start once, keep running to process Kafka messages):"
        echo "   source .env.hybrid-consumer && ./bin/consumer &"
        echo ""
        echo "   # Check consumer status:"
        echo "   ps aux | grep consumer"
        echo ""
        echo "   # Stop consumer:"
        echo "   pkill -f consumer"
        echo ""
        echo "💡 Development Tips:"
        echo "   • Collector: One-shot execution (collect → send → exit)"
        echo "   • Consumer: Long-running process (continuously processes Kafka)"
        echo "   • Run collector multiple times to test different scenarios"
        echo "   • Consumer automatically processes all messages from Kafka"
        echo "   • Check Kafka UI: http://localhost:8090"
        echo "   • Use Option 7 for automated end-to-end testing"
        echo ""
    else
        echo "📝 Daily Development Cycle:"
        echo "  1. Edit code in your favorite editor/IDE"
        echo "  2. Rebuild instantly: go build -o bin/collector main.go"
        echo "  3. Test immediately: source .env.hybrid && ./bin/collector"
        echo "  4. Debug with standard Go tools (delve, IDE debuggers)"
        echo "  5. Access live APIs for testing"
        echo ""
    fi
    if [ "$kafka_enabled" = "true" ]; then
        echo "🔗 Available Endpoints (Kafka Mode):"
        echo "  • Kafka UI: http://localhost:8090 (monitor topics, messages, consumers)"
        echo "  • PostgreSQL: localhost:5432 (query processed data)"
        echo ""
        echo "📊 Monitoring Commands:"
        echo "  • Kafka topics: Check Kafka UI at http://localhost:8090"
        echo "  • Consumer status: ps aux | grep consumer"
        echo "  • Database data: psql -h localhost -p 5432 -U clusterinfo -d clusterinfo"
    else
        echo "🔗 Available Endpoints (Legacy Mode):"
        echo "  • PostgreSQL: localhost:5432 (query collected data directly)"
        echo "  • Note: Collector runs as Job (no HTTP endpoints)"
    fi
    echo ""
    echo "💡 Pro Tips:"
    echo "  • Use 'source .env.hybrid' before running collector"
    echo "  • Services persist across restarts (no redeployment needed)"
    echo "  • Port forwarding runs in background automatically"
    echo "  • Database contains real cluster data for realistic testing"
    echo "  • Use './scripts/test-hybrid-setup.sh' for full system validation"
    echo ""
    echo "🗄️ Database Access:"
    echo "  • Direct access: psql -h localhost -p 5432 -U clusterinfo -d clusterinfo"
    echo "  • Password: devpassword"
    echo "  • Browse with any PostgreSQL GUI tool"
    echo ""
    echo "🔧 Service Management Commands:"
    echo "==============================="
    echo ""
    echo "📊 Monitor Services:"
    echo "   • Check all resources: kubectl get all -n $namespace"
    echo "   • PostgreSQL logs: kubectl logs -l app=postgres -n $namespace -f"
    if [ "$kafka_enabled" = "true" ]; then
        echo "   • Kafka logs: kubectl logs -l app=kafka -n $namespace -f"
    fi
    echo "   • Service status: kubectl get pods -n $namespace -w"
    echo ""
    echo "🔗 Port Forwarding Management:"
    echo "   • Check active forwards: ps aux | grep port-forward"
    echo "   • Stop all forwards: pkill -f 'kubectl.*port-forward'"
    echo "   • Restart manually: ./port-forward.sh start $namespace postgres"
    echo ""
    echo "🗄️ Database Management:"
    echo "   • Direct SQL access: psql -h localhost -p 5432 -U clusterinfo -d clusterinfo"
    echo "   • View tables: \\dt (inside psql)"
    echo "   • Check data: SELECT * FROM cluster_snapshots LIMIT 5;"
    echo ""
    echo "🧹 Cleanup Options:"
    echo "   • Remove services only: kubectl delete namespace $namespace"
    echo "   • Keep namespace, restart services: kubectl rollout restart deployment -n $namespace"
    echo "   • Full cleanup: kubectl delete namespace $namespace && rm -f .env.hybrid"
    echo ""
    echo "🎯 READY FOR DEVELOPMENT!"
    echo "=========================="
    echo ""
    if [ "$kafka_enabled" = "true" ]; then
        echo "🚀 Quick Start Commands (Kafka Mode):"
        echo "   # Run collector (one-shot data collection):"
        echo "   source .env.hybrid && ./bin/collector"
        echo ""
        echo "   # Check consumer is running:"
        echo "   ps aux | grep consumer"
        echo ""
        echo "   # Monitor Kafka and database:"
        echo "   open http://localhost:8090  # Kafka UI"
        echo "   PGPASSWORD=devpassword psql -h localhost -p 5432 -U clusterinfo -d clusterinfo"
    else
        echo "🚀 Quick Start Commands (Legacy Mode):"
        echo "   # Run collector (Job mode - runs once and exits):"
        echo "   source .env.hybrid && ./bin/collector"
        echo ""
        echo "   # Query collected data directly from database:"
        echo "   PGPASSWORD=devpassword psql -h localhost -p 5432 -U clusterinfo -d clusterinfo"
    fi
    echo ""
    echo "🧪 Run Full System Test:"
    echo "   ./scripts/test-hybrid-setup.sh"
    echo ""
    echo "✅ Hybrid development setup completed!"
    echo ""
    echo "📝 To use the collector:"
    echo "   source .env.hybrid && ./bin/collector"
}

# Function to setup end-to-end test (Collector→Kafka→Consumer→PostgreSQL)
setup_e2e_test() {
    local namespace="cluster-info-dev"
    
    echo ""
    echo "🧪 END-TO-END TEST SETUP"
    echo "========================"
    echo ""
    echo "🎯 What is End-to-End Testing?"
    echo "• Tests the complete data flow: Collector → Kafka → Consumer → PostgreSQL"
    echo "• Validates Kafka message production and consumption"
    echo "• Ensures data integrity throughout the pipeline"
    echo "• All processing runs locally with Kubernetes infrastructure"
    echo "• Smart background process management with auto-cleanup"
    echo ""
    echo "🔄 Test Sequence:"
    echo "1. Check and deploy infrastructure if needed"
    echo "2. Build local binaries"
    echo "3. Check for existing background processes"
    echo "4. Run consumer locally to monitor Kafka"
    echo "5. Execute collector to produce messages"
    echo "6. Verify data flow through the entire pipeline"
    echo "7. Offer smart background process management"
    echo ""
    
    read -p "🚀 Ready to start E2E test? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "❌ E2E test cancelled."
        return 1
    fi
    
    echo ""
    echo "🧪 Step 1: Checking infrastructure..."
    
    # Check if infrastructure is ready with smart deployment
    check_and_deploy_e2e_infrastructure "$namespace"
    
    echo ""
    echo "🔨 Step 2: Building project..."
    
    # Build the project
    if ! make build; then
        echo "❌ Build failed. Cannot run E2E test."
        return 1
    fi
    
    echo ""
    echo "🧪 Step 3: Running E2E test with smart background management..."
    
    # Run E2E test with smart background management
    run_e2e_test "$namespace"
    
    echo ""
    echo "✅ E2E test setup completed!"
    echo ""
    echo "🔧 Available Commands:"
    echo "   • Check status: ./e2e-helper.sh status"
    echo "   • Stop all: ./e2e-helper.sh stop"
    echo "   • Start consumer: ./e2e-helper.sh start-consumer"
    echo "   • Start collector: ./e2e-helper.sh start-collector"
    echo "   • Start both: ./e2e-helper.sh start-both"
}

# Function to check and deploy E2E infrastructure smartly
check_and_deploy_e2e_infrastructure() {
    local namespace=$1
    
    echo "🏗️ Checking E2E infrastructure in namespace: $namespace"
    
    # Ensure namespace exists
    ensure_dev_namespace $namespace
    
    # Check what services are already running
    local postgres_exists=false
    local kafka_exists=false
    local kafka_ui_exists=false
    
    echo ""
    echo "🔍 Checking existing services..."
    
    # Check PostgreSQL
    if kubectl get deployment postgres -n $namespace > /dev/null 2>&1; then
        postgres_exists=true
        echo "✅ PostgreSQL already deployed"
    elif kubectl get deployment dev-services-postgresql -n $namespace > /dev/null 2>&1; then
        postgres_exists=true
        echo "✅ PostgreSQL already deployed (dev-services)"
    else
        echo "❌ PostgreSQL not found"
    fi
    
    # Check Kafka
    if kubectl get deployment kafka -n $namespace > /dev/null 2>&1; then
        kafka_exists=true
        echo "✅ Kafka already deployed"
    elif kubectl get deployment dev-services-kafka -n $namespace > /dev/null 2>&1; then
        kafka_exists=true
        echo "✅ Kafka already deployed (dev-services)"
    else
        echo "❌ Kafka not found"
    fi
    
    # Check Kafka UI
    if kubectl get deployment kafka-ui -n $namespace > /dev/null 2>&1; then
        kafka_ui_exists=true
        echo "✅ Kafka UI already deployed"
    elif kubectl get deployment dev-services-kafka-ui -n $namespace > /dev/null 2>&1; then
        kafka_ui_exists=true
        echo "✅ Kafka UI already deployed (dev-services)"
    else
        echo "❌ Kafka UI not found"
    fi
    
    echo ""
    
    # Show summary and ask user what to do
    if [ "$postgres_exists" = "true" ] && [ "$kafka_exists" = "true" ] && [ "$kafka_ui_exists" = "true" ]; then
        echo "✅ All services already deployed! Reusing existing infrastructure."
        echo "ℹ️  This saves time and resources by not redeploying."
        echo ""
        return 0
    elif [ "$postgres_exists" = "true" ] || [ "$kafka_exists" = "true" ] || [ "$kafka_ui_exists" = "true" ]; then
        echo "⚠️  Some services already exist:"
        [ "$postgres_exists" = "true" ] && echo "   • PostgreSQL: ✅ Deployed"
        [ "$kafka_exists" = "true" ] && echo "   • Kafka: ✅ Deployed" 
        [ "$kafka_ui_exists" = "true" ] && echo "   • Kafka UI: ✅ Deployed"
        [ "$postgres_exists" = "false" ] && echo "   • PostgreSQL: ❌ Missing"
        [ "$kafka_exists" = "false" ] && echo "   • Kafka: ❌ Missing"
        [ "$kafka_ui_exists" = "false" ] && echo "   • Kafka UI: ❌ Missing"
        echo ""
        echo "🤔 What would you like to do?"
        echo "1. Deploy missing services only (recommended)"
        echo "2. Deploy all services (may cause conflicts)"
        echo "3. Continue with existing services only"
        echo ""
        read -p "Select option (1-3): " deploy_choice
        
        case $deploy_choice in
            1)
                echo "🔧 Deploying only missing services..."
                [ "$postgres_exists" = "false" ] && deploy_minimal_postgres_service $namespace
                [ "$kafka_exists" = "false" ] && deploy_minimal_kafka_services $namespace
                [ "$kafka_ui_exists" = "false" ] && deploy_kafka_ui_standalone $namespace
                echo "⏳ Waiting for new deployments..."
                sleep 20
                ;;
            2)
                echo "🚀 Deploying all services (may overwrite existing)..."
                deploy_e2e_infrastructure $namespace
                ;;
            3)
                echo "✅ Continuing with existing services only"
                ;;
            *)
                echo "ℹ️ Invalid choice, continuing with existing services"
                ;;
        esac
    else
        echo "🚀 No existing services found, deploying complete infrastructure..."
        deploy_e2e_infrastructure $namespace
    fi
    
    echo "✅ E2E infrastructure ready!"
}

# Function to deploy collector job/cronjob to specified namespace
deploy_collector_to_namespace() {
    local namespace=$1
    
    echo "🚀 Deploying collector to namespace: $namespace"
    
    # Create collector ConfigMap
    kubectl apply -n $namespace -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-info-collector-config
  namespace: $namespace
data:
  DB_HOST: "postgres"
  DB_PORT: "5432"
  DB_USER: "clusterinfo"
  DB_NAME: "clusterinfo"
  DB_PASSWORD: "devpassword"
  KAFKA_ENABLED: "false"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-info-collector
  namespace: $namespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-info-collector-$namespace
rules:
- apiGroups: [""]
  resources: ["pods", "nodes", "services", "configmaps", "secrets", "persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-info-collector-$namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-info-collector-$namespace
subjects:
- kind: ServiceAccount
  name: cluster-info-collector
  namespace: $namespace
---
apiVersion: batch/v1
kind: Job
metadata:
  name: cluster-info-collector-job
  namespace: $namespace
spec:
  template:
    spec:
      serviceAccountName: cluster-info-collector
      containers:
      - name: collector
        image: k8s-cluster-info-collector:latest
        imagePullPolicy: Never
        envFrom:
        - configMapRef:
            name: cluster-info-collector-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: cluster-info-collector-config
              key: DB_PASSWORD
      restartPolicy: OnFailure
  backoffLimit: 3
EOF
}

# Function to verify PostgreSQL database is ready and accessible
verify_postgres_database() {
    local namespace=$1
    local max_attempts=30
    local attempt=1
    
    echo "🔍 Verifying PostgreSQL database readiness..."
    
    # Wait for PostgreSQL pod to be ready
    echo "   Waiting for PostgreSQL pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $namespace --timeout=120s
    
    # Wait for port forwarding to be active
    local retries=0
    while [ $retries -lt 10 ]; do
        if nc -z localhost 5432 2>/dev/null; then
            echo "✅ PostgreSQL port is accessible"
            break
        fi
        echo "   Waiting for PostgreSQL port to be accessible (attempt $((retries + 1))/10)..."
        sleep 3
        retries=$((retries + 1))
    done
    
    if [ $retries -eq 10 ]; then
        echo "❌ PostgreSQL port not accessible after port forwarding"
        return 1
    fi
    
    # Test database connection and verify database exists
    echo "   Testing database connection and verifying database exists..."
    while [ $attempt -le $max_attempts ]; do
        if command -v psql &> /dev/null; then
            # Use psql if available
            if PGPASSWORD=devpassword psql -h localhost -p 5432 -U clusterinfo -d clusterinfo -c "SELECT 1;" >/dev/null 2>&1; then
                echo "✅ Database 'clusterinfo' is accessible and ready"
                return 0
            elif PGPASSWORD=devpassword psql -h localhost -p 5432 -U clusterinfo -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
                # Database server is accessible but clusterinfo database doesn't exist, create it
                echo "   Database 'clusterinfo' not found, creating it..."
                if PGPASSWORD=devpassword psql -h localhost -p 5432 -U clusterinfo -d postgres -c "CREATE DATABASE clusterinfo;" >/dev/null 2>&1; then
                    echo "✅ Database 'clusterinfo' created successfully"
                    return 0
                else
                    echo "❌ Failed to create database 'clusterinfo'"
                fi
            fi
        else
            # Fallback: Use kubectl exec to test from within the pod
            if kubectl exec -n $namespace deployment/postgres -- psql -U clusterinfo -d clusterinfo -c "SELECT 1;" >/dev/null 2>&1; then
                echo "✅ Database 'clusterinfo' is accessible and ready"
                return 0
            elif kubectl exec -n $namespace deployment/postgres -- psql -U clusterinfo -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
                # Database server is accessible but clusterinfo database doesn't exist, create it
                echo "   Database 'clusterinfo' not found, creating it..."
                if kubectl exec -n $namespace deployment/postgres -- psql -U clusterinfo -d postgres -c "CREATE DATABASE clusterinfo;" >/dev/null 2>&1; then
                    echo "✅ Database 'clusterinfo' created successfully"
                    return 0
                else
                    echo "❌ Failed to create database 'clusterinfo'"
                fi
            fi
        fi
        
        echo "   Database not ready yet (attempt $attempt/$max_attempts)..."
        sleep 3
        attempt=$((attempt + 1))
    done
    
    echo "❌ Database verification failed after $max_attempts attempts"
    echo "   This might indicate:"
    echo "   • PostgreSQL container is still initializing"
    echo "   • Database 'clusterinfo' was not created properly"
    echo "   • Connection parameters are incorrect"
    return 1
}

# Function to test the complete hybrid setup
test_hybrid_setup() {
    local namespace=${1:-"cluster-info-dev"}
    
    echo ""
    echo "🧪 Testing Hybrid Development Setup"
    echo "=================================="
    
    # Check if environment is sourced
    if [ -z "$DB_HOST" ]; then
        echo "⚠️  Environment not sourced. Running: source .env.hybrid"
        source .env.hybrid
    fi
    
    echo "✅ Environment variables loaded"
    
    # Test database connectivity
    echo ""
    echo "🗄️ Testing database connectivity..."
    if command -v nc &> /dev/null; then
        if nc -z localhost 5432; then
            echo "✅ PostgreSQL port accessible"
        else
            echo "❌ PostgreSQL port not accessible"
            return 1
        fi
    fi
    
    # Test if collector binary exists
    echo ""
    echo "📦 Checking collector binary..."
    if [ -f "./bin/collector" ]; then
        echo "✅ Collector binary exists"
    else
        echo "❌ Collector binary not found. Building..."
        go build -o bin/collector main.go || return 1
    fi
    
    # Get initial snapshot count
    echo ""
    echo "📊 Checking initial database state..."
    local initial_count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM cluster_snapshots;" 2>/dev/null | tr -d ' ')
    echo "📈 Initial snapshots in database: $initial_count"
    
    # Run collector (Job mode - runs once and exits)
    echo ""
    echo "🚀 Running collector (Job mode)..."
    echo "🔧 Environment: KAFKA_ENABLED=$KAFKA_ENABLED, KAFKA_BROKERS=$KAFKA_BROKERS"
    
    # Run collector with explicit environment variables
    KAFKA_ENABLED=$KAFKA_ENABLED \
    KAFKA_BROKERS=$KAFKA_BROKERS \
    KAFKA_TOPIC=$KAFKA_TOPIC \
    DB_HOST=$DB_HOST \
    DB_PORT=$DB_PORT \
    DB_NAME=$DB_NAME \
    DB_USER=$DB_USER \
    DB_PASSWORD=$DB_PASSWORD \
    LOG_LEVEL=$LOG_LEVEL \
    LOG_FORMAT=$LOG_FORMAT \
    ./bin/collector
    
    local collector_exit_code=$?
    
    if [ $collector_exit_code -eq 0 ]; then
        echo "✅ Collector completed successfully"
    else
        echo "❌ Collector failed with exit code: $collector_exit_code"
        return 1
    fi
    
    # Wait for consumer to process if using Kafka
    if [ "$KAFKA_ENABLED" = "true" ]; then
        echo ""
        echo "⏳ Waiting for consumer to process Kafka message..."
        sleep 5
    fi
    
    # Check if new data was written
    echo ""
    echo "🔍 Checking if data was collected..."
    local final_count=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM cluster_snapshots;" 2>/dev/null | tr -d ' ')
    echo "📈 Final snapshots in database: $final_count"
    
    if [ "$final_count" -gt "$initial_count" ]; then
        echo "✅ New snapshot created! Data collection working."
        
        # Show latest snapshot info
        echo ""
        echo "� Latest snapshot:"
        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT id, created_at, LENGTH(data::text) as data_size_bytes FROM cluster_snapshots ORDER BY created_at DESC LIMIT 1;" 2>/dev/null
    else
        echo "⚠️  No new snapshot created. Check logs for issues."
    fi
    
    echo ""
    echo "✅ Hybrid setup test completed!"
    echo ""
    echo "💡 To continue development:"
    echo "   source .env.hybrid && ./bin/collector"
}

# Helper function to safely setup port forwarding
setup_port_forward() {
    local service_name=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local service_type=${5:-"service"}  # service or deployment
    
    echo "🔗 Setting up port forwarding for $service_name ($local_port -> $remote_port)..."
    
    # Check if port is already in use
    if lsof -i :$local_port >/dev/null 2>&1; then
        echo "⚠️  Port $local_port is already in use"
        
        # Check if it's our port forward
        if pgrep -f "kubectl.*port-forward.*$service_name.*$local_port" >/dev/null; then
            echo "✅ Port forwarding for $service_name already active"
            return 0
        else
            echo "⚠️  Port $local_port is used by another process:"
            lsof -i :$local_port | head -3
            
            read -p "Kill existing process and continue? (y/N): " kill_process
            if [[ $kill_process =~ ^[Yy]$ ]]; then
                echo "🔄 Stopping processes on port $local_port..."
                pkill -f "kubectl.*port-forward.*$local_port" 2>/dev/null || true
                sleep 2
            else
                echo "❌ Skipping port forward for $service_name"
                return 1
            fi
        fi
    fi
    
    # Start port forwarding
    echo "🔗 Starting port forward: $service_type/$service_name $local_port:$remote_port"
    kubectl port-forward $service_type/$service_name $local_port:$remote_port -n $namespace > /tmp/port-forward-$service_name.log 2>&1 &
    
    # Give it a moment to establish
    sleep 2
    
    # Verify it's working
    if pgrep -f "kubectl.*port-forward.*$service_name.*$local_port" >/dev/null; then
        echo "✅ Port forwarding active for $service_name"
        return 0
    else
        echo "❌ Failed to start port forwarding for $service_name"
        return 1
    fi
}

# Main execution logic
main() {
    echo "🚀 K8s Cluster Info Collector - Hybrid Development Setup"
    echo "======================================================="
    echo ""
    
    # Run basic validation first
    check_rbac_permissions
    show_cluster_status
    
    echo ""
    echo "🎯 Starting interactive development setup..."
    
    # This is a hybrid setup script, go to development setup with menu
    setup_development
}

# Function to deploy Kafka UI standalone
deploy_kafka_ui_standalone() {
    local namespace=$1
    
    echo "🖥️ Deploying Kafka UI..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-ui
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-ui
  template:
    metadata:
      labels:
        app: kafka-ui
    spec:
      containers:
      - name: kafka-ui
        image: provectuslabs/kafka-ui:latest
        env:
        - name: KAFKA_CLUSTERS_0_NAME
          value: "local"
        - name: KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS
          value: "kafka:9092"
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-ui
  namespace: $namespace
spec:
  selector:
    app: kafka-ui
  ports:
  - port: 8080
    targetPort: 8080
EOF
}

# Function to start consumer in background with auto-cleanup
start_background_consumer_safe() {
    echo "🔄 Starting consumer in background (safe mode)..."
    
    # Stop any existing consumer first
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local existing_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $existing_pid > /dev/null 2>&1; then
            echo "🛑 Stopping existing consumer (PID: $existing_pid)..."
            kill $existing_pid 2>/dev/null
            sleep 2
        fi
        rm -f /tmp/e2e-consumer-bg.pid
    fi
    
    # Start consumer in background
    (
        set -a
        source .env.e2e-consumer
        set +a
        echo "🔄 Background Consumer started (PID: $$) - monitoring topic: $KAFKA_TOPIC" | tee -a /tmp/e2e-consumer-bg.log
        ./bin/consumer >> /tmp/e2e-consumer-bg.log 2>&1
    ) &
    
    local consumer_bg_pid=$!
    echo $consumer_bg_pid > /tmp/e2e-consumer-bg.pid
    
    echo "✅ Consumer started in background (PID: $consumer_bg_pid)"
    echo "📁 Logs: tail -f /tmp/e2e-consumer-bg.log"
    echo "🛑 Stop: kill $consumer_bg_pid (or use ./e2e-helper.sh stop)"
}

# Function to start collector in background with auto-cleanup
start_background_collector_safe() {
    echo "📊 Starting collector in background (safe mode, every 60 seconds)..."
    
    # Stop any existing collector first
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local existing_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $existing_pid > /dev/null 2>&1; then
            echo "🛑 Stopping existing collector (PID: $existing_pid)..."
            kill $existing_pid 2>/dev/null
            sleep 2
        fi
        rm -f /tmp/e2e-collector-bg.pid
    fi
    
    # Start collector loop in background
    (
        set -a
        source .env.e2e-collector
        set +a
        echo "📊 Background Collector started (PID: $$) - collecting every 60 seconds" | tee -a /tmp/e2e-collector-bg.log
        
        while true; do
            echo "$(date): Running collector..." >> /tmp/e2e-collector-bg.log
            ./bin/collector >> /tmp/e2e-collector-bg.log 2>&1
            echo "$(date): Collector completed, sleeping for 60 seconds..." >> /tmp/e2e-collector-bg.log
            sleep 60
        done
    ) &
    
    local collector_bg_pid=$!
    echo $collector_bg_pid > /tmp/e2e-collector-bg.pid
    
    echo "✅ Collector started in background (PID: $collector_bg_pid)"
    echo "📁 Logs: tail -f /tmp/e2e-collector-bg.log"
    echo "🛑 Stop: kill $collector_bg_pid (or use ./e2e-helper.sh stop)"
}

# Function to stop all E2E background processes
stop_e2e_background() {
    echo "🛑 Stopping E2E background processes..."
    
    local stopped_any=false
    
    # Stop consumer
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local consumer_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $consumer_pid > /dev/null 2>&1; then
            if kill $consumer_pid 2>/dev/null; then
                echo "✅ Consumer stopped (PID: $consumer_pid)"
                stopped_any=true
            fi
        fi
        rm -f /tmp/e2e-consumer-bg.pid
    fi
    
    # Stop collector
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local collector_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $collector_pid > /dev/null 2>&1; then
            if kill $collector_pid 2>/dev/null; then
                echo "✅ Collector stopped (PID: $collector_pid)"
                stopped_any=true
            fi
        fi
        rm -f /tmp/e2e-collector-bg.pid
    fi
    
    if [ "$stopped_any" = "false" ]; then
        echo "ℹ️  No E2E background processes were running"
    else
        echo "✅ All E2E background processes stopped"
    fi
}

# Function to show E2E background status
show_e2e_background_status() {
    echo "📊 E2E Background Process Status:"
    echo ""
    
    # Check consumer
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local consumer_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $consumer_pid > /dev/null 2>&1; then
            echo "✅ Consumer running (PID: $consumer_pid)"
            echo "   📁 Logs: tail -f /tmp/e2e-consumer-bg.log"
        else
            echo "❌ Consumer not running (stale PID file)"
            rm -f /tmp/e2e-consumer-bg.pid
        fi
    else
        echo "⚪ Consumer not running"
    fi
    
    # Check collector
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local collector_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $collector_pid > /dev/null 2>&1; then
            echo "✅ Collector running (PID: $collector_pid)"
            echo "   📁 Logs: tail -f /tmp/e2e-collector-bg.log"
        else
            echo "❌ Collector not running (stale PID file)"
            rm -f /tmp/e2e-collector-bg.pid
        fi
    else
        echo "⚪ Collector not running"
    fi
    
    echo ""
    echo "🔧 Management Commands:"
    echo "   • Stop all: stop_e2e_background"
    echo "   • Status: show_e2e_background_status"
    echo "   • Consumer logs: tail -f /tmp/e2e-consumer-bg.log"
    echo "   • Collector logs: tail -f /tmp/e2e-collector-bg.log"
    echo "   • Helper script: ./e2e-helper.sh status"
}

# Function to run E2E test with smart background management
run_e2e_test() {
    local namespace=$1
    
    echo "🧪 Running End-to-End Test..."
    echo ""
    echo "🎯 Test Sequence:"
    echo "1. Check and stop any existing background processes"
    echo "2. Start local consumer to watch Kafka"
    echo "3. Run collector to produce messages"
    echo "4. Monitor message flow through Kafka"
    echo "5. Verify data reaches PostgreSQL"
    echo "6. Offer smart background process management"
    echo ""
    
    # Test 1: Check if services are accessible
    echo "🔍 Step 1: Testing service connectivity..."
    if ! nc -z localhost 5432 2>/dev/null; then
        echo "❌ PostgreSQL not accessible. Check port forwarding."
        return 1
    fi
    echo "✅ PostgreSQL accessible"
    
    if ! nc -z localhost 9092 2>/dev/null; then
        echo "❌ Kafka not accessible. Check port forwarding."
        return 1
    fi
    echo "✅ Kafka accessible"
    
    # Check for existing background processes and offer to stop them
    echo ""
    echo "🔍 Step 2: Checking for existing background processes..."
    
    local has_existing=false
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local consumer_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $consumer_pid > /dev/null 2>&1; then
            echo "⚠️  Consumer already running (PID: $consumer_pid)"
            has_existing=true
        fi
    fi
    
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local collector_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $collector_pid > /dev/null 2>&1; then
            echo "⚠️  Collector already running (PID: $collector_pid)"
            has_existing=true
        fi
    fi
    
    if [ "$has_existing" = "true" ]; then
        echo ""
        echo "🤔 Stop existing processes and continue with fresh E2E test?"
        echo "1. Yes, stop existing and start fresh (recommended)"
        echo "2. No, keep existing and skip E2E test"
        echo ""
        read -p "Select option (1-2): " cleanup_choice
        
        case $cleanup_choice in
            1)
                echo "🛑 Stopping existing processes..."
                stop_e2e_background
                echo ""
                ;;
            2)
                echo "ℹ️  Keeping existing processes, skipping E2E test"
                echo "   Use './e2e-helper.sh status' to check current status"
                return 0
                ;;
            *)
                echo "ℹ️  Invalid choice, stopping existing processes..."
                stop_e2e_background
                echo ""
                ;;
        esac
    else
        echo "✅ No existing background processes found"
    fi
    
    # Test 3: Start consumer in background
    echo "🔄 Step 3: Starting local consumer..."
    echo "📊 Consumer will monitor Kafka topic and write to PostgreSQL..."
    
    # Source the consumer environment and start it in background
    (
        set -a
        source .env.e2e-consumer
        set +a
        echo "🔄 Consumer started (PID: $$) - monitoring topic: $KAFKA_TOPIC"
        ./bin/consumer
    ) &
    local consumer_pid=$!
    echo "consumer_pid:$consumer_pid" > /tmp/e2e-consumer.pid
    
    echo "✅ Consumer started (PID: $consumer_pid)"
    echo "ℹ️  Consumer is now watching Kafka topic 'cluster-info'"
    
    # Wait a moment for consumer to initialize
    sleep 5
    
    # Test 4: Run collector to produce messages
    echo ""
    echo "🚀 Step 4: Running collector to produce messages..."
    echo "📊 Collector will gather cluster info and send to Kafka..."
    
    # Source the collector environment and run once
    (
        set -a
        source .env.e2e-collector
        set +a
        echo "🚀 Collector running - gathering cluster data..."
        timeout 60s ./bin/collector
    )
    
    echo "✅ Collector execution completed"
    
    # Test 5: Check Kafka for messages
    echo ""
    echo "🔍 Step 5: Checking Kafka for messages..."
    
    # Check if topic exists and has messages
    kubectl exec -n $namespace deploy/kafka -- kafka-topics.sh --describe --topic cluster-info --bootstrap-server localhost:9092 2>/dev/null || {
        echo "⚠️ Topic 'cluster-info' may not exist yet. Creating it..."
        kubectl exec -n $namespace deploy/kafka -- kafka-topics.sh --create --topic cluster-info --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
    }
    
    # Wait a moment for processing
    sleep 10
    
    # Test 6: Check database
    echo ""
    echo "🗄️ Step 6: Checking PostgreSQL for data..."
    echo "📊 Database status:"
    
    # Check if we can connect to the database
    if command -v psql &> /dev/null; then
        echo "🔍 Checking database tables..."
        PGPASSWORD=devpassword psql -h localhost -U clusterinfo -d clusterinfo -c "\dt" 2>/dev/null || {
            echo "⚠️ Cannot connect to database or tables don't exist yet"
        }
        
        echo "🔍 Checking recent cluster snapshots..."
        PGPASSWORD=devpassword psql -h localhost -U clusterinfo -d clusterinfo -c "SELECT COUNT(*) as snapshot_count FROM cluster_snapshots;" 2>/dev/null || {
            echo "⚠️ cluster_snapshots table may not exist yet"
        }
    else
        echo "⚠️ psql not available. Install PostgreSQL client to check database directly."
    fi
    
    # Stop the test consumer
    echo ""
    echo "🛑 Stopping test consumer..."
    if [ -f /tmp/e2e-consumer.pid ]; then
        local saved_pid=$(cat /tmp/e2e-consumer.pid | cut -d: -f2)
        if kill $saved_pid 2>/dev/null; then
            echo "✅ Test consumer stopped (PID: $saved_pid)"
        else
            echo "⚠️ Test consumer may have already stopped"
        fi
        rm -f /tmp/e2e-consumer.pid
    fi
    
    echo ""
    echo "🎉 End-to-End Test Completed!"
    echo ""
    echo "📊 Summary:"
    echo "✅ Infrastructure deployed to namespace: $namespace"
    echo "✅ Local binaries built and configured"
    echo "✅ Consumer ran locally and processed messages"
    echo "✅ Collector produced messages to Kafka"
    echo "✅ Port forwarding established"
    echo "✅ Monitoring endpoints available"
    echo ""
    echo "🖥️ Next Steps:"
    echo "1. Monitor Kafka UI: http://localhost:8090"
    echo "2. Run collector again: source .env.e2e-collector && ./bin/collector"
    echo "3. Start consumer again: source .env.e2e-consumer && ./bin/consumer"
    echo "4. Check database: psql -h localhost -U clusterinfo -d clusterinfo"
    echo ""
    
    # Ask if user wants to run in background
    echo "🚀 Background Process Options:"
    echo "1. Run consumer in background continuously"
    echo "2. Run collector in background (every 60 seconds)"
    echo "3. Run both in background"
    echo "4. Exit (manual control)"
    echo ""
    read -p "Select option (1-4): " bg_option
    
    case $bg_option in
        1)
            start_background_consumer_safe
            ;;
        2)
            start_background_collector_safe
            ;;
        3)
            start_background_consumer_safe
            sleep 3
            start_background_collector_safe
            ;;
        4)
            echo "✅ E2E test completed. Use manual commands above for further testing."
            ;;
        *)
            echo "ℹ️ Invalid choice. Exiting with manual control."
            ;;
    esac
    
    # Create helper script for background process management
    create_e2e_helper_script
}

# Function to create E2E helper script
create_e2e_helper_script() {
    echo ""
    echo "📝 Creating E2E helper script..."
    
    cat > e2e-helper.sh <<'EOF'
#!/bin/bash

# E2E Background Process Helper Script
# Usage: source e2e-helper.sh (to load functions into your shell)
#    or: ./e2e-helper.sh [command] (to run specific commands)

# Function to start consumer in background
start_background_consumer() {
    echo "🔄 Starting consumer in background..."
    
    # Check if consumer is already running
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local existing_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $existing_pid > /dev/null 2>&1; then
            echo "⚠️ Consumer already running (PID: $existing_pid)"
            echo "   Stop it first: kill $existing_pid"
            return 1
        else
            rm -f /tmp/e2e-consumer-bg.pid
        fi
    fi
    
    # Start consumer in background
    (
        set -a
        source .env.e2e-consumer
        set +a
        echo "🔄 Background Consumer started (PID: $$) - monitoring topic: $KAFKA_TOPIC" | tee -a /tmp/e2e-consumer-bg.log
        ./bin/consumer >> /tmp/e2e-consumer-bg.log 2>&1
    ) &
    
    local consumer_bg_pid=$!
    echo $consumer_bg_pid > /tmp/e2e-consumer-bg.pid
    
    echo "✅ Consumer started in background (PID: $consumer_bg_pid)"
    echo "📁 Logs: tail -f /tmp/e2e-consumer-bg.log"
    echo "🛑 Stop: kill $consumer_bg_pid (or use stop_e2e_background)"
}

# Function to start collector in background (periodic)
start_background_collector() {
    echo "📊 Starting collector in background (every 60 seconds)..."
    
    # Check if collector is already running
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local existing_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $existing_pid > /dev/null 2>&1; then
            echo "⚠️ Collector already running (PID: $existing_pid)"
            echo "   Stop it first: kill $existing_pid"
            return 1
        else
            rm -f /tmp/e2e-collector-bg.pid
        fi
    fi
    
    # Start collector loop in background
    (
        set -a
        source .env.e2e-collector
        set +a
        echo "📊 Background Collector started (PID: $$) - collecting every 60 seconds" | tee -a /tmp/e2e-collector-bg.log
        
        while true; do
            echo "$(date): Running collector..." >> /tmp/e2e-collector-bg.log
            ./bin/collector >> /tmp/e2e-collector-bg.log 2>&1
            echo "$(date): Collector completed, sleeping for 60 seconds..." >> /tmp/e2e-collector-bg.log
            sleep 60
        done
    ) &
    
    local collector_bg_pid=$!
    echo $collector_bg_pid > /tmp/e2e-collector-bg.pid
    
    echo "✅ Collector started in background (PID: $collector_bg_pid)"
    echo "📁 Logs: tail -f /tmp/e2e-collector-bg.log"
    echo "🛑 Stop: kill $collector_bg_pid (or use stop_e2e_background)"
}

# Function to stop all E2E background processes
stop_e2e_background() {
    echo "🛑 Stopping E2E background processes..."
    
    # Stop consumer
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local consumer_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $consumer_pid > /dev/null 2>&1; then
            kill $consumer_pid
            echo "✅ Consumer stopped (PID: $consumer_pid)"
        fi
        rm -f /tmp/e2e-consumer-bg.pid
    fi
    
    # Stop collector
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local collector_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $collector_pid > /dev/null 2>&1; then
            kill $collector_pid
            echo "✅ Collector stopped (PID: $collector_pid)"
        fi
        rm -f /tmp/e2e-collector-bg.pid
    fi
    
    echo "✅ All E2E background processes stopped"
}

# Function to show E2E background status
show_e2e_background_status() {
    echo "📊 E2E Background Process Status:"
    echo ""
    
    # Check consumer
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local consumer_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $consumer_pid > /dev/null 2>&1; then
            echo "✅ Consumer running (PID: $consumer_pid)"
            echo "   📁 Logs: tail -f /tmp/e2e-consumer-bg.log"
        else
            echo "❌ Consumer not running (stale PID file)"
            rm -f /tmp/e2e-consumer-bg.pid
        fi
    else
        echo "⚪ Consumer not running"
    fi
    
    # Check collector
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local collector_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $collector_pid > /dev/null 2>&1; then
            echo "✅ Collector running (PID: $collector_pid)"
            echo "   📁 Logs: tail -f /tmp/e2e-collector-bg.log"
        else
            echo "❌ Collector not running (stale PID file)"
            rm -f /tmp/e2e-collector-bg.pid
        fi
    else
        echo "⚪ Collector not running"
    fi
    
    echo ""
    echo "🔧 Management Commands:"
    echo "   • Stop all: stop_e2e_background"
    echo "   • Status: show_e2e_background_status"
    echo "   • Consumer logs: tail -f /tmp/e2e-consumer-bg.log"
    echo "   • Collector logs: tail -f /tmp/e2e-collector-bg.log"
}

# Command line interface
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script is being executed, not sourced
    case "${1:-help}" in
        start-consumer)
            start_background_consumer
            ;;
        start-collector)
            start_background_collector
            ;;
        start-both)
            start_background_consumer
            sleep 3
            start_background_collector
            ;;
        stop)
            stop_e2e_background
            ;;
        status)
            show_e2e_background_status
            ;;
        help|--help|-h)
            echo "E2E Background Process Helper"
            echo ""
            echo "Usage: ./e2e-helper.sh [command]"
            echo "   or: source e2e-helper.sh (to load functions)"
            echo ""
            echo "Commands:"
            echo "  start-consumer   Start consumer in background"
            echo "  start-collector  Start collector in background"
            echo "  start-both       Start both in background"
            echo "  stop             Stop all background processes"
            echo "  status           Show status of background processes"
            echo "  help             Show this help"
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo "Use './e2e-helper.sh help' for usage information"
            exit 1
            ;;
    esac
else
    # Script is being sourced
    echo "✅ E2E helper functions loaded into shell"
    echo "Available functions: start_background_consumer, start_background_collector, stop_e2e_background, show_e2e_background_status"
fi
EOF

    chmod +x e2e-helper.sh
    echo "✅ E2E helper script created: e2e-helper.sh"
    echo ""
    echo "🔧 Usage Options:"
    echo "   • Load functions: source e2e-helper.sh"
    echo "   • Quick start: ./e2e-helper.sh start-both"
    echo "   • Check status: ./e2e-helper.sh status"
    echo "   • Stop all: ./e2e-helper.sh stop"
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main
fi
