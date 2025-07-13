package models

import (
	"testing"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestClusterInfo(t *testing.T) {
	timestamp := time.Now()
	clusterInfo := ClusterInfo{
		Timestamp:   timestamp,
		Deployments: []DeploymentInfo{},
		Pods:        []PodInfo{},
		Nodes:       []NodeInfo{},
	}

	if clusterInfo.Timestamp != timestamp {
		t.Errorf("expected timestamp %v, got %v", timestamp, clusterInfo.Timestamp)
	}
}

func TestDeploymentInfo(t *testing.T) {
	deployment := DeploymentInfo{
		Name:            "test-deployment",
		Namespace:       "default",
		CreatedTime:     time.Now(),
		Replicas:        3,
		ReadyReplicas:   2,
		UpdatedReplicas: 3,
		Labels:          map[string]string{"app": "test"},
		Annotations:     map[string]string{"version": "1.0"},
	}

	if deployment.Name != "test-deployment" {
		t.Errorf("expected name 'test-deployment', got %s", deployment.Name)
	}
	if deployment.Replicas != 3 {
		t.Errorf("expected 3 replicas, got %d", deployment.Replicas)
	}
}

func TestPodInfo(t *testing.T) {
	pod := PodInfo{
		Name:           "test-pod",
		Namespace:      "default",
		DeploymentName: "test-deployment",
		CreatedTime:    time.Now(),
		Phase:          "Running",
		NodeName:       "node-1",
		PodIP:          "10.0.0.1",
		HostIP:         "192.168.1.1",
		RestartCount:   0,
		CPURequest:     "100m",
		CPULimit:       "200m",
		MemoryRequest:  "128Mi",
		MemoryLimit:    "256Mi",
		Labels:         map[string]string{"app": "test"},
		Annotations:    map[string]string{"version": "1.0"},
	}

	if pod.Name != "test-pod" {
		t.Errorf("expected name 'test-pod', got %s", pod.Name)
	}
	if pod.Phase != "Running" {
		t.Errorf("expected phase 'Running', got %s", pod.Phase)
	}
}

func TestNodeInfo(t *testing.T) {
	node := NodeInfo{
		Name:               "test-node",
		CreatedTime:        time.Now(),
		Ready:              true,
		CPUCapacity:        "2",
		MemoryCapacity:     "4Gi",
		StorageCapacity:    "100Gi",
		CPUAllocatable:     "1.5",
		MemoryAllocatable:  "3Gi",
		StorageAllocatable: "90Gi",
		OSImage:            "Ubuntu 20.04",
		KernelVersion:      "5.4.0",
		KubeletVersion:     "v1.24.0",
		Labels:             map[string]string{"node-type": "worker"},
		Annotations:        map[string]string{"zone": "us-east-1a"},
	}

	if node.Name != "test-node" {
		t.Errorf("expected name 'test-node', got %s", node.Name)
	}
	if !node.Ready {
		t.Error("expected node to be ready")
	}
}

func TestContainerStatus(t *testing.T) {
	status := ContainerStatus{
		Name:         "test-container",
		Ready:        true,
		RestartCount: 0,
		Image:        "nginx:latest",
		State:        "running",
	}

	if status.Name != "test-container" {
		t.Errorf("expected name 'test-container', got %s", status.Name)
	}
	if !status.Ready {
		t.Error("expected container to be ready")
	}
}

func TestExtractResourceInfo(t *testing.T) {
	containers := []corev1.Container{
		{
			Name: "test-container",
			Resources: corev1.ResourceRequirements{
				Requests: corev1.ResourceList{
					corev1.ResourceCPU:    resource.MustParse("100m"),
					corev1.ResourceMemory: resource.MustParse("128Mi"),
				},
				Limits: corev1.ResourceList{
					corev1.ResourceCPU:    resource.MustParse("200m"),
					corev1.ResourceMemory: resource.MustParse("256Mi"),
				},
			},
		},
	}

	cpuRequest, cpuLimit := ExtractResourceInfo(containers, corev1.ResourceCPU)
	memoryRequest, memoryLimit := ExtractResourceInfo(containers, corev1.ResourceMemory)

	if cpuRequest != "100m" {
		t.Errorf("expected CPU request '100m', got %s", cpuRequest)
	}
	if cpuLimit != "200m" {
		t.Errorf("expected CPU limit '200m', got %s", cpuLimit)
	}
	if memoryRequest != "128Mi" {
		t.Errorf("expected memory request '128Mi', got %s", memoryRequest)
	}
	if memoryLimit != "256Mi" {
		t.Errorf("expected memory limit '256Mi', got %s", memoryLimit)
	}
}

func TestGetDeploymentName(t *testing.T) {
	tests := []struct {
		name      string
		ownerRefs []metav1.OwnerReference
		expected  string
	}{
		{
			name: "with ReplicaSet owner",
			ownerRefs: []metav1.OwnerReference{
				{
					Kind: "ReplicaSet",
					Name: "test-deployment-abc123",
				},
			},
			expected: "test-deployment-abc123",
		},
		{
			name:      "no owners",
			ownerRefs: []metav1.OwnerReference{},
			expected:  "",
		},
		{
			name: "different owner kind",
			ownerRefs: []metav1.OwnerReference{
				{
					Kind: "DaemonSet",
					Name: "test-daemonset",
				},
			},
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetDeploymentName(tt.ownerRefs)
			if result != tt.expected {
				t.Errorf("expected %s, got %s", tt.expected, result)
			}
		})
	}
}
