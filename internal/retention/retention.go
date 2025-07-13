package retention

import (
	"database/sql"
	"fmt"
	"time"

	"k8s-cluster-info-collector/internal/database"

	"github.com/sirupsen/logrus"
)

// RetentionManager handles automatic cleanup of old data
type RetentionManager struct {
	db     *database.DB
	logger *logrus.Logger
	config RetentionConfig
}

// RetentionConfig holds retention policy configuration
type RetentionConfig struct {
	Enabled              bool
	MaxAge               time.Duration
	MaxSnapshots         int
	CleanupInterval      time.Duration
	DeleteBatchSize      int
	PreserveLatestPerDay bool
}

// New creates a new retention manager
func New(db *database.DB, logger *logrus.Logger, config RetentionConfig) *RetentionManager {
	return &RetentionManager{
		db:     db,
		logger: logger,
		config: config,
	}
}

// Start begins the retention cleanup process
func (r *RetentionManager) Start() {
	if !r.config.Enabled {
		r.logger.Info("Data retention is disabled")
		return
	}

	r.logger.WithFields(logrus.Fields{
		"max_age":       r.config.MaxAge,
		"max_snapshots": r.config.MaxSnapshots,
		"interval":      r.config.CleanupInterval,
	}).Info("Starting data retention manager")

	ticker := time.NewTicker(r.config.CleanupInterval)
	go func() {
		for range ticker.C {
			if err := r.cleanup(); err != nil {
				r.logger.WithError(err).Error("Failed to perform retention cleanup")
			}
		}
	}()
}

// cleanup performs the actual data cleanup
func (r *RetentionManager) cleanup() error {
	r.logger.Info("Starting retention cleanup")

	deletedCount := 0

	// Clean up by age
	if r.config.MaxAge > 0 {
		count, err := r.cleanupByAge()
		if err != nil {
			return fmt.Errorf("failed to cleanup by age: %w", err)
		}
		deletedCount += count
	}

	// Clean up by count
	if r.config.MaxSnapshots > 0 {
		count, err := r.cleanupByCount()
		if err != nil {
			return fmt.Errorf("failed to cleanup by count: %w", err)
		}
		deletedCount += count
	}

	r.logger.WithField("deleted_snapshots", deletedCount).Info("Retention cleanup completed")
	return nil
}

// cleanupByAge removes snapshots older than MaxAge
func (r *RetentionManager) cleanupByAge() (int, error) {
	cutoffTime := time.Now().Add(-r.config.MaxAge)

	var snapshotIDs []int
	query := `
		SELECT id FROM cluster_snapshots 
		WHERE timestamp < $1
		ORDER BY timestamp ASC
		LIMIT $2
	`

	rows, err := r.db.Query(query, cutoffTime, r.config.DeleteBatchSize)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			return 0, err
		}
		snapshotIDs = append(snapshotIDs, id)
	}

	if len(snapshotIDs) == 0 {
		return 0, nil
	}

	return r.deleteSnapshots(snapshotIDs)
}

// cleanupByCount removes excess snapshots beyond MaxSnapshots
func (r *RetentionManager) cleanupByCount() (int, error) {
	// Count total snapshots
	var totalCount int
	err := r.db.QueryRow("SELECT COUNT(*) FROM cluster_snapshots").Scan(&totalCount)
	if err != nil {
		return 0, err
	}

	if totalCount <= r.config.MaxSnapshots {
		return 0, nil
	}

	excessCount := totalCount - r.config.MaxSnapshots
	if excessCount > r.config.DeleteBatchSize {
		excessCount = r.config.DeleteBatchSize
	}

	var snapshotIDs []int
	query := `
		SELECT id FROM cluster_snapshots 
		ORDER BY timestamp ASC
		LIMIT $1
	`

	rows, err := r.db.Query(query, excessCount)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			return 0, err
		}
		snapshotIDs = append(snapshotIDs, id)
	}

	if len(snapshotIDs) == 0 {
		return 0, nil
	}

	return r.deleteSnapshots(snapshotIDs)
}

// deleteSnapshots removes the specified snapshots and all related data
func (r *RetentionManager) deleteSnapshots(snapshotIDs []int) (int, error) {
	if len(snapshotIDs) == 0 {
		return 0, nil
	}

	tx, err := r.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	// Build the IN clause for the snapshot IDs
	placeholders := ""
	params := make([]interface{}, len(snapshotIDs))
	for i, id := range snapshotIDs {
		if i > 0 {
			placeholders += ","
		}
		placeholders += fmt.Sprintf("$%d", i+1)
		params[i] = id
	}

	// Delete from all tables (cascading deletes should handle this, but being explicit)
	tables := []string{
		"persistent_volume_claims",
		"persistent_volumes",
		"secrets",
		"configmaps",
		"ingresses",
		"services",
		"nodes",
		"pods",
		"deployments",
		"cluster_snapshots",
	}

	for _, table := range tables {
		query := fmt.Sprintf("DELETE FROM %s WHERE snapshot_id IN (%s)", table, placeholders)
		if table == "cluster_snapshots" {
			query = fmt.Sprintf("DELETE FROM %s WHERE id IN (%s)", table, placeholders)
		}

		_, err := tx.Exec(query, params...)
		if err != nil {
			return 0, fmt.Errorf("failed to delete from %s: %w", table, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}

	r.logger.WithField("snapshot_ids", snapshotIDs).Info("Deleted snapshots")
	return len(snapshotIDs), nil
}

// GetRetentionStats returns statistics about data retention
func (r *RetentionManager) GetRetentionStats() (RetentionStats, error) {
	stats := RetentionStats{}

	// Total snapshots
	err := r.db.QueryRow("SELECT COUNT(*) FROM cluster_snapshots").Scan(&stats.TotalSnapshots)
	if err != nil {
		return stats, err
	}

	// Oldest snapshot
	err = r.db.QueryRow("SELECT MIN(timestamp) FROM cluster_snapshots").Scan(&stats.OldestSnapshot)
	if err != nil && err != sql.ErrNoRows {
		return stats, err
	}

	// Newest snapshot
	err = r.db.QueryRow("SELECT MAX(timestamp) FROM cluster_snapshots").Scan(&stats.NewestSnapshot)
	if err != nil && err != sql.ErrNoRows {
		return stats, err
	}

	// Database size (PostgreSQL specific)
	err = r.db.QueryRow(`
		SELECT pg_size_pretty(pg_total_relation_size('cluster_snapshots')) as size
	`).Scan(&stats.DatabaseSize)
	if err != nil {
		stats.DatabaseSize = "unknown"
	}

	return stats, nil
}

// RetentionStats holds retention statistics
type RetentionStats struct {
	TotalSnapshots int       `json:"total_snapshots"`
	OldestSnapshot time.Time `json:"oldest_snapshot"`
	NewestSnapshot time.Time `json:"newest_snapshot"`
	DatabaseSize   string    `json:"database_size"`
}
