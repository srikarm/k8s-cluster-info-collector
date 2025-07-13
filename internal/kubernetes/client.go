package kubernetes

import (
	"context"

	"github.com/sirupsen/logrus"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	metricsv1beta1 "k8s.io/metrics/pkg/client/clientset/versioned"

	"k8s-cluster-info-collector/internal/config"
)

// Client wraps Kubernetes clients with additional functionality
type Client struct {
	Clientset     *kubernetes.Clientset
	MetricsClient *metricsv1beta1.Clientset
	logger        *logrus.Logger
}

// NewClient creates a new Kubernetes client
func NewClient(cfg *config.KubeConfig, logger *logrus.Logger) (*Client, error) {
	var kubeConfig *rest.Config
	var err error

	if cfg.ConfigPath != "" {
		logger.WithField("config_path", cfg.ConfigPath).Info("Using kubeconfig file")
		kubeConfig, err = clientcmd.BuildConfigFromFlags("", cfg.ConfigPath)
	} else {
		logger.Info("Using in-cluster configuration")
		kubeConfig, err = rest.InClusterConfig()
	}

	if err != nil {
		return nil, err
	}

	clientset, err := kubernetes.NewForConfig(kubeConfig)
	if err != nil {
		return nil, err
	}

	// Initialize metrics client (optional, may not be available in all clusters)
	metricsClient, err := metricsv1beta1.NewForConfig(kubeConfig)
	if err != nil {
		logger.WithError(err).Warn("Failed to create metrics client, will continue without metrics")
		metricsClient = nil
	}

	logger.Info("Kubernetes client initialized successfully")

	return &Client{
		Clientset:     clientset,
		MetricsClient: metricsClient,
		logger:        logger,
	}, nil
}

// TestConnection tests the Kubernetes connection
func (c *Client) TestConnection(ctx context.Context) error {
	_, err := c.Clientset.Discovery().ServerVersion()
	if err != nil {
		return err
	}
	c.logger.Info("Kubernetes connection test successful")
	return nil
}
