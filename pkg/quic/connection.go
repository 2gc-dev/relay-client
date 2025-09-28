package quic

import (
	"context"
	"crypto/tls"
	"fmt"
	"sync"
	"time"

	"github.com/quic-go/quic-go"
)

// QUICConnection manages QUIC connections and streams
type QUICConnection struct {
	conn      *quic.Conn
	streams   map[string]*quic.Stream
	mu        sync.RWMutex
	logger    Logger
	config    *quic.Config
	tlsConfig *tls.Config
}

// Logger interface for QUIC connection logging
type Logger interface {
	Info(msg string, fields ...interface{})
	Error(msg string, fields ...interface{})
	Debug(msg string, fields ...interface{})
	Warn(msg string, fields ...interface{})
}

// NewQUICConnection creates a new QUIC connection manager
func NewQUICConnection(logger Logger) *QUICConnection {
	return &QUICConnection{
		streams: make(map[string]*quic.Stream),
		logger:  logger,
		config: &quic.Config{
			HandshakeIdleTimeout:  10 * time.Second,
			MaxIdleTimeout:        30 * time.Second,
			MaxIncomingStreams:    100,
			MaxIncomingUniStreams: 100,
			KeepAlivePeriod:       15 * time.Second,
		},
		tlsConfig: &tls.Config{
			InsecureSkipVerify: false,
			MinVersion:         tls.VersionTLS13,
			NextProtos:         []string{"cloudbridge-p2p", "h3", "h3-29", "h3-28", "h3-27"},
		},
	}
}

// Connect establishes a QUIC connection to the specified address
func (q *QUICConnection) Connect(ctx context.Context, addr string) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	q.logger.Info("Connecting to QUIC server", "address", addr)

	conn, err := quic.DialAddr(ctx, addr, q.tlsConfig, q.config)
	if err != nil {
		return fmt.Errorf("failed to connect to QUIC server: %w", err)
	}

	q.conn = conn
	q.logger.Info("QUIC connection established", "address", addr)

	// Start connection monitoring
	go q.monitorConnection()

	return nil
}

// Listen starts listening for incoming QUIC connections
func (q *QUICConnection) Listen(ctx context.Context, addr string) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	q.logger.Info("Starting QUIC listener", "address", addr)

	listener, err := quic.ListenAddr(addr, q.tlsConfig, q.config)
	if err != nil {
		return fmt.Errorf("failed to start QUIC listener: %w", err)
	}

	q.logger.Info("QUIC listener started", "address", addr)

	// Accept connections
	go q.acceptConnections(ctx, listener)

	return nil
}

// CreateStream creates a new bidirectional stream
func (q *QUICConnection) CreateStream(ctx context.Context, streamID string) (*quic.Stream, error) {
	q.mu.RLock()
	defer q.mu.RUnlock()

	if q.conn == nil {
		return nil, fmt.Errorf("QUIC connection not established")
	}

	stream, err := q.conn.OpenStreamSync(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create stream: %w", err)
	}

	q.streams[streamID] = stream
	q.logger.Debug("Stream created", "stream_id", streamID)

	return stream, nil
}

// AcceptStream accepts an incoming stream
func (q *QUICConnection) AcceptStream(ctx context.Context) (*quic.Stream, error) {
	q.mu.RLock()
	defer q.mu.RUnlock()

	if q.conn == nil {
		return nil, fmt.Errorf("QUIC connection not established")
	}

	stream, err := q.conn.AcceptStream(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to accept stream: %w", err)
	}

	streamID := fmt.Sprintf("stream_%d", stream.StreamID())
	q.streams[streamID] = stream
	q.logger.Debug("Stream accepted", "stream_id", streamID)

	return stream, nil
}

// GetStream returns a stream by ID
func (q *QUICConnection) GetStream(streamID string) (*quic.Stream, bool) {
	q.mu.RLock()
	defer q.mu.RUnlock()

	stream, exists := q.streams[streamID]
	return stream, exists
}

// CloseStream closes a stream
func (q *QUICConnection) CloseStream(streamID string) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	stream, exists := q.streams[streamID]
	if !exists {
		return fmt.Errorf("stream not found: %s", streamID)
	}

	if err := stream.Close(); err != nil {
		q.logger.Error("Failed to close stream", "stream_id", streamID, "error", err)
		return err
	}

	delete(q.streams, streamID)
	q.logger.Debug("Stream closed", "stream_id", streamID)

	return nil
}

// Close closes the QUIC connection
func (q *QUICConnection) Close() error {
	q.mu.Lock()
	defer q.mu.Unlock()

	if q.conn == nil {
		return nil
	}

	q.logger.Info("Closing QUIC connection")

	// Close all streams
	for streamID, stream := range q.streams {
		if err := stream.Close(); err != nil {
			q.logger.Error("Failed to close stream", "stream_id", streamID, "error", err)
		}
	}
	q.streams = make(map[string]*quic.Stream)

	// Close connection
	if err := q.conn.CloseWithError(0, "client shutdown"); err != nil {
		q.logger.Error("Failed to close QUIC connection", "error", err)
		return err
	}

	q.conn = nil
	q.logger.Info("QUIC connection closed")

	return nil
}

// IsConnected returns true if the connection is active
func (q *QUICConnection) IsConnected() bool {
	q.mu.RLock()
	defer q.mu.RUnlock()

	return q.conn != nil
}

// GetConnectionState returns the connection state
func (q *QUICConnection) GetConnectionState() quic.ConnectionState {
	q.mu.RLock()
	defer q.mu.RUnlock()

	if q.conn == nil {
		return quic.ConnectionState{}
	}

	return q.conn.ConnectionState()
}

// GetStats returns connection statistics
func (q *QUICConnection) GetStats() map[string]interface{} {
	q.mu.RLock()
	defer q.mu.RUnlock()

	stats := map[string]interface{}{
		"connected":    q.conn != nil,
		"stream_count": len(q.streams),
	}

	if q.conn != nil {
		state := q.conn.ConnectionState()
		stats["tls_handshake_complete"] = state.TLS.HandshakeComplete
		stats["peer_certificates"] = len(state.TLS.PeerCertificates)
	}

	return stats
}

// SetTLSConfig sets the TLS configuration
func (q *QUICConnection) SetTLSConfig(config *tls.Config) {
	q.mu.Lock()
	defer q.mu.Unlock()

	q.tlsConfig = config
}

// SetQUICConfig sets the QUIC configuration
func (q *QUICConnection) SetQUICConfig(config *quic.Config) {
	q.mu.Lock()
	defer q.mu.Unlock()

	q.config = config
}

// monitorConnection monitors the connection state
func (q *QUICConnection) monitorConnection() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			q.mu.RLock()
			connected := q.conn != nil
			q.mu.RUnlock()

			if !connected {
				q.logger.Warn("QUIC connection lost")
				return
			}

			// Log connection stats
			stats := q.GetStats()
			q.logger.Debug("QUIC connection stats", "stats", stats)
		}
	}
}

// acceptConnections accepts incoming connections
func (q *QUICConnection) acceptConnections(ctx context.Context, listener *quic.Listener) {
	defer listener.Close()

	for {
		select {
		case <-ctx.Done():
			q.logger.Info("Stopping QUIC listener")
			return
		default:
			conn, err := listener.Accept(ctx)
			if err != nil {
				q.logger.Error("Failed to accept QUIC connection", "error", err)
				continue
			}

			q.logger.Info("QUIC connection accepted", "remote_addr", conn.RemoteAddr())

			// Handle the connection
			go q.handleIncomingConnection(conn)
		}
	}
}

// handleIncomingConnection handles an incoming QUIC connection
func (q *QUICConnection) handleIncomingConnection(conn *quic.Conn) {
	defer conn.CloseWithError(0, "connection closed")

	// Accept streams from this connection
	for {
		stream, err := conn.AcceptStream(context.Background())
		if err != nil {
			q.logger.Error("Failed to accept stream from incoming connection", "error", err)
			return
		}

		streamID := fmt.Sprintf("incoming_%d", stream.StreamID())
		q.mu.Lock()
		q.streams[streamID] = stream
		q.mu.Unlock()

		q.logger.Debug("Incoming stream accepted", "stream_id", streamID)

		// Handle the stream
		go q.handleStream(streamID, stream)
	}
}

// handleStream handles a stream
func (q *QUICConnection) handleStream(streamID string, stream *quic.Stream) {
	defer func() {
		stream.Close()
		q.mu.Lock()
		delete(q.streams, streamID)
		q.mu.Unlock()
	}()

	// Read from stream
	buffer := make([]byte, 4096)
	for {
		n, err := stream.Read(buffer)
		if err != nil {
			q.logger.Debug("Stream read error", "stream_id", streamID, "error", err)
			return
		}

		q.logger.Debug("Data received on stream", "stream_id", streamID, "bytes", n)

		// Echo back the data (for testing)
		if _, err := stream.Write(buffer[:n]); err != nil {
			q.logger.Error("Failed to write to stream", "stream_id", streamID, "error", err)
			return
		}
	}
}
