package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"time"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
)

// Server represents the HTTP server for consumer health and metrics
type Server struct {
	httpServer   *http.Server
	logger       *logrus.Logger
	config       Config
	startTime    time.Time
	version      string
	commitHash   string
	buildTime    string
	messageCount int64
	lastMessage  time.Time
}

// Config holds server configuration
type Config struct {
	Enabled bool   `json:"enabled"`
	Address string `json:"address"`
	Port    int    `json:"port"`
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Status             string            `json:"status"`
	Timestamp          time.Time         `json:"timestamp"`
	Version            string            `json:"version"`
	CommitHash         string            `json:"commit_hash,omitempty"`
	BuildTime          string            `json:"build_time,omitempty"`
	Uptime             string            `json:"uptime"`
	ServiceType        string            `json:"service_type"`
	ProcessDescription string            `json:"process_description"`
	Checks             map[string]string `json:"checks"`
	Summary            string            `json:"summary"`
}

// MetricsResponse represents the metrics response
type MetricsResponse struct {
	Service     ServiceMetrics  `json:"service"`
	Runtime     RuntimeMetrics  `json:"runtime"`
	Consumer    ConsumerMetrics `json:"consumer"`
	LastUpdated time.Time       `json:"last_updated"`
	Summary     MetricsSummary  `json:"summary"`
}

// MetricsSummary provides a high-level summary
type MetricsSummary struct {
	HealthStatus  string `json:"health_status"`
	MemoryUsageMB uint64 `json:"memory_usage_mb"`
	MessagesRate  string `json:"messages_rate"`
	UptimeHuman   string `json:"uptime_human"`
}

// ServiceMetrics contains service-level metrics
type ServiceMetrics struct {
	Name        string    `json:"name"`
	Version     string    `json:"version"`
	Uptime      string    `json:"uptime"`
	StartTime   time.Time `json:"start_time"`
	ServiceType string    `json:"service_type"`
}

// RuntimeMetrics contains Go runtime metrics
type RuntimeMetrics struct {
	GoVersion    string        `json:"go_version"`
	NumGoroutine int           `json:"num_goroutine"`
	NumCPU       int           `json:"num_cpu"`
	Memory       MemoryMetrics `json:"memory"`
	GC           GCMetrics     `json:"gc"`
	OS           OSMetrics     `json:"os"`
}

// MemoryMetrics contains memory usage metrics
type MemoryMetrics struct {
	AllocMB      uint64 `json:"alloc_mb"`
	TotalAllocMB uint64 `json:"total_alloc_mb"`
	SysMB        uint64 `json:"sys_mb"`
	NumGC        uint32 `json:"num_gc"`
	HeapAllocMB  uint64 `json:"heap_alloc_mb"`
	HeapSysMB    uint64 `json:"heap_sys_mb"`
	HeapIdleMB   uint64 `json:"heap_idle_mb"`
	HeapInuseMB  uint64 `json:"heap_inuse_mb"`
	Description  string `json:"description"`
}

// GCMetrics contains garbage collection metrics
type GCMetrics struct {
	NumGC        uint32        `json:"num_gc"`
	PauseTotal   time.Duration `json:"pause_total_ns"`
	LastPause    time.Duration `json:"last_pause_ns"`
	PausePercent float64       `json:"pause_percent"`
	Description  string        `json:"description"`
}

// OSMetrics contains operating system metrics
type OSMetrics struct {
	GOOS        string `json:"goos"`
	GOARCH      string `json:"goarch"`
	Description string `json:"description"`
}

// ConsumerMetrics contains Kafka consumer specific metrics
type ConsumerMetrics struct {
	MessagesProcessed int64     `json:"messages_processed"`
	LastMessageTime   time.Time `json:"last_message_time"`
	MessagesPerSecond float64   `json:"messages_per_second"`
	Status            string    `json:"status"`
	StatusDescription string    `json:"status_description"`
}

// New creates a new HTTP server for consumer
func New(config Config, logger *logrus.Logger, version, commitHash, buildTime string) *Server {
	s := &Server{
		logger:     logger,
		config:     config,
		startTime:  time.Now(),
		version:    version,
		commitHash: commitHash,
		buildTime:  buildTime,
	}

	if config.Enabled {
		s.setupServer()
	}

	return s
}

// setupServer configures the HTTP server and routes
func (s *Server) setupServer() {
	router := mux.NewRouter()
	api := router.PathPrefix("/api/v1").Subrouter()

	// API root endpoint
	api.HandleFunc("", s.apiRootHandler).Methods("GET")
	api.HandleFunc("/", s.apiRootHandler).Methods("GET")
	router.HandleFunc("/api/v1", s.apiRootHandler).Methods("GET")

	// Health endpoint
	api.HandleFunc("/health", s.healthHandler).Methods("GET")
	api.HandleFunc("/healthz", s.healthHandler).Methods("GET") // Kubernetes style

	// Metrics endpoint
	api.HandleFunc("/metrics", s.metricsHandler).Methods("GET")

	// Ready endpoint (for Kubernetes readiness probe)
	api.HandleFunc("/ready", s.readyHandler).Methods("GET")

	// Version endpoint
	api.HandleFunc("/version", s.versionHandler).Methods("GET")

	// Add middleware
	router.Use(s.loggingMiddleware)
	router.Use(s.corsMiddleware)

	address := fmt.Sprintf("%s:%d", s.config.Address, s.config.Port)
	s.httpServer = &http.Server{
		Addr:         address,
		Handler:      router,
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
}

// apiRootHandler returns API metadata and available endpoints
func (s *Server) apiRootHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	resp := map[string]interface{}{
		"api":         "Kubernetes Cluster Info Consumer Health/Status API",
		"version":     s.version,
		"description": "This endpoint provides health, metrics, and status for the consumer process. For full cluster data and resource APIs, see the main REST API server.",
		"endpoints": []string{
			"/api/v1/health",
			"/api/v1/metrics",
			"/api/v1/ready",
			"/api/v1/version",
		},
		"note": "This server only provides health, metrics, and status endpoints. All resource/data APIs are served by the main REST API server (see documentation). The collector does not expose HTTP endpoints.",
	}
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	encoder.Encode(resp)
}

// Start starts the HTTP server
func (s *Server) Start() error {
	if !s.config.Enabled {
		s.logger.Info("Consumer HTTP server is disabled")
		return nil
	}

	s.logger.Infof("Starting consumer HTTP server on %s", s.httpServer.Addr)

	go func() {
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			s.logger.Errorf("Consumer HTTP server error: %v", err)
		}
	}()

	return nil
}

// Stop stops the HTTP server gracefully
func (s *Server) Stop(ctx context.Context) error {
	if !s.config.Enabled || s.httpServer == nil {
		return nil
	}

	s.logger.Info("Stopping consumer HTTP server...")
	return s.httpServer.Shutdown(ctx)
}

// UpdateMessageCount updates the consumer message count
func (s *Server) UpdateMessageCount(count int64) {
	s.messageCount = count
	s.lastMessage = time.Now()
}

// Health handler
func (s *Server) healthHandler(w http.ResponseWriter, r *http.Request) {
	checks := make(map[string]string)
	checks["server"] = "healthy"

	// Add consumer specific health checks
	if time.Since(s.lastMessage) > 5*time.Minute && s.messageCount > 0 {
		checks["consumer"] = "stale"
	} else {
		checks["consumer"] = "healthy"
	}

	response := HealthResponse{
		Status:             "healthy",
		Timestamp:          time.Now(),
		Version:            s.version,
		CommitHash:         s.commitHash,
		BuildTime:          s.buildTime,
		Uptime:             time.Since(s.startTime).String(),
		ServiceType:        "kafka-consumer",
		ProcessDescription: "Kafka Consumer for Kubernetes Cluster Info (long-running process that reads from Kafka and writes to PostgreSQL)",
		Checks:             checks,
	}

	w.Header().Set("Content-Type", "application/json")

	// Create a JSON encoder with indentation for readable output
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	encoder.Encode(response)
}

// Metrics handler
func (s *Server) metricsHandler(w http.ResponseWriter, r *http.Request) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	uptime := time.Since(s.startTime)
	messagesPerSecond := float64(s.messageCount) / uptime.Seconds()

	response := MetricsResponse{
		Service: ServiceMetrics{
			Name:        "cluster-info-consumer",
			Version:     s.version,
			Uptime:      uptime.String(),
			StartTime:   s.startTime,
			ServiceType: "kafka-consumer",
		},
		Runtime: RuntimeMetrics{
			GoVersion:    runtime.Version(),
			NumGoroutine: runtime.NumGoroutine(),
			NumCPU:       runtime.NumCPU(),
			Memory: MemoryMetrics{
				AllocMB:      bToMb(m.Alloc),
				TotalAllocMB: bToMb(m.TotalAlloc),
				SysMB:        bToMb(m.Sys),
				NumGC:        m.NumGC,
				HeapAllocMB:  bToMb(m.HeapAlloc),
				HeapSysMB:    bToMb(m.HeapSys),
				HeapIdleMB:   bToMb(m.HeapIdle),
				HeapInuseMB:  bToMb(m.HeapInuse),
				Description:  "Memory usage statistics in megabytes",
			},
			GC: GCMetrics{
				NumGC:        m.NumGC,
				PauseTotal:   time.Duration(m.PauseTotalNs),
				LastPause:    time.Duration(m.PauseNs[(m.NumGC+255)%256]),
				PausePercent: float64(m.PauseTotalNs) / float64(uptime.Nanoseconds()) * 100,
				Description:  "Garbage collection performance statistics",
			},
			OS: OSMetrics{
				GOOS:        runtime.GOOS,
				GOARCH:      runtime.GOARCH,
				Description: "Operating system and architecture information",
			},
		},
		Consumer: ConsumerMetrics{
			MessagesProcessed: s.messageCount,
			LastMessageTime:   s.lastMessage,
			MessagesPerSecond: messagesPerSecond,
			Status:            s.getConsumerStatus(),
			StatusDescription: s.getConsumerStatusDescription(),
		},
		LastUpdated: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")

	// Create a JSON encoder with indentation for readable output
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	encoder.Encode(response)
}

// Ready handler for Kubernetes readiness probe
func (s *Server) readyHandler(w http.ResponseWriter, r *http.Request) {
	// Consumer is ready if it has processed at least one message or has been running for more than 30 seconds
	if s.messageCount > 0 || time.Since(s.startTime) > 30*time.Second {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ready"))
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte("not ready"))
	}
}

// Version handler
func (s *Server) versionHandler(w http.ResponseWriter, r *http.Request) {
	version := map[string]string{
		"version":     s.version,
		"commit_hash": s.commitHash,
		"build_time":  s.buildTime,
		"go_version":  runtime.Version(),
		"service":     "cluster-info-consumer",
	}

	w.Header().Set("Content-Type", "application/json")

	// Create a JSON encoder with indentation for readable output
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	encoder.Encode(version)
}

// Logging middleware
func (s *Server) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		s.logger.Infof("%s %s %v", r.Method, r.URL.Path, time.Since(start))
	})
}

// CORS middleware
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

// Helper functions
func bToMb(b uint64) uint64 {
	return b / 1024 / 1024
}

func (s *Server) getConsumerStatus() string {
	if s.messageCount == 0 {
		return "waiting"
	}

	if time.Since(s.lastMessage) > 5*time.Minute {
		return "idle"
	}

	return "active"
}

func (s *Server) getConsumerStatusDescription() string {
	if s.messageCount == 0 {
		return "Consumer is running but has not processed any messages yet"
	}

	if time.Since(s.lastMessage) > 5*time.Minute {
		return "Consumer was active but no recent messages received"
	}

	return "Consumer is actively processing messages"
}
