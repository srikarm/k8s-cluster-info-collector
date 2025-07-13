-- Sample queries for the cluster_info database

-- Get the latest cluster snapshot summary
SELECT 
    timestamp,
    jsonb_array_length(data->'deployments') as deployment_count,
    jsonb_array_length(data->'pods') as pod_count,
    jsonb_array_length(data->'nodes') as node_count
FROM cluster_snapshots 
ORDER BY timestamp DESC 
LIMIT 1;

-- Get deployment health overview from latest snapshot
SELECT 
    name,
    namespace,
    replicas,
    ready_replicas,
    CASE 
        WHEN ready_replicas = replicas THEN 'Healthy'
        WHEN ready_replicas > 0 THEN 'Degraded'
        ELSE 'Unhealthy'
    END as health_status
FROM deployments 
WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
ORDER BY namespace, name;

-- Get pods with resource constraints (no limits set)
SELECT 
    name,
    namespace,
    deployment_name,
    cpu_request,
    cpu_limit,
    memory_request,
    memory_limit,
    CASE 
        WHEN cpu_limit = '' AND memory_limit = '' THEN 'No Limits'
        WHEN cpu_limit = '' THEN 'No CPU Limit'
        WHEN memory_limit = '' THEN 'No Memory Limit'
        ELSE 'Limits Set'
    END as resource_status
FROM pods 
WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
    AND (cpu_limit = '' OR memory_limit = '')
ORDER BY namespace, name;

-- Get node resource utilization summary
SELECT 
    name,
    ready,
    cpu_capacity,
    memory_capacity,
    cpu_allocatable,
    memory_allocatable,
    ROUND(
        (SELECT COUNT(*) FROM pods p WHERE p.node_name = n.name AND p.snapshot_id = n.snapshot_id)::numeric, 0
    ) as pod_count
FROM nodes n
WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
ORDER BY name;

-- Get pods with high restart counts (potential issues)
SELECT 
    name,
    namespace,
    deployment_name,
    restart_count,
    phase,
    node_name,
    created_time
FROM pods 
WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
    AND restart_count > 0
ORDER BY restart_count DESC, created_time DESC;

-- Get deployment rollout history (comparing recent snapshots)
WITH recent_snapshots AS (
    SELECT id, timestamp 
    FROM cluster_snapshots 
    ORDER BY timestamp DESC 
    LIMIT 5
)
SELECT 
    d.name,
    d.namespace,
    cs.timestamp,
    d.replicas,
    d.ready_replicas,
    d.updated_replicas
FROM deployments d
JOIN recent_snapshots cs ON d.snapshot_id = cs.id
ORDER BY d.name, d.namespace, cs.timestamp DESC;

-- Get storage usage by pods
SELECT 
    namespace,
    COUNT(*) as pod_count,
    COUNT(CASE WHEN storage_request != '' THEN 1 END) as pods_with_storage_request,
    STRING_AGG(DISTINCT storage_request, ', ') as storage_requests
FROM pods 
WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
GROUP BY namespace
ORDER BY pod_count DESC;

-- Performance metrics: container status distribution
SELECT 
    phase,
    COUNT(*) as pod_count,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 2) as percentage
FROM pods 
WHERE snapshot_id = (SELECT MAX(id) FROM cluster_snapshots)
GROUP BY phase
ORDER BY pod_count DESC;
