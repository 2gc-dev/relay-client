package metrics

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/client_golang/prometheus/push"
)

// PushgatewayConfig contains Pushgateway configuration
type PushgatewayConfig struct {
	Enabled      bool
	URL          string
	JobName      string
	Instance     string
	PushInterval time.Duration
}

// Metrics represents the metrics system
type Metrics struct {
	enabled bool
	port    int
	server  *http.Server

	// Pushgateway support
	pushgatewayConfig *PushgatewayConfig
	pusher            *push.Pusher
	pushCtx           context.Context
	pushCancel        context.CancelFunc
	pushMutex         sync.RWMutex

	// Required client metrics
	clientBytesSent prometheus.Counter
	clientBytesRecv prometheus.Counter
	p2pSessions     prometheus.Gauge
	transportMode   prometheus.Gauge

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

// NewMetricsWithPushgateway creates a new metrics system with Pushgateway support
func NewMetricsWithPushgateway(enabled bool, port int, pushConfig *PushgatewayConfig) *Metrics {
	m := &Metrics{
		enabled:           enabled,
		port:              port,
		pushgatewayConfig: pushConfig,
	}

	if enabled {
		m.initPrometheusMetrics()
		if pushConfig != nil && pushConfig.Enabled {
			m.initPushgateway()
		}
	}

	return m
}

// initPrometheusMetrics initializes Prometheus metrics
func (m *Metrics) initPrometheusMetrics() {
	// Required client metrics for Pushgateway
	m.clientBytesSent = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "client_bytes_sent",
			Help: "Total bytes sent by client",
		},
	)

	m.clientBytesRecv = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "client_bytes_recv",
			Help: "Total bytes received by client",
		},
	)

	m.p2pSessions = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "p2p_sessions",
			Help: "Number of active P2P sessions",
		},
	)

	m.transportMode = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "transport_mode",
			Help: "Current transport mode (0=QUIC, 1=WireGuard, 2=gRPC)",
		},
	)

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
		m.clientBytesSent,
		m.clientBytesRecv,
		m.p2pSessions,
		m.transportMode,
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

// initPushgateway initializes Pushgateway pusher
func (m *Metrics) initPushgateway() {
	if m.pushgatewayConfig == nil || !m.pushgatewayConfig.Enabled {
		return
	}

	// Create pusher
	m.pusher = push.New(m.pushgatewayConfig.URL, m.pushgatewayConfig.JobName).
		Grouping("instance", m.pushgatewayConfig.Instance).
		Collector(m.clientBytesSent).
		Collector(m.clientBytesRecv).
		Collector(m.p2pSessions).
		Collector(m.transportMode)

	// Start push context
	m.pushCtx, m.pushCancel = context.WithCancel(context.Background())

	// Start periodic pushing
	go m.pushLoop()

	fmt.Printf("Pushgateway initialized: %s (job: %s, instance: %s)\n",
		m.pushgatewayConfig.URL,
		m.pushgatewayConfig.JobName,
		m.pushgatewayConfig.Instance)
}

// pushLoop runs the periodic push to Pushgateway
func (m *Metrics) pushLoop() {
	ticker := time.NewTicker(m.pushgatewayConfig.PushInterval)
	defer ticker.Stop()

	// Initial push
	m.pushMetrics()

	for {
		select {
		case <-m.pushCtx.Done():
			return
		case <-ticker.C:
			m.pushMetrics()
		}
	}
}

// pushMetrics pushes metrics to Pushgateway with exponential backoff
func (m *Metrics) pushMetrics() {
	m.pushMutex.RLock()
	pusher := m.pusher
	m.pushMutex.RUnlock()

	if pusher == nil {
		return
	}

	// Exponential backoff parameters
	maxRetries := 3
	baseDelay := 1 * time.Second
	maxDelay := 30 * time.Second

	for attempt := 0; attempt < maxRetries; attempt++ {
		err := pusher.Push()
		if err == nil {
			// Success
			return
		}

		// Calculate delay with exponential backoff
		delay := time.Duration(1<<uint(attempt)) * baseDelay
		if delay > maxDelay {
			delay = maxDelay
		}

		fmt.Printf("Failed to push metrics to Pushgateway (attempt %d/%d): %v, retrying in %v\n",
			attempt+1, maxRetries, err, delay)

		// Wait before retry
		select {
		case <-m.pushCtx.Done():
			return
		case <-time.After(delay):
			continue
		}
	}

	fmt.Printf("Failed to push metrics to Pushgateway after %d attempts\n", maxRetries)
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
	// Stop Pushgateway pushing
	m.pushMutex.Lock()
	if m.pushCancel != nil {
		m.pushCancel()
		m.pushCancel = nil // Prevent double cancel
	}
	m.pushMutex.Unlock()

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

// RecordClientBytesSent records bytes sent by client
func (m *Metrics) RecordClientBytesSent(bytes int64) {
	if !m.enabled {
		return
	}
	m.clientBytesSent.Add(float64(bytes))
}

// RecordClientBytesRecv records bytes received by client
func (m *Metrics) RecordClientBytesRecv(bytes int64) {
	if !m.enabled {
		return
	}
	m.clientBytesRecv.Add(float64(bytes))
}

// SetP2PSessions sets the number of active P2P sessions
func (m *Metrics) SetP2PSessions(count int) {
	if !m.enabled {
		return
	}
	m.p2pSessions.Set(float64(count))
}

// SetTransportMode sets the current transport mode
// 0=QUIC, 1=WireGuard, 2=gRPC
func (m *Metrics) SetTransportMode(mode int) {
	if !m.enabled {
		return
	}
	m.transportMode.Set(float64(mode))
}

// ForcePush forces an immediate push to Pushgateway
func (m *Metrics) ForcePush() error {
	if !m.enabled || m.pusher == nil {
		return fmt.Errorf("pushgateway not enabled or configured")
	}

	return m.pusher.Push()
}

// GetPushgatewayConfig returns the Pushgateway configuration
func (m *Metrics) GetPushgatewayConfig() *PushgatewayConfig {
	return m.pushgatewayConfig
}

// GetMetrics returns current metrics as a map
func (m *Metrics) GetMetrics() map[string]interface{} {
	if !m.enabled {
		return map[string]interface{}{"enabled": false}
	}

	result := map[string]interface{}{
		"enabled": true,
		"port":    m.port,
	}

	if m.pushgatewayConfig != nil && m.pushgatewayConfig.Enabled {
		result["pushgateway"] = map[string]interface{}{
			"enabled":       m.pushgatewayConfig.Enabled,
			"url":           m.pushgatewayConfig.URL,
			"job_name":      m.pushgatewayConfig.JobName,
			"instance":      m.pushgatewayConfig.Instance,
			"push_interval": m.pushgatewayConfig.PushInterval.String(),
		}
	}

	return result
}
