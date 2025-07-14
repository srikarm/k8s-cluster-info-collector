package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"k8s-cluster-info-collector/internal/api"
	"k8s-cluster-info-collector/internal/config"
	"k8s-cluster-info-collector/internal/database"
	"k8s-cluster-info-collector/internal/kafka"
	"k8s-cluster-info-collector/internal/logger"
	"k8s-cluster-info-collector/internal/store"
	"k8s-cluster-info-collector/internal/streaming"
)

// Build information (to be set via ldflags during build)
var (
	version    = "dev"
	commitHash = "unknown"
	buildTime  = "unknown"
)

func main() {
	// Build information is now at package level for ldflags

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize logger
	loggerInstance := logger.New(&cfg.Logger)
	loggerInstance.Infof("Starting Kafka Consumer Service v%s (commit: %s, built: %s)", version, commitHash, buildTime)

	// Initialize database
	db, err := database.New(&cfg.Database, loggerInstance)
	if err != nil {
		loggerInstance.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	// Initialize store
	dataStore := store.New(db, loggerInstance)

	// Initialize Kafka consumer
	if !cfg.Kafka.Enabled {
		loggerInstance.Fatal("Kafka must be enabled for consumer service")
	}

	consumer, err := kafka.NewConsumer(&cfg.Kafka, dataStore, loggerInstance)
	if err != nil {
		loggerInstance.Fatalf("Failed to initialize Kafka consumer: %v", err)
	}

	// Initialize API server (full REST API)
	apiConfig := api.APIConfig{
		Enabled: cfg.Consumer.Server.Enabled,
		Address: fmt.Sprintf("%s:%d", cfg.Consumer.Server.Address, cfg.Consumer.Server.Port),
		Prefix:  "/api/v1",
	}

	// Streaming hub (optional, can be nil if not used)
	var streamingHub *streaming.Hub = nil

	apiServer := api.New(db, loggerInstance, apiConfig, streamingHub, version, commitHash)

	// Start API server (runs in goroutine)
	go func() {
		if err := apiServer.Start(); err != nil {
			loggerInstance.Errorf("Failed to start API server: %v", err)
		}
	}()

	// (Removed: consumer health/metrics server startup. All endpoints are now served by the unified API server.)

	// Create context that can be cancelled
	ctx, cancel := context.WithCancel(context.Background())

	// Start consumer
	if err := consumer.Start(ctx); err != nil {
		loggerInstance.Fatalf("Failed to start Kafka consumer: %v", err)
	}

	loggerInstance.Info("Kafka consumer service started successfully")
	if cfg.Consumer.Server.Enabled {
		loggerInstance.Infof("API server available at http://%s:%d/api/v1", cfg.Consumer.Server.Address, cfg.Consumer.Server.Port)
		loggerInstance.Infof("Health endpoint: http://%s:%d/api/v1/health", cfg.Consumer.Server.Address, cfg.Consumer.Server.Port)
		loggerInstance.Infof("Metrics endpoint: http://%s:%d/api/v1/metrics", cfg.Consumer.Server.Address, cfg.Consumer.Server.Port)
	}

	// Wait for interrupt signal to gracefully shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	loggerInstance.Info("Received shutdown signal, stopping consumer...")

	// Cancel context and stop consumer
	cancel()
	if err := consumer.Stop(); err != nil {
		loggerInstance.Errorf("Error stopping consumer: %v", err)
	}

	// No explicit API server shutdown (for simplicity); add if needed

	loggerInstance.Info("Kafka consumer service stopped")
}
