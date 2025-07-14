package config

import (
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
	"github.com/sirupsen/logrus"
)

// Config holds application configuration
type Config struct {
	Database  DatabaseConfig
	Logger    LoggerConfig
	Kube      KubeConfig
	Metrics   MetricsConfig
	Retention RetentionConfig
	API       APIConfig
	Alerting  AlertingConfig
	Streaming StreamingConfig
	Kafka     KafkaConfig
	Consumer  ConsumerConfig
}

// DatabaseConfig holds database connection configuration
type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	Name     string
	SSLMode  string
}

// LoggerConfig holds logging configuration
type LoggerConfig struct {
	Level  logrus.Level
	Format string
}

// KubeConfig holds Kubernetes configuration
type KubeConfig struct {
	ConfigPath string
}

// MetricsConfig holds metrics configuration
type MetricsConfig struct {
	Enabled bool
	Address string
}

// RetentionConfig holds data retention configuration
type RetentionConfig struct {
	Enabled         bool
	MaxAge          time.Duration
	MaxSnapshots    int
	CleanupInterval time.Duration
	DeleteBatchSize int
}

// APIConfig holds REST API configuration
type APIConfig struct {
	Enabled bool
	Address string
	Prefix  string
}

// AlertingConfig holds alerting configuration
type AlertingConfig struct {
	Enabled            bool
	AlertmanagerURL    string
	Timeout            time.Duration
	CollectionFailures bool
	ResourceThresholds bool
	NodeDownAlerts     bool
}

// StreamingConfig holds WebSocket streaming configuration
type StreamingConfig struct {
	Enabled bool
	Address string
}

// KafkaConfig holds Kafka configuration
type KafkaConfig struct {
	Enabled   bool
	Brokers   []string
	Topic     string
	Partition int32
}

// ConsumerConfig holds consumer HTTP server configuration
type ConsumerConfig struct {
	Server ConsumerServerConfig
}

// ConsumerServerConfig holds consumer HTTP server configuration
type ConsumerServerConfig struct {
	Enabled bool
	Address string
	Port    int
}

// Load loads configuration from environment variables and .env file
func Load() (*Config, error) {
	// Load .env file if present
	_ = godotenv.Load()

	// Parse log level
	logLevel := logrus.InfoLevel
	if level := os.Getenv("LOG_LEVEL"); level != "" {
		if parsedLevel, err := logrus.ParseLevel(level); err == nil {
			logLevel = parsedLevel
		}
	}

	// Parse metrics enabled flag
	metricsEnabled := false
	if value := os.Getenv("METRICS_ENABLED"); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			metricsEnabled = parsedValue
		}
	}

	// Parse retention configuration
	retentionEnabled := false
	if value := os.Getenv("RETENTION_ENABLED"); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			retentionEnabled = parsedValue
		}
	}

	retentionMaxAge := 7 * 24 * time.Hour // Default: 7 days
	if value := os.Getenv("RETENTION_MAX_AGE"); value != "" {
		if parsedValue, err := time.ParseDuration(value); err == nil {
			retentionMaxAge = parsedValue
		}
	}

	retentionMaxSnapshots := 100 // Default: 100 snapshots
	if value := os.Getenv("RETENTION_MAX_SNAPSHOTS"); value != "" {
		if parsedValue, err := strconv.Atoi(value); err == nil {
			retentionMaxSnapshots = parsedValue
		}
	}

	retentionCleanupInterval := 6 * time.Hour // Default: 6 hours
	if value := os.Getenv("RETENTION_CLEANUP_INTERVAL"); value != "" {
		if parsedValue, err := time.ParseDuration(value); err == nil {
			retentionCleanupInterval = parsedValue
		}
	}

	retentionDeleteBatchSize := 50 // Default: 50 snapshots per batch
	if value := os.Getenv("RETENTION_DELETE_BATCH_SIZE"); value != "" {
		if parsedValue, err := strconv.Atoi(value); err == nil {
			retentionDeleteBatchSize = parsedValue
		}
	}

	// Parse API configuration
	apiEnabled := false
	if value := os.Getenv("API_ENABLED"); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			apiEnabled = parsedValue
		}
	}

	// Parse alerting configuration
	alertingEnabled := false
	if value := os.Getenv("ALERTING_ENABLED"); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			alertingEnabled = parsedValue
		}
	}

	alertingTimeout := 10 * time.Second
	if value := os.Getenv("ALERTING_TIMEOUT"); value != "" {
		if parsedValue, err := time.ParseDuration(value); err == nil {
			alertingTimeout = parsedValue
		}
	}

	// Parse streaming configuration
	streamingEnabled := false
	if value := os.Getenv("STREAMING_ENABLED"); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			streamingEnabled = parsedValue
		}
	}

	// Parse Kafka configuration
	kafkaEnabled := false
	if value := os.Getenv("KAFKA_ENABLED"); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			kafkaEnabled = parsedValue
		}
	}

	kafkaBrokers := []string{"localhost:9092"}
	if value := os.Getenv("KAFKA_BROKERS"); value != "" {
		// Split comma-separated brokers
		kafkaBrokers = strings.Split(strings.ReplaceAll(value, " ", ""), ",")
	}

	kafkaPartition := int32(0)
	if value := os.Getenv("KAFKA_PARTITION"); value != "" {
		if parsedValue, err := strconv.ParseInt(value, 10, 32); err == nil {
			kafkaPartition = int32(parsedValue)
		}
	}

	// Parse consumer configuration
	consumerServerEnabled := false
	if value := os.Getenv("CONSUMER_SERVER_ENABLED"); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			consumerServerEnabled = parsedValue
		}
	}

	consumerServerPort := 8083
	if value := os.Getenv("CONSUMER_SERVER_PORT"); value != "" {
		if parsedValue, err := strconv.Atoi(value); err == nil {
			consumerServerPort = parsedValue
		}
	}

	config := &Config{
		Database: DatabaseConfig{
			Host:     getEnvOrDefault("DB_HOST", "localhost"),
			Port:     getEnvOrDefault("DB_PORT", "5432"),
			User:     getEnvOrDefault("DB_USER", "postgres"),
			Password: getEnvOrDefault("DB_PASSWORD", ""),
			Name:     getEnvOrDefault("DB_NAME", "postgres"),
			SSLMode:  getEnvOrDefault("DB_SSL_MODE", "disable"),
		},
		Logger: LoggerConfig{
			Level:  logLevel,
			Format: getEnvOrDefault("LOG_FORMAT", "json"), // json or text
		},
		Kube: KubeConfig{
			ConfigPath: os.Getenv("KUBECONFIG"),
		},
		Metrics: MetricsConfig{
			Enabled: metricsEnabled,
			Address: getEnvOrDefault("METRICS_ADDRESS", ":8080"),
		},
		Retention: RetentionConfig{
			Enabled:         retentionEnabled,
			MaxAge:          retentionMaxAge,
			MaxSnapshots:    retentionMaxSnapshots,
			CleanupInterval: retentionCleanupInterval,
			DeleteBatchSize: retentionDeleteBatchSize,
		},
		API: APIConfig{
			Enabled: apiEnabled,
			Address: getEnvOrDefault("API_ADDRESS", ":8081"),
			Prefix:  getEnvOrDefault("API_PREFIX", "/api/v1"),
		},
		Alerting: AlertingConfig{
			Enabled:            alertingEnabled,
			AlertmanagerURL:    getEnvOrDefault("ALERTMANAGER_URL", "http://localhost:9093"),
			Timeout:            alertingTimeout,
			CollectionFailures: getEnvAsBool("ALERTING_COLLECTION_FAILURES", true),
			ResourceThresholds: getEnvAsBool("ALERTING_RESOURCE_THRESHOLDS", true),
			NodeDownAlerts:     getEnvAsBool("ALERTING_NODE_DOWN", true),
		},
		Streaming: StreamingConfig{
			Enabled: streamingEnabled,
			Address: getEnvOrDefault("STREAMING_ADDRESS", ":8082"),
		},
		Kafka: KafkaConfig{
			Enabled:   kafkaEnabled,
			Brokers:   kafkaBrokers,
			Topic:     getEnvOrDefault("KAFKA_TOPIC", "cluster-info"),
			Partition: kafkaPartition,
		},
		Consumer: ConsumerConfig{
			Server: ConsumerServerConfig{
				Enabled: consumerServerEnabled,
				Address: getEnvOrDefault("CONSUMER_SERVER_ADDRESS", ""),
				Port:    consumerServerPort,
			},
		},
	}

	return config, nil
}

// getEnvOrDefault returns environment variable value or default if not set
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvAsBool returns environment variable value as bool or default if not set
func getEnvAsBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if parsedValue, err := strconv.ParseBool(value); err == nil {
			return parsedValue
		}
	}
	return defaultValue
}
