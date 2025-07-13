#!/bin/bash

# Kubernetes Cluster Info Collector - Helm Deployment Script
set -e

CHART_NAME="cluster-info-collector"
CHART_PATH="helm/cluster-info-collector"
NAMESPACE="cluster-info"
RELEASE_NAME="my-cluster-info"

echo "🚀 Kubernetes Cluster Info Collector Helm Deployment"
echo "=================================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed or not in PATH"
    echo "Please install Helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -d "$CHART_PATH" ]; then
    echo "❌ Helm chart not found at $CHART_PATH"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Check current kubectl context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
echo "📋 Current kubectl context: $CURRENT_CONTEXT"

read -p "Do you want to continue with this context? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Validate Helm chart
echo "🔍 Validating Helm chart..."
if helm lint "$CHART_PATH"; then
    echo "✅ Helm chart validation passed"
else
    echo "❌ Helm chart validation failed"
    exit 1
fi

# Create namespace if it doesn't exist
echo "📁 Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Deploy with different configurations based on user choice
echo "🎯 Choose deployment configuration:"
echo "1) Development (minimal resources, local testing)"
echo "2) Production (full resources, external access)"
echo "3) External dependencies (use external Kafka/PostgreSQL)"
echo "4) Custom values file"
read -p "Enter choice (1-4): " -n 1 -r CHOICE
echo

case $CHOICE in
    1)
        echo "🔧 Deploying with development configuration..."
        helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --set collector.schedule="*/5 * * * *" \
            --set consumer.replicaCount=1 \
            --set consumer.autoscaling.enabled=false \
            --set postgresql.auth.password="devpassword" \
            --set postgresql.primary.persistence.size="1Gi" \
            --set kafka.persistence.size="1Gi" \
            --wait --timeout=300s
        ;;
    2)
        echo "🏭 Deploying with production configuration..."
        read -p "Enter PostgreSQL password: " -s DB_PASSWORD
        echo
        read -p "Enter ingress hostname (e.g., cluster-info.example.com): " HOSTNAME
        
        helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --set collector.schedule="0 */1 * * *" \
            --set consumer.replicaCount=3 \
            --set consumer.autoscaling.enabled=true \
            --set consumer.autoscaling.maxReplicas=10 \
            --set postgresql.auth.password="$DB_PASSWORD" \
            --set postgresql.primary.persistence.size="50Gi" \
            --set kafka.persistence.size="20Gi" \
            --set ingress.enabled=true \
            --set ingress.hosts[0].host="$HOSTNAME" \
            --set ingress.hosts[0].paths[0].path="/" \
            --set ingress.hosts[0].paths[0].pathType="Prefix" \
            --wait --timeout=600s
        ;;
    3)
        echo "🔗 Deploying with external dependencies..."
        read -p "Enter Kafka brokers (comma-separated): " KAFKA_BROKERS
        read -p "Enter PostgreSQL host: " DB_HOST
        read -p "Enter PostgreSQL password: " -s DB_PASSWORD
        echo
        
        helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --set kafka.enabled=false \
            --set kafka.external.enabled=true \
            --set kafka.external.brokers="$KAFKA_BROKERS" \
            --set postgresql.enabled=false \
            --set database.host="$DB_HOST" \
            --set database.password="$DB_PASSWORD" \
            --wait --timeout=300s
        ;;
    4)
        read -p "Enter path to values file: " VALUES_FILE
        if [ ! -f "$VALUES_FILE" ]; then
            echo "❌ Values file not found: $VALUES_FILE"
            exit 1
        fi
        
        echo "📄 Deploying with custom values file: $VALUES_FILE"
        helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --values "$VALUES_FILE" \
            --wait --timeout=600s
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo "✅ Deployment completed successfully!"

# Show deployment status
echo "📊 Deployment Status:"
echo "===================="
kubectl get all -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

echo ""
echo "📝 Useful Commands:"
echo "==================="
echo "View logs:"
echo "  kubectl logs -f deployment/$RELEASE_NAME-consumer -n $NAMESPACE"
echo ""
echo "Port forward API:"
echo "  kubectl port-forward service/$RELEASE_NAME 8080:8080 -n $NAMESPACE"
echo ""
echo "Access PostgreSQL:"
echo "  kubectl exec -it deployment/$RELEASE_NAME-postgresql -n $NAMESPACE -- psql -U clusterinfo -d clusterinfo"
echo ""
echo "Check HPA status:"
echo "  kubectl get hpa -n $NAMESPACE"
echo ""
echo "Uninstall:"
echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo "  kubectl delete namespace $NAMESPACE"

echo ""
echo "🎉 Deployment completed! Check the logs and services above."
