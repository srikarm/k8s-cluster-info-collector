package main

import (
	"fmt"
	"log"

	"k8s-cluster-info-collector/internal/config"
	"k8s-cluster-info-collector/internal/logger"
)

// Simple test to verify modular components can be imported and used
func testModules() {
	fmt.Println("Testing modular architecture...")

	// Test config loading
	cfg, err := config.Load()
	if err != nil {
		log.Printf("Config loading test: FAILED - %v", err)
	} else {
		fmt.Printf("Config loading test: PASSED - DB Host: %s\n", cfg.Database.Host)
	}

	// Test logger initialization
	loggerInstance := logger.New(&cfg.Logger)
	loggerInstance.Info("Logger test: PASSED - Logger initialized successfully")

	fmt.Println("Modular architecture test completed!")
}
