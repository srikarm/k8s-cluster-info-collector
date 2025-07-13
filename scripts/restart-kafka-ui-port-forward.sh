#!/bin/bash

# Script to restart Kafka UI port forwarding with correct port mapping
echo "🔗 Restarting Kafka UI Port Forwarding"
echo "======================================"

NAMESPACE="cluster-info-dev"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-n NAMESPACE]"
            echo "Restarts Kafka UI port forwarding to use localhost:8090"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🔧 Configuration:"
echo "   Namespace: $NAMESPACE"
echo ""

# Kill existing Kafka UI port forwards
echo "🛑 Stopping existing Kafka UI port forwards..."
pkill -f "kubectl.*port-forward.*kafka-ui" 2>/dev/null || true
pkill -f "kubectl.*port-forward.*8080" 2>/dev/null || true
pkill -f "kubectl.*port-forward.*8090" 2>/dev/null || true

sleep 2

# Check if Kafka UI service exists
if ! kubectl get service kafka-ui -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Kafka UI service not found in namespace '$NAMESPACE'"
    echo "Available services:"
    kubectl get services -n "$NAMESPACE" -o name | sed 's/service\///' | sed 's/^/  /'
    exit 1
fi

echo "✅ Found Kafka UI service in namespace '$NAMESPACE'"

# Start new port forwarding: localhost:8090 -> kafka-ui:8080
echo "🔗 Starting Kafka UI port forwarding: localhost:8090 -> kafka-ui:8080"
kubectl port-forward service/kafka-ui 8090:8080 -n "$NAMESPACE" > /tmp/port-forward-kafka-ui.log 2>&1 &
pf_pid=$!

# Wait for port forward to establish
sleep 3

# Test connectivity
echo "🧪 Testing Kafka UI connectivity..."
if nc -z localhost 8090 2>/dev/null; then
    echo "✅ Kafka UI is accessible at http://localhost:8090"
    echo "📋 Port forwarding PID: $pf_pid"
    echo "📝 Log file: /tmp/port-forward-kafka-ui.log"
else
    echo "❌ Kafka UI not accessible on localhost:8090"
    echo "📋 Check logs: cat /tmp/port-forward-kafka-ui.log"
    exit 1
fi

echo ""
echo "🎉 Kafka UI port forwarding restarted successfully!"
echo ""
echo "🌐 Access Kafka UI: http://localhost:8090"
echo "🔍 Monitor logs: tail -f /tmp/port-forward-kafka-ui.log"
echo "🛑 Stop forwarding: pkill -f 'kubectl.*port-forward.*kafka-ui'"
echo ""
