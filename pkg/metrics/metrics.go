package metrics

import (
	"fmt"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics represents the metrics system
type Metrics struct {
	enabled bool
	port    int
	server  *http.Server

	// Prometheus metrics
	bytesTransferred   *prometheus.CounterVec
	connectionsHandled *prometheus.CounterVec
	activeConnections  *prometheus.GaugeVec
	connectionDuration *prometheus.HistogramVec
	bufferPoolSize     *prometheus.GaugeVec
	bufferPoolUsage    *prometheus.GaugeVec
	errorsTotal        *prometheus.CounterVec
	heartbeatLatency   *prometheus.HistogramVec
}

// NewMetrics creates a new metrics system
func NewMetrics(enabled bool, port int) *Metrics {
	m := &Metrics{
		enabled: enabled,
		port:    port,
	}

	if enabled {
		m.initPrometheusMetrics()
	}

	return m
}

// initPrometheusMetrics initializes Prometheus metrics
func (m *Metrics) initPrometheusMetrics() {
	// Bytes transferred counter
	m.bytesTransferred = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cloudbridge_bytes_transferred_total",
			Help: "Total bytes transferred through tunnels",
		},
		[]string{"tunnel_id", "tenant_id", "direction"},
	)

	// Connections handled counter
	m.connectionsHandled = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cloudbridge_connections_handled_total",
			Help: "Total connections handled by tunnels",
		},
		[]string{"tunnel_id", "tenant_id"},
	)

	// Active connections gauge
	m.activeConnections = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cloudbridge_active_connections",
			Help: "Number of active connections",
		},
		[]string{"tunnel_id", "tenant_id"},
	)

	// Connection duration histogram
	m.connectionDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "cloudbridge_connection_duration_seconds",
			Help:    "Connection duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"tunnel_id", "tenant_id"},
	)

	// Buffer pool size gauge
	m.bufferPoolSize = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cloudbridge_buffer_pool_size",
			Help: "Buffer pool size",
		},
		[]string{"tunnel_id"},
	)

	// Buffer pool usage gauge
	m.bufferPoolUsage = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "cloudbridge_buffer_pool_usage",
			Help: "Buffer pool usage",
		},
		[]string{"tunnel_id"},
	)

	// Errors total counter
	m.errorsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cloudbridge_errors_total",
			Help: "Total number of errors",
		},
		[]string{"error_type", "tunnel_id", "tenant_id"},
	)

	// Heartbeat latency histogram
	m.heartbeatLatency = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "cloudbridge_heartbeat_latency_seconds",
			Help:    "Heartbeat latency in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"tenant_id"},
	)

	// Register metrics
	prometheus.MustRegister(
		m.bytesTransferred,
		m.connectionsHandled,
		m.activeConnections,
		m.connectionDuration,
		m.bufferPoolSize,
		m.bufferPoolUsage,
		m.errorsTotal,
		m.heartbeatLatency,
	)
}

// Start starts the metrics server
func (m *Metrics) Start() error {
	if !m.enabled {
		return nil
	}

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())

	m.server = &http.Server{
		Addr:    fmt.Sprintf(":%d", m.port),
		Handler: mux,
	}

	go func() {
		if err := m.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fmt.Printf("Metrics server error: %v\n", err)
		}
	}()

	fmt.Printf("Metrics server started on port %d\n", m.port)
	return nil
}

// Stop stops the metrics server
func (m *Metrics) Stop() error {
	if m.server != nil {
		return m.server.Close()
	}
	return nil
}

// RecordBytesTransferred records bytes transferred
func (m *Metrics) RecordBytesTransferred(tunnelID, tenantID, direction string, bytes int64) {
	if !m.enabled {
		return
	}

	m.bytesTransferred.WithLabelValues(tunnelID, tenantID, direction).Add(float64(bytes))
}

// RecordConnectionHandled records a handled connection
func (m *Metrics) RecordConnectionHandled(tunnelID, tenantID string) {
	if !m.enabled {
		return
	}

	m.connectionsHandled.WithLabelValues(tunnelID, tenantID).Inc()
}

// SetActiveConnections sets active connections count
func (m *Metrics) SetActiveConnections(tunnelID, tenantID string, count int) {
	if !m.enabled {
		return
	}

	m.activeConnections.WithLabelValues(tunnelID, tenantID).Set(float64(count))
}

// RecordConnectionDuration records connection duration
func (m *Metrics) RecordConnectionDuration(tunnelID, tenantID string, duration time.Duration) {
	if !m.enabled {
		return
	}

	m.connectionDuration.WithLabelValues(tunnelID, tenantID).Observe(duration.Seconds())
}

// SetBufferPoolSize sets buffer pool size
func (m *Metrics) SetBufferPoolSize(tunnelID string, size int) {
	if !m.enabled {
		return
	}

	m.bufferPoolSize.WithLabelValues(tunnelID).Set(float64(size))
}

// SetBufferPoolUsage sets buffer pool usage
func (m *Metrics) SetBufferPoolUsage(tunnelID string, usage int) {
	if !m.enabled {
		return
	}

	m.bufferPoolUsage.WithLabelValues(tunnelID).Set(float64(usage))
}

// RecordError records an error
func (m *Metrics) RecordError(errorType, tunnelID, tenantID string) {
	if !m.enabled {
		return
	}

	m.errorsTotal.WithLabelValues(errorType, tunnelID, tenantID).Inc()
}

// RecordHeartbeatLatency records heartbeat latency
func (m *Metrics) RecordHeartbeatLatency(tenantID string, latency time.Duration) {
	if !m.enabled {
		return
	}

	m.heartbeatLatency.WithLabelValues(tenantID).Observe(latency.Seconds())
}

// GetMetrics returns current metrics as a map
func (m *Metrics) GetMetrics() map[string]interface{} {
	if !m.enabled {
		return map[string]interface{}{"enabled": false}
	}

	return map[string]interface{}{
		"enabled": true,
		"port":    m.port,
	}
}
