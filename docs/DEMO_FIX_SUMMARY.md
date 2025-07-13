# Fix Summary: Demo Script Namespace Issue

## Problem
The `demo-hybrid.sh` script was failing with the error:
```
the namespace from the provided object "default" does not match the namespace "cluster-info-dev". You must pass '--namespace=default' to perform this operation.
```

## Root Causes
1. **Incorrect namespace function**: The demo script had its own `ensure_namespace()` function that was using incorrect kubectl syntax for labels
2. **Missing namespace specification**: The `kubectl apply` command wasn't explicitly specifying the namespace
3. **macOS compatibility**: The script used `timeout` command which isn't available on macOS by default

## Fixes Applied

### 1. Namespace Function Fix
**Before:**
```bash
# Custom function with incorrect label syntax
ensure_namespace() {
    local create_cmd="kubectl create namespace $namespace"
    if [ -n "$labels" ]; then
        create_cmd="$create_cmd --labels=$labels"  # ❌ Wrong syntax
    fi
}
```

**After:**
```bash
# Use shared namespace functions
source ./namespace-functions.sh
```

### 2. Explicit Namespace in kubectl apply
**Before:**
```bash
kubectl apply -f - <<EOF
```

**After:**
```bash
kubectl apply -n demo-hybrid -f - <<EOF
```

### 3. macOS Compatibility Fix
**Before:**
```bash
timeout 5s ./bin/collector || true
```

**After:**
```bash
./bin/collector &
local binary_pid=$!
sleep 5
kill $binary_pid 2>/dev/null || true
```

## Testing
The fixes were validated by:
1. Testing namespace creation with proper labels
2. Verifying kubectl apply works with explicit namespace
3. Confirming the script sources the correct namespace functions

## Result
The `demo-hybrid.sh` script now:
- ✅ Creates namespaces correctly with proper labels
- ✅ Applies resources to the correct namespace explicitly  
- ✅ Works on macOS without external dependencies
- ✅ Uses the shared namespace management functions for consistency

You can now run `./demo-hybrid.sh` without namespace errors.
