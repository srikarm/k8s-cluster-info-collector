package api

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"

	"k8s-cluster-info-collector/internal/database"
	"k8s-cluster-info-collector/internal/models"
	"k8s-cluster-info-collector/internal/streaming"
)

// Server represents the REST API server
type Server struct {
	db     *database.DB
	logger *logrus.Logger
	router *mux.Router
	config APIConfig
	hub    *streaming.Hub
}

// APIConfig holds API server configuration
type APIConfig struct {
	Enabled bool
	Address string
	Prefix  string
}

// New creates a new API server
func New(db *database.DB, logger *logrus.Logger, config APIConfig, hub *streaming.Hub) *Server {
	s := &Server{
		db:     db,
		logger: logger,
		router: mux.NewRouter(),
		config: config,
		hub:    hub,
	}

	s.setupRoutes()
	return s
}

// setupRoutes configures all API routes
func (s *Server) setupRoutes() {
	prefix := s.config.Prefix
	if prefix == "" {
		prefix = "/api/v1"
	}

	api := s.router.PathPrefix(prefix).Subrouter()

	// Middleware
	api.Use(s.loggingMiddleware)
	api.Use(s.corsMiddleware)

	// Snapshots endpoints
	api.HandleFunc("/snapshots", s.getSnapshots).Methods("GET")
	api.HandleFunc("/snapshots/{id}", s.getSnapshot).Methods("GET")
	api.HandleFunc("/snapshots/latest", s.getLatestSnapshot).Methods("GET")

	// Resource endpoints
	api.HandleFunc("/deployments", s.getDeployments).Methods("GET")
	api.HandleFunc("/pods", s.getPods).Methods("GET")
	api.HandleFunc("/nodes", s.getNodes).Methods("GET")
	api.HandleFunc("/services", s.getServices).Methods("GET")
	api.HandleFunc("/ingresses", s.getIngresses).Methods("GET")
	api.HandleFunc("/configmaps", s.getConfigMaps).Methods("GET")
	api.HandleFunc("/secrets", s.getSecrets).Methods("GET")
	api.HandleFunc("/persistent-volumes", s.getPersistentVolumes).Methods("GET")
	api.HandleFunc("/persistent-volume-claims", s.getPersistentVolumeClaims).Methods("GET")

	// WebSocket streaming endpoints
	api.HandleFunc("/ws", s.handleWebSocket).Methods("GET")

	// Statistics endpoints
	api.HandleFunc("/stats", s.getStats).Methods("GET")
	api.HandleFunc("/stats/retention", s.getRetentionStats).Methods("GET")

	// Health endpoint
	api.HandleFunc("/health", s.getHealth).Methods("GET")
}

// Start starts the API server
func (s *Server) Start() error {
	if !s.config.Enabled {
		s.logger.Info("API server is disabled")
		return nil
	}

	s.logger.WithField("address", s.config.Address).Info("Starting API server")
	return http.ListenAndServe(s.config.Address, s.router)
}

// Middleware functions
func (s *Server) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		s.logger.WithFields(logrus.Fields{
			"method":   r.Method,
			"url":      r.URL.Path,
			"duration": time.Since(start),
		}).Info("API request")
	})
}

func (s *Server) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// Response helpers
func (s *Server) writeJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(data); err != nil {
		s.logger.WithError(err).Error("Failed to encode JSON response")
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (s *Server) writeError(w http.ResponseWriter, message string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}

// API endpoint handlers
func (s *Server) getSnapshots(w http.ResponseWriter, r *http.Request) {
	limit := 50 // Default limit
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 1000 {
			limit = parsed
		}
	}

	rows, err := s.db.Query(`
		SELECT id, timestamp, 
			(SELECT COUNT(*) FROM deployments WHERE snapshot_id = cs.id) as deployments,
			(SELECT COUNT(*) FROM pods WHERE snapshot_id = cs.id) as pods,
			(SELECT COUNT(*) FROM nodes WHERE snapshot_id = cs.id) as nodes,
			(SELECT COUNT(*) FROM services WHERE snapshot_id = cs.id) as services,
			(SELECT COUNT(*) FROM ingresses WHERE snapshot_id = cs.id) as ingresses,
			(SELECT COUNT(*) FROM configmaps WHERE snapshot_id = cs.id) as configmaps,
			(SELECT COUNT(*) FROM secrets WHERE snapshot_id = cs.id) as secrets,
			(SELECT COUNT(*) FROM persistent_volumes WHERE snapshot_id = cs.id) as persistent_volumes,
			(SELECT COUNT(*) FROM persistent_volume_claims WHERE snapshot_id = cs.id) as persistent_volume_claims
		FROM cluster_snapshots cs
		ORDER BY timestamp DESC
		LIMIT $1
	`, limit)
	if err != nil {
		s.logger.WithError(err).Error("Failed to query snapshots")
		s.writeError(w, "Failed to fetch snapshots", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var snapshots []map[string]interface{}
	for rows.Next() {
		var id int
		var timestamp time.Time
		var deployments, pods, nodes, services, ingresses, configmaps, secrets, pvs, pvcs int

		err := rows.Scan(&id, &timestamp, &deployments, &pods, &nodes, &services, &ingresses, &configmaps, &secrets, &pvs, &pvcs)
		if err != nil {
			s.logger.WithError(err).Error("Failed to scan snapshot row")
			continue
		}

		snapshots = append(snapshots, map[string]interface{}{
			"id":                       id,
			"timestamp":                timestamp,
			"deployments":              deployments,
			"pods":                     pods,
			"nodes":                    nodes,
			"services":                 services,
			"ingresses":                ingresses,
			"configmaps":               configmaps,
			"secrets":                  secrets,
			"persistent_volumes":       pvs,
			"persistent_volume_claims": pvcs,
		})
	}

	s.writeJSON(w, map[string]interface{}{
		"snapshots": snapshots,
		"count":     len(snapshots),
	})
}

func (s *Server) getSnapshot(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	idStr := vars["id"]

	id, err := strconv.Atoi(idStr)
	if err != nil {
		s.writeError(w, "Invalid snapshot ID", http.StatusBadRequest)
		return
	}

	var data string
	var timestamp time.Time
	err = s.db.QueryRow("SELECT timestamp, data FROM cluster_snapshots WHERE id = $1", id).Scan(&timestamp, &data)
	if err != nil {
		if err == sql.ErrNoRows {
			s.writeError(w, "Snapshot not found", http.StatusNotFound)
			return
		}
		s.logger.WithError(err).Error("Failed to query snapshot")
		s.writeError(w, "Failed to fetch snapshot", http.StatusInternalServerError)
		return
	}

	var clusterInfo models.ClusterInfo
	if err := json.Unmarshal([]byte(data), &clusterInfo); err != nil {
		s.logger.WithError(err).Error("Failed to unmarshal cluster info")
		s.writeError(w, "Failed to parse snapshot data", http.StatusInternalServerError)
		return
	}

	s.writeJSON(w, map[string]interface{}{
		"id":           id,
		"timestamp":    timestamp,
		"cluster_info": clusterInfo,
	})
}

func (s *Server) getLatestSnapshot(w http.ResponseWriter, r *http.Request) {
	var id int
	err := s.db.QueryRow("SELECT id FROM cluster_snapshots ORDER BY timestamp DESC LIMIT 1").Scan(&id)
	if err != nil {
		if err == sql.ErrNoRows {
			s.writeError(w, "No snapshots found", http.StatusNotFound)
			return
		}
		s.logger.WithError(err).Error("Failed to query latest snapshot")
		s.writeError(w, "Failed to fetch latest snapshot", http.StatusInternalServerError)
		return
	}

	// Redirect to the specific snapshot endpoint
	http.Redirect(w, r, fmt.Sprintf("%s/snapshots/%d", s.config.Prefix, id), http.StatusFound)
}

func (s *Server) getDeployments(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "deployments", "name, namespace, replicas, ready_replicas, created_time")
}

func (s *Server) getPods(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "pods", "name, namespace, phase, node_name, restart_count, created_time")
}

func (s *Server) getNodes(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "nodes", "name, ready, cpu_capacity, memory_capacity, created_time")
}

func (s *Server) getServices(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "services", "name, namespace, type, cluster_ip, created_time")
}

func (s *Server) getIngresses(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "ingresses", "name, namespace, hosts, created_time")
}

func (s *Server) getConfigMaps(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "configmaps", "name, namespace, data_keys, created_time")
}

func (s *Server) getSecrets(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "secrets", "name, namespace, type, data_keys, created_time")
}

func (s *Server) getPersistentVolumes(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "persistent_volumes", "name, capacity, access_modes, status, storage_class, created_time")
}

func (s *Server) getPersistentVolumeClaims(w http.ResponseWriter, r *http.Request) {
	s.getResourceData(w, r, "persistent_volume_claims", "name, namespace, requested_size, access_modes, status, created_time")
}

func (s *Server) getResourceData(w http.ResponseWriter, r *http.Request, table, columns string) {
	snapshotID := s.getLatestSnapshotID()
	if snapshotID == 0 {
		s.writeError(w, "No snapshots available", http.StatusNotFound)
		return
	}

	// Parse query parameters
	limit := 100
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 1000 {
			limit = parsed
		}
	}

	namespace := r.URL.Query().Get("namespace")

	query := fmt.Sprintf("SELECT %s FROM %s WHERE snapshot_id = $1", columns, table)
	args := []interface{}{snapshotID}

	if namespace != "" {
		query += " AND namespace = $2"
		args = append(args, namespace)
	}

	query += fmt.Sprintf(" ORDER BY created_time DESC LIMIT %d", limit)

	rows, err := s.db.Query(query, args...)
	if err != nil {
		s.logger.WithError(err).Error("Failed to query resource data")
		s.writeError(w, "Failed to fetch resource data", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		columns, err := rows.Columns()
		if err != nil {
			continue
		}

		values := make([]interface{}, len(columns))
		valuePtrs := make([]interface{}, len(columns))
		for i := range values {
			valuePtrs[i] = &values[i]
		}

		if err := rows.Scan(valuePtrs...); err != nil {
			continue
		}

		result := make(map[string]interface{})
		for i, col := range columns {
			result[col] = values[i]
		}
		results = append(results, result)
	}

	s.writeJSON(w, map[string]interface{}{
		"data":  results,
		"count": len(results),
	})
}

func (s *Server) getStats(w http.ResponseWriter, r *http.Request) {
	stats := make(map[string]interface{})

	// Total snapshots
	var totalSnapshots int
	s.db.QueryRow("SELECT COUNT(*) FROM cluster_snapshots").Scan(&totalSnapshots)
	stats["total_snapshots"] = totalSnapshots

	// Latest snapshot stats
	snapshotID := s.getLatestSnapshotID()
	if snapshotID > 0 {
		latestStats := make(map[string]int)
		tables := []string{"deployments", "pods", "nodes", "services", "ingresses", "configmaps", "secrets", "persistent_volumes", "persistent_volume_claims"}

		for _, table := range tables {
			var count int
			s.db.QueryRow(fmt.Sprintf("SELECT COUNT(*) FROM %s WHERE snapshot_id = $1", table), snapshotID).Scan(&count)
			latestStats[table] = count
		}
		stats["latest_snapshot"] = latestStats
	}

	s.writeJSON(w, stats)
}

func (s *Server) getRetentionStats(w http.ResponseWriter, r *http.Request) {
	stats := make(map[string]interface{})

	// Database size
	var dbSize string
	err := s.db.QueryRow("SELECT pg_size_pretty(pg_database_size(current_database()))").Scan(&dbSize)
	if err == nil {
		stats["database_size"] = dbSize
	}

	// Oldest and newest snapshots
	var oldest, newest time.Time
	s.db.QueryRow("SELECT MIN(timestamp), MAX(timestamp) FROM cluster_snapshots").Scan(&oldest, &newest)
	stats["oldest_snapshot"] = oldest
	stats["newest_snapshot"] = newest
	stats["retention_span"] = newest.Sub(oldest).String()

	s.writeJSON(w, stats)
}

func (s *Server) getHealth(w http.ResponseWriter, r *http.Request) {
	// Check database connectivity
	if err := s.db.Ping(); err != nil {
		s.writeError(w, "Database unavailable", http.StatusServiceUnavailable)
		return
	}

	s.writeJSON(w, map[string]string{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func (s *Server) getLatestSnapshotID() int {
	var id int
	s.db.QueryRow("SELECT id FROM cluster_snapshots ORDER BY timestamp DESC LIMIT 1").Scan(&id)
	return id
}

// handleWebSocket handles WebSocket connections
func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	if s.hub == nil {
		s.writeError(w, "WebSocket streaming not enabled", http.StatusServiceUnavailable)
		return
	}

	s.hub.HandleWebSocket(w, r)
}

// BroadcastUpdate sends cluster updates to connected WebSocket clients
func (s *Server) BroadcastUpdate(data *models.ClusterInfo) {
	if s.hub != nil {
		s.hub.BroadcastClusterUpdate(data)
	}
}

// writeJSON writes JSON response
