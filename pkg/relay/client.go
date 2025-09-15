package relay

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net"
	"strconv"
	"sync"

	"github.com/2gc-dev/cloudbridge-client/pkg/auth"
	"github.com/2gc-dev/cloudbridge-client/pkg/config"
	"github.com/2gc-dev/cloudbridge-client/pkg/errors"
	"github.com/2gc-dev/cloudbridge-client/pkg/heartbeat"
	"github.com/2gc-dev/cloudbridge-client/pkg/metrics"
	"github.com/2gc-dev/cloudbridge-client/pkg/p2p"
	"github.com/2gc-dev/cloudbridge-client/pkg/performance"
	"github.com/2gc-dev/cloudbridge-client/pkg/tunnel"
	"github.com/2gc-dev/cloudbridge-client/pkg/types"
	"github.com/golang-jwt/jwt/v5"
)

// Client represents a CloudBridge Relay client
type Client struct {
	config         *types.Config
	conn           net.Conn
	encoder        *json.Encoder
	decoder        *json.Decoder
	authManager    *auth.AuthManager
	tunnelManager  *tunnel.Manager
	heartbeatMgr   *heartbeat.Manager
	retryStrategy  *errors.RetryStrategy
	metrics        *metrics.Metrics
	optimizer      *performance.Optimizer
	p2pManager     *p2p.Manager
	connectionType string
	logger         *relayLogger
	mu             sync.RWMutex
	connected      bool
	clientID       string
	tenantID       string
	ctx            context.Context
	cancel         context.CancelFunc
}

// Message types as defined in the requirements
const (
	MessageTypeHello             = "hello"
	MessageTypeHelloResponse     = "hello_response"
	MessageTypeAuth              = "auth"
	MessageTypeAuthResponse      = "auth_response"
	MessageTypeTunnelInfo        = "tunnel_info"
	MessageTypeTunnelResponse    = "tunnel_response"
	MessageTypeHeartbeat         = "heartbeat"
	MessageTypeHeartbeatResponse = "heartbeat_response"
	MessageTypeError             = "error"
	// P2P message types
	MessageTypeP2PHandshake     = "p2p_handshake"
	MessageTypeP2PHandshakeResp = "p2p_handshake_response"
	MessageTypePeerDiscovery    = "peer_discovery"
	MessageTypePeerList         = "peer_list"
	MessageTypeMeshConfig       = "mesh_config"
)

// NewClient creates a new CloudBridge Relay client
func NewClient(cfg *types.Config) (*Client, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Create authentication manager
	authManager, err := auth.NewAuthManager(&auth.AuthConfig{
		Type:   cfg.Auth.Type,
		Secret: cfg.Auth.Secret,
		Keycloak: &auth.KeycloakConfig{
			ServerURL: cfg.Auth.Keycloak.ServerURL,
			Realm:     cfg.Auth.Keycloak.Realm,
			ClientID:  cfg.Auth.Keycloak.ClientID,
			JWKSURL:   cfg.Auth.Keycloak.JWKSURL,
		},
	})
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create auth manager: %w", err)
	}

	// Create retry strategy
	retryStrategy := errors.NewRetryStrategy(
		cfg.RateLimiting.MaxRetries,
		cfg.RateLimiting.BackoffMultiplier,
		cfg.RateLimiting.MaxBackoff,
	)

	// Create metrics system
	metrics := metrics.NewMetrics(cfg.Metrics.Enabled, cfg.Metrics.PrometheusPort)

	// Create performance optimizer
	optimizer := performance.NewOptimizer(cfg.Performance.Enabled)

	client := &Client{
		config:        cfg,
		authManager:   authManager,
		retryStrategy: retryStrategy,
		metrics:       metrics,
		optimizer:     optimizer,
		logger:        NewRelayLogger("relay-client"),
		ctx:           ctx,
		cancel:        cancel,
	}

	// Create tunnel manager
	client.tunnelManager = tunnel.NewManager(client)

	// Create heartbeat manager
	client.heartbeatMgr = heartbeat.NewManager(client)

	// Initialize performance optimization
	if cfg.Performance.Enabled {
		switch cfg.Performance.OptimizationMode {
		case "high_throughput":
			optimizer.OptimizeForHighThroughput()
		case "low_latency":
			optimizer.OptimizeForLowLatency()
		}
	}

	// Start metrics server
	if err := metrics.Start(); err != nil {
		cancel()
		return nil, fmt.Errorf("failed to start metrics server: %w", err)
	}

	return client, nil
}

// Connect establishes a connection to the relay server
func (c *Client) Connect() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.connected {
		return fmt.Errorf("already connected")
	}

	// Create TLS config
	tlsConfig, err := config.CreateTLSConfig(c.config)
	if err != nil {
		return fmt.Errorf("failed to create TLS config: %w", err)
	}

	// Establish connection
	var conn net.Conn
	address := net.JoinHostPort(c.config.Relay.Host, strconv.Itoa(c.config.Relay.Port))
	if tlsConfig != nil {
		conn, err = tls.Dial("tcp", address, tlsConfig)
	} else {
		conn, err = net.Dial("tcp", address)
	}

	if err != nil {
		return errors.NewRelayError(errors.ErrTLSHandshakeFailed, fmt.Sprintf("failed to connect: %v", err))
	}

	c.conn = conn
	c.encoder = json.NewEncoder(conn)
	c.decoder = json.NewDecoder(conn)

	// Send hello message
	if err := c.sendHello(); err != nil {
		if cerr := conn.Close(); cerr != nil {
			_ = cerr // Игнорируем ошибку закрытия соединения при ошибке отправки hello
		}
		return fmt.Errorf("failed to send hello: %w", err)
	}

	// Receive hello response
	if err := c.receiveHelloResponse(); err != nil {
		if cerr := conn.Close(); cerr != nil {
			_ = cerr // Игнорируем ошибку закрытия соединения при ошибке получения hello response
		}
		return fmt.Errorf("failed to receive hello response: %w", err)
	}

	c.connected = true
	return nil
}

// Authenticate authenticates with the relay server
func (c *Client) Authenticate(token string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.connected {
		return fmt.Errorf("not connected")
	}

	// Validate token and extract claims
	validatedToken, err := c.authManager.ValidateToken(token)
	if err != nil {
		return fmt.Errorf("failed to validate token: %w", err)
	}

	// Extract subject and tenant_id from token
	_, tenantID, err := c.authManager.ExtractClaims(validatedToken)
	if err != nil {
		return fmt.Errorf("failed to extract claims: %w", err)
	}

	// Store tenant ID
	c.tenantID = tenantID

	// Create auth message
	authMsg, err := c.authManager.CreateAuthMessage(token)
	if err != nil {
		return fmt.Errorf("failed to create auth message: %w", err)
	}

	// Send auth message
	if err := c.sendMessage(authMsg); err != nil {
		return fmt.Errorf("failed to send auth message: %w", err)
	}

	// Receive auth response
	response, err := c.receiveMessage()
	if err != nil {
		return fmt.Errorf("failed to receive auth response: %w", err)
	}

	// Check response type
	if response["type"] != MessageTypeAuthResponse {
		return fmt.Errorf("unexpected response type: %s", response["type"])
	}

	// Check status
	if status, ok := response["status"].(string); !ok || status != "ok" {
		errorMsg := "authentication failed"
		if msg, ok := response["error"].(string); ok {
			errorMsg = msg
		}
		return errors.NewRelayError(errors.ErrAuthenticationFailed, errorMsg)
	}

	// Store client ID
	if clientID, ok := response["client_id"].(string); ok {
		c.clientID = clientID
	}

	// Determine connection type from JWT token
	connectionType, err := c.authManager.ExtractConnectionType(validatedToken)
	if err != nil {
		// If connection type is not specified, default to client-server
		connectionType = "client-server"
		c.logger.Warn("Failed to extract connection type from token, defaulting to client-server", "error", err)
	}
	c.connectionType = connectionType

	// Initialize P2P manager if connection type is P2P mesh
	if connectionType == "p2p-mesh" {
		if err := c.initializeP2PManager(validatedToken); err != nil {
			return fmt.Errorf("failed to initialize P2P manager: %w", err)
		}
	}

	return nil
}

// CreateTunnel creates a tunnel with the specified parameters
func (c *Client) CreateTunnel(tunnelID string, localPort int, remoteHost string, remotePort int) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.connected {
		return fmt.Errorf("not connected")
	}

	// Create tunnel info message
	tunnelMsg := map[string]interface{}{
		"type":        MessageTypeTunnelInfo,
		"tunnel_id":   tunnelID,
		"tenant_id":   c.tenantID,
		"local_port":  localPort,
		"remote_host": remoteHost,
		"remote_port": remotePort,
	}

	// Send tunnel message
	if err := c.sendMessage(tunnelMsg); err != nil {
		return fmt.Errorf("failed to send tunnel message: %w", err)
	}

	// Receive tunnel response
	response, err := c.receiveMessage()
	if err != nil {
		return fmt.Errorf("failed to receive tunnel response: %w", err)
	}

	// Check response type
	if response["type"] != MessageTypeTunnelResponse {
		return fmt.Errorf("unexpected response type: %s", response["type"])
	}

	// Check status
	if status, ok := response["status"].(string); !ok || status != "ok" {
		errorMsg := "tunnel creation failed"
		if msg, ok := response["error"].(string); ok {
			errorMsg = msg
		}
		return errors.NewRelayError(errors.ErrTunnelCreationFailed, errorMsg)
	}

	// Register tunnel with tunnel manager
	if err := c.tunnelManager.RegisterTunnel(tunnelID, localPort, remoteHost, remotePort); err != nil {
		return fmt.Errorf("failed to register tunnel: %w", err)
	}

	return nil
}

// StartHeartbeat starts the heartbeat mechanism
func (c *Client) StartHeartbeat() error {
	return c.heartbeatMgr.Start()
}

// StopHeartbeat stops the heartbeat mechanism
func (c *Client) StopHeartbeat() {
	c.heartbeatMgr.Stop()
}

// Close closes the client connection and cleans up resources
func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.connected {
		return nil
	}

	// Stop heartbeat
	c.heartbeatMgr.Stop()

	// Stop metrics server
	if c.metrics != nil {
		if err := c.metrics.Stop(); err != nil {
			// Log error but don't fail close operation
			fmt.Printf("Failed to stop metrics: %v\n", err)
		}
	}

	// Close connection
	if c.conn != nil {
		if err := c.conn.Close(); err != nil {
			fmt.Printf("Failed to close connection: %v\n", err)
		}
	}

	// Cancel context
	c.cancel()

	c.connected = false
	return nil
}

// IsConnected returns true if the client is connected
func (c *Client) IsConnected() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.connected
}

// GetClientID returns the client ID
func (c *Client) GetClientID() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.clientID
}

// sendHello sends a hello message
func (c *Client) sendHello() error {
	helloMsg := map[string]interface{}{
		"type":     MessageTypeHello,
		"version":  "1.0",
		"features": []string{"tls", "heartbeat", "tunnel_info"},
	}
	return c.sendMessage(helloMsg)
}

// receiveHelloResponse receives a hello response
func (c *Client) receiveHelloResponse() error {
	response, err := c.receiveMessage()
	if err != nil {
		return fmt.Errorf("failed to receive hello response: %w", err)
	}

	if response["type"] != MessageTypeHelloResponse {
		return fmt.Errorf("unexpected response type: %s", response["type"])
	}

	return nil
}

// sendMessage sends a JSON message
func (c *Client) sendMessage(msg map[string]interface{}) error {
	return c.encoder.Encode(msg)
}

// receiveMessage receives a JSON message
func (c *Client) receiveMessage() (map[string]interface{}, error) {
	var msg map[string]interface{}
	if err := c.decoder.Decode(&msg); err != nil {
		return nil, fmt.Errorf("failed to decode message: %w", err)
	}
	return msg, nil
}

// SendHeartbeat sends a heartbeat message
func (c *Client) SendHeartbeat() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.connected {
		return fmt.Errorf("not connected")
	}

	heartbeatMsg := map[string]interface{}{
		"type": MessageTypeHeartbeat,
	}

	if err := c.sendMessage(heartbeatMsg); err != nil {
		return fmt.Errorf("failed to send heartbeat: %w", err)
	}

	response, err := c.receiveMessage()
	if err != nil {
		return fmt.Errorf("failed to receive heartbeat response: %w", err)
	}

	if response["type"] != MessageTypeHeartbeatResponse {
		return fmt.Errorf("unexpected response type: %s", response["type"])
	}

	return nil
}

// GetConfig returns the client configuration
func (c *Client) GetConfig() *types.Config {
	return c.config
}

// GetRetryStrategy returns the retry strategy
func (c *Client) GetRetryStrategy() *errors.RetryStrategy {
	return c.retryStrategy
}

// GetTenantID returns the tenant ID
func (c *Client) GetTenantID() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.tenantID
}

// GetMetrics returns the metrics system
func (c *Client) GetMetrics() *metrics.Metrics {
	return c.metrics
}

// GetOptimizer returns the performance optimizer
func (c *Client) GetOptimizer() *performance.Optimizer {
	return c.optimizer
}

// initializeP2PManager initializes the P2P manager with configuration from JWT token
func (c *Client) initializeP2PManager(token *jwt.Token) error {
	// Extract P2P configuration from JWT token
	p2pConfig, err := p2p.ExtractP2PConfigFromToken(c.authManager, token)
	if err != nil {
		return fmt.Errorf("failed to extract P2P config from token: %w", err)
	}

	// Create P2P logger
	p2pLogger := &p2pLogger{client: c}

	// Create P2P manager
	c.p2pManager = p2p.NewManager(p2pConfig, p2pLogger)

	// Start P2P manager
	if err := c.p2pManager.Start(); err != nil {
		return fmt.Errorf("failed to start P2P manager: %w", err)
	}

	c.logger.Info("P2P manager initialized and started successfully",
		"connection_type", p2pConfig.ConnectionType,
		"tenant_id", p2pConfig.TenantID)

	return nil
}

// GetP2PManager returns the P2P manager
func (c *Client) GetP2PManager() *p2p.Manager {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.p2pManager
}

// GetConnectionType returns the connection type
func (c *Client) GetConnectionType() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.connectionType
}

// p2pLogger implements the p2p.Logger interface
type p2pLogger struct {
	client *Client
}

func (pl *p2pLogger) Info(msg string, fields ...interface{}) {
	pl.client.logger.Info(msg, fields...)
}

func (pl *p2pLogger) Error(msg string, fields ...interface{}) {
	pl.client.logger.Error(msg, fields...)
}

func (pl *p2pLogger) Debug(msg string, fields ...interface{}) {
	pl.client.logger.Debug(msg, fields...)
}

func (pl *p2pLogger) Warn(msg string, fields ...interface{}) {
	pl.client.logger.Warn(msg, fields...)
}

// relayLogger implements logging for the relay client
type relayLogger struct {
	prefix string
}

// NewRelayLogger creates a new relay logger
func NewRelayLogger(prefix string) *relayLogger {
	return &relayLogger{
		prefix: prefix,
	}
}

func (rl *relayLogger) Info(msg string, fields ...interface{}) {
	if len(fields) > 0 {
		fmt.Printf("[%s] INFO: %s %v\n", rl.prefix, msg, fields)
	} else {
		fmt.Printf("[%s] INFO: %s\n", rl.prefix, msg)
	}
}

func (rl *relayLogger) Error(msg string, fields ...interface{}) {
	if len(fields) > 0 {
		fmt.Printf("[%s] ERROR: %s %v\n", rl.prefix, msg, fields)
	} else {
		fmt.Printf("[%s] ERROR: %s\n", rl.prefix, msg)
	}
}

func (rl *relayLogger) Debug(msg string, fields ...interface{}) {
	if len(fields) > 0 {
		fmt.Printf("[%s] DEBUG: %s %v\n", rl.prefix, msg, fields)
	} else {
		fmt.Printf("[%s] DEBUG: %s\n", rl.prefix, msg)
	}
}

func (rl *relayLogger) Warn(msg string, fields ...interface{}) {
	if len(fields) > 0 {
		fmt.Printf("[%s] WARN: %s %v\n", rl.prefix, msg, fields)
	} else {
		fmt.Printf("[%s] WARN: %s\n", rl.prefix, msg)
	}
}
