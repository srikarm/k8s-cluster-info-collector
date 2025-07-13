package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"k8s-cluster-info-collector/internal/config"
	"k8s-cluster-info-collector/internal/database"
	"k8s-cluster-info-collector/internal/kafka"
	"k8s-cluster-info-collector/internal/logger"
	"k8s-cluster-info-collector/internal/store"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize logger
	loggerInstance := logger.New(&cfg.Logger)
	loggerInstance.Info("Starting Kafka Consumer Service")

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

	// Create context that can be cancelled
	ctx, cancel := context.WithCancel(context.Background())

	// Start consumer
	if err := consumer.Start(ctx); err != nil {
		loggerInstance.Fatalf("Failed to start Kafka consumer: %v", err)
	}

	loggerInstance.Info("Kafka consumer service started successfully")

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

	loggerInstance.Info("Kafka consumer service stopped")
}
