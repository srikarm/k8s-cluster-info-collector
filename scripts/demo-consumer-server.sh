#!/bin/bash

# Test script to demonstrate consumer health/metrics endpoints with JSON formatting
echo "🧪 Consumer HTTP Server JSON Formatting Demo"
echo "============================================="

# Build consumer if not exists
if [ ! -f "./bin/consumer" ]; then
    echo "📦 Building consumer..."
    make build-consumer
fi

# Set environment for testing (disable Kafka and database for demo)
export CONSUMER_SERVER_ENABLED=true
export CONSUMER_SERVER_PORT=8083
export CONSUMER_SERVER_ADDRESS=""
export KAFKA_ENABLED=false
export DB_HOST="dummy"  # Will fail but server should still start
export LOG_LEVEL=info

echo ""
echo "🚀 Starting consumer with HTTP server..."
echo "   Server will be available at: http://localhost:8083"
echo "   Testing JSON formatting improvements..."
echo ""

# Start consumer in background
./bin/consumer &
CONSUMER_PID=$!

# Wait for server to start
sleep 3

# Test endpoints with better JSON formatting display
echo "🔍 Testing endpoints with JSON formatting..."

echo ""
echo "📋 Health endpoint (with formatted JSON):"
echo "=========================================="
curl -s http://localhost:8083/health

echo ""
echo ""
echo "📊 Version endpoint (with formatted JSON):"
echo "=========================================="
curl -s http://localhost:8083/version

echo ""
echo ""
echo "📈 Metrics endpoint (with formatted JSON):"
echo "=========================================="
curl -s http://localhost:8083/metrics

echo ""
echo ""
echo "🏃 Ready endpoint:"
echo "================="
curl -s http://localhost:8083/ready

echo ""
echo ""
echo "✅ JSON formatting test completed!"
echo ""
echo "🌐 Available endpoints:"
echo "   • Health:   http://localhost:8083/health"
echo "   • Metrics:  http://localhost:8083/metrics"
echo "   • Ready:    http://localhost:8083/ready"
echo "   • Version:  http://localhost:8083/version"

# Keep server running for manual testing
echo ""
echo "🔄 Consumer is running with HTTP server..."
echo "   Open another terminal to test endpoints manually"
echo "   Press Ctrl+C to stop the consumer"

# Wait for interrupt
trap "echo ''; echo '🛑 Stopping consumer...'; kill $CONSUMER_PID 2>/dev/null; exit 0" SIGINT
wait $CONSUMER_PID
