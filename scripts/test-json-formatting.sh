#!/bin/bash

# Script to test the JSON formatting of consumer HTTP endpoints
# This will start a minimal HTTP server for testing

echo "Testing JSON formatting for consumer HTTP endpoints..."

# Build the consumer
echo "Building consumer..."
make build-consumer

# Start PostgreSQL and Kafka for a proper test
echo "Starting PostgreSQL..."
docker run --name test-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=password -e POSTGRES_DB=k8s_cluster_info -p 5432:5432 -d postgres:13 > /dev/null 2>&1

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 5

# Set environment variables for consumer
export CONSUMER_SERVER_ENABLED=true
export CONSUMER_SERVER_PORT=8083
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=k8s_cluster_info
export DB_USER=postgres
export DB_PASSWORD=password
export DB_SSL_MODE=disable
export KAFKA_ENABLED=false
export LOG_LEVEL=info

# Start the consumer in the background
echo "Starting consumer with HTTP server..."
./bin/consumer &
CONSUMER_PID=$!

# Wait for the server to start
sleep 3

# Test endpoints with JSON formatting
echo ""
echo "=== Testing Health Endpoint ==="
curl -s http://localhost:8083/health | python3 -m json.tool

echo ""
echo "=== Testing Metrics Endpoint ==="
curl -s http://localhost:8083/metrics | python3 -m json.tool

echo ""
echo "=== Testing Version Endpoint ==="
curl -s http://localhost:8083/version | python3 -m json.tool

echo ""
echo "=== Testing Ready Endpoint ==="
curl -s http://localhost:8083/ready

# Cleanup
echo ""
echo "Cleaning up..."
kill $CONSUMER_PID 2>/dev/null
docker stop test-postgres > /dev/null 2>&1
docker rm test-postgres > /dev/null 2>&1

echo "Test complete!"
