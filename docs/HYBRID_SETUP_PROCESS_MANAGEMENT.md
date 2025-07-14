# Hybrid Setup Script - Process Management

The `setup-hybrid.sh` script now includes command-line options for managing local collector and consumer processes during development.

## New Commands

### Stop All Processes
```bash
./scripts/setup-hybrid.sh stop
```
Stops all running collector and consumer processes, plus cleans up port forwards.

### Stop Specific Processes
```bash
# Stop only collector processes
./scripts/setup-hybrid.sh stop-collector

# Stop only consumer processes  
./scripts/setup-hybrid.sh stop-consumer
```

### Check Process Status
```bash
./scripts/setup-hybrid.sh status
```
Shows the status of all running collector, consumer, and port forward processes.

### Interactive Setup (Default)
```bash
# These are equivalent
./scripts/setup-hybrid.sh
./scripts/setup-hybrid.sh setup
```

### Help
```bash
./scripts/setup-hybrid.sh help
```

## Use Cases

### Local Development Workflow
1. Start hybrid setup: `./scripts/setup-hybrid.sh`
2. Do development work...
3. Stop processes when done: `./scripts/setup-hybrid.sh stop`
4. Check if anything is still running: `./scripts/setup-hybrid.sh status`

### Troubleshooting
If processes seem stuck or you want to start clean:
```bash
# Stop everything
./scripts/setup-hybrid.sh stop

# Verify everything is stopped
./scripts/setup-hybrid.sh status

# Start fresh
./scripts/setup-hybrid.sh setup
```

### Selective Management
During development, you might want to restart just one component:
```bash
# Stop just the consumer
./scripts/setup-hybrid.sh stop-consumer

# Then restart it manually or through the interactive menu
```

## What Gets Stopped

### Collector Processes
- `./bin/collector` binary processes
- Background collector processes (PID files)
- Any other processes matching "collector"

### Consumer Processes  
- `./bin/consumer` binary processes
- Background consumer processes (PID files)
- Any other processes matching "consumer"

### Port Forwards
- PostgreSQL (5432)
- Kafka (9092) 
- Kafka UI (8080, 8090)

## Integration with e2e-helper.sh

The script works alongside the existing `e2e-helper.sh` script:
- `./scripts/setup-hybrid.sh stop` - High-level stop command
- `./e2e-helper.sh stop` - More detailed e2e process management

Both can be used together for comprehensive process management during local development.
