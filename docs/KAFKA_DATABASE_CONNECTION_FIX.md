# Kafka Database Connection Fix

## Problem

Option 4 (Hybrid Kafka Development) was failing with the error:
```
2025/07/13 00:00:06 Failed to initialize application: failed to initialize database: failed to ping database: pq: role "postgres" does not exist
```

## Root Cause

The application was always initializing a database connection, even in Kafka mode where the collector should only write to Kafka. This caused two issues:

1. **Wrong database credentials**: The config defaulted to `postgres` user/database, but our PostgreSQL deployment uses `clusterinfo`
2. **Incorrect architecture**: In Kafka mode, the collector should NOT connect to the database at all

## Architecture Fix

### Before (Incorrect)
```
Collector App (main.go):
├── Database connection (always initialized) ❌
├── Kafka producer (if Kafka enabled)
├── Kafka consumer (if Kafka enabled) ❌
└── Store (always with database) ❌
```

### After (Correct)
```
Collector App (main.go):
├── Database connection (only if Kafka disabled) ✅
├── Kafka producer (if Kafka enabled) ✅
└── Store (only if Kafka disabled) ✅

Consumer App (cmd/consumer/main.go):
├── Database connection (always) ✅
├── Kafka consumer (always) ✅
└── Store (always with database) ✅
```

## Changes Made

### 1. Modified `internal/app/app.go`

- **Database initialization**: Only when `!cfg.Kafka.Enabled`
- **Store initialization**: Only when `!cfg.Kafka.Enabled`
- **Removed kafka consumer**: From main collector app (handled by separate binary)
- **Added logging**: Clear messages about mode selection

### 2. Fixed `.env.hybrid` Reference

- Updated setup script to reference `.env.hybrid-consumer` instead of `.env.e2e-consumer`

### 3. Binary Architecture

- **`./bin/collector`**: Main collector (Kafka mode: writes to Kafka only)
- **`./bin/consumer`**: Separate consumer (reads from Kafka, writes to database)

## Testing

```bash
# Build both binaries
make build

# Test collector in Kafka mode (should work without database)
source .env.hybrid && ./bin/collector

# Test consumer separately (requires database and Kafka)
source .env.hybrid-consumer && ./bin/consumer
```

## Usage

### Option 4: Hybrid Kafka Development

```bash
# Terminal 1: Run collector (produces to Kafka)
source .env.hybrid && ./bin/collector

# Terminal 2: Run consumer (consumes from Kafka, writes to DB)
source .env.hybrid-consumer && ./bin/consumer
```

### Environment Files

- **`.env.hybrid`**: Collector environment (Kafka only, no database)
- **`.env.hybrid-consumer`**: Consumer environment (Kafka + database)

## Result

✅ **Option 4 now works correctly**:
- Collector starts without database connection errors
- Clean separation of concerns (collector → Kafka, consumer → database)
- Proper Kafka streaming architecture: `Collector → Kafka → Consumer → PostgreSQL`

## Related Files

- `internal/app/app.go` - Main application logic
- `cmd/consumer/main.go` - Consumer binary
- `.env.hybrid` - Collector environment
- `.env.hybrid-consumer` - Consumer environment
- `scripts/setup-hybrid.sh` - Setup script
