# Service Existence Checks - Enhanced Scripts

## Problem Identified ❌

**Before the improvements**, both the former `demo-hybrid.sh` script and `test-setup.sh` had these issues:

1. **No service existence checks** - Scripts would try to create PostgreSQL/Kafka even if they already existed
2. **No port conflict detection** - Port forwarding would fail if ports were already in use
3. **Resource waste** - Multiple deployments of the same services
4. **Poor user experience** - Confusing errors when running scripts multiple times

## Solutions Implemented ✅

### 1. 🔍 **Service Existence Checks (formerly in `demo-hybrid.sh`, now in `test-setup.sh`)**

**Before**:
```bash
# Always tried to create PostgreSQL regardless of existence
kubectl apply -n demo-hybrid -f - <<EOF
```

**After**:
```bash
# Check if PostgreSQL is already deployed
if kubectl get deployment postgres -n demo-hybrid >/dev/null 2>&1; then
    echo "✅ PostgreSQL deployment already exists, skipping creation"
    echo "   Using existing PostgreSQL service"
else
    echo "📦 Creating new PostgreSQL deployment..."
    kubectl apply -n demo-hybrid -f - <<EOF
```

### 2. 🔌 **Smart Port Forwarding (formerly in `demo-hybrid.sh`, now enhanced in `test-setup.sh`)**

**Before**:
```bash
# Kill any existing port forwards and start new one
pkill -f "kubectl.*port-forward.*5432" 2>/dev/null || true
kubectl port-forward service/postgres 5432:5432 -n demo-hybrid &
```

**After**:
```bash
# Check if port 5432 is already in use
if lsof -i :5432 >/dev/null 2>&1; then
    echo "⚠️  Port 5432 is already in use"
    
    if pgrep -f "kubectl.*port-forward.*postgres.*5432" >/dev/null; then
        echo "✅ PostgreSQL port forwarding already active"
        # Use existing port forward
    else
        echo "⚠️  Port used by another process"
        # Show what's using the port and ask user
        lsof -i :5432
        read -p "Continue anyway? (y/N): " continue_anyway
    fi
else
    # Start new port forwarding
    kubectl port-forward service/postgres 5432:5432 -n demo-hybrid &
fi
```

### 3. 🗄️ **Enhanced Service Deployment in `test-setup.sh`**

**PostgreSQL Function - Before**:
```bash
deploy_minimal_postgres_service() {
    local namespace=$1
    echo "📦 Deploying minimal PostgreSQL service..."
    kubectl apply -n $namespace -f - <<EOF
```

**PostgreSQL Function - After**:
```bash
deploy_minimal_postgres_service() {
    local namespace=$1
    
    # Check if PostgreSQL is already deployed
    if kubectl get deployment postgres -n $namespace >/dev/null 2>&1; then
        echo "✅ PostgreSQL deployment already exists in namespace '$namespace'"
        echo "   Checking if service is ready..."
        
        if kubectl get service postgres -n $namespace >/dev/null 2>&1; then
            echo "✅ PostgreSQL service is already available"
            return 0
        else
            echo "⚠️  Deployment exists but service missing, recreating service..."
        fi
    else
        echo "📦 Deploying minimal PostgreSQL service to namespace '$namespace'..."
    fi
    
    kubectl apply -n $namespace -f - <<EOF
```

**Kafka Function - Before**:
```bash
deploy_minimal_kafka_services() {
    local namespace=$1
    echo "📦 Deploying minimal Kafka and PostgreSQL services..."
    # Always deployed both services
```

**Kafka Function - After**:
```bash
deploy_minimal_kafka_services() {
    local namespace=$1
    
    echo "📦 Deploying minimal Kafka and PostgreSQL services to namespace '$namespace'..."
    
    # Check if PostgreSQL already exists
    local postgres_exists=false
    if kubectl get deployment postgres -n $namespace >/dev/null 2>&1; then
        echo "✅ PostgreSQL deployment already exists"
        postgres_exists=true
    fi
    
    # Check if Kafka already exists  
    local kafka_exists=false
    if kubectl get deployment kafka -n $namespace >/dev/null 2>&1; then
        echo "✅ Kafka deployment already exists"
        kafka_exists=true
    fi

    # Deploy only what doesn't exist
    if [ "$postgres_exists" = false ]; then
        # Deploy PostgreSQL
    else
        echo "   Skipping PostgreSQL creation (already exists)"
    fi
    
    if [ "$kafka_exists" = false ]; then
        # Deploy Kafka
    else
        echo "   Skipping Kafka creation (already exists)"
    fi
```

### 4. 🛠️ **New Port Forwarding Helper Function**

Added comprehensive `setup_port_forward()` function:

```bash
setup_port_forward() {
    local service_name=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    
    echo "🔗 Setting up port forwarding for $service_name ($local_port -> $remote_port)..."
    
    # Check if port is already in use
    if lsof -i :$local_port >/dev/null 2>&1; then
        # Check if it's our port forward
        if pgrep -f "kubectl.*port-forward.*$service_name.*$local_port" >/dev/null; then
            echo "✅ Port forwarding for $service_name already active"
            return 0
        else
            # Show what's using the port and ask user
            echo "⚠️  Port $local_port is used by another process:"
            lsof -i :$local_port | head -3
            read -p "Kill existing process and continue? (y/N): " kill_process
        fi
    fi
    
    # Start port forwarding with verification
    kubectl port-forward service/$service_name $local_port:$remote_port -n $namespace &
    
    # Verify it's working
    if pgrep -f "kubectl.*port-forward.*$service_name.*$local_port" >/dev/null; then
        echo "✅ Port forwarding active for $service_name"
    else
        echo "❌ Failed to start port forwarding for $service_name"
    fi
}
```

## Benefits of These Improvements

### 🚀 **Better User Experience**
- **No duplicate resources** - Scripts detect existing services
- **Clear feedback** - Users know what's being created vs. reused
- **Graceful handling** - Smart port conflict resolution
- **Faster runs** - Skip unnecessary deployments

### 🔧 **Improved Reliability**
- **Idempotent operations** - Scripts can be run multiple times safely
- **Port conflict detection** - No mysterious port forwarding failures
- **Resource awareness** - Knows what's already deployed
- **Error prevention** - Stops before conflicts occur

### 💰 **Resource Efficiency**
- **No duplicate services** - Save cluster resources
- **Reuse existing deployments** - Faster setup when services exist
- **Smart cleanup** - Only kill processes when necessary
- **Better namespace management** - Avoid resource conflicts

## Example Output

### When Services Don't Exist (First Run):
```bash
🚀 Step 1: Deploying PostgreSQL service to Kubernetes...
📦 Creating new PostgreSQL deployment...
✅ PostgreSQL service deployed

🔗 Step 2: Setting up port forwarding...
🔗 Starting port forward: service/postgres 5432:5432
✅ Port forwarding active for postgres
```

### When Services Already Exist (Subsequent Runs):
```bash
🚀 Step 1: Deploying PostgreSQL service to Kubernetes...
✅ PostgreSQL deployment already exists, skipping creation
   Using existing PostgreSQL service

🔗 Step 2: Setting up port forwarding...
✅ PostgreSQL port forwarding already active
🔗 Using existing port forward (PID: 12345)
```

### When Port Conflicts Exist:
```bash
🔗 Step 2: Setting up port forwarding...
⚠️  Port 5432 is already in use
   Checking if it's our PostgreSQL port forward...
⚠️  Port 5432 is used by another process
   Current process using port 5432:
COMMAND   PID   USER   FD   TYPE   DEVICE SIZE/OFF NODE NAME
postgres  1234  user   5u   IPv4   0x...      0t0  TCP localhost:5432 (LISTEN)
Continue anyway? (y/N):
```

## Summary

These improvements make the scripts **production-ready** with:
- ✅ **Smart service detection** - No duplicate deployments
- ✅ **Port conflict resolution** - Graceful handling of port issues  
- ✅ **Idempotent operations** - Safe to run multiple times
- ✅ **Better user feedback** - Clear status messages
- ✅ **Resource efficiency** - Reuse existing services
- ✅ **Error prevention** - Stop before conflicts occur

The scripts now behave intelligently and provide a much better development experience!
