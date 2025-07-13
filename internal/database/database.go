package database

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/config"
)

// DB wraps the database connection with additional functionality
type DB struct {
	*sql.DB
	logger *logrus.Logger
}

// New creates a new database connection
func New(cfg *config.DatabaseConfig, logger *logrus.Logger) (*DB, error) {
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.Name, cfg.SSLMode)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	dbWrapper := &DB{
		DB:     db,
		logger: logger,
	}

	// Create tables if they don't exist
	if err := dbWrapper.createTables(); err != nil {
		return nil, fmt.Errorf("failed to create tables: %w", err)
	}

	logger.Info("Database connection established successfully")
	return dbWrapper, nil
}

// createTables creates the necessary database tables
func (db *DB) createTables() error {
	query := `
	CREATE TABLE IF NOT EXISTS cluster_snapshots (
		id SERIAL PRIMARY KEY,
		timestamp TIMESTAMP NOT NULL,
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS deployments (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		namespace VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		replicas INTEGER,
		ready_replicas INTEGER,
		updated_replicas INTEGER,
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS pods (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		namespace VARCHAR(255) NOT NULL,
		deployment_name VARCHAR(255),
		created_time TIMESTAMP NOT NULL,
		phase VARCHAR(50),
		node_name VARCHAR(255),
		restart_count INTEGER,
		cpu_request VARCHAR(50),
		cpu_limit VARCHAR(50),
		memory_request VARCHAR(50),
		memory_limit VARCHAR(50),
		storage_request VARCHAR(50),
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS nodes (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		ready BOOLEAN,
		cpu_capacity VARCHAR(50),
		memory_capacity VARCHAR(50),
		storage_capacity VARCHAR(50),
		cpu_allocatable VARCHAR(50),
		memory_allocatable VARCHAR(50),
		storage_allocatable VARCHAR(50),
		os_image VARCHAR(255),
		kernel_version VARCHAR(255),
		kubelet_version VARCHAR(255),
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS services (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		namespace VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		type VARCHAR(50),
		cluster_ip VARCHAR(45),
		external_ips TEXT[],
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS ingresses (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		namespace VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		hosts TEXT[],
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS configmaps (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		namespace VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		data_keys TEXT[],
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS secrets (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		namespace VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		type VARCHAR(100),
		data_keys TEXT[],
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS persistent_volumes (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		capacity VARCHAR(50),
		access_modes TEXT[],
		reclaim_policy VARCHAR(50),
		storage_class VARCHAR(255),
		status VARCHAR(50),
		volume_source VARCHAR(100),
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS persistent_volume_claims (
		id SERIAL PRIMARY KEY,
		snapshot_id INTEGER REFERENCES cluster_snapshots(id) ON DELETE CASCADE,
		name VARCHAR(255) NOT NULL,
		namespace VARCHAR(255) NOT NULL,
		created_time TIMESTAMP NOT NULL,
		requested_size VARCHAR(50),
		access_modes TEXT[],
		storage_class VARCHAR(255),
		status VARCHAR(50),
		volume_name VARCHAR(255),
		data JSONB NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Create indexes for better query performance
	CREATE INDEX IF NOT EXISTS idx_deployments_namespace ON deployments(namespace);
	CREATE INDEX IF NOT EXISTS idx_deployments_name ON deployments(name);
	CREATE INDEX IF NOT EXISTS idx_deployments_snapshot ON deployments(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_pods_namespace ON pods(namespace);
	CREATE INDEX IF NOT EXISTS idx_pods_deployment ON pods(deployment_name);
	CREATE INDEX IF NOT EXISTS idx_pods_node ON pods(node_name);
	CREATE INDEX IF NOT EXISTS idx_pods_snapshot ON pods(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_nodes_name ON nodes(name);
	CREATE INDEX IF NOT EXISTS idx_nodes_snapshot ON nodes(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_services_namespace ON services(namespace);
	CREATE INDEX IF NOT EXISTS idx_services_name ON services(name);
	CREATE INDEX IF NOT EXISTS idx_services_snapshot ON services(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_ingresses_namespace ON ingresses(namespace);
	CREATE INDEX IF NOT EXISTS idx_ingresses_name ON ingresses(name);
	CREATE INDEX IF NOT EXISTS idx_ingresses_snapshot ON ingresses(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_configmaps_namespace ON configmaps(namespace);
	CREATE INDEX IF NOT EXISTS idx_configmaps_name ON configmaps(name);
	CREATE INDEX IF NOT EXISTS idx_configmaps_snapshot ON configmaps(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_secrets_namespace ON secrets(namespace);
	CREATE INDEX IF NOT EXISTS idx_secrets_name ON secrets(name);
	CREATE INDEX IF NOT EXISTS idx_secrets_snapshot ON secrets(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_persistent_volumes_name ON persistent_volumes(name);
	CREATE INDEX IF NOT EXISTS idx_persistent_volumes_snapshot ON persistent_volumes(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_persistent_volume_claims_namespace ON persistent_volume_claims(namespace);
	CREATE INDEX IF NOT EXISTS idx_persistent_volume_claims_name ON persistent_volume_claims(name);
	CREATE INDEX IF NOT EXISTS idx_persistent_volume_claims_snapshot ON persistent_volume_claims(snapshot_id);
	CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp ON cluster_snapshots(timestamp);
	`

	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to create tables: %w", err)
	}

	db.logger.Info("Database tables created/verified successfully")
	return nil
}

// Close closes the database connection
func (db *DB) Close() error {
	db.logger.Info("Closing database connection")
	return db.DB.Close()
}
