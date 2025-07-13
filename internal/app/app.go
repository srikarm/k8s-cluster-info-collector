package app

import (
	"context"
	"fmt"

	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/alerting"
	"k8s-cluster-info-collector/internal/api"
	"k8s-cluster-info-collector/internal/collector"
	"k8s-cluster-info-collector/internal/config"
	"k8s-cluster-info-collector/internal/database"
	"k8s-cluster-info-collector/internal/kafka"
	"k8s-cluster-info-collector/internal/kubernetes"
	"k8s-cluster-info-collector/internal/logger"
	"k8s-cluster-info-collector/internal/metrics"
	"k8s-cluster-info-collector/internal/retention"
	"k8s-cluster-info-collector/internal/store"
	"k8s-cluster-info-collector/internal/streaming"
)

// App represents the main application
type App struct {
	config        *config.Config
	logger        *logrus.Logger
	db            *database.DB
	k8sClient     *kubernetes.Client
	collector     *collector.ClusterCollector
	store         *store.Store
	kafkaProducer *kafka.Producer
	// Note: kafkaConsumer removed - handled by separate consumer binary
	metrics      *metrics.Metrics
	retention    *retention.RetentionManager
	alerting     *alerting.AlertManager
	apiServer    *api.Server
	streamingHub *streaming.Hub
}

// New creates a new application instance
func New() (*App, error) {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		return nil, fmt.Errorf("failed to load configuration: %w", err)
	}

	// Initialize logger
	log := logger.New(&cfg.Logger)
	log.Info("Starting Cluster Info Collector")

	// Initialize database only if Kafka is not enabled
	// In Kafka mode, collector writes to Kafka only, consumer handles database
	var db *database.DB
	if !cfg.Kafka.Enabled {
		var err error
		db, err = database.New(&cfg.Database, log)
		if err != nil {
			return nil, fmt.Errorf("failed to initialize database: %w", err)
		}
		log.Info("Database connection initialized (legacy mode)")
	} else {
		log.Info("Skipping database initialization (Kafka mode - collector writes to Kafka only)")
	}

	// Initialize Kubernetes client
	k8sClient, err := kubernetes.NewClient(&cfg.Kube, log)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize Kubernetes client: %w", err)
	}

	// Test Kubernetes connection
	ctx := context.Background()
	if err := k8sClient.TestConnection(ctx); err != nil {
		return nil, fmt.Errorf("failed to connect to Kubernetes cluster: %w", err)
	}

	// Initialize Kafka producer if enabled
	var kafkaProducer *kafka.Producer
	if cfg.Kafka.Enabled {
		kafkaProducer, err = kafka.NewProducer(&cfg.Kafka, log)
		if err != nil {
			return nil, fmt.Errorf("failed to initialize Kafka producer: %w", err)
		}
	}

	// Initialize store and Kafka consumer
	// Store is only needed for legacy mode (collector writes directly to database)
	var dataStore *store.Store
	if !cfg.Kafka.Enabled {
		// Legacy mode: collector uses store to write directly to database
		dataStore = store.New(db, log)
	}

	// Note: Kafka consumer is handled by separate consumer binary (cmd/consumer/main.go)
	// The collector only produces to Kafka when Kafka is enabled

	// Initialize collector with Kafka producer
	clusterCollector := collector.New(k8sClient, kafkaProducer, log)

	// Collector runs as Job - no HTTP servers or background services needed
	// All services (metrics, API, streaming, retention) are disabled for Job mode

	return &App{
		config:        cfg,
		logger:        log,
		db:            db,
		k8sClient:     k8sClient,
		collector:     clusterCollector,
		store:         dataStore,
		kafkaProducer: kafkaProducer,
		// All HTTP servers and background services removed for Job mode
		metrics:      nil,
		retention:    nil,
		alerting:     nil,
		apiServer:    nil,
		streamingHub: nil,
	}, nil
}

// Run executes the main application logic
func (a *App) Run(ctx context.Context) error {
	// Note: Kafka consumer is handled by separate consumer binary
	// This collector only produces to Kafka when Kafka is enabled

	// Collector always runs in one-shot mode like a Kubernetes Job:
	// 1. Start up and verify connectivity to services
	// 2. Collect cluster information
	// 3. Write to output destination (Kafka or Database)
	// 4. Exit cleanly
	// This behavior is consistent whether running as K8s Job, CronJob, or locally

	a.logger.Info("Starting cluster information collector (Job mode)")
	a.logger.Info("Collector behavior: start → collect → write → exit")

	// Run single collection and exit (Job behavior)
	return a.collectAndStore(ctx)
}

// collectAndStore performs a single collection and storage cycle
func (a *App) collectAndStore(ctx context.Context) error {
	a.logger.Info("Starting cluster information collection")

	// Record collection start
	if a.metrics != nil {
		a.metrics.RecordCollectionStart()
	}

	// Collect cluster information and send to Kafka (if enabled) or store directly
	if a.config.Kafka.Enabled {
		// Collect and send to Kafka
		if err := a.collector.Collect(ctx); err != nil {
			if a.metrics != nil {
				a.metrics.RecordCollectionError()
			}
			// Send alert for collection failure
			if a.alerting != nil {
				a.alerting.SendCollectionFailureAlert(err, "default")
			}
			return fmt.Errorf("failed to collect and send cluster information: %w", err)
		}

		// When using Kafka, the data will be processed by the consumer
		if a.metrics != nil {
			a.metrics.RecordCollectionSuccess()
		}
		a.logger.Info("Cluster information collection completed and sent to Kafka")
		return nil
	} else {
		// Legacy mode: collect and store directly to database
		a.logger.Info("Running in legacy mode - storing directly to database")

		// Collect cluster information
		clusterInfo, err := a.collector.CollectClusterInfo(ctx)
		if err != nil {
			if a.metrics != nil {
				a.metrics.RecordCollectionError()
			}
			// Send alert for collection failure
			if a.alerting != nil {
				a.alerting.SendCollectionFailureAlert(err, "default")
			}
			return fmt.Errorf("failed to collect cluster information: %w", err)
		}

		// Store directly to database
		if err := a.store.StoreClusterInfo(*clusterInfo); err != nil {
			if a.metrics != nil {
				a.metrics.RecordCollectionError()
			}
			return fmt.Errorf("failed to store cluster information: %w", err)
		}

		if a.metrics != nil {
			a.metrics.RecordCollectionSuccess()
		}
		a.logger.Info("Cluster information collection completed and stored to database")
		return nil
	}
}

// Close gracefully shuts down the application
func (a *App) Close() error {
	a.logger.Info("Shutting down application")

	// Note: Kafka consumer is handled by separate consumer binary

	// Close Kafka producer
	if a.kafkaProducer != nil {
		if err := a.kafkaProducer.Close(); err != nil {
			a.logger.WithError(err).Error("Failed to close Kafka producer")
		}
	}

	if a.db != nil {
		if err := a.db.Close(); err != nil {
			a.logger.WithError(err).Error("Failed to close database connection")
			return err
		}
	}

	a.logger.Info("Application shutdown complete")
	return nil
}
