package alerting

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/models"
)

// Alert represents an alert to be sent to Alertmanager
type Alert struct {
	Labels      map[string]string `json:"labels"`
	Annotations map[string]string `json:"annotations"`
	StartsAt    time.Time         `json:"startsAt"`
	EndsAt      time.Time         `json:"endsAt,omitempty"`
}

// AlertManager handles sending alerts to Alertmanager
type AlertManager struct {
	url    string
	client *http.Client
	logger *logrus.Logger
}

// Config holds alerting configuration
type Config struct {
	Enabled            bool
	AlertmanagerURL    string
	Timeout            time.Duration
	CollectionFailures bool
	ResourceThresholds bool
	NodeDownAlerts     bool
}

// NewAlertManager creates a new AlertManager instance
func NewAlertManager(config Config, logger *logrus.Logger) *AlertManager {
	if !config.Enabled {
		return nil
	}

	return &AlertManager{
		url: config.AlertmanagerURL,
		client: &http.Client{
			Timeout: config.Timeout,
		},
		logger: logger,
	}
}

// SendAlert sends an alert to Alertmanager
func (am *AlertManager) SendAlert(alert Alert) error {
	if am == nil {
		return nil // Alerting disabled
	}

	alerts := []Alert{alert}
	data, err := json.Marshal(alerts)
	if err != nil {
		return fmt.Errorf("failed to marshal alert: %w", err)
	}

	resp, err := am.client.Post(
		fmt.Sprintf("%s/api/v1/alerts", am.url),
		"application/json",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return fmt.Errorf("failed to send alert: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("alertmanager returned status %d", resp.StatusCode)
	}

	am.logger.WithFields(logrus.Fields{
		"alert":  alert.Labels["alertname"],
		"status": "sent",
	}).Info("Alert sent to Alertmanager")

	return nil
}

// SendCollectionFailureAlert sends an alert when collection fails
func (am *AlertManager) SendCollectionFailureAlert(err error, cluster string) error {
	alert := Alert{
		Labels: map[string]string{
			"alertname": "ClusterCollectionFailure",
			"severity":  "critical",
			"cluster":   cluster,
			"service":   "cluster-info-collector",
		},
		Annotations: map[string]string{
			"summary":     "Cluster data collection failed",
			"description": fmt.Sprintf("Failed to collect cluster data: %s", err.Error()),
		},
		StartsAt: time.Now(),
	}

	return am.SendAlert(alert)
}

// SendNodeDownAlert sends an alert when nodes are not ready
func (am *AlertManager) SendNodeDownAlert(nodeInfo models.NodeInfo, cluster string) error {
	status := "Ready"
	if !nodeInfo.Ready {
		status = "NotReady"
	}

	alert := Alert{
		Labels: map[string]string{
			"alertname": "NodeNotReady",
			"severity":  "warning",
			"cluster":   cluster,
			"node":      nodeInfo.Name,
			"service":   "cluster-info-collector",
		},
		Annotations: map[string]string{
			"summary":     fmt.Sprintf("Node %s is not ready", nodeInfo.Name),
			"description": fmt.Sprintf("Node %s has ready status: %s", nodeInfo.Name, status),
		},
		StartsAt: time.Now(),
	}

	return am.SendAlert(alert)
}

// SendResourceThresholdAlert sends an alert when resource usage is high
func (am *AlertManager) SendResourceThresholdAlert(resourceType string, count int, threshold int, cluster string) error {
	alert := Alert{
		Labels: map[string]string{
			"alertname":     "HighResourceCount",
			"severity":      "warning",
			"cluster":       cluster,
			"resource_type": resourceType,
			"service":       "cluster-info-collector",
		},
		Annotations: map[string]string{
			"summary":     fmt.Sprintf("High %s count detected", resourceType),
			"description": fmt.Sprintf("%s count (%d) exceeds threshold (%d)", resourceType, count, threshold),
		},
		StartsAt: time.Now(),
	}

	return am.SendAlert(alert)
}

// SendDatabaseConnectionAlert sends an alert when database connection fails
func (am *AlertManager) SendDatabaseConnectionAlert(err error, cluster string) error {
	alert := Alert{
		Labels: map[string]string{
			"alertname": "DatabaseConnectionFailure",
			"severity":  "critical",
			"cluster":   cluster,
			"service":   "cluster-info-collector",
		},
		Annotations: map[string]string{
			"summary":     "Database connection failed",
			"description": fmt.Sprintf("Failed to connect to database: %s", err.Error()),
		},
		StartsAt: time.Now(),
	}

	return am.SendAlert(alert)
}

// AnalyzeAndAlert analyzes cluster data and sends relevant alerts
func (am *AlertManager) AnalyzeAndAlert(snapshot *models.ClusterInfo, clusterName string, config Config) {
	if am == nil {
		return
	}

	// Check for node issues
	if config.NodeDownAlerts {
		for _, node := range snapshot.Nodes {
			if !node.Ready {
				if err := am.SendNodeDownAlert(node, clusterName); err != nil {
					am.logger.WithError(err).Error("Failed to send node down alert")
				}
			}
		}
	}

	// Check resource thresholds
	if config.ResourceThresholds {
		resourceCounts := map[string]int{
			"pods":        len(snapshot.Pods),
			"deployments": len(snapshot.Deployments),
			"services":    len(snapshot.Services),
			"configmaps":  len(snapshot.ConfigMaps),
		}

		// Define thresholds (could be configurable)
		thresholds := map[string]int{
			"pods":        1000,
			"deployments": 200,
			"services":    100,
			"configmaps":  500,
		}

		for resourceType, count := range resourceCounts {
			if threshold, exists := thresholds[resourceType]; exists && count > threshold {
				if err := am.SendResourceThresholdAlert(resourceType, count, threshold, clusterName); err != nil {
					am.logger.WithError(err).Errorf("Failed to send %s threshold alert", resourceType)
				}
			}
		}
	}
}
