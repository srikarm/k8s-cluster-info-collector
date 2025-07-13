# Fix Summary: test-setup.sh Namespace Issue (Option 3-3)

## Problem
When selecting option 3 (Development Setup) and then option 3 (Hybrid mode) in `test-setup.sh`, the following error occurred:
```
Deploying PostgreSQL service to Kubernetes...
the namespace from the provided object "default" does not match the namespace "cluster-info-dev". You must pass '--namespace=default' to perform this operation.
```

## Root Cause
Two functions in `test-setup.sh` were missing the explicit namespace specification (`-n $namespace`) in their `kubectl apply` commands:

1. **`deploy_minimal_postgres_service()`** - Used for PostgreSQL-only hybrid mode
2. **`deploy_minimal_kafka_services()`** - Used for Kafka + PostgreSQL hybrid mode

## Fixes Applied

### 1. Fixed `deploy_minimal_postgres_service()` function
**Before:**
```bash
kubectl apply -f - <<EOF
```

**After:**
```bash
kubectl apply -n $namespace -f - <<EOF
```

### 2. Fixed `deploy_minimal_kafka_services()` function  
**Before:**
```bash
kubectl apply -f - <<EOF
```

**After:**
```bash
kubectl apply -n $namespace -f - <<EOF
```

## Affected Workflows
These fixes resolve the namespace issue for the following development setup paths:

- **Option 3 → Option 3**: Hybrid Development (PostgreSQL only)
- **Option 3 → Option 4**: Hybrid Development (Kafka + PostgreSQL)
- Any other workflows that use these minimal service deployment functions

## Verification
✅ Both functions now correctly apply resources to the specified namespace
✅ Resources are created in `cluster-info-dev` namespace as intended
✅ No more "default namespace mismatch" errors

## Result
You can now successfully run:
```bash
./test-setup.sh
# Select option 3 (Development Setup)
# Select option 3 or 4 (Hybrid modes)
```

The PostgreSQL and Kafka services will be deployed correctly to the `cluster-info-dev` namespace without any namespace conflicts.
