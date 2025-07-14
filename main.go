package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"k8s-cluster-info-collector/internal/app"
)

var (
	version    string
	commitHash string
)

func main() {
	// Create context that listens for the interrupt signal from the OS
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Initialize and run the application
	application, err := app.New(version, commitHash)
	if err != nil {
		log.Fatalf("Failed to initialize application: %v", err)
	}
	defer func() {
		if err := application.Close(); err != nil {
			log.Printf("Error during application shutdown: %v", err)
		}
	}()

	// Run the application
	if err := application.Run(ctx); err != nil {
		log.Fatalf("Application error: %v", err)
	}
}
