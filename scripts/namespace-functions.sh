#!/bin/bash

# Shared namespace management functions
# These functions are used by setup-hybrid.sh and other scripts

# Function to ensure namespace exists with optional labels
ensure_namespace() {
    local namespace_name="$1"
    local labels="$2"
    local description="$3"
    
    if kubectl get namespace "$namespace_name" >/dev/null 2>&1; then
        echo "✅ Namespace '$namespace_name' already exists"
        return 0
    fi
    
    echo "📦 Creating namespace: $namespace_name"
    
    # Create basic namespace
    kubectl create namespace "$namespace_name"
    
    # Apply labels if provided
    if [[ -n "$labels" ]]; then
        echo "🏷️  Applying labels: $labels"
        IFS=',' read -ra LABEL_ARRAY <<< "$labels"
        for label in "${LABEL_ARRAY[@]}"; do
            kubectl label namespace "$namespace_name" "$label"
        done
    fi
    
    # Apply description annotation if provided
    if [[ -n "$description" ]]; then
        echo "📝 Adding description: $description"
        kubectl annotate namespace "$namespace_name" "description=$description"
    fi
    
    echo "✅ Namespace '$namespace_name' created successfully"
}

# Function to create development namespace with standard labels
ensure_dev_namespace() {
    local namespace_name="$1"
    local component="${2:-development}"
    
    local labels="app.kubernetes.io/component=$component,app.kubernetes.io/part-of=k8s-cluster-info-collector"
    local description="Development environment for k8s-cluster-info-collector"
    
    ensure_namespace "$namespace_name" "$labels" "$description"
}

# Function to display namespace information
show_namespace_info() {
    local namespace_name="$1"
    
    if ! kubectl get namespace "$namespace_name" >/dev/null 2>&1; then
        echo "❌ Namespace '$namespace_name' does not exist"
        return 1
    fi
    
    echo "📊 Namespace Information: $namespace_name"
    echo "=========================================="
    
    # Basic info
    kubectl get namespace "$namespace_name" -o wide
    echo ""
    
    # Labels
    echo "🏷️  Labels:"
    kubectl get namespace "$namespace_name" --show-labels | awk 'NR>1 {print $NF}' | tr ',' '\n' | sed 's/^/   /'
    echo ""
    
    # Annotations
    echo "📝 Annotations:"
    kubectl get namespace "$namespace_name" -o jsonpath='{.metadata.annotations}' | jq -r 'to_entries[] | "   \(.key): \(.value)"' 2>/dev/null || echo "   None"
    echo ""
    
    # Resources
    echo "📦 Resources in namespace:"
    kubectl get all -n "$namespace_name" 2>/dev/null || echo "   No resources found"
}
