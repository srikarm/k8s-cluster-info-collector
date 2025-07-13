#!/bin/bash

# Kubernetes Cluster Info Collector v2.0 - API Test Script
# Tests the v2.0 API endpoints when the collector is running

set -e

echo "🧪 Kubernetes Cluster Info Collector v2.0 - API Testing"
echo "======================================================"

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8081/api/v1}"
METRICS_URL="${METRICS_URL:-http://localhost:8080/metrics}"
WS_URL="${WS_URL:-ws://localhost:8082/api/v1/ws}"

echo ""
echo "🔗 Testing against:"
echo "• API Base: $API_BASE_URL"
echo "• Metrics: $METRICS_URL"
echo "• WebSocket: $WS_URL"

# Function to test an endpoint
test_endpoint() {
    local endpoint="$1"
    local description="$2"
    local expected_status="${3:-200}"
    
    echo -n "Testing $description... "
    
    if command -v curl >/dev/null 2>&1; then
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE_URL$endpoint" 2>/dev/null || echo "000")
        
        if [ "$status_code" = "$expected_status" ]; then
            echo "✅ ($status_code)"
            return 0
        else
            echo "❌ ($status_code, expected $expected_status)"
            return 1
        fi
    else
        echo "⚠️  (curl not available)"
        return 1
    fi
}

# Function to test with response content
test_endpoint_with_content() {
    local endpoint="$1"
    local description="$2"
    
    echo "Testing $description..."
    
    if command -v curl >/dev/null 2>&1; then
        local response=$(curl -s "$API_BASE_URL$endpoint" 2>/dev/null || echo "ERROR")
        
        if [ "$response" != "ERROR" ] && [ -n "$response" ]; then
            echo "✅ Response received ($(echo "$response" | wc -c) bytes)"
            
            # Try to parse as JSON and show summary
            if command -v python3 >/dev/null 2>&1; then
                echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict):
        print(f'   📊 JSON keys: {list(data.keys())[:5]}')
        if 'snapshots' in data:
            print(f'   📅 Snapshots: {len(data[\"snapshots\"])}')
        elif 'deployments' in data:
            print(f'   🚀 Deployments: {len(data[\"deployments\"])}')
        elif 'pods' in data:
            print(f'   🏗️  Pods: {len(data[\"pods\"])}')
        elif 'status' in data:
            print(f'   ❤️  Health: {data[\"status\"]}')
except:
    print('   📄 Non-JSON response')
" 2>/dev/null || echo "   📄 Response format check skipped"
            fi
        else
            echo "❌ No response or error"
            return 1
        fi
    else
        echo "⚠️  curl not available"
        return 1
    fi
}

echo ""
echo "🏥 Health & Status Checks:"

# Test health endpoint
test_endpoint_with_content "/health" "Health Check"

echo ""
echo "📊 Snapshot Endpoints:"

# Test snapshots
test_endpoint "/snapshots" "List Snapshots"
test_endpoint "/snapshots/latest" "Latest Snapshot" "302"  # Should redirect

echo ""
echo "🎯 Resource Endpoints (9 Types in v2.0):"

# Test all v2.0 resource endpoints
RESOURCES=(
    "/deployments:Deployments"
    "/pods:Pods"
    "/nodes:Nodes"
    "/services:Services (v2.0)"
    "/ingresses:Ingresses (v2.0)"
    "/configmaps:ConfigMaps (v2.0)"
    "/secrets:Secrets (v2.0)"
    "/persistent-volumes:PersistentVolumes (v2.0)"
    "/persistent-volume-claims:PersistentVolumeClaims (v2.0)"
)

for resource in "${RESOURCES[@]}"; do
    endpoint="${resource%%:*}"
    description="${resource##*:}"
    test_endpoint "$endpoint" "$description"
done

echo ""
echo "📈 Statistics & Metrics:"

# Test statistics endpoints
test_endpoint "/stats" "General Statistics"
test_endpoint "/stats/retention" "Retention Statistics"

# Test v2.0 Kafka statistics
echo -n "Testing Kafka Statistics (v2.0)... "
kafka_response=$(curl -s "$API_BASE_URL/stats/kafka" 2>/dev/null || echo "ERROR")
if [ "$kafka_response" != "ERROR" ]; then
    if echo "$kafka_response" | grep -q "kafka_enabled"; then
        echo "✅ (Kafka stats available)"
    else
        echo "⚠️  (Kafka disabled or not configured)"
    fi
else
    echo "❌ (No response)"
fi

# Test Prometheus metrics
echo -n "Testing Prometheus Metrics... "
if curl -s "$METRICS_URL" | head -1 | grep -q "HELP\|TYPE" 2>/dev/null; then
    echo "✅ (Prometheus format detected)"
else
    echo "❌ (Not available or wrong format)"
fi

echo ""
echo "🌊 WebSocket Test:"

# Test WebSocket (basic connection test)
if command -v nc >/dev/null 2>&1; then
    echo -n "Testing WebSocket port... "
    if nc -z localhost 8082 2>/dev/null; then
        echo "✅ (Port 8082 is open)"
    else
        echo "❌ (Port 8082 not accessible)"
    fi
else
    echo "⚠️  WebSocket test skipped (netcat not available)"
fi

echo ""
echo "🔧 Manual Testing Commands:"
echo ""
echo "# Health check"
echo "curl $API_BASE_URL/health | jq ."
echo ""
echo "# Latest cluster snapshot"
echo "curl $API_BASE_URL/snapshots/latest | jq ."
echo ""
echo "# Kafka statistics (v2.0)"
echo "curl $API_BASE_URL/stats/kafka | jq ."
echo ""
echo "# Prometheus metrics"
echo "curl $METRICS_URL"
echo ""
echo "# List pods with filtering"
echo "curl '$API_BASE_URL/pods?limit=5&namespace=default' | jq ."
echo ""
echo "# WebSocket test (requires wscat: npm install -g wscat)"
echo "wscat -c $WS_URL"
echo ""
echo "📚 View API Documentation:"
echo "./scripts/view-api-docs.sh"
echo ""
echo "✅ API testing completed!"
echo ""
echo "💡 Tips:"
echo "• Use 'jq' for better JSON formatting"
echo "• Set environment variables to test different URLs:"
echo "  export API_BASE_URL=http://your-service:8081/api/v1"
echo "• Check logs: kubectl logs -f deployment/cluster-info-collector"
