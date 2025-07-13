# Hybrid Kafka Mode Data Flow Fix

## Issue Identified

In the hybrid Kafka setup, the collector was incorrectly configured to write to both Kafka AND PostgreSQL directly, which violates the intended data flow pattern.

## Correct Data Flow

### Hybrid Legacy Mode (Option 3)
```
Collector → PostgreSQL
```
- Collector writes directly to database
- Simple, straightforward data flow

### Hybrid Kafka Mode (Option 4) - **FIXED**
```
Collector → Kafka → Consumer → PostgreSQL
```
- **Collector**: Only writes to Kafka (no database connection)
- **Consumer**: Reads from Kafka and writes to PostgreSQL
- **Separation of Concerns**: Producer vs Consumer logic

## Changes Made

### 1. Updated Collector Environment (`.env.hybrid`)

**Before (Incorrect):**
```bash
# Had both Kafka AND database settings
export KAFKA_ENABLED=true
export DB_HOST=localhost
export DB_PORT=5432
export KAFKA_BROKERS=localhost:9092
```

**After (Correct):**
```bash
# Kafka mode - NO database settings for collector
export KAFKA_ENABLED=true
# Database settings removed - collector doesn't write to DB in Kafka mode
# Consumer will handle DB writes from Kafka messages
export KAFKA_BROKERS=localhost:9092
export KAFKA_TOPIC=cluster-info
```

### 2. Added Consumer Environment (`.env.hybrid-consumer`)

**New file for Kafka mode:**
```bash
# Hybrid Kafka Mode - Consumer reads from Kafka and writes to DB
KAFKA_ENABLED=true
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC=cluster-info
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=clusterinfo
DATABASE_USER=clusterinfo
DATABASE_PASSWORD=devpassword
DATABASE_SSLMODE=disable
LOG_LEVEL=info
```

### 3. Updated Build Process

- Now uses `make build` to build both `collector` and `consumer` binaries
- Creates both collector and consumer environments in Kafka mode
- Only creates collector environment in legacy mode

### 4. Fixed Runtime Environment Variables

**Kafka Mode Collector (Correct):**
```bash
# Only Kafka-related environment variables
KAFKA_ENABLED=true \
KAFKA_BROKERS=localhost:9092 \
KAFKA_TOPIC=cluster-info \
./bin/collector
```

**Legacy Mode Collector (Unchanged):**
```bash
# Only database-related environment variables
KAFKA_ENABLED=false \
DB_HOST=localhost \
DB_PORT=5432 \
./bin/collector
```

## Usage Examples

### Hybrid Kafka Mode (Option 4)

1. **Run Setup:**
   ```bash
   ./scripts/setup-hybrid.sh
   # Select option 4: Hybrid Kafka
   ```

2. **Run Collector (produces to Kafka):**
   ```bash
   source .env.hybrid
   ./bin/collector
   ```

3. **Run Consumer (consumes from Kafka, writes to DB):**
   ```bash
   source .env.hybrid-consumer
   ./bin/consumer
   ```

4. **Or Use E2E Testing:**
   ```bash
   ./scripts/setup-hybrid.sh
   # Select option 7: E2E Test
   # This automatically manages both collector and consumer
   ```

## Benefits of the Fix

1. **🎯 Correct Architecture**: Proper separation between producer (collector) and consumer
2. **🔄 True Event Streaming**: Data flows through Kafka as intended
3. **📈 Scalability**: Multiple consumers can process the same Kafka messages
4. **🛡️ Data Integrity**: Single source of truth (Kafka) before database writes
5. **🧪 Testing Alignment**: Matches E2E testing patterns

## Verification

You can verify the correct behavior by:

1. **Check Kafka Messages:**
   ```bash
   # After running collector in Kafka mode
   kubectl exec -it deploy/kafka -n cluster-info-dev -- \
     kafka-console-consumer.sh --topic cluster-info --from-beginning --bootstrap-server localhost:9092
   ```

2. **Check Database (should be empty until consumer runs):**
   ```bash
   # After collector but before consumer
   psql -h localhost -U clusterinfo -d clusterinfo -c "SELECT COUNT(*) FROM cluster_snapshots;"
   # Should return 0 or very few records
   ```

3. **Check Database (after consumer runs):**
   ```bash
   # After both collector and consumer
   psql -h localhost -U clusterinfo -d clusterinfo -c "SELECT COUNT(*) FROM cluster_snapshots;"
   # Should show new records from Kafka consumption
   ```

## Files Modified

- `scripts/setup-hybrid.sh` - Fixed environment creation and runtime execution
- `.env.hybrid` - Removed database settings for Kafka mode
- **New:** `.env.hybrid-consumer` - Added consumer environment for Kafka mode

## Status

✅ **RESOLVED** - Hybrid Kafka mode now correctly follows the intended data flow pattern of Collector → Kafka → Consumer → PostgreSQL.
