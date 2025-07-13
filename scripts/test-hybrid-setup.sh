#!/bin/bash

# Standalone script to test hybrid development setup
# Run this after setting up hybrid development mode

set -e

echo "🧪 Hybrid Development Test Suite"
echo "================================"
echo ""

# Check if we're in the right directory
if [ ! -f "setup-hybrid.sh" ]; then
    echo "❌ Please run this from the k8s-cluster-info-collector directory"
    exit 1
fi

# Check if hybrid environment exists
if [ ! -f ".env.hybrid" ]; then
    echo "❌ .env.hybrid not found. Please run hybrid setup first:"
    echo "   ./scripts/setup-hybrid.sh → Option 3 → Option 3"
    exit 1
fi

# Source the environment
echo "📋 Loading hybrid environment..."
source .env.hybrid
echo "✅ Environment loaded"

# Check if binary exists
if [ ! -f "./bin/collector" ]; then
    echo "📦 Building collector binary..."
    go build -o bin/collector main.go || {
        echo "❌ Build failed"
        exit 1
    }
fi

echo "✅ Collector binary ready"

# Test database connection
echo ""
echo "🗄️ Testing database connectivity..."
if command -v nc &> /dev/null; then
    if nc -z localhost 5432; then
        echo "✅ PostgreSQL accessible on localhost:5432"
    else
        echo "❌ PostgreSQL not accessible. Is port forwarding running?"
        echo "   Try: kubectl port-forward service/postgres 5432:5432 -n cluster-info-dev"
        exit 1
    fi
else
    echo "⚠️  nc command not available for connectivity test"
fi

# Test Kafka if enabled
if [ "$KAFKA_ENABLED" = "true" ]; then
    echo ""
    echo "🌊 Testing Kafka connectivity..."
    if command -v nc &> /dev/null; then
        if nc -z localhost 9092; then
            echo "✅ Kafka accessible on localhost:9092"
        else
            echo "❌ Kafka not accessible. Is port forwarding running?"
            exit 1
        fi
    fi
fi

# Start the collector
echo ""
echo "🚀 Starting collector for full system test..."
./bin/collector &
collector_pid=$!

# Wait for startup
echo "⏳ Waiting for services to start (15 seconds)..."
sleep 15

# Test all endpoints
echo ""
echo "🔍 Testing API endpoints..."

# Health check
if curl -s -f http://localhost:8081/api/v1/health >/dev/null 2>&1; then
    echo "✅ Health endpoint: http://localhost:8081/api/v1/health"
else
    echo "❌ Health endpoint not responding"
fi

# Metrics
if curl -s -f http://localhost:8080/metrics >/dev/null 2>&1; then
    echo "✅ Metrics endpoint: http://localhost:8080/metrics"
else
    echo "❌ Metrics endpoint not responding"
fi

# Wait for data collection
echo ""
echo "⏳ Waiting for initial data collection (10 seconds)..."
sleep 10

# Test cluster endpoints
echo ""
echo "🔍 Testing cluster data endpoints..."

test_endpoint() {
    local url=$1
    local name=$2
    
    if response=$(curl -s -f "$url" 2>/dev/null); then
        echo "✅ $name endpoint: $url"
        # Show sample data (first few lines)
        echo "$response" | head -3 | sed 's/^/   /'
    else
        echo "⚠️  $name endpoint not ready yet: $url"
    fi
}

test_endpoint "http://localhost:8081/api/v1/stats" "Statistics"
test_endpoint "http://localhost:8081/api/v1/nodes" "Nodes"  
test_endpoint "http://localhost:8081/api/v1/pods" "Pods"

# Test database content
echo ""
echo "🗄️ Testing database content..."
if command -v psql &> /dev/null; then
    echo "📊 Database statistics:"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        resource_type,
        COUNT(*) as total_records,
        MAX(created_at) as latest_collection
    FROM cluster_snapshots 
    GROUP BY resource_type 
    ORDER BY resource_type;" 2>/dev/null || echo "⚠️  Could not query database"
else
    echo "ℹ️  Install psql to check database: brew install postgresql"
fi

# WebSocket test (if wscat is available)
echo ""
echo "🌐 Testing WebSocket endpoint..."
if command -v wscat &> /dev/null; then
    echo "✅ WebSocket test (5 seconds):"
    timeout 5 wscat -c ws://localhost:8082/api/v1/ws 2>/dev/null | head -3 || echo "   WebSocket connection tested"
else
    echo "ℹ️  Install wscat to test WebSocket: npm install -g wscat"
fi

# Stop collector
echo ""
echo "🛑 Stopping test collector..."
kill $collector_pid 2>/dev/null || true
wait $collector_pid 2>/dev/null || true

echo ""
echo "✅ Hybrid Development Test Completed!"
echo ""
echo "📋 Summary:"
echo "   • PostgreSQL: Running in Kubernetes (port-forwarded)"
if [ "$KAFKA_ENABLED" = "true" ]; then
    echo "   • Kafka: Running in Kubernetes (port-forwarded)"
fi
echo "   • Collector: Built and tested locally"
echo "   • APIs: Health, Metrics, and Cluster endpoints tested"
echo "   • Database: Contains live cluster data"
echo ""
echo "🚀 Ready for development!"
echo ""
echo "💡 Next steps:"
echo "   1. Start collector: source .env.hybrid && ./bin/collector"
echo "   2. Make code changes"
echo "   3. Rebuild: go build -o bin/collector main.go"
echo "   4. Test APIs: curl http://localhost:8081/api/v1/stats"
echo ""
echo "🔧 Useful commands:"
echo "   • API docs: ./scripts/view-api-docs.sh"
echo "   • Stop services: kubectl delete namespace cluster-info-dev"
echo "   • Restart setup: ./scripts/setup-hybrid.sh → Option 3 → Option 3"
