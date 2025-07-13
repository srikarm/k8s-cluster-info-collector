package main

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"testing"
	"time"

	"k8s-cluster-info-collector/internal/app"

	_ "github.com/lib/pq"
)

// TestIntegration tests the full application flow
// This test requires a PostgreSQL database and Kubernetes cluster
func TestIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test in short mode")
	}

	// Check if required environment variables are set
	if os.Getenv("DB_HOST") == "" {
		t.Skip("DB_HOST not set, skipping integration test")
	}

	// Set up test environment
	os.Setenv("DB_NAME", "cluster_info_test")
	defer os.Unsetenv("DB_NAME")

	// Create test database
	if err := createTestDatabase(); err != nil {
		t.Fatalf("failed to create test database: %v", err)
	}
	defer cleanupTestDatabase()

	// Initialize application
	application, err := app.New()
	if err != nil {
		t.Fatalf("failed to initialize application: %v", err)
	}
	defer func() {
		if err := application.Close(); err != nil {
			t.Logf("error during application cleanup: %v", err)
		}
	}()

	// Run the application with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Test that the application can run successfully
	err = application.Run(ctx)
	if err != nil && err != context.DeadlineExceeded {
		t.Fatalf("application run failed: %v", err)
	}

	// Verify data was collected and stored
	if err := verifyDataStored(); err != nil {
		t.Errorf("data verification failed: %v", err)
	}
}

func createTestDatabase() error {
	// Connect to default postgres database to create test database
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	if dbPort == "" {
		dbPort = "5432"
	}
	dbUser := os.Getenv("DB_USER")
	if dbUser == "" {
		dbUser = "postgres"
	}
	dbPassword := os.Getenv("DB_PASSWORD")

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=postgres sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return err
	}
	defer db.Close()

	// Create test database
	_, err = db.Exec("CREATE DATABASE cluster_info_test")
	if err != nil {
		// Database might already exist, which is fine
		return nil
	}

	return nil
}

func cleanupTestDatabase() error {
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	if dbPort == "" {
		dbPort = "5432"
	}
	dbUser := os.Getenv("DB_USER")
	if dbUser == "" {
		dbUser = "postgres"
	}
	dbPassword := os.Getenv("DB_PASSWORD")

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=postgres sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return err
	}
	defer db.Close()

	// Drop test database
	_, err = db.Exec("DROP DATABASE IF EXISTS cluster_info_test")
	return err
}

func verifyDataStored() error {
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	if dbPort == "" {
		dbPort = "5432"
	}
	dbUser := os.Getenv("DB_USER")
	if dbUser == "" {
		dbUser = "postgres"
	}
	dbPassword := os.Getenv("DB_PASSWORD")

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=cluster_info_test sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return err
	}
	defer db.Close()

	// Check if cluster_snapshots table has data
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM cluster_snapshots").Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to query cluster_snapshots: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("no cluster snapshots found in database")
	}

	return nil
}
