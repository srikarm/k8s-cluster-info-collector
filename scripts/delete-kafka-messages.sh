#!/bin/bash

set -e

# Script to delete Kafka messages for cluster-info-collector
echo "🗑️ Kafka Message Deletion Tool"
echo "=============================="
echo ""

# Default values
NAMESPACE="cluster-info-dev"
TOPIC="cluster-info"
KAFKA_POD=""
KAFKA_SERVICE="kafka"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: cluster-info-dev)"
    echo "  -t, --topic TOPIC           Kafka topic name (default: cluster-info)"
    echo "  -s, --service SERVICE       Kafka service name (default: kafka)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          Delete all messages from default topic"
    echo "  $0 -t my-topic             Delete messages from specific topic"
    echo "  $0 -n production -t logs    Delete messages from logs topic in production namespace"
    echo ""
    echo "⚠️  WARNING: This operation is irreversible!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -t|--topic)
            TOPIC="$2"
            shift 2
            ;;
        -s|--service)
            KAFKA_SERVICE="$2"
            shift 2
            ;;
        -h|--help)
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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    echo "✅ kubectl is available and connected to cluster"
}

# Function to check if namespace exists
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        echo "❌ Namespace '$NAMESPACE' does not exist"
        echo "Available namespaces:"
        kubectl get namespaces -o name | sed 's/namespace\///' | sed 's/^/  /'
        exit 1
    fi
    
    echo "✅ Namespace '$NAMESPACE' exists"
}

# Function to find Kafka pod
find_kafka_pod() {
    echo "🔍 Looking for Kafka pod in namespace '$NAMESPACE'..."
    
    # Try different common Kafka pod selectors
    local selectors=("app=kafka" "app.kubernetes.io/name=kafka" "component=kafka")
    
    for selector in "${selectors[@]}"; do
        KAFKA_POD=$(kubectl get pods -n "$NAMESPACE" -l "$selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$KAFKA_POD" ]; then
            echo "✅ Found Kafka pod: $KAFKA_POD (selector: $selector)"
            return 0
        fi
    done
    
    # If no pod found with selectors, try to find by name pattern
    KAFKA_POD=$(kubectl get pods -n "$NAMESPACE" -o name | grep -E "(kafka|dev-services)" | head -1 | cut -d'/' -f2)
    if [ -n "$KAFKA_POD" ]; then
        echo "✅ Found Kafka pod: $KAFKA_POD (by name pattern)"
        return 0
    fi
    
    echo "❌ Could not find Kafka pod in namespace '$NAMESPACE'"
    echo "Available pods:"
    kubectl get pods -n "$NAMESPACE" -o name | sed 's/pod\///' | sed 's/^/  /'
    exit 1
}

# Function to check if Kafka service exists
check_kafka_service() {
    if ! kubectl get service "$KAFKA_SERVICE" -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "⚠️  Kafka service '$KAFKA_SERVICE' not found in namespace '$NAMESPACE'"
        echo "Available services:"
        kubectl get services -n "$NAMESPACE" -o name | sed 's/service\///' | sed 's/^/  /'
        
        # Try to find alternative service names
        local alt_service=$(kubectl get services -n "$NAMESPACE" -o name | grep -E "(kafka|dev-services)" | head -1 | cut -d'/' -f2)
        if [ -n "$alt_service" ]; then
            echo "💡 Found alternative Kafka service: $alt_service"
            read -p "Use '$alt_service' instead? (y/n): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                KAFKA_SERVICE="$alt_service"
                echo "✅ Using service: $KAFKA_SERVICE"
            else
                exit 1
            fi
        else
            exit 1
        fi
    else
        echo "✅ Kafka service '$KAFKA_SERVICE' exists"
    fi
}

# Function to list topics
list_topics() {
    echo "📋 Listing available topics..."
    
    local topics
    topics=$(kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --list 2>/dev/null || echo "")
    
    if [ -z "$topics" ]; then
        echo "⚠️  No topics found or unable to connect to Kafka"
        return 1
    fi
    
    echo "Available topics:"
    echo "$topics" | sed 's/^/  /'
    echo ""
    
    # Check if our target topic exists
    if echo "$topics" | grep -q "^$TOPIC$"; then
        echo "✅ Target topic '$TOPIC' exists"
        return 0
    else
        echo "❌ Target topic '$TOPIC' does not exist"
        return 1
    fi
}

# Function to show topic information
show_topic_info() {
    echo "📊 Topic Information for '$TOPIC':"
    
    # Get topic description
    kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --describe \
        --topic "$TOPIC" 2>/dev/null || {
        echo "❌ Could not get topic description"
        return 1
    }
    
    echo ""
    
    # Get message count (approximate)
    echo "📈 Getting message count..."
    local earliest_offset=$(kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-run-class.sh \
        kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic "$TOPIC" \
        --time -2 2>/dev/null | cut -d: -f3 | paste -sd+ | bc 2>/dev/null || echo "0")
    
    local latest_offset=$(kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-run-class.sh \
        kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic "$TOPIC" \
        --time -1 2>/dev/null | cut -d: -f3 | paste -sd+ | bc 2>/dev/null || echo "0")
    
    local message_count=$((latest_offset - earliest_offset))
    
    echo "📊 Estimated message count: $message_count"
    echo "   Earliest offset: $earliest_offset"
    echo "   Latest offset: $latest_offset"
    echo ""
}

# Function to delete all messages from topic
delete_messages() {
    echo "🗑️ Preparing to delete all messages from topic '$TOPIC'..."
    echo ""
    echo "⚠️  WARNING: This operation will permanently delete ALL messages in the topic!"
    echo "⚠️  This action cannot be undone!"
    echo ""
    echo "Topic: $TOPIC"
    echo "Namespace: $NAMESPACE"
    echo "Kafka Pod: $KAFKA_POD"
    echo ""
    
    read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " confirm
    
    if [ "$confirm" != "DELETE" ]; then
        echo "❌ Operation cancelled."
        exit 0
    fi
    
    echo ""
    echo "🗑️ Deleting messages from topic '$TOPIC'..."
    
    # Method 1: Delete and recreate topic (fastest)
    echo "Method 1: Delete and recreate topic"
    
    # Get current topic configuration
    echo "📋 Getting current topic configuration..."
    local topic_config
    topic_config=$(kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --describe \
        --topic "$TOPIC" 2>/dev/null)
    
    local partitions=$(echo "$topic_config" | grep "PartitionCount" | sed 's/.*PartitionCount: \([0-9]*\).*/\1/')
    local replication=$(echo "$topic_config" | grep "ReplicationFactor" | sed 's/.*ReplicationFactor: \([0-9]*\).*/\1/')
    
    echo "📊 Current topic config: Partitions=$partitions, Replication=$replication"
    
    # Delete topic
    echo "🗑️ Deleting topic..."
    kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --delete \
        --topic "$TOPIC" || {
        echo "❌ Failed to delete topic"
        exit 1
    }
    
    # Wait a moment for deletion to complete
    echo "⏳ Waiting for topic deletion to complete..."
    sleep 5
    
    # Recreate topic with same configuration
    echo "🔄 Recreating topic with same configuration..."
    kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --create \
        --topic "$TOPIC" \
        --partitions "$partitions" \
        --replication-factor "$replication" || {
        echo "❌ Failed to recreate topic"
        echo "💡 You may need to recreate the topic manually:"
        echo "   kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-topics.sh --bootstrap-server localhost:9092 --create --topic $TOPIC --partitions $partitions --replication-factor $replication"
        exit 1
    }
    
    echo "✅ Topic '$TOPIC' has been recreated with all messages deleted!"
}

# Function to delete messages using retention (alternative method)
delete_messages_retention() {
    echo "🗑️ Alternative method: Using retention policy to delete messages..."
    echo "This method temporarily sets retention to 1ms to delete all messages"
    echo ""
    
    # Set retention to 1ms
    echo "⚙️ Setting retention.ms to 1..."
    kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-configs.sh \
        --bootstrap-server localhost:9092 \
        --entity-type topics \
        --entity-name "$TOPIC" \
        --alter \
        --add-config retention.ms=1 || {
        echo "❌ Failed to set retention policy"
        exit 1
    }
    
    echo "⏳ Waiting for Kafka to delete old messages (30 seconds)..."
    sleep 30
    
    # Reset retention to default (1 week = 604800000ms)
    echo "⚙️ Resetting retention policy to default..."
    kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-configs.sh \
        --bootstrap-server localhost:9092 \
        --entity-type topics \
        --entity-name "$TOPIC" \
        --alter \
        --delete-config retention.ms || {
        echo "⚠️ Failed to reset retention policy, but messages should be deleted"
    }
    
    echo "✅ Messages deleted using retention policy method!"
}

# Function to verify deletion
verify_deletion() {
    echo ""
    echo "🔍 Verifying message deletion..."
    
    # Wait a moment for Kafka to update
    sleep 5
    
    # Check message count
    local latest_offset=$(kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- kafka-run-class.sh \
        kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic "$TOPIC" \
        --time -1 2>/dev/null | cut -d: -f3 | paste -sd+ | bc 2>/dev/null || echo "0")
    
    echo "📊 Current latest offset: $latest_offset"
    
    if [ "$latest_offset" -eq 0 ]; then
        echo "✅ All messages have been successfully deleted!"
    else
        echo "⚠️ Some messages may still exist (offset: $latest_offset)"
        echo "   This could be normal as Kafka may take time to reflect changes"
    fi
    
    echo ""
    echo "📋 Updated topic information:"
    show_topic_info
}

# Main execution
main() {
    echo "🔧 Configuration:"
    echo "   Namespace: $NAMESPACE"
    echo "   Topic: $TOPIC"
    echo "   Kafka Service: $KAFKA_SERVICE"
    echo ""
    
    # Perform checks
    check_kubectl
    check_namespace
    find_kafka_pod
    check_kafka_service
    
    echo ""
    
    # List topics and show info
    if ! list_topics; then
        echo "❌ Cannot proceed without valid topic"
        exit 1
    fi
    
    show_topic_info
    
    # Delete messages
    delete_messages
    
    # Verify deletion
    verify_deletion
    
    echo ""
    echo "🎉 Kafka message deletion completed!"
    echo ""
    echo "💡 Useful commands:"
    echo "   • List topics: kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-topics.sh --bootstrap-server localhost:9092 --list"
    echo "   • Check topic: kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic $TOPIC"
    echo "   • Produce test message: kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-console-producer.sh --bootstrap-server localhost:9092 --topic $TOPIC"
    echo "   • Consume messages: kubectl exec -n $NAMESPACE $KAFKA_POD -- kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic $TOPIC --from-beginning"
    echo ""
}

# Run main function
main "$@"
