package store

import (
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/lib/pq"
	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/database"
	"k8s-cluster-info-collector/internal/models"
)

// Store handles data persistence operations
type Store struct {
	db     *database.DB
	logger *logrus.Logger
}

// New creates a new store instance
func New(db *database.DB, logger *logrus.Logger) *Store {
	return &Store{
		db:     db,
		logger: logger,
	}
}

// StoreClusterInfo stores complete cluster information in the database
func (s *Store) StoreClusterInfo(info models.ClusterInfo) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Store cluster snapshot
	dataJSON, err := json.Marshal(info)
	if err != nil {
		return fmt.Errorf("failed to marshal cluster info: %w", err)
	}

	var snapshotID int
	err = tx.QueryRow(
		"INSERT INTO cluster_snapshots (timestamp, data) VALUES ($1, $2) RETURNING id",
		info.Timestamp, dataJSON,
	).Scan(&snapshotID)
	if err != nil {
		return fmt.Errorf("failed to insert cluster snapshot: %w", err)
	}

	s.logger.WithField("snapshot_id", snapshotID).Info("Created cluster snapshot")

	// Store deployments
	if err := s.storeDeployments(tx, snapshotID, info.Deployments); err != nil {
		return fmt.Errorf("failed to store deployments: %w", err)
	}

	// Store pods
	if err := s.storePods(tx, snapshotID, info.Pods); err != nil {
		return fmt.Errorf("failed to store pods: %w", err)
	}

	// Store nodes
	if err := s.storeNodes(tx, snapshotID, info.Nodes); err != nil {
		return fmt.Errorf("failed to store nodes: %w", err)
	}

	// Store services
	if err := s.storeServices(tx, snapshotID, info.Services); err != nil {
		return fmt.Errorf("failed to store services: %w", err)
	}

	// Store ingresses
	if err := s.storeIngresses(tx, snapshotID, info.Ingresses); err != nil {
		return fmt.Errorf("failed to store ingresses: %w", err)
	}

	// Store configmaps
	if err := s.storeConfigMaps(tx, snapshotID, info.ConfigMaps); err != nil {
		return fmt.Errorf("failed to store configmaps: %w", err)
	}

	// Store secrets
	if err := s.storeSecrets(tx, snapshotID, info.Secrets); err != nil {
		return fmt.Errorf("failed to store secrets: %w", err)
	}

	// Store persistent volumes
	if err := s.storePersistentVolumes(tx, snapshotID, info.PersistentVolumes); err != nil {
		return fmt.Errorf("failed to store persistent volumes: %w", err)
	}

	// Store persistent volume claims
	if err := s.storePersistentVolumeClaims(tx, snapshotID, info.PersistentVolumeClaims); err != nil {
		return fmt.Errorf("failed to store persistent volume claims: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	s.logger.WithFields(logrus.Fields{
		"snapshot_id":              snapshotID,
		"deployments":              len(info.Deployments),
		"pods":                     len(info.Pods),
		"nodes":                    len(info.Nodes),
		"services":                 len(info.Services),
		"ingresses":                len(info.Ingresses),
		"configmaps":               len(info.ConfigMaps),
		"secrets":                  len(info.Secrets),
		"persistent_volumes":       len(info.PersistentVolumes),
		"persistent_volume_claims": len(info.PersistentVolumeClaims),
	}).Info("Successfully stored cluster information")

	return nil
}

// storeDeployments stores deployment information
func (s *Store) storeDeployments(tx *sql.Tx, snapshotID int, deployments []models.DeploymentInfo) error {
	for _, deployment := range deployments {
		deploymentJSON, err := json.Marshal(deployment)
		if err != nil {
			return fmt.Errorf("failed to marshal deployment %s: %w", deployment.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO deployments (snapshot_id, name, namespace, created_time, replicas, 
				ready_replicas, updated_replicas, data) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
			snapshotID, deployment.Name, deployment.Namespace, deployment.CreatedTime,
			deployment.Replicas, deployment.ReadyReplicas, deployment.UpdatedReplicas, deploymentJSON)
		if err != nil {
			return fmt.Errorf("failed to insert deployment %s: %w", deployment.Name, err)
		}
	}
	return nil
}

// storePods stores pod information
func (s *Store) storePods(tx *sql.Tx, snapshotID int, pods []models.PodInfo) error {
	for _, pod := range pods {
		podJSON, err := json.Marshal(pod)
		if err != nil {
			return fmt.Errorf("failed to marshal pod %s: %w", pod.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO pods (snapshot_id, name, namespace, deployment_name, created_time, 
				phase, node_name, restart_count, cpu_request, cpu_limit, memory_request, 
				memory_limit, storage_request, data) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
			snapshotID, pod.Name, pod.Namespace, pod.DeploymentName, pod.CreatedTime,
			pod.Phase, pod.NodeName, pod.RestartCount, pod.CPURequest, pod.CPULimit,
			pod.MemoryRequest, pod.MemoryLimit, pod.StorageRequest, podJSON)
		if err != nil {
			return fmt.Errorf("failed to insert pod %s: %w", pod.Name, err)
		}
	}
	return nil
}

// storeNodes stores node information
func (s *Store) storeNodes(tx *sql.Tx, snapshotID int, nodes []models.NodeInfo) error {
	for _, node := range nodes {
		nodeJSON, err := json.Marshal(node)
		if err != nil {
			return fmt.Errorf("failed to marshal node %s: %w", node.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO nodes (snapshot_id, name, created_time, ready, cpu_capacity, 
				memory_capacity, storage_capacity, cpu_allocatable, memory_allocatable, 
				storage_allocatable, os_image, kernel_version, kubelet_version, data) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
			snapshotID, node.Name, node.CreatedTime, node.Ready, node.CPUCapacity,
			node.MemoryCapacity, node.StorageCapacity, node.CPUAllocatable,
			node.MemoryAllocatable, node.StorageAllocatable, node.OSImage,
			node.KernelVersion, node.KubeletVersion, nodeJSON)
		if err != nil {
			return fmt.Errorf("failed to insert node %s: %w", node.Name, err)
		}
	}
	return nil
}

// storeServices stores service information
func (s *Store) storeServices(tx *sql.Tx, snapshotID int, services []models.ServiceInfo) error {
	for _, service := range services {
		serviceJSON, err := json.Marshal(service)
		if err != nil {
			return fmt.Errorf("failed to marshal service %s: %w", service.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO services (snapshot_id, name, namespace, created_time, type, 
				cluster_ip, external_ips, data) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
			snapshotID, service.Name, service.Namespace, service.CreatedTime,
			service.Type, service.ClusterIP, pq.Array(service.ExternalIPs), serviceJSON)
		if err != nil {
			return fmt.Errorf("failed to insert service %s: %w", service.Name, err)
		}
	}
	return nil
}

// storeIngresses stores ingress information
func (s *Store) storeIngresses(tx *sql.Tx, snapshotID int, ingresses []models.IngressInfo) error {
	for _, ingress := range ingresses {
		ingressJSON, err := json.Marshal(ingress)
		if err != nil {
			return fmt.Errorf("failed to marshal ingress %s: %w", ingress.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO ingresses (snapshot_id, name, namespace, created_time, hosts, data) 
			VALUES ($1, $2, $3, $4, $5, $6)`,
			snapshotID, ingress.Name, ingress.Namespace, ingress.CreatedTime,
			pq.Array(ingress.Hosts), ingressJSON)
		if err != nil {
			return fmt.Errorf("failed to insert ingress %s: %w", ingress.Name, err)
		}
	}
	return nil
}

// storeConfigMaps stores configmap information
func (s *Store) storeConfigMaps(tx *sql.Tx, snapshotID int, configMaps []models.ConfigMapInfo) error {
	for _, cm := range configMaps {
		cmJSON, err := json.Marshal(cm)
		if err != nil {
			return fmt.Errorf("failed to marshal configmap %s: %w", cm.Name, err)
		}

		// Extract data keys
		var dataKeys []string
		for key := range cm.Data {
			dataKeys = append(dataKeys, key)
		}

		_, err = tx.Exec(`
			INSERT INTO configmaps (snapshot_id, name, namespace, created_time, data_keys, data) 
			VALUES ($1, $2, $3, $4, $5, $6)`,
			snapshotID, cm.Name, cm.Namespace, cm.CreatedTime, pq.Array(dataKeys), cmJSON)
		if err != nil {
			return fmt.Errorf("failed to insert configmap %s: %w", cm.Name, err)
		}
	}
	return nil
}

// storeSecrets stores secret information
func (s *Store) storeSecrets(tx *sql.Tx, snapshotID int, secrets []models.SecretInfo) error {
	for _, secret := range secrets {
		secretJSON, err := json.Marshal(secret)
		if err != nil {
			return fmt.Errorf("failed to marshal secret %s: %w", secret.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO secrets (snapshot_id, name, namespace, created_time, type, data_keys, data) 
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			snapshotID, secret.Name, secret.Namespace, secret.CreatedTime,
			secret.Type, pq.Array(secret.DataKeys), secretJSON)
		if err != nil {
			return fmt.Errorf("failed to insert secret %s: %w", secret.Name, err)
		}
	}
	return nil
}

// storePersistentVolumes stores persistent volume information
func (s *Store) storePersistentVolumes(tx *sql.Tx, snapshotID int, pvs []models.PersistentVolumeInfo) error {
	for _, pv := range pvs {
		pvJSON, err := json.Marshal(pv)
		if err != nil {
			return fmt.Errorf("failed to marshal persistent volume %s: %w", pv.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO persistent_volumes (snapshot_id, name, created_time, capacity, 
				access_modes, reclaim_policy, storage_class, status, volume_source, data) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			snapshotID, pv.Name, pv.CreatedTime, pv.Capacity,
			pq.Array(pv.AccessModes), pv.ReclaimPolicy, pv.StorageClass,
			pv.Status, pv.VolumeSource, pvJSON)
		if err != nil {
			return fmt.Errorf("failed to insert persistent volume %s: %w", pv.Name, err)
		}
	}
	return nil
}

// storePersistentVolumeClaims stores persistent volume claim information
func (s *Store) storePersistentVolumeClaims(tx *sql.Tx, snapshotID int, pvcs []models.PersistentVolumeClaimInfo) error {
	for _, pvc := range pvcs {
		pvcJSON, err := json.Marshal(pvc)
		if err != nil {
			return fmt.Errorf("failed to marshal persistent volume claim %s: %w", pvc.Name, err)
		}

		_, err = tx.Exec(`
			INSERT INTO persistent_volume_claims (snapshot_id, name, namespace, created_time, 
				requested_size, access_modes, storage_class, status, volume_name, data) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			snapshotID, pvc.Name, pvc.Namespace, pvc.CreatedTime,
			pvc.RequestedSize, pq.Array(pvc.AccessModes), pvc.StorageClass,
			pvc.Status, pvc.VolumeName, pvcJSON)
		if err != nil {
			return fmt.Errorf("failed to insert persistent volume claim %s: %w", pvc.Name, err)
		}
	}
	return nil
}
