# E2E Background Process Management

## Overview

The E2E testing system now includes smart background process management that automatically handles existing processes to provide a seamless restart experience.

## Key Features

### 1. Smart Process Detection
- Automatically detects existing collector and consumer background processes
- Shows process IDs and current status
- Warns about conflicts before starting new processes

### 2. Auto-Cleanup Option
When option 7 is selected and existing processes are detected:
```
⚠️  Consumer already running (PID: 12345)
⚠️  Collector already running (PID: 12346)

🤔 Stop existing processes and continue with fresh E2E test?
1. Yes, stop existing and start fresh (recommended)
2. No, keep existing and skip E2E test

Select option (1-2): _
```

### 3. Background Process Management
- **Consumer**: Continuously monitors Kafka topic `cluster-info`
- **Collector**: Runs every 60 seconds to gather cluster data
- **PID Tracking**: Uses `/tmp/e2e-*-bg.pid` files for process management
- **Log Management**: Separate log files for each process

## Usage

### Option 7 Enhanced Workflow
1. **Infrastructure Check**: Smart deployment that reuses existing services
2. **Process Detection**: Automatically finds existing background processes
3. **User Choice**: Option to stop existing or skip test
4. **Clean Start**: Fresh E2E test with new processes
5. **Background Options**: Choose to run consumer, collector, or both in background

### Manual Management
Use the generated `e2e-helper.sh` script:

```bash
# Quick commands
./e2e-helper.sh start-both      # Start consumer + collector
./e2e-helper.sh status          # Check process status
./e2e-helper.sh stop            # Stop all processes

# Individual control
./e2e-helper.sh start-consumer  # Start only consumer
./e2e-helper.sh start-collector # Start only collector
```

### Shell Integration
Load functions into your shell:
```bash
source e2e-helper.sh
start_background_consumer
show_e2e_background_status
stop_e2e_background
```

## Process Lifecycle

### Starting Processes
- Checks for existing processes before starting
- Returns error if conflicts detected (when using helper script)
- Auto-cleanup option available in option 7

### Stopping Processes
- Graceful shutdown with `kill` signal
- Automatic PID file cleanup
- Status verification

### Monitoring
- Real-time log files: `/tmp/e2e-*-bg.log`
- Process status checking with `ps`
- Stale PID file detection and cleanup

## Enhanced Port Forwarding Integration

The `scripts/port-forward.sh` script now includes E2E process status:

```
📊 E2E Background Process Status:
✅ Consumer running (PID: 12345)
   📁 Logs: tail -f /tmp/e2e-consumer-bg.log
✅ Collector running (PID: 12346)
   📁 Logs: tail -f /tmp/e2e-collector-bg.log
```

## Files Created

- `e2e-helper.sh`: Background process management script
- `/tmp/e2e-consumer-bg.pid`: Consumer process ID
- `/tmp/e2e-collector-bg.pid`: Collector process ID
- `/tmp/e2e-consumer-bg.log`: Consumer logs
- `/tmp/e2e-collector-bg.log`: Collector logs

## Benefits

1. **Seamless Restarts**: No manual process cleanup required
2. **Smart Detection**: Knows about existing processes
3. **User Control**: Choose to stop or keep existing processes
4. **Unified Management**: One place to control all E2E processes
5. **Safe Operations**: Prevents duplicate processes
6. **Integrated Status**: Port forwarding script shows E2E status
