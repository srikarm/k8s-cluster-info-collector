package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"time"
)

// Simple test structures matching our consumer server
type HealthResponse struct {
	Status      string            `json:"status"`
	Timestamp   time.Time         `json:"timestamp"`
	Version     string            `json:"version"`
	CommitHash  string            `json:"commit_hash"`
	BuildTime   string            `json:"build_time"`
	Uptime      string            `json:"uptime"`
	ServiceType string            `json:"service_type"`
	Checks      map[string]string `json:"checks"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	checks := make(map[string]string)
	checks["server"] = "healthy"
	checks["consumer"] = "healthy"

	response := HealthResponse{
		Status:      "healthy",
		Timestamp:   time.Now(),
		Version:     "test-version",
		CommitHash:  "test-commit",
		BuildTime:   "test-build-time",
		Uptime:      "5m30s",
		ServiceType: "kafka-consumer",
		Checks:      checks,
	}

	w.Header().Set("Content-Type", "application/json")

	// Create a JSON encoder with indentation for readable output
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	encoder.Encode(response)
}

type MemoryMetrics struct {
	AllocMB      uint64 `json:"alloc_mb"`
	TotalAllocMB uint64 `json:"total_alloc_mb"`
	SysMB        uint64 `json:"sys_mb"`
	NumGC        uint32 `json:"num_gc"`
	Description  string `json:"description"`
}

type MetricsResponse struct {
	Service struct {
		Name        string    `json:"name"`
		Version     string    `json:"version"`
		Uptime      string    `json:"uptime"`
		StartTime   time.Time `json:"start_time"`
		ServiceType string    `json:"service_type"`
	} `json:"service"`
	Runtime struct {
		GoVersion    string        `json:"go_version"`
		NumGoroutine int           `json:"num_goroutine"`
		NumCPU       int           `json:"num_cpu"`
		Memory       MemoryMetrics `json:"memory"`
	} `json:"runtime"`
	LastUpdated time.Time `json:"last_updated"`
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	response := MetricsResponse{
		LastUpdated: time.Now(),
	}

	response.Service.Name = "cluster-info-consumer"
	response.Service.Version = "test-version"
	response.Service.Uptime = "5m30s"
	response.Service.StartTime = time.Now().Add(-5 * time.Minute)
	response.Service.ServiceType = "kafka-consumer"

	response.Runtime.GoVersion = runtime.Version()
	response.Runtime.NumGoroutine = runtime.NumGoroutine()
	response.Runtime.NumCPU = runtime.NumCPU()
	response.Runtime.Memory = MemoryMetrics{
		AllocMB:      m.Alloc / 1024 / 1024,
		TotalAllocMB: m.TotalAlloc / 1024 / 1024,
		SysMB:        m.Sys / 1024 / 1024,
		NumGC:        m.NumGC,
		Description:  "Memory usage statistics in megabytes",
	}

	w.Header().Set("Content-Type", "application/json")

	// Create a JSON encoder with indentation for readable output
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	encoder.Encode(response)
}

func main() {
	fmt.Println("Starting JSON formatting test server on port 8084...")

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/metrics", metricsHandler)

	fmt.Println("Test the endpoints:")
	fmt.Println("curl http://localhost:8084/health")
	fmt.Println("curl http://localhost:8084/metrics")

	http.ListenAndServe(":8084", nil)
}
