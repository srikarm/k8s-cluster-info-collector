package collector

import (
	"context"
	"time"

	"github.com/sirupsen/logrus"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"k8s-cluster-info-collector/internal/kafka"
	"k8s-cluster-info-collector/internal/kubernetes"
	"k8s-cluster-info-collector/internal/models"
)

// ClusterCollector collects information from Kubernetes cluster
type ClusterCollector struct {
	client   *kubernetes.Client
	producer *kafka.Producer
	logger   *logrus.Logger
}

// New creates a new cluster collector
func New(client *kubernetes.Client, producer *kafka.Producer, logger *logrus.Logger) *ClusterCollector {
	return &ClusterCollector{
		client:   client,
		producer: producer,
		logger:   logger,
	}
}

// Collect gathers all cluster information and sends it to Kafka
func (c *ClusterCollector) Collect(ctx context.Context) error {
	timestamp := time.Now()
	c.logger.Info("Starting cluster information collection")

	// Collect all information
	deployments, err := c.collectDeployments(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(deployments)).Info("Collected deployments")

	pods, err := c.collectPods(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(pods)).Info("Collected pods")

	nodes, err := c.collectNodes(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(nodes)).Info("Collected nodes")

	services, err := c.collectServices(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(services)).Info("Collected services")

	ingresses, err := c.collectIngresses(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(ingresses)).Info("Collected ingresses")

	configMaps, err := c.collectConfigMaps(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(configMaps)).Info("Collected configmaps")

	secrets, err := c.collectSecrets(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(secrets)).Info("Collected secrets")

	persistentVolumes, err := c.collectPersistentVolumes(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(persistentVolumes)).Info("Collected persistent volumes")

	persistentVolumeClaims, err := c.collectPersistentVolumeClaims(ctx)
	if err != nil {
		return err
	}
	c.logger.WithField("count", len(persistentVolumeClaims)).Info("Collected persistent volume claims")

	// Create cluster snapshot
	clusterInfo := &models.ClusterInfo{
		Timestamp:              timestamp,
		Deployments:            deployments,
		Pods:                   pods,
		Nodes:                  nodes,
		Services:               services,
		Ingresses:              ingresses,
		ConfigMaps:             configMaps,
		Secrets:                secrets,
		PersistentVolumes:      persistentVolumes,
		PersistentVolumeClaims: persistentVolumeClaims,
	}

	// Send to Kafka
	if c.producer != nil {
		if err := c.producer.SendClusterInfo(clusterInfo); err != nil {
			c.logger.WithError(err).Error("Failed to send cluster info to Kafka")
			return err
		}
	}

	c.logger.Info("Cluster information collection completed and sent to Kafka")
	return nil
}

// CollectClusterInfo gathers all cluster information and returns it (for legacy/direct storage mode)
func (c *ClusterCollector) CollectClusterInfo(ctx context.Context) (*models.ClusterInfo, error) {
	timestamp := time.Now()
	c.logger.Info("Starting cluster information collection (legacy mode)")

	// Collect all information
	deployments, err := c.collectDeployments(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(deployments)).Info("Collected deployments")

	pods, err := c.collectPods(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(pods)).Info("Collected pods")

	nodes, err := c.collectNodes(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(nodes)).Info("Collected nodes")

	services, err := c.collectServices(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(services)).Info("Collected services")

	ingresses, err := c.collectIngresses(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(ingresses)).Info("Collected ingresses")

	configMaps, err := c.collectConfigMaps(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(configMaps)).Info("Collected configmaps")

	secrets, err := c.collectSecrets(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(secrets)).Info("Collected secrets")

	persistentVolumes, err := c.collectPersistentVolumes(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(persistentVolumes)).Info("Collected persistent volumes")

	persistentVolumeClaims, err := c.collectPersistentVolumeClaims(ctx)
	if err != nil {
		return nil, err
	}
	c.logger.WithField("count", len(persistentVolumeClaims)).Info("Collected persistent volume claims")

	// Create cluster snapshot
	clusterInfo := &models.ClusterInfo{
		Timestamp:              timestamp,
		Deployments:            deployments,
		Pods:                   pods,
		Nodes:                  nodes,
		Services:               services,
		Ingresses:              ingresses,
		ConfigMaps:             configMaps,
		Secrets:                secrets,
		PersistentVolumes:      persistentVolumes,
		PersistentVolumeClaims: persistentVolumeClaims,
	}

	c.logger.Info("Cluster information collection completed (legacy mode)")
	return clusterInfo, nil
}

// collectDeployments gathers deployment information
func (c *ClusterCollector) collectDeployments(ctx context.Context) ([]models.DeploymentInfo, error) {
	deploymentList, err := c.client.Clientset.AppsV1().Deployments("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var deployments []models.DeploymentInfo
	for _, deploy := range deploymentList.Items {
		replicas := int32(0)
		if deploy.Spec.Replicas != nil {
			replicas = *deploy.Spec.Replicas
		}

		deployments = append(deployments, models.DeploymentInfo{
			Name:            deploy.Name,
			Namespace:       deploy.Namespace,
			CreatedTime:     deploy.CreationTimestamp.Time,
			Replicas:        replicas,
			ReadyReplicas:   deploy.Status.ReadyReplicas,
			UpdatedReplicas: deploy.Status.UpdatedReplicas,
			Conditions:      deploy.Status.Conditions,
			Labels:          deploy.Labels,
			Annotations:     deploy.Annotations,
		})
	}

	return deployments, nil
}

// collectPods gathers pod information
func (c *ClusterCollector) collectPods(ctx context.Context) ([]models.PodInfo, error) {
	podList, err := c.client.Clientset.CoreV1().Pods("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var pods []models.PodInfo
	for _, pod := range podList.Items {
		// Extract resource requests and limits
		cpuRequest, cpuLimit := models.ExtractResourceInfo(pod.Spec.Containers, corev1.ResourceCPU)
		memoryRequest, memoryLimit := models.ExtractResourceInfo(pod.Spec.Containers, corev1.ResourceMemory)
		storageRequest, _ := models.ExtractResourceInfo(pod.Spec.Containers, corev1.ResourceStorage)

		// Get deployment name from owner references
		deploymentName := models.GetDeploymentName(pod.OwnerReferences)

		// Calculate total restart count and container statuses
		var totalRestartCount int32
		var containerStatuses []models.ContainerStatus
		for _, containerStatus := range pod.Status.ContainerStatuses {
			totalRestartCount += containerStatus.RestartCount
			state := "unknown"
			if containerStatus.State.Running != nil {
				state = "running"
			} else if containerStatus.State.Waiting != nil {
				state = "waiting"
			} else if containerStatus.State.Terminated != nil {
				state = "terminated"
			}

			containerStatuses = append(containerStatuses, models.ContainerStatus{
				Name:         containerStatus.Name,
				Ready:        containerStatus.Ready,
				RestartCount: containerStatus.RestartCount,
				Image:        containerStatus.Image,
				State:        state,
			})
		}

		pods = append(pods, models.PodInfo{
			Name:              pod.Name,
			Namespace:         pod.Namespace,
			DeploymentName:    deploymentName,
			CreatedTime:       pod.CreationTimestamp.Time,
			Phase:             string(pod.Status.Phase),
			NodeName:          pod.Spec.NodeName,
			PodIP:             pod.Status.PodIP,
			HostIP:            pod.Status.HostIP,
			RestartCount:      totalRestartCount,
			CPURequest:        cpuRequest,
			CPULimit:          cpuLimit,
			MemoryRequest:     memoryRequest,
			MemoryLimit:       memoryLimit,
			StorageRequest:    storageRequest,
			Labels:            pod.Labels,
			Annotations:       pod.Annotations,
			ContainerStatuses: containerStatuses,
		})
	}

	return pods, nil
}

// collectNodes gathers node information
func (c *ClusterCollector) collectNodes(ctx context.Context) ([]models.NodeInfo, error) {
	nodeList, err := c.client.Clientset.CoreV1().Nodes().List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var nodes []models.NodeInfo
	for _, node := range nodeList.Items {
		// Check node ready status
		ready := false
		for _, condition := range node.Status.Conditions {
			if condition.Type == corev1.NodeReady && condition.Status == corev1.ConditionTrue {
				ready = true
				break
			}
		}

		// Get resource information safely
		cpuCapacity := ""
		if cpu, ok := node.Status.Capacity[corev1.ResourceCPU]; ok {
			cpuCapacity = cpu.String()
		}
		memoryCapacity := ""
		if memory, ok := node.Status.Capacity[corev1.ResourceMemory]; ok {
			memoryCapacity = memory.String()
		}
		storageCapacity := ""
		if storage, ok := node.Status.Capacity[corev1.ResourceStorage]; ok {
			storageCapacity = storage.String()
		}
		cpuAllocatable := ""
		if cpu, ok := node.Status.Allocatable[corev1.ResourceCPU]; ok {
			cpuAllocatable = cpu.String()
		}
		memoryAllocatable := ""
		if memory, ok := node.Status.Allocatable[corev1.ResourceMemory]; ok {
			memoryAllocatable = memory.String()
		}
		storageAllocatable := ""
		if storage, ok := node.Status.Allocatable[corev1.ResourceStorage]; ok {
			storageAllocatable = storage.String()
		}

		nodes = append(nodes, models.NodeInfo{
			Name:               node.Name,
			CreatedTime:        node.CreationTimestamp.Time,
			Ready:              ready,
			CPUCapacity:        cpuCapacity,
			MemoryCapacity:     memoryCapacity,
			StorageCapacity:    storageCapacity,
			CPUAllocatable:     cpuAllocatable,
			MemoryAllocatable:  memoryAllocatable,
			StorageAllocatable: storageAllocatable,
			OSImage:            node.Status.NodeInfo.OSImage,
			KernelVersion:      node.Status.NodeInfo.KernelVersion,
			KubeletVersion:     node.Status.NodeInfo.KubeletVersion,
			Labels:             node.Labels,
			Annotations:        node.Annotations,
		})
	}

	return nodes, nil
}

// collectServices collects all services from the cluster
func (c *ClusterCollector) collectServices(ctx context.Context) ([]models.ServiceInfo, error) {
	serviceList, err := c.client.Clientset.CoreV1().Services("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var services []models.ServiceInfo
	for _, svc := range serviceList.Items {
		// Convert Kubernetes ServicePort to our ServicePort
		var ports []models.ServicePort
		for _, port := range svc.Spec.Ports {
			ports = append(ports, models.ServicePort{
				Name:       port.Name,
				Protocol:   string(port.Protocol),
				Port:       port.Port,
				TargetPort: port.TargetPort.String(),
				NodePort:   port.NodePort,
			})
		}

		services = append(services, models.ServiceInfo{
			Name:        svc.Name,
			Namespace:   svc.Namespace,
			CreatedTime: svc.CreationTimestamp.Time,
			Type:        string(svc.Spec.Type),
			ClusterIP:   svc.Spec.ClusterIP,
			ExternalIPs: svc.Spec.ExternalIPs,
			Ports:       ports,
			Selector:    svc.Spec.Selector,
			Labels:      svc.Labels,
			Annotations: svc.Annotations,
		})
	}

	return services, nil
}

// collectIngresses collects all ingresses from the cluster
func (c *ClusterCollector) collectIngresses(ctx context.Context) ([]models.IngressInfo, error) {
	ingressList, err := c.client.Clientset.NetworkingV1().Ingresses("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var ingresses []models.IngressInfo
	for _, ing := range ingressList.Items {
		// Extract hosts
		var hosts []string
		for _, rule := range ing.Spec.Rules {
			if rule.Host != "" {
				hosts = append(hosts, rule.Host)
			}
		}

		// Extract paths
		var paths []models.IngressPath
		for _, rule := range ing.Spec.Rules {
			if rule.HTTP != nil {
				for _, path := range rule.HTTP.Paths {
					pathType := ""
					if path.PathType != nil {
						pathType = string(*path.PathType)
					}

					serviceName := ""
					var servicePort int32
					if path.Backend.Service != nil {
						serviceName = path.Backend.Service.Name
						servicePort = path.Backend.Service.Port.Number
					}

					paths = append(paths, models.IngressPath{
						Path:        path.Path,
						PathType:    pathType,
						ServiceName: serviceName,
						ServicePort: servicePort,
					})
				}
			}
		}

		// Extract TLS configuration
		var tls []models.IngressTLS
		for _, tlsConfig := range ing.Spec.TLS {
			tls = append(tls, models.IngressTLS{
				Hosts:      tlsConfig.Hosts,
				SecretName: tlsConfig.SecretName,
			})
		}

		ingresses = append(ingresses, models.IngressInfo{
			Name:        ing.Name,
			Namespace:   ing.Namespace,
			CreatedTime: ing.CreationTimestamp.Time,
			Hosts:       hosts,
			Paths:       paths,
			TLS:         tls,
			Labels:      ing.Labels,
			Annotations: ing.Annotations,
		})
	}

	return ingresses, nil
}

// collectConfigMaps collects all configmaps from the cluster
func (c *ClusterCollector) collectConfigMaps(ctx context.Context) ([]models.ConfigMapInfo, error) {
	configMapList, err := c.client.Clientset.CoreV1().ConfigMaps("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var configMaps []models.ConfigMapInfo
	for _, cm := range configMapList.Items {
		configMaps = append(configMaps, models.ConfigMapInfo{
			Name:        cm.Name,
			Namespace:   cm.Namespace,
			CreatedTime: cm.CreationTimestamp.Time,
			Data:        cm.Data,
			BinaryData:  cm.BinaryData,
			Labels:      cm.Labels,
			Annotations: cm.Annotations,
		})
	}

	return configMaps, nil
}

// collectSecrets collects all secrets from the cluster (metadata only, not actual secret data)
func (c *ClusterCollector) collectSecrets(ctx context.Context) ([]models.SecretInfo, error) {
	secretList, err := c.client.Clientset.CoreV1().Secrets("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var secrets []models.SecretInfo
	for _, secret := range secretList.Items {
		// Only collect keys, not the actual secret data for security
		var dataKeys []string
		for key := range secret.Data {
			dataKeys = append(dataKeys, key)
		}

		secrets = append(secrets, models.SecretInfo{
			Name:        secret.Name,
			Namespace:   secret.Namespace,
			CreatedTime: secret.CreationTimestamp.Time,
			Type:        string(secret.Type),
			DataKeys:    dataKeys,
			Labels:      secret.Labels,
			Annotations: secret.Annotations,
		})
	}

	return secrets, nil
}

// collectPersistentVolumes collects all persistent volumes from the cluster
func (c *ClusterCollector) collectPersistentVolumes(ctx context.Context) ([]models.PersistentVolumeInfo, error) {
	pvList, err := c.client.Clientset.CoreV1().PersistentVolumes().List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var pvs []models.PersistentVolumeInfo
	for _, pv := range pvList.Items {
		// Convert access modes to strings
		var accessModes []string
		for _, mode := range pv.Spec.AccessModes {
			accessModes = append(accessModes, string(mode))
		}

		// Get capacity
		capacity := ""
		if storage, ok := pv.Spec.Capacity[corev1.ResourceStorage]; ok {
			capacity = storage.String()
		}

		// Get claim reference
		claimRef := ""
		if pv.Spec.ClaimRef != nil {
			claimRef = pv.Spec.ClaimRef.Namespace + "/" + pv.Spec.ClaimRef.Name
		}

		// Get volume source type
		volumeSource := ""
		if pv.Spec.PersistentVolumeSource.HostPath != nil {
			volumeSource = "hostPath"
		} else if pv.Spec.PersistentVolumeSource.NFS != nil {
			volumeSource = "nfs"
		} else if pv.Spec.PersistentVolumeSource.AWSElasticBlockStore != nil {
			volumeSource = "awsElasticBlockStore"
		} else if pv.Spec.PersistentVolumeSource.GCEPersistentDisk != nil {
			volumeSource = "gcePersistentDisk"
		} else {
			volumeSource = "other"
		}

		// Get volume mode
		volumeMode := ""
		if pv.Spec.VolumeMode != nil {
			volumeMode = string(*pv.Spec.VolumeMode)
		}

		pvs = append(pvs, models.PersistentVolumeInfo{
			Name:          pv.Name,
			CreatedTime:   pv.CreationTimestamp.Time,
			Capacity:      capacity,
			AccessModes:   accessModes,
			ReclaimPolicy: string(pv.Spec.PersistentVolumeReclaimPolicy),
			StorageClass:  pv.Spec.StorageClassName,
			VolumeMode:    volumeMode,
			Status:        string(pv.Status.Phase),
			ClaimRef:      claimRef,
			VolumeSource:  volumeSource,
			Labels:        pv.Labels,
			Annotations:   pv.Annotations,
		})
	}

	return pvs, nil
}

// collectPersistentVolumeClaims collects all persistent volume claims from the cluster
func (c *ClusterCollector) collectPersistentVolumeClaims(ctx context.Context) ([]models.PersistentVolumeClaimInfo, error) {
	pvcList, err := c.client.Clientset.CoreV1().PersistentVolumeClaims("").List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	var pvcs []models.PersistentVolumeClaimInfo
	for _, pvc := range pvcList.Items {
		// Convert access modes to strings
		var accessModes []string
		for _, mode := range pvc.Spec.AccessModes {
			accessModes = append(accessModes, string(mode))
		}

		// Get requested size
		requestedSize := ""
		if storage, ok := pvc.Spec.Resources.Requests[corev1.ResourceStorage]; ok {
			requestedSize = storage.String()
		}

		// Get storage class
		storageClass := ""
		if pvc.Spec.StorageClassName != nil {
			storageClass = *pvc.Spec.StorageClassName
		}

		// Get volume mode
		volumeMode := ""
		if pvc.Spec.VolumeMode != nil {
			volumeMode = string(*pvc.Spec.VolumeMode)
		}

		pvcs = append(pvcs, models.PersistentVolumeClaimInfo{
			Name:          pvc.Name,
			Namespace:     pvc.Namespace,
			CreatedTime:   pvc.CreationTimestamp.Time,
			RequestedSize: requestedSize,
			AccessModes:   accessModes,
			StorageClass:  storageClass,
			VolumeMode:    volumeMode,
			Status:        string(pvc.Status.Phase),
			VolumeName:    pvc.Spec.VolumeName,
			Labels:        pvc.Labels,
			Annotations:   pvc.Annotations,
		})
	}

	return pvcs, nil
}
