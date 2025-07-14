#!/bin/bash

# Script to test consumer health and metrics endpoints
echo "🔍 Consumer Health & Metrics Endpoint Test"
echo "=========================================="

# Default values
CONSUMER_HOST="localhost"
CONSUMER_PORT="8083"
NAMESPACE="cluster-info-dev"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --host HOST             Consumer host (default: localhost)"
    echo "  -p, --port PORT             Consumer port (default: 8083)"
    echo "  -n, --namespace NAMESPACE   Kubernetes namespace (default: cluster-info-dev)"
    echo "  --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          Test local consumer"
    echo "  $0 -p 8084                  Test consumer on different port"
    echo "  $0 --host consumer.example.com  Test remote consumer"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            CONSUMER_HOST="$2"
            shift 2
            ;;
        -p|--port)
            CONSUMER_PORT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

BASE_URL="http://${CONSUMER_HOST}:${CONSUMER_PORT}"

echo "🔧 Configuration:"
echo "   Consumer: ${BASE_URL}"
echo "   Namespace: ${NAMESPACE}"
echo ""

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local description=$2
    
    echo "🔍 Testing ${description}..."
    echo "   Endpoint: ${BASE_URL}${endpoint}"
    
    if curl -s -f "${BASE_URL}${endpoint}" >/dev/null 2>&1; then
        echo "✅ ${description} - Endpoint accessible"
        echo "📋 Response:"
        curl -s "${BASE_URL}${endpoint}" | jq '.' 2>/dev/null || curl -s "${BASE_URL}${endpoint}"
    else
        echo "❌ ${description} - Endpoint not accessible"
        echo "💡 Check if consumer is running with CONSUMER_SERVER_ENABLED=true"
    fi
    echo ""
}

# Test if consumer is reachable
echo "🏥 Testing Consumer Health & Metrics Endpoints"
echo "=============================================="

# Health endpoint
test_endpoint "/health" "Health Check"

# Metrics endpoint
test_endpoint "/metrics" "Metrics"

# Ready endpoint
test_endpoint "/ready" "Readiness Probe"

# Version endpoint
test_endpoint "/version" "Version Info"

echo "🎯 Consumer Endpoint Summary:"
echo "   • Health: ${BASE_URL}/health"
echo "   • Metrics: ${BASE_URL}/metrics"
echo "   • Ready: ${BASE_URL}/ready"
echo "   • Version: ${BASE_URL}/version"
echo ""

# If testing local consumer, provide quick start commands
if [ "$CONSUMER_HOST" = "localhost" ]; then
    echo "💡 Quick Start Commands:"
    echo "   # Start consumer with HTTP server:"
    echo "   export CONSUMER_SERVER_ENABLED=true"
    echo "   export CONSUMER_SERVER_PORT=8083"
    echo "   source .env.hybrid-consumer && ./bin/consumer"
    echo ""
    echo "   # Test endpoints:"
    echo "   curl ${BASE_URL}/health | jq"
    echo "   curl ${BASE_URL}/metrics | jq"
    echo ""
fi

# Kubernetes port forwarding instructions
echo "🔗 Kubernetes Port Forwarding:"
echo "   kubectl port-forward service/consumer 8083:8083 -n ${NAMESPACE}"
echo "   # Then test with: $0"
echo ""
