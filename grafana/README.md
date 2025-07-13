# Grafana Dashboard Setup

This directory contains pre-built Grafana dashboards for the Kubernetes Cluster Info Collector.

## Available Dashboards

### 1. Cluster Overview Dashboard (`cluster-overview-dashboard.json`)
- **Collection Success Rate**: Shows the percentage of successful data collections
- **Collection Duration**: Displays how long collections take
- **Database Operation Duration**: Shows database performance
- **WebSocket Connections**: Number of active streaming connections
- **Resource Counts Over Time**: Timeline of pods, deployments, services, and nodes
- **Collection Status**: Success and failure rates over time
- **ConfigMaps and Secrets**: Count of configuration resources
- **Storage Resources**: Persistent volumes and claims

### 2. Alerts Dashboard (`alerts-dashboard.json`)
- **Active Alerts**: Current alerts from Alertmanager
- **Node Readiness**: Table showing node status
- **Resource Threshold Violations**: Resources exceeding thresholds
- **Collection Failures Over Time**: Timeline of collection failures
- **Database Connection Issues**: Database error tracking

## Installation

### Option 1: Import via Grafana UI
1. Open Grafana web interface
2. Go to "+" → "Import"
3. Copy and paste the JSON content from the dashboard files
4. Click "Import"

### Option 2: Import via API
```bash
# Import cluster overview dashboard
curl -X POST \
  -H "Content-Type: application/json" \
  -d @cluster-overview-dashboard.json \
  http://admin:admin@localhost:3000/api/dashboards/db

# Import alerts dashboard
curl -X POST \
  -H "Content-Type: application/json" \
  -d @alerts-dashboard.json \
  http://admin:admin@localhost:3000/api/dashboards/db
```

### Option 3: Grafana Provisioning
1. Copy dashboard files to Grafana's dashboards directory
2. Add to `grafana.ini` or via environment variables:
```ini
[dashboards]
default_home_dashboard_path = /var/lib/grafana/dashboards/cluster-overview-dashboard.json
```

## Prerequisites

### Data Sources
Make sure the following data sources are configured in Grafana:

1. **Prometheus** - For metrics collection
   - URL: `http://prometheus:9090` (or your Prometheus endpoint)
   - Access: Server (default)

2. **Alertmanager** (optional) - For alerts
   - URL: `http://alertmanager:9093` (or your Alertmanager endpoint)
   - Access: Server (default)

### Metrics Endpoint
Ensure the cluster-info-collector is running with metrics enabled:
```bash
METRICS_ENABLED=true ./cluster-info-collector
```

The metrics will be available at: `http://localhost:8080/metrics`

## Prometheus Configuration

Add the following to your `prometheus.yml` to scrape metrics:

```yaml
scrape_configs:
  - job_name: 'cluster-info-collector'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: /metrics
    scrape_interval: 30s
```

## Customization

### Adjusting Thresholds
You can customize alert thresholds in the dashboard panels:
1. Edit the dashboard
2. Select the panel to modify
3. Go to the "Thresholds" tab
4. Adjust the values as needed

### Adding New Panels
To add custom panels:
1. Edit the dashboard
2. Click "Add panel"
3. Use the available metrics:
   - `cluster_info_collections_total`
   - `cluster_info_collection_duration_seconds`
   - `cluster_info_resource_count`
   - `cluster_info_database_operation_duration_seconds`
   - `cluster_info_websocket_connections`

### Time Ranges
Default time ranges can be adjusted in the dashboard settings:
- Overview: 1 hour (good for operational monitoring)
- Alerts: 24 hours (good for historical analysis)

## Troubleshooting

### No Data Displayed
1. Check if Prometheus is configured correctly
2. Verify metrics endpoint is accessible: `curl http://localhost:8080/metrics`
3. Check Prometheus targets: `http://prometheus:9090/targets`

### Alerts Not Showing
1. Verify Alertmanager is configured as a data source
2. Check if alerting rules are defined in Prometheus
3. Ensure the cluster-info-collector has alerting enabled

### Performance Issues
1. Reduce refresh rate for heavy dashboards
2. Use longer time ranges for aggregated views
3. Consider using recording rules for complex queries

## Example Alerting Rules

Add these to your Prometheus configuration:

```yaml
groups:
  - name: cluster-info-collector
    rules:
      - alert: ClusterCollectionFailure
        expr: rate(cluster_info_collections_total{status="failure"}[5m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Cluster data collection failing"
          description: "Collection failures detected for {{ $labels.instance }}"

      - alert: HighCollectionDuration
        expr: cluster_info_collection_duration_seconds > 60
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Collection taking too long"
          description: "Collection duration is {{ $value }} seconds"
```
