package metrics

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
)

// Metrics holds all Prometheus metrics
type Metrics struct {
	logger                    *logrus.Logger
	collectionsTotal          *prometheus.CounterVec
	collectionDuration        *prometheus.HistogramVec
	resourcesCollected        *prometheus.GaugeVec
	collectionErrors          *prometheus.CounterVec
	databaseOperations        *prometheus.CounterVec
	databaseOperationDuration *prometheus.HistogramVec
}

// New creates a new metrics instance
func New(logger *logrus.Logger) *Metrics {
	m := &Metrics{
		logger: logger,
		collectionsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "cluster_info_collections_total",
				Help: "Total number of cluster info collections",
			},
			[]string{"status"},
		),
		collectionDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "cluster_info_collection_duration_seconds",
				Help:    "Duration of cluster info collection in seconds",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"resource_type"},
		),
		resourcesCollected: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "cluster_info_resources_collected",
				Help: "Number of resources collected in the last collection",
			},
			[]string{"resource_type"},
		),
		collectionErrors: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "cluster_info_collection_errors_total",
				Help: "Total number of collection errors",
			},
			[]string{"resource_type", "error_type"},
		),
		databaseOperations: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "cluster_info_database_operations_total",
				Help: "Total number of database operations",
			},
			[]string{"operation", "status"},
		),
		databaseOperationDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "cluster_info_database_operation_duration_seconds",
				Help:    "Duration of database operations in seconds",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"operation"},
		),
	}

	// Register metrics
	prometheus.MustRegister(
		m.collectionsTotal,
		m.collectionDuration,
		m.resourcesCollected,
		m.collectionErrors,
		m.databaseOperations,
		m.databaseOperationDuration,
	)

	return m
}

// RecordCollectionStart records the start of a collection
func (m *Metrics) RecordCollectionStart() {
	m.collectionsTotal.WithLabelValues("started").Inc()
}

// RecordCollectionSuccess records a successful collection
func (m *Metrics) RecordCollectionSuccess() {
	m.collectionsTotal.WithLabelValues("success").Inc()
}

// RecordCollectionError records a collection error
func (m *Metrics) RecordCollectionError() {
	m.collectionsTotal.WithLabelValues("error").Inc()
}

// RecordCollectionDuration records the duration of a collection operation
func (m *Metrics) RecordCollectionDuration(resourceType string, duration float64) {
	m.collectionDuration.WithLabelValues(resourceType).Observe(duration)
}

// SetResourcesCollected sets the number of resources collected
func (m *Metrics) SetResourcesCollected(resourceType string, count int) {
	m.resourcesCollected.WithLabelValues(resourceType).Set(float64(count))
}

// RecordCollectionResourceError records an error during resource collection
func (m *Metrics) RecordCollectionResourceError(resourceType, errorType string) {
	m.collectionErrors.WithLabelValues(resourceType, errorType).Inc()
}

// RecordDatabaseOperation records a database operation
func (m *Metrics) RecordDatabaseOperation(operation, status string) {
	m.databaseOperations.WithLabelValues(operation, status).Inc()
}

// RecordDatabaseOperationDuration records the duration of a database operation
func (m *Metrics) RecordDatabaseOperationDuration(operation string, duration float64) {
	m.databaseOperationDuration.WithLabelValues(operation).Observe(duration)
}

// Handler returns the HTTP handler for Prometheus metrics
func (m *Metrics) Handler() http.Handler {
	return promhttp.Handler()
}

// StartMetricsServer starts the metrics HTTP server
func (m *Metrics) StartMetricsServer(addr string) error {
	m.logger.WithField("address", addr).Info("Starting metrics server")

	http.Handle("/metrics", m.Handler())
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	return http.ListenAndServe(addr, nil)
}
