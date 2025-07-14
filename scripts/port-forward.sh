#!/bin/bash

# Port Forward Manager for K8s Cluster Info Collector
# Usage: ./port-forward.sh [start|stop|status] [namespace] [service-name]

set -e

DEFAULT_NAMESPACE="cluster-info-dev"
DEFAULT_SERVICE="my-cluster-info"
SERVICES_MODE=false

# Parse arguments for services mode
if [ "$1" = "services" ]; then
    SERVICES_MODE=true
    shift
    DEFAULT_NAMESPACE="cluster-info-dev"
    DEFAULT_SERVICE="postgres"
fi

NAMESPACE=${2:-$DEFAULT_NAMESPACE}
SERVICE=${3:-$DEFAULT_SERVICE}

# Function to start port forwarding
start_port_forward() {
    echo "🔗 Starting port forwarding..."
    echo "   Namespace: $NAMESPACE"
    echo "   Service: $SERVICE"
    echo "   Mode: $([ "$SERVICES_MODE" = "true" ] && echo "Services Only" || echo "Full Application")"
    
    # Check for existing port forwards before killing them
    check_existing_port_forwards
    
    # Selective cleanup - only kill conflicting port forwards
    selective_stop_port_forward
    
    # Wait a moment
    sleep 2
    
    if [ "$SERVICES_MODE" = "true" ]; then
        start_services_port_forward
    else
        start_application_port_forward
    fi
}

# Function to start services-only port forwarding
start_services_port_forward() {
    echo "🗄️ Starting service port forwarding..."
    
    # PostgreSQL
    if kubectl get service postgres -n $NAMESPACE > /dev/null 2>&1; then
        echo "🔗 Forwarding PostgreSQL port (5432)..."
        kubectl port-forward service/postgres 5432:5432 -n $NAMESPACE > /tmp/port-forward-postgres.log 2>&1 &
        local pf_postgres_pid=$!
    elif kubectl get service dev-services-postgresql -n $NAMESPACE > /dev/null 2>&1; then
        echo "🔗 Forwarding PostgreSQL port (5432)..."
        kubectl port-forward service/dev-services-postgresql 5432:5432 -n $NAMESPACE > /tmp/port-forward-postgres.log 2>&1 &
        local pf_postgres_pid=$!
    else
        echo "⚠️  PostgreSQL service not found"
        local pf_postgres_pid=""
    fi
    
    # Kafka (if available)
    if kubectl get service kafka -n $NAMESPACE > /dev/null 2>&1; then
        echo "🌊 Forwarding Kafka port (9092)..."
        kubectl port-forward service/kafka 9092:9092 -n $NAMESPACE > /tmp/port-forward-kafka.log 2>&1 &
        local pf_kafka_pid=$!
        
        # Note: KRaft mode Kafka doesn't need Zookeeper
        echo "ℹ️  Using KRaft mode Kafka (no Zookeeper needed)"
        local pf_zookeeper_pid=""
    elif kubectl get service dev-services-kafka -n $NAMESPACE > /dev/null 2>&1; then
        echo "🌊 Forwarding Kafka port (9092)..."
        kubectl port-forward service/dev-services-kafka 9092:9092 -n $NAMESPACE > /tmp/port-forward-kafka.log 2>&1 &
        local pf_kafka_pid=$!
        
        # Check if this deployment includes Zookeeper (legacy mode)
        if kubectl get service dev-services-kafka -n $NAMESPACE -o yaml | grep -q "2181" 2>/dev/null; then
            echo "🔗 Forwarding Zookeeper port (2181)..."
            kubectl port-forward service/dev-services-kafka 2181:2181 -n $NAMESPACE > /tmp/port-forward-zookeeper.log 2>&1 &
            local pf_zookeeper_pid=$!
        else
            echo "ℹ️  Using KRaft mode Kafka (no Zookeeper needed)"
            local pf_zookeeper_pid=""
        fi
    else
        echo "ℹ️  Kafka service not found (legacy mode)"
        local pf_kafka_pid=""
        local pf_zookeeper_pid=""
    fi
    
    # Kafka UI (if available)
    if kubectl get service kafka-ui -n $NAMESPACE > /dev/null 2>&1; then
        echo "🖥️  Forwarding Kafka UI port (8090)..."
        kubectl port-forward service/kafka-ui 8090:8080 -n $NAMESPACE > /tmp/port-forward-kafka-ui.log 2>&1 &
        local pf_kafka_ui_pid=$!
    elif kubectl get service dev-services-kafka-ui -n $NAMESPACE > /dev/null 2>&1; then
        echo "🖥️  Forwarding Kafka UI port (8090)..."
        kubectl port-forward service/dev-services-kafka-ui 8090:8080 -n $NAMESPACE > /tmp/port-forward-kafka-ui.log 2>&1 &
        local pf_kafka_ui_pid=$!
    else
        echo "ℹ️  Kafka UI service not found"
        local pf_kafka_ui_pid=""
    fi
    
    # Save PIDs (always include all, filter out empty)
    local pid_list=""
    [ -n "$pf_postgres_pid" ] && pid_list+="$pf_postgres_pid "
    [ -n "$pf_kafka_pid" ] && pid_list+="$pf_kafka_pid "
    [ -n "$pf_zookeeper_pid" ] && pid_list+="$pf_zookeeper_pid "
    [ -n "$pf_kafka_ui_pid" ] && pid_list+="$pf_kafka_ui_pid "
    # Trim trailing space
    pid_list=$(echo "$pid_list" | xargs)
    echo "$pid_list" > /tmp/services-port-forward-pids.txt
    
    # Wait for port forwards to establish
    sleep 3
    
    echo ""
    if [ -z "$pf_postgres_pid" ] && [ -z "$pf_kafka_pid" ] && [ -z "$pf_zookeeper_pid" ] && [ -z "$pf_kafka_ui_pid" ]; then
        echo "⚠️  No service port-forwards were started! Check your services and namespace."
    else
        echo "✅ Service port forwarding started!"
        echo ""
        echo "📊 Service endpoints (active):"
        [ -n "$pf_postgres_pid" ] && echo "   • PostgreSQL: localhost:5432 (PID: $pf_postgres_pid)" || echo "   • PostgreSQL: not forwarded"
        [ -n "$pf_kafka_pid" ] && echo "   • Kafka: localhost:9092 (PID: $pf_kafka_pid)" || echo "   • Kafka: not forwarded"
        [ -n "$pf_zookeeper_pid" ] && echo "   • Zookeeper: localhost:2181 (PID: $pf_zookeeper_pid)" || echo "   • Zookeeper: not forwarded"
        [ -n "$pf_kafka_ui_pid" ] && echo "   • Kafka UI: http://localhost:8090 (PID: $pf_kafka_ui_pid)" || echo "   • Kafka UI: not forwarded"
    fi
    
    # Test service connectivity
    test_service_connectivity
}

# Function to start application port forwarding
start_application_port_forward() {
    # Check if service exists
    if ! kubectl get service $SERVICE -n $NAMESPACE > /dev/null 2>&1; then
        echo "❌ Service '$SERVICE' not found in namespace '$NAMESPACE'"
        echo "Available services:"
        kubectl get services -n $NAMESPACE 2>/dev/null || echo "No services found"
        exit 1
    fi
    
    # Start port forwarding in background with error checking
    echo "📊 Forwarding metrics port (8080)..."
    kubectl port-forward service/$SERVICE 8080:8080 -n $NAMESPACE > /tmp/port-forward-8080.log 2>&1 &
    local pf_metrics_pid=$!
    sleep 0.5
    if ! ps -p $pf_metrics_pid > /dev/null 2>&1; then
        echo "⚠️  Failed to start port-forward for Metrics (PID $pf_metrics_pid)"
        pf_metrics_pid=""
    fi

    echo "🔗 Forwarding API port (8081)..."
    kubectl port-forward service/$SERVICE 8081:8081 -n $NAMESPACE > /tmp/port-forward-8081.log 2>&1 &
    local pf_api_pid=$!
    sleep 0.5
    if ! ps -p $pf_api_pid > /dev/null 2>&1; then
        echo "⚠️  Failed to start port-forward for API (PID $pf_api_pid)"
        pf_api_pid=""
    fi

    echo "🌐 Forwarding WebSocket port (8082)..."
    kubectl port-forward service/$SERVICE 8082:8082 -n $NAMESPACE > /tmp/port-forward-8082.log 2>&1 &
    local pf_ws_pid=$!
    sleep 0.5
    if ! ps -p $pf_ws_pid > /dev/null 2>&1; then
        echo "⚠️  Failed to start port-forward for WebSocket (PID $pf_ws_pid)"
        pf_ws_pid=""
    fi

    # Save PIDs (always include all, filter out empty)
    local pid_list=""
    [ -n "$pf_metrics_pid" ] && pid_list+="$pf_metrics_pid "
    [ -n "$pf_api_pid" ] && pid_list+="$pf_api_pid "
    [ -n "$pf_ws_pid" ] && pid_list+="$pf_ws_pid "
    pid_list=$(echo "$pid_list" | xargs)
    echo "$pid_list" > /tmp/port-forward-pids.txt

    # Wait for port forwards to establish
    sleep 3

    echo ""
    if [ -z "$pf_metrics_pid" ] && [ -z "$pf_api_pid" ] && [ -z "$pf_ws_pid" ]; then
        echo "⚠️  No application port-forwards were started! Check your service and namespace."
    else
        echo "✅ Application port forwarding started!"
        echo ""
        echo "📊 Application endpoints (active):"
        [ -n "$pf_metrics_pid" ] && echo "   • Metrics: http://localhost:8080/metrics (PID: $pf_metrics_pid)" || echo "   • Metrics: not forwarded"
        [ -n "$pf_api_pid" ] && echo "   • API: http://localhost:8081/api/v1/health (PID: $pf_api_pid)" || echo "   • API: not forwarded"
        [ -n "$pf_ws_pid" ] && echo "   • WebSocket: ws://localhost:8082/api/v1/ws (PID: $pf_ws_pid)" || echo "   • WebSocket: not forwarded"
    fi

    # Test connectivity
    test_connectivity
}

# Function to stop port forwarding
stop_port_forward() {
    echo "🛑 Stopping port forwarding..."
    
    # Check what's running first
    local all_forwards=$(ps aux | grep -E "kubectl.*port-forward" | grep -v grep || true)
    
    if [ -z "$all_forwards" ]; then
        echo "ℹ️  No active port forwards found"
        return 0
    fi
    
    echo "🔍 Found active port forwards:"
    echo "$all_forwards" | while read line; do
        echo "   • $line"
    done
    echo ""
    
    # Ask user what to stop
    echo "🤔 What would you like to stop?"
    echo "1. All port forwards (aggressive cleanup)"
    echo "2. Only port forwards for namespace: $NAMESPACE"
    echo "3. Port forwards + E2E background processes"
    echo "4. Cancel (keep existing port forwards)"
    echo ""
    read -p "Select option (1-4): " stop_choice
    
    case $stop_choice in
        1)
            echo "🧹 Stopping ALL port forwards..."
            aggressive_stop_all
            ;;
        2)
            echo "🎯 Stopping port forwards for namespace: $NAMESPACE only..."
            if [ "$SERVICES_MODE" = "true" ]; then
                stop_namespace_service_forwards
            else
                stop_namespace_application_forwards
            fi
            ;;
        3)
            echo "🎯 Stopping port forwards for namespace: $NAMESPACE and E2E processes..."
            if [ "$SERVICES_MODE" = "true" ]; then
                stop_namespace_service_forwards
            else
                stop_namespace_application_forwards
            fi
            stop_e2e_background_processes
            ;;
        4)
            echo "✅ Keeping existing port forwards"
            return 0
            ;;
        *)
            echo "ℹ️ Invalid choice, stopping namespace-specific forwards only"
            if [ "$SERVICES_MODE" = "true" ]; then
                stop_namespace_service_forwards
            else
                stop_namespace_application_forwards
            fi
            ;;
    esac
    
    echo "✅ Port forwarding cleanup completed"
}

# Function for aggressive cleanup (original behavior)
aggressive_stop_all() {
    # Kill by PID if available (application)
    if [ -f /tmp/port-forward-pids.txt ]; then
        local pids=$(cat /tmp/port-forward-pids.txt)
        for pid in $pids; do
            if kill $pid 2>/dev/null; then
                echo "   Stopped application process $pid"
            fi
        done
        rm -f /tmp/port-forward-pids.txt
    fi
    
    # Kill by PID if available (services)
    if [ -f /tmp/services-port-forward-pids.txt ]; then
        local pids=$(cat /tmp/services-port-forward-pids.txt)
        for pid in $pids; do
            if kill $pid 2>/dev/null; then
                echo "   Stopped service process $pid"
            fi
        done
        rm -f /tmp/services-port-forward-pids.txt
    fi
    
    # Kill any remaining port forwards
    pkill -f "kubectl.*port-forward.*8080" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*8081" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*8082" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*8090" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*5432" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*9092" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*2181" 2>/dev/null || true
    
    # Clean up log files
    rm -f /tmp/port-forward-*.log
}

# Function to show status
show_status() {
    echo "📊 Port Forward Status:"
    echo ""
    
    # Check if PIDs file exists
    if [ -f /tmp/port-forward-pids.txt ]; then
        local pids=$(cat /tmp/port-forward-pids.txt)
        echo "🔧 Saved PIDs: $pids"
        
        for pid in $pids; do
            if ps -p $pid > /dev/null 2>&1; then
                echo "✅ Process $pid is running"
            else
                echo "❌ Process $pid is not running"
            fi
        done
    else
        echo "ℹ️  No saved PIDs found"
    fi
    
    echo ""
    echo "🔍 Active port forward processes:"
    ps aux | grep -E "kubectl.*port-forward.*(8080|8081|8082|8090|5432|9092|2181)" | grep -v grep || echo "   No active port forwards found"
    
    echo ""
    echo "🌐 Port connectivity test:"
    if [ "$SERVICES_MODE" = "true" ]; then
        test_service_connectivity
    else
        test_connectivity
    fi
    
    # Check E2E background processes
    check_e2e_background_processes
}

# Function to test service connectivity
test_service_connectivity() {
    # Test each service port
    if nc -z localhost 5432 2>/dev/null; then
        echo "✅ PostgreSQL (5432) accessible"
    else
        echo "❌ PostgreSQL (5432) not accessible"
    fi
    
    if nc -z localhost 9092 2>/dev/null; then
        echo "✅ Kafka (9092) accessible"
    else
        echo "ℹ️  Kafka (9092) not accessible (may be legacy mode)"
    fi
    
    if nc -z localhost 2181 2>/dev/null; then
        echo "✅ Zookeeper (2181) accessible"
    else
        echo "ℹ️  Zookeeper (2181) not accessible (likely using KRaft mode)"
    fi
    
    if nc -z localhost 8090 2>/dev/null; then
        echo "✅ Kafka UI (8090) accessible"
    else
        echo "ℹ️  Kafka UI (8090) not accessible (may not be deployed)"
    fi
}

# Function to test connectivity
test_connectivity() {
    # Test each port
    for port in 8080 8081 8082; do
        if nc -z localhost $port 2>/dev/null; then
            echo "✅ Port $port is accessible"
        else
            echo "❌ Port $port is not accessible"
        fi
    done
    
    echo ""
    echo "🧪 Service tests:"
    
    # Test metrics endpoint
    if curl -s http://localhost:8080/metrics > /dev/null 2>&1; then
        echo "✅ Metrics endpoint responding"
    elif curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ Health endpoint responding"
    else
        echo "❌ Metrics/Health endpoint not responding"
    fi
    
    # Test API endpoint
    if curl -s http://localhost:8081/api/v1/health > /dev/null 2>&1; then
        echo "✅ API endpoint responding"
    else
        echo "❌ API endpoint not responding"
    fi
}

# Function to show usage
show_usage() {
    echo "Port Forward Manager for K8s Cluster Info Collector"
    echo ""
    echo "Usage: $0 [services] [command] [namespace] [service-name]"
    echo ""
    echo "Modes:"
    echo "  (default)     Application port forwarding (8080, 8081, 8082)"
    echo "  services      Services-only port forwarding (5432, 9092, 2181)"
    echo ""
    echo "Commands:"
    echo "  start         Start port forwarding (default)"
    echo "  stop          Stop port forwarding"
    echo "  restart       Restart port forwarding"
    echo "  status        Show port forwarding status"
    echo "  test          Test connectivity only"
    echo ""
    echo "Parameters:"
    echo "  namespace     Kubernetes namespace"
    echo "                Default: cluster-info (app), cluster-info-dev (services)"
    echo "  service-name  Service name"
    echo "                Default: my-cluster-info (app), postgres (services)"
    echo ""
    echo "Examples:"
    echo "  $0 start                                    # Application mode"
    echo "  $0 services start                           # Services mode"
    echo "  $0 start cluster-info my-cluster-info       # Custom app service"
    echo "  $0 services start cluster-info-dev postgres # Custom services"
    echo "  $0 stop                                     # Stop all"
    echo "  $0 status                                   # Check status"
    echo ""
    echo "Application endpoints (default mode):"
    echo "  • Metrics: http://localhost:8080/metrics"
    echo "  • API: http://localhost:8081/api/v1/health"
    echo "  • WebSocket: ws://localhost:8082/api/v1/ws"
    echo ""
    echo "Service endpoints (services mode):"
    echo "  • PostgreSQL: localhost:5432"
    echo "  • Kafka: localhost:9092"
    echo "  • Zookeeper: localhost:2181"
    echo "  • Kafka UI: http://localhost:8090 (if deployed)"
}

# Function to check existing port forwards
check_existing_port_forwards() {
    echo "🔍 Checking for existing port forwards..."
    
    local active_forwards=""
    if [ "$SERVICES_MODE" = "true" ]; then
        # Check service ports
        active_forwards=$(ps aux | grep -E "kubectl.*port-forward.*(5432|9092|2181|8090)" | grep -v grep | grep -E "$NAMESPACE" || true)
    else
        # Check application ports  
        active_forwards=$(ps aux | grep -E "kubectl.*port-forward.*(8080|8081|8082)" | grep -v grep | grep -E "$NAMESPACE" || true)
    fi
    
    if [ -n "$active_forwards" ]; then
        echo "⚠️  Found existing port forwards for this namespace:"
        echo "$active_forwards" | while read line; do
            echo "   • $line"
        done
        echo ""
        echo "🤔 These will be stopped and replaced. Continue?"
        read -p "Press Enter to continue or Ctrl+C to cancel: "
    else
        echo "✅ No conflicting port forwards found"
    fi
}

# Function to selectively stop port forwards
selective_stop_port_forward() {
    echo "🛑 Stopping conflicting port forwards for namespace: $NAMESPACE"
    
    if [ "$SERVICES_MODE" = "true" ]; then
        # Stop only service port forwards for this namespace
        stop_namespace_service_forwards
    else
        # Stop only application port forwards for this namespace
        stop_namespace_application_forwards
    fi
}

# Function to stop service port forwards for specific namespace
stop_namespace_service_forwards() {
    # Kill service port forwards for this specific namespace
    local service_processes=$(ps aux | grep -E "kubectl.*port-forward.*(postgres|kafka|kafka-ui)" | grep -E "$NAMESPACE" | grep -v grep || true)
    
    if [ -n "$service_processes" ]; then
        echo "   Stopping service port forwards for namespace: $NAMESPACE"
        echo "$service_processes" | while read line; do
            local pid=$(echo $line | awk '{print $2}')
            if kill $pid 2>/dev/null; then
                echo "   ✅ Stopped process $pid"
            fi
        done
    fi
    
    # Also stop by saved PIDs if they match our namespace
    if [ -f /tmp/services-port-forward-pids.txt ]; then
        local pids=$(cat /tmp/services-port-forward-pids.txt)
        for pid in $pids; do
            # Check if this PID belongs to our namespace
            local pid_info=$(ps -p $pid -o command --no-headers 2>/dev/null | grep "$NAMESPACE" || true)
            if [ -n "$pid_info" ]; then
                if kill $pid 2>/dev/null; then
                    echo "   ✅ Stopped saved PID $pid for namespace $NAMESPACE"
                fi
            fi
        done
        rm -f /tmp/services-port-forward-pids.txt
    fi
}

# Function to stop application port forwards for specific namespace  
stop_namespace_application_forwards() {
    # Kill application port forwards for this specific namespace and service
    local app_processes=$(ps aux | grep -E "kubectl.*port-forward.*service/$SERVICE" | grep -E "$NAMESPACE" | grep -v grep || true)
    
    if [ -n "$app_processes" ]; then
        echo "   Stopping application port forwards for service: $SERVICE in namespace: $NAMESPACE"
        echo "$app_processes" | while read line; do
            local pid=$(echo $line | awk '{print $2}')
            if kill $pid 2>/dev/null; then
                echo "   ✅ Stopped process $pid"
            fi
        done
    fi
    
    # Also stop by saved PIDs if they match our service
    if [ -f /tmp/port-forward-pids.txt ]; then
        local pids=$(cat /tmp/port-forward-pids.txt)
        for pid in $pids; do
            # Check if this PID belongs to our service
            local pid_info=$(ps -p $pid -o command --no-headers 2>/dev/null | grep -E "$NAMESPACE.*$SERVICE" || true)
            if [ -n "$pid_info" ]; then
                if kill $pid 2>/dev/null; then
                    echo "   ✅ Stopped saved PID $pid for service $SERVICE"
                fi
            fi
        done
        rm -f /tmp/port-forward-pids.txt
    fi
}

# Function to check E2E background processes
check_e2e_background_processes() {
    echo ""
    echo "🧪 E2E Background Processes Status:"
    
    # Check collector
    if [ -f /tmp/e2e-collector-bg.pid ]; then
        local collector_pid=$(cat /tmp/e2e-collector-bg.pid)
        if ps -p $collector_pid > /dev/null 2>&1; then
            echo "   ✅ Collector running (PID: $collector_pid)"
            echo "      📁 Logs: tail -f /tmp/e2e-collector-bg.log"
        else
            echo "   ❌ Collector not running (stale PID file)"
        fi
    else
        echo "   ⚪ Collector not running"
    fi
    
    # Check consumer
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local consumer_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $consumer_pid > /dev/null 2>&1; then
            echo "   ✅ Consumer running (PID: $consumer_pid)"
            echo "      📁 Logs: tail -f /tmp/e2e-consumer-bg.log"
        else
            echo "   ❌ Consumer not running (stale PID file)"
        fi
    else
        echo "   ⚪ Consumer not running"
    fi
    
    # Show management options if helper script exists
    if [ -f "./e2e-helper.sh" ]; then
        echo ""
        echo "   🔧 E2E Management:"
        echo "      • Start both: ./e2e-helper.sh start-both"
        echo "      • Check status: ./e2e-helper.sh status"
        echo "      • Stop all: ./e2e-helper.sh stop"
    else
        echo "      ℹ️  Run option 7 (E2E Testing) to create helper script"
    fi
}

# Function to stop E2E background processes
stop_e2e_background_processes() {
    echo "🛑 Stopping E2E background processes..."
    
    local stopped_any=false
    
    # Stop consumer
    if [ -f /tmp/e2e-consumer-bg.pid ]; then
        local consumer_pid=$(cat /tmp/e2e-consumer-bg.pid)
        if ps -p $consumer_pid > /dev/null 2>&1; then
            if kill $consumer_pid 2>/dev/null; then
                echo "   ✅ Consumer stopped (PID: $consumer_pid)"
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
                echo "   ✅ Collector stopped (PID: $collector_pid)"
                stopped_any=true
            fi
        fi
        rm -f /tmp/e2e-collector-bg.pid
    fi
    
    if [ "$stopped_any" = "false" ]; then
        echo "   ℹ️  No E2E background processes were running"
    fi
}

# Main logic
case ${1:-start} in
    start)
        start_port_forward
        ;;
    stop)
        stop_port_forward
        ;;
    restart)
        stop_port_forward
        sleep 2
        start_port_forward
        ;;
    status)
        show_status
        ;;
    test)
        if [ "$SERVICES_MODE" = "true" ]; then
            test_service_connectivity
        else
            test_connectivity
        fi
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
