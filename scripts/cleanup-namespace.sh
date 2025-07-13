#!/bin/bash

# Kubernetes Namespace Cleanup Script
# Safely removes namespaces and handles stuck finalizers
# Usage: ./scripts/cleanup-namespace.sh [namespace] [--force]

set -e

# Default values
DEFAULT_NAMESPACE="cluster-info-dev"
FORCE_MODE=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_action() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

# Function to show usage
show_usage() {
    echo "🧹 Kubernetes Namespace Cleanup Script"
    echo ""
    echo "Usage: $0 [namespace] [options]"
    echo ""
    echo "Arguments:"
    echo "  namespace         Namespace to clean up (default: $DEFAULT_NAMESPACE)"
    echo ""
    echo "Options:"
    echo "  --force          Force cleanup without confirmation"
    echo "  --dry-run        Show what would be deleted without actually deleting"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Clean up default namespace"
    echo "  $0 cluster-info-dev                  # Clean up specific namespace"
    echo "  $0 cluster-info-dev --force          # Clean up without confirmation"
    echo "  $0 cluster-info-dev --dry-run        # Show what would be deleted"
    echo ""
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
}

# Function to check if namespace exists
namespace_exists() {
    local namespace=$1
    kubectl get namespace "$namespace" &> /dev/null
}

# Function to check if namespace is terminating
namespace_terminating() {
    local namespace=$1
    local status=$(kubectl get namespace "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    [ "$status" = "Terminating" ]
}

# Function to get resources in namespace
get_namespace_resources() {
    local namespace=$1
    print_status "Scanning resources in namespace '$namespace'..."
    
    # Very simple approach - just show that we're checking
    echo "  • Checking for common resources..."
    
    # Try a quick check, but don't let it hang
    (
        # Run in a subshell with a timeout-like approach
        kubectl get pods -n "$namespace" --no-headers 2>/dev/null | head -3 | while read line; do
            echo "  • Found pod: $(echo $line | awk '{print $1}')"
        done
        
        # Quick count if possible
        local count=$(kubectl get all -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
        if [ "$count" != "unknown" ] && [ "$count" -gt 0 ]; then
            echo "  • Total resources: $count"
        else
            echo "  • Namespace appears empty or inaccessible"
        fi
    ) &
    
    # Wait for the background job but with a timeout
    local bg_pid=$!
    local wait_time=0
    while kill -0 $bg_pid 2>/dev/null && [ $wait_time -lt 3 ]; do
        sleep 1
        wait_time=$((wait_time + 1))
    done
    
    # Kill the background process if it's still running
    kill $bg_pid 2>/dev/null || true
    wait $bg_pid 2>/dev/null || true
}

# Function to force delete pods
force_delete_pods() {
    local namespace=$1
    print_action "Force deleting pods in namespace '$namespace'..."
    
    local pods=$(kubectl get pods -n "$namespace" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)
    
    if [ -n "$pods" ]; then
        for pod in $pods; do
            if [ "$DRY_RUN" = true ]; then
                echo "  Would force delete pod: $pod"
            else
                print_action "Force deleting pod: $pod"
                kubectl delete pod "$pod" -n "$namespace" --force --grace-period=0 2>/dev/null || true
            fi
        done
    else
        print_status "No pods found in namespace"
    fi
}

# Function to remove finalizers from resources
remove_finalizers() {
    local namespace=$1
    print_action "Removing finalizers from resources in namespace '$namespace'..."
    
    # Common resource types that might have finalizers
    local resource_types=("persistentvolumeclaims" "persistentvolumes" "services" "endpoints" "configmaps" "secrets" "deployments" "replicasets" "statefulsets" "daemonsets" "jobs" "cronjobs")
    
    for resource_type in "${resource_types[@]}"; do
        local resources=$(kubectl get "$resource_type" -n "$namespace" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)
        
        if [ -n "$resources" ]; then
            for resource in $resources; do
                # Check if resource has finalizers
                local finalizers=$(kubectl get "$resource_type" "$resource" -n "$namespace" -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)
                
                if [ -n "$finalizers" ] && [ "$finalizers" != "[]" ] && [ "$finalizers" != "null" ]; then
                    if [ "$DRY_RUN" = true ]; then
                        echo "  Would remove finalizers from $resource_type: $resource"
                    else
                        print_action "Removing finalizers from $resource_type: $resource"
                        kubectl patch "$resource_type" "$resource" -n "$namespace" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
                    fi
                fi
            done
        fi
    done
}

# Function to force delete namespace via API
force_delete_namespace_api() {
    local namespace=$1
    print_action "Attempting direct API deletion of namespace '$namespace'..."
    
    if [ "$DRY_RUN" = true ]; then
        echo "  Would force delete namespace via API: $namespace"
        return 0
    fi
    
    # Simple approach - just try to delete with force
    kubectl delete namespace "$namespace" --force --grace-period=0 2>/dev/null || true
    
    # Remove any remaining finalizers
    kubectl patch namespace "$namespace" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
}
remove_namespace_finalizers() {
    local namespace=$1
    print_action "Removing finalizers from namespace '$namespace'..."
    
    # Check if namespace has finalizers
    local finalizers=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)
    
    if [ -n "$finalizers" ] && [ "$finalizers" != "[]" ] && [ "$finalizers" != "null" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  Would remove finalizers from namespace: $namespace"
        else
            print_action "Removing finalizers from namespace: $namespace"
            kubectl patch namespace "$namespace" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        fi
    else
        print_status "No finalizers found on namespace"
    fi
}

# Function to delete namespace
delete_namespace() {
    local namespace=$1
    
    if [ "$DRY_RUN" = true ]; then
        echo "  Would delete namespace: $namespace"
        return 0
    fi
    
    print_action "Deleting namespace '$namespace'..."
    
    # Try normal deletion first
    if kubectl delete namespace "$namespace" --timeout=60s 2>/dev/null; then
        print_success "Namespace deletion initiated successfully"
        return 0
    else
        print_warning "Normal deletion failed, trying force cleanup..."
        
        # Force delete by removing finalizers
        remove_namespace_finalizers "$namespace"
        
        # Try deletion again
        if kubectl delete namespace "$namespace" --timeout=30s 2>/dev/null; then
            print_success "Namespace deletion initiated with force cleanup"
            return 0
        else
            print_warning "Namespace might be stuck in terminating state"
            print_status "You may need to manually clean up with cluster admin privileges"
            return 1
        fi
    fi
}

# Function to wait for namespace deletion
wait_for_deletion() {
    local namespace=$1
    local max_wait=30
    local wait_time=0
    
    if [ "$DRY_RUN" = true ]; then
        return 0
    fi
    
    # Quick check if namespace is already gone
    if ! namespace_exists "$namespace"; then
        print_success "Namespace successfully deleted"
        return 0
    fi
    
    print_status "Waiting for namespace deletion to complete (max ${max_wait}s)..."
    
    while namespace_exists "$namespace" && [ $wait_time -lt $max_wait ]; do
        echo -n "."
        sleep 1
        wait_time=$((wait_time + 1))
        
        # Check every 5 seconds for faster feedback
        if [ $((wait_time % 5)) -eq 0 ]; then
            if ! namespace_exists "$namespace"; then
                echo ""
                print_success "Namespace successfully deleted"
                return 0
            fi
        fi
    done
    echo ""
    
    if namespace_exists "$namespace"; then
        print_warning "Namespace still exists after ${max_wait}s"
        print_status "Namespace may be stuck - this can happen with some cluster configurations"
        return 1
    else
        print_success "Namespace successfully deleted"
        return 0
    fi
}

# Function to cleanup port-forwards
cleanup_port_forwards() {
    local namespace=$1
    print_action "Cleaning up port-forwards for namespace '$namespace'..."
    
    if [ "$DRY_RUN" = true ]; then
        echo "  Would kill port-forward processes for namespace: $namespace"
        return
    fi
    
    # Find and kill port-forward processes for this namespace
    local pids=$(pgrep -f "kubectl.*port-forward.*$namespace" 2>/dev/null || true)
    
    if [ -n "$pids" ]; then
        for pid in $pids; do
            print_action "Killing port-forward process: $pid"
            kill "$pid" 2>/dev/null || true
        done
        sleep 2
    else
        print_status "No port-forward processes found for namespace"
    fi
}

# Function to perform comprehensive cleanup
comprehensive_cleanup() {
    local namespace=$1
    
    echo "🧹 Starting comprehensive cleanup for namespace: $namespace"
    echo "=================================================="
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No actual changes will be made"
        echo ""
    fi
    
    # Step 1: Show current resources
    print_status "Current resources in namespace:"
    get_namespace_resources "$namespace"
    echo ""
    
    # Step 2: Cleanup port-forwards
    cleanup_port_forwards "$namespace"
    echo ""
    
    # Step 3: Force delete pods
    force_delete_pods "$namespace"
    echo ""
    
    # Step 4: Remove finalizers from resources
    remove_finalizers "$namespace"
    echo ""
    
    # Step 5: Delete namespace
    if delete_namespace "$namespace"; then
        echo ""
        # Step 6: Wait for deletion to complete (only if deletion was initiated but namespace might still exist)
        wait_for_deletion "$namespace"
    else
        echo ""
        print_error "Failed to delete namespace - may require manual intervention"
    fi
}

# Main script execution
main() {
    local namespace="$DEFAULT_NAMESPACE"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                namespace="$1"
                shift
                ;;
        esac
    done
    
    # Check prerequisites
    check_kubectl
    
    # Check if namespace exists
    if ! namespace_exists "$namespace"; then
        print_success "Namespace '$namespace' does not exist - nothing to clean up"
        exit 0
    fi
    
    # Check if namespace is already terminating
    if namespace_terminating "$namespace"; then
        print_warning "Namespace '$namespace' is already in Terminating state"
        print_status "Attempting to force cleanup..."
        
        # For terminating namespaces, try aggressive cleanup immediately
        if [ "$DRY_RUN" = false ]; then
            # Remove finalizers from namespace
            remove_namespace_finalizers "$namespace"
            
            # Try force delete
            force_delete_namespace_api "$namespace"
            
            # Quick check if it worked
            sleep 2
            if ! namespace_exists "$namespace"; then
                print_success "Cleanup completed for namespace: $namespace"
                exit 0
            fi
            
            # If still exists, give it a short wait
            print_status "Namespace still terminating - waiting up to 10 seconds..."
            local wait_count=0
            while namespace_exists "$namespace" && [ $wait_count -lt 10 ]; do
                echo -n "."
                sleep 1
                wait_count=$((wait_count + 1))
            done
            echo ""
            
            if ! namespace_exists "$namespace"; then
                print_success "Cleanup completed for namespace: $namespace"
            else
                print_warning "Namespace is still stuck after force cleanup"
                print_status "This is common with some Kubernetes configurations"
                print_status "The namespace may eventually be cleaned up by the cluster"
                print_status "If it persists, try: kubectl delete namespace $namespace --force --grace-period=0"
            fi
        else
            print_status "Would force cleanup terminating namespace: $namespace"
        fi
        exit 0
    fi
    
    # Confirmation prompt (unless force mode or dry run)
    if [ "$FORCE_MODE" = false ] && [ "$DRY_RUN" = false ]; then
        echo ""
        print_warning "This will DELETE namespace '$namespace' and ALL its resources!"
        print_warning "This action cannot be undone."
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleanup cancelled by user"
            exit 0
        fi
        echo ""
    fi
    
    # Perform cleanup
    comprehensive_cleanup "$namespace"
    
    if [ "$DRY_RUN" = false ]; then
        echo ""
        print_success "Cleanup completed for namespace: $namespace"
        echo ""
        print_status "To recreate the environment, run:"
        echo "  ./scripts/setup-hybrid.sh"
    else
        echo ""
        print_status "Dry run completed - no changes were made"
    fi
}

# Run main function with all arguments
main "$@"
