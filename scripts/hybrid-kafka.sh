#!/bin/bash

# Hybrid Kafka Development Helper Script
# Manages the collector (one-shot) and consumer (long-running) workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

show_help() {
    echo "🌊 Hybrid Kafka Development Helper"
    echo "=================================="
    echo ""
    echo "🎯 Proper Kafka Workflow:"
    echo "   • Collector: Runs once → Collects data → Sends to Kafka → Exits"
    echo "   • Consumer: Starts once → Keeps running → Processes all Kafka messages"
    echo ""
    echo "📋 Available Commands:"
    echo "   collect          Run collector (one-shot data collection)"
    echo "   start-consumer   Start consumer in background"
    echo "   stop-consumer    Stop consumer"
    echo "   status          Show collector/consumer status"
    echo "   kafka-ui        Open Kafka UI in browser"
    echo "   db-connect      Connect to PostgreSQL database"
    echo "   logs            Show recent consumer logs"
    echo "   restart         Restart consumer"
    echo "   help            Show this help message"
    echo ""
    echo "📝 Example Development Workflow:"
    echo "   1. ./scripts/hybrid-kafka.sh start-consumer"
    echo "   2. ./scripts/hybrid-kafka.sh collect"
    echo "   3. ./scripts/hybrid-kafka.sh status"
    echo "   4. Edit code, rebuild, repeat step 2"
}

run_collector() {
    echo "🚀 Running collector (one-shot mode)..."
    if [[ ! -f ".env.hybrid" ]]; then
        echo "❌ .env.hybrid not found. Run the hybrid setup first."
        exit 1
    fi
    
    source .env.hybrid
    ./bin/collector
    echo "✅ Collector completed and exited."
}

start_consumer() {
    echo "🔄 Starting consumer..."
    if [[ ! -f ".env.hybrid-consumer" ]]; then
        echo "❌ .env.hybrid-consumer not found. Run the hybrid setup first."
        exit 1
    fi
    
    # Check if consumer is already running
    if pgrep -f "./bin/consumer" > /dev/null; then
        echo "⚠️  Consumer is already running. Use 'restart' to restart it."
        show_status
        return 0
    fi
    
    source .env.hybrid-consumer
    nohup ./bin/consumer > consumer.log 2>&1 &
    local consumer_pid=$!
    echo "✅ Consumer started (PID: $consumer_pid)"
    echo "📋 Logs: tail -f consumer.log"
}

stop_consumer() {
    echo "🛑 Stopping consumer..."
    if pgrep -f "./bin/consumer" > /dev/null; then
        pkill -f "./bin/consumer"
        echo "✅ Consumer stopped."
    else
        echo "ℹ️  Consumer is not running."
    fi
}

show_status() {
    echo "📊 Hybrid Kafka Status"
    echo "====================="
    echo ""
    
    # Check collector (should not be running)
    if pgrep -f "./bin/collector" > /dev/null; then
        echo "🔄 Collector: Running (unexpected - should run once and exit)"
    else
        echo "✅ Collector: Ready (not running - correct for one-shot mode)"
    fi
    
    # Check consumer (should be running)
    local consumer_pid=$(pgrep -f "./bin/consumer" || echo "")
    if [[ -n "$consumer_pid" ]]; then
        echo "✅ Consumer: Running (PID: $consumer_pid)"
        echo "   📋 Log file: consumer.log"
        echo "   🕒 Started: $(ps -o lstart= -p $consumer_pid 2>/dev/null || echo 'Unknown')"
    else
        echo "❌ Consumer: Not running"
        echo "   💡 Start with: ./scripts/hybrid-kafka.sh start-consumer"
    fi
    
    echo ""
    echo "🔗 Services:"
    echo "   • Kafka UI: http://localhost:8090"
    echo "   • PostgreSQL: localhost:5432"
    echo ""
}

open_kafka_ui() {
    echo "🖥️  Opening Kafka UI..."
    if command -v open >/dev/null 2>&1; then
        open http://localhost:8090
    else
        echo "📋 Kafka UI: http://localhost:8090"
    fi
}

connect_db() {
    echo "🗄️  Connecting to PostgreSQL..."
    if command -v psql >/dev/null 2>&1; then
        PGPASSWORD=devpassword psql -h localhost -p 5432 -U clusterinfo -d clusterinfo
    else
        echo "❌ psql not found. Install PostgreSQL client:"
        echo "   brew install postgresql"
    fi
}

show_logs() {
    echo "📋 Consumer logs (last 20 lines):"
    echo "================================="
    if [[ -f "consumer.log" ]]; then
        tail -20 consumer.log
        echo ""
        echo "💡 Follow logs: tail -f consumer.log"
    else
        echo "❌ consumer.log not found. Consumer may not have been started yet."
    fi
}

restart_consumer() {
    echo "🔄 Restarting consumer..."
    stop_consumer
    sleep 2
    start_consumer
}

# Main command handling
case "${1:-help}" in
    collect)
        run_collector
        ;;
    start-consumer)
        start_consumer
        ;;
    stop-consumer)
        stop_consumer
        ;;
    status)
        show_status
        ;;
    kafka-ui)
        open_kafka_ui
        ;;
    db-connect)
        connect_db
        ;;
    logs)
        show_logs
        ;;
    restart)
        restart_consumer
        ;;
    help|--help|-h|*)
        show_help
        ;;
esac
