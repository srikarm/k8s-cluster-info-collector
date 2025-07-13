package models

import (
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// ClusterInfo represents a complete snapshot of cluster state
type ClusterInfo struct {
	Timestamp              time.Time                   `json:"timestamp"`
	Deployments            []DeploymentInfo            `json:"deployments"`
	Pods                   []PodInfo                   `json:"pods"`
	Nodes                  []NodeInfo                  `json:"nodes"`
	Services               []ServiceInfo               `json:"services"`
	Ingresses              []IngressInfo               `json:"ingresses"`
	ConfigMaps             []ConfigMapInfo             `json:"configmaps"`
	Secrets                []SecretInfo                `json:"secrets"`
	PersistentVolumes      []PersistentVolumeInfo      `json:"persistent_volumes"`
	PersistentVolumeClaims []PersistentVolumeClaimInfo `json:"persistent_volume_claims"`
}

// DeploymentInfo contains deployment details
type DeploymentInfo struct {
	Name            string                       `json:"name"`
	Namespace       string                       `json:"namespace"`
	CreatedTime     time.Time                    `json:"created_time"`
	Replicas        int32                        `json:"replicas"`
	ReadyReplicas   int32                        `json:"ready_replicas"`
	UpdatedReplicas int32                        `json:"updated_replicas"`
	Conditions      []appsv1.DeploymentCondition `json:"conditions"`
	Labels          map[string]string            `json:"labels"`
	Annotations     map[string]string            `json:"annotations"`
}

// PodInfo contains pod details and metrics
type PodInfo struct {
	Name              string            `json:"name"`
	Namespace         string            `json:"namespace"`
	DeploymentName    string            `json:"deployment_name"`
	CreatedTime       time.Time         `json:"created_time"`
	Phase             string            `json:"phase"`
	NodeName          string            `json:"node_name"`
	PodIP             string            `json:"pod_ip"`
	HostIP            string            `json:"host_ip"`
	RestartCount      int32             `json:"restart_count"`
	CPURequest        string            `json:"cpu_request"`
	CPULimit          string            `json:"cpu_limit"`
	MemoryRequest     string            `json:"memory_request"`
	MemoryLimit       string            `json:"memory_limit"`
	StorageRequest    string            `json:"storage_request"`
	Labels            map[string]string `json:"labels"`
	Annotations       map[string]string `json:"annotations"`
	ContainerStatuses []ContainerStatus `json:"container_statuses"`
}

// ContainerStatus represents the status of a container within a pod
type ContainerStatus struct {
	Name         string `json:"name"`
	Ready        bool   `json:"ready"`
	RestartCount int32  `json:"restart_count"`
	Image        string `json:"image"`
	State        string `json:"state"`
}

// NodeInfo contains node resource information and status
type NodeInfo struct {
	Name               string            `json:"name"`
	CreatedTime        time.Time         `json:"created_time"`
	Ready              bool              `json:"ready"`
	CPUCapacity        string            `json:"cpu_capacity"`
	MemoryCapacity     string            `json:"memory_capacity"`
	StorageCapacity    string            `json:"storage_capacity"`
	CPUAllocatable     string            `json:"cpu_allocatable"`
	MemoryAllocatable  string            `json:"memory_allocatable"`
	StorageAllocatable string            `json:"storage_allocatable"`
	OSImage            string            `json:"os_image"`
	KernelVersion      string            `json:"kernel_version"`
	KubeletVersion     string            `json:"kubelet_version"`
	Labels             map[string]string `json:"labels"`
	Annotations        map[string]string `json:"annotations"`
}

// ServiceInfo contains service details
type ServiceInfo struct {
	Name        string            `json:"name"`
	Namespace   string            `json:"namespace"`
	CreatedTime time.Time         `json:"created_time"`
	Type        string            `json:"type"`
	ClusterIP   string            `json:"cluster_ip"`
	ExternalIPs []string          `json:"external_ips"`
	Ports       []ServicePort     `json:"ports"`
	Selector    map[string]string `json:"selector"`
	Labels      map[string]string `json:"labels"`
	Annotations map[string]string `json:"annotations"`
}

// ServicePort represents a service port
type ServicePort struct {
	Name       string `json:"name"`
	Protocol   string `json:"protocol"`
	Port       int32  `json:"port"`
	TargetPort string `json:"target_port"`
	NodePort   int32  `json:"node_port,omitempty"`
}

// IngressInfo contains ingress details
type IngressInfo struct {
	Name        string            `json:"name"`
	Namespace   string            `json:"namespace"`
	CreatedTime time.Time         `json:"created_time"`
	Hosts       []string          `json:"hosts"`
	Paths       []IngressPath     `json:"paths"`
	TLS         []IngressTLS      `json:"tls"`
	Labels      map[string]string `json:"labels"`
	Annotations map[string]string `json:"annotations"`
}

// IngressPath represents an ingress path rule
type IngressPath struct {
	Path        string `json:"path"`
	PathType    string `json:"path_type"`
	ServiceName string `json:"service_name"`
	ServicePort int32  `json:"service_port"`
}

// IngressTLS represents TLS configuration for ingress
type IngressTLS struct {
	Hosts      []string `json:"hosts"`
	SecretName string   `json:"secret_name"`
}

// ConfigMapInfo contains ConfigMap details
type ConfigMapInfo struct {
	Name        string            `json:"name"`
	Namespace   string            `json:"namespace"`
	CreatedTime time.Time         `json:"created_time"`
	Data        map[string]string `json:"data"`
	BinaryData  map[string][]byte `json:"binary_data,omitempty"`
	Labels      map[string]string `json:"labels"`
	Annotations map[string]string `json:"annotations"`
}

// SecretInfo contains Secret details
type SecretInfo struct {
	Name        string            `json:"name"`
	Namespace   string            `json:"namespace"`
	CreatedTime time.Time         `json:"created_time"`
	Type        string            `json:"type"`
	DataKeys    []string          `json:"data_keys"` // Only store keys, not actual secret data
	Labels      map[string]string `json:"labels"`
	Annotations map[string]string `json:"annotations"`
}

// PersistentVolumeInfo contains PersistentVolume details
type PersistentVolumeInfo struct {
	Name          string            `json:"name"`
	CreatedTime   time.Time         `json:"created_time"`
	Capacity      string            `json:"capacity"`
	AccessModes   []string          `json:"access_modes"`
	ReclaimPolicy string            `json:"reclaim_policy"`
	StorageClass  string            `json:"storage_class"`
	VolumeMode    string            `json:"volume_mode"`
	Status        string            `json:"status"`
	ClaimRef      string            `json:"claim_ref,omitempty"`
	VolumeSource  string            `json:"volume_source"`
	Labels        map[string]string `json:"labels"`
	Annotations   map[string]string `json:"annotations"`
}

// PersistentVolumeClaimInfo contains PersistentVolumeClaim details
type PersistentVolumeClaimInfo struct {
	Name          string            `json:"name"`
	Namespace     string            `json:"namespace"`
	CreatedTime   time.Time         `json:"created_time"`
	RequestedSize string            `json:"requested_size"`
	AccessModes   []string          `json:"access_modes"`
	StorageClass  string            `json:"storage_class,omitempty"`
	VolumeMode    string            `json:"volume_mode"`
	Status        string            `json:"status"`
	VolumeName    string            `json:"volume_name,omitempty"`
	Labels        map[string]string `json:"labels"`
	Annotations   map[string]string `json:"annotations"`
}

// GetDeploymentName extracts deployment name from owner references
func GetDeploymentName(ownerRefs []metav1.OwnerReference) string {
	for _, ref := range ownerRefs {
		if ref.Kind == "ReplicaSet" {
			// For deployment pods, we need to trace back from ReplicaSet to Deployment
			// This is a simplified approach - in a real scenario, you might want to
			// make an additional API call to get the ReplicaSet and its owner
			return ref.Name
		}
	}
	return ""
}

// ExtractResourceInfo extracts resource requests and limits from containers
func ExtractResourceInfo(containers []corev1.Container, resourceName corev1.ResourceName) (string, string) {
	var totalRequest, totalLimit string
	for _, container := range containers {
		if container.Resources.Requests != nil {
			if req, ok := container.Resources.Requests[resourceName]; ok {
				totalRequest = req.String()
			}
		}
		if container.Resources.Limits != nil {
			if limit, ok := container.Resources.Limits[resourceName]; ok {
				totalLimit = limit.String()
			}
		}
	}
	return totalRequest, totalLimit
}
