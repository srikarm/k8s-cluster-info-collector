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
