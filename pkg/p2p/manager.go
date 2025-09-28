package p2p

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/2gc-dev/cloudbridge-client/pkg/api"
	"github.com/2gc-dev/cloudbridge-client/pkg/auth"
	"github.com/2gc-dev/cloudbridge-client/pkg/ice"
	"github.com/2gc-dev/cloudbridge-client/pkg/quic"
	"github.com/golang-jwt/jwt/v5"
	pionice "github.com/pion/ice/v2"
	quicgo "github.com/quic-go/quic-go"
)

// Manager handles P2P connections using QUIC + ICE/STUN/TURN
type Manager struct {
	config          *P2PConfig
	iceAgent        *ice.ICEAgent
	quicConn        *quic.QUICConnection
	mesh            *MeshNetwork
	status          *P2PStatus
	apiManager      *api.Manager
	ctx             context.Context
	cancel          context.CancelFunc
	mu              sync.RWMutex
	logger          Logger
	sessionID       string
	peerID          string
	tenantID        string
	token           string
	relaySessionID  string
	connections     map[string]*PeerConnection
	heartbeatTicker *time.Ticker
}

// Logger interface for P2P manager logging
type Logger interface {
	Info(msg string, fields ...interface{})
	Error(msg string, fields ...interface{})
	Debug(msg string, fields ...interface{})
	Warn(msg string, fields ...interface{})
}

// PeerConnection represents a connection to another peer
type PeerConnection struct {
	PeerID      string
	SessionID   string
	Stream      *quicgo.Stream
	ConnectedAt time.Time
	LastSeen    time.Time
	mu          sync.RWMutex
}

// NewManager creates a new P2P manager
func NewManager(config *P2PConfig, logger Logger) *Manager {
	ctx, cancel := context.WithCancel(context.Background())

	return &Manager{
		config:      config,
		status:      &P2PStatus{ConnectionType: config.ConnectionType, MeshEnabled: true},
		ctx:         ctx,
		cancel:      cancel,
		logger:      logger,
		connections: make(map[string]*PeerConnection),
	}
}

// NewManagerWithAPI creates a new P2P manager with HTTP API support
func NewManagerWithAPI(config *P2PConfig, apiConfig *api.ManagerConfig, authManager *auth.AuthManager, token string, logger Logger) *Manager {
	ctx, cancel := context.WithCancel(context.Background())

	// Parse heartbeat interval from mesh config
	heartbeatInterval := 30 * time.Second // default
	if config.MeshConfig != nil && config.MeshConfig.HeartbeatInterval != nil {
		heartbeatInterval = api.ParseHeartbeatInterval(config.MeshConfig.HeartbeatInterval)
	}

	// Create API manager
	apiManagerConfig := &api.ManagerConfig{
		BaseURL:            apiConfig.BaseURL,
		InsecureSkipVerify: apiConfig.InsecureSkipVerify,
		Timeout:            apiConfig.Timeout,
		MaxRetries:         apiConfig.MaxRetries,
		BackoffMultiplier:  apiConfig.BackoffMultiplier,
		MaxBackoff:         apiConfig.MaxBackoff,
		Token:              token,
		TenantID:           config.TenantID,
		HeartbeatInterval:  heartbeatInterval,
	}

	apiManager := api.NewManager(apiManagerConfig, authManager, logger)

	return &Manager{
		config:      config,
		apiManager:  apiManager,
		status:      &P2PStatus{ConnectionType: config.ConnectionType, MeshEnabled: true},
		ctx:         ctx,
		cancel:      cancel,
		logger:      logger,
		connections: make(map[string]*PeerConnection),
	}
}

// Start initializes and starts the P2P manager
func (m *Manager) Start() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logger.Info("Starting P2P manager with QUIC + ICE/STUN/TURN")

	// Generate session ID
	m.sessionID = fmt.Sprintf("sess_%d", time.Now().UnixNano())

	// Start HTTP API manager if available
	if m.apiManager != nil {
		if err := m.apiManager.Start(); err != nil {
			return fmt.Errorf("failed to start API manager: %w", err)
		}
		m.peerID = m.apiManager.GetPeerID()
		m.logger.Info("HTTP API manager started", "peer_id", m.peerID)
	}

	// Initialize ICE agent
	if err := m.initializeICE(); err != nil {
		return fmt.Errorf("failed to initialize ICE: %w", err)
	}

	// Initialize QUIC connection
	if err := m.initializeQUIC(); err != nil {
		return fmt.Errorf("failed to initialize QUIC: %w", err)
	}

	// Connect to relay server with authentication
	if err := m.connectToRelayServer(); err != nil {
		return fmt.Errorf("failed to connect to relay server: %w", err)
	}

	// Start peer discovery
	if m.apiManager != nil {
		go m.startPeerDiscovery()
	}

	// Start heartbeat routine
	m.startHeartbeat()

	// Create mesh network
	if m.config.MeshConfig != nil {
		m.mesh = NewMeshNetwork(m.config.MeshConfig, m.logger)
		if err := m.mesh.Start(); err != nil {
			return fmt.Errorf("failed to start mesh network: %w", err)
		}
	}

	m.status.IsConnected = true
	m.status.MeshEnabled = true
	m.logger.Info("P2P manager started successfully")
	return nil
}

// Stop stops the P2P manager and cleans up resources
func (m *Manager) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logger.Info("Stopping P2P manager")

	// Stop heartbeat ticker
	if m.heartbeatTicker != nil {
		m.heartbeatTicker.Stop()
	}

	// Cancel context to stop all goroutines
	m.cancel()

	// Stop API manager
	if m.apiManager != nil {
		m.apiManager.Stop()
	}

	// Close all peer connections
	for peerID, conn := range m.connections {
		if err := conn.Stream.Close(); err != nil {
			m.logger.Error("Failed to close peer connection", "peer_id", peerID, "error", err)
		}
	}
	m.connections = make(map[string]*PeerConnection)

	// Stop QUIC connection
	if m.quicConn != nil {
		if err := m.quicConn.Close(); err != nil {
			m.logger.Error("Failed to close QUIC connection", "error", err)
		}
	}

	// Stop ICE agent
	if m.iceAgent != nil {
		if err := m.iceAgent.Stop(); err != nil {
			m.logger.Error("Failed to stop ICE agent", "error", err)
		}
	}

	// Stop mesh network
	if m.mesh != nil {
		if err := m.mesh.Stop(); err != nil {
			m.logger.Error("Failed to stop mesh network", "error", err)
		}
	}

	m.status.IsConnected = false
	m.logger.Info("P2P manager stopped")
	return nil
}

// initializeICE initializes the ICE agent
func (m *Manager) initializeICE() error {
	m.logger.Info("Initializing ICE agent")

	// Hardcoded STUN servers for edge.2gc.ru
	stunServers := []string{"edge.2gc.ru:19302"}

	// Create ICE agent
	m.iceAgent = ice.NewICEAgent(stunServers, []string{}, m.logger)

	if err := m.iceAgent.Start(); err != nil {
		return fmt.Errorf("failed to start ICE agent: %w", err)
	}

	// Gather candidates
	candidates, err := m.iceAgent.GatherCandidates()
	if err != nil {
		return fmt.Errorf("failed to gather ICE candidates: %w", err)
	}

	m.logger.Info("ICE candidates gathered", "count", len(candidates))
	return nil
}

// initializeQUIC initializes the QUIC connection
func (m *Manager) initializeQUIC() error {
	m.logger.Info("Initializing QUIC connection")

	// Create QUIC connection manager
	m.quicConn = quic.NewQUICConnection(m.logger)

	// Start listening for incoming connections on configured port (5553)
	listenAddr := ":5553"
	if err := m.quicConn.Listen(m.ctx, listenAddr); err != nil {
		return fmt.Errorf("failed to start QUIC listener: %w", err)
	}

	m.logger.Info("QUIC listener started", "address", listenAddr)
	return nil
}

// connectToRelayServer connects to the relay server with authentication
func (m *Manager) connectToRelayServer() error {
	if m.apiManager == nil {
		return fmt.Errorf("API manager not available")
	}

	// Get token from API manager
	token := m.apiManager.GetToken()
	if token == "" {
		return fmt.Errorf("no token available for authentication")
	}

	// Connect to relay server QUIC endpoint
	relayAddr := "10.244.3.33:5553" // Direct pod IP for testing
	m.logger.Info("Connecting to relay server", "address", relayAddr)

	// Create QUIC connection to relay server
	err := m.quicConn.Connect(m.ctx, relayAddr)
	if err != nil {
		return fmt.Errorf("failed to connect to relay server: %w", err)
	}

	// Create authentication stream
	stream, err := m.quicConn.CreateStream(m.ctx, "auth")
	if err != nil {
		return fmt.Errorf("failed to create auth stream: %w", err)
	}

	// Send authentication token in the expected format
	authData := fmt.Sprintf("AUTH %s", token)
	_, err = stream.Write([]byte(authData))
	if err != nil {
		return fmt.Errorf("failed to send auth token: %w", err)
	}

	// Read authentication response
	buffer := make([]byte, 1024)
	n, err := stream.Read(buffer)
	if err != nil {
		return fmt.Errorf("failed to read auth response: %w", err)
	}

	response := string(buffer[:n])
	if response != "AUTH_OK" {
		return fmt.Errorf("authentication failed: %s", response)
	}

	m.logger.Info("Successfully authenticated with relay server")
	return nil
}

// ConnectToPeer establishes a connection to another peer
func (m *Manager) ConnectToPeer(targetPeerID string) error {
	m.logger.Info("Connecting to peer", "target_peer_id", targetPeerID)

	// 1. Gather ICE candidates
	candidates, err := m.iceAgent.GatherCandidates()
	if err != nil {
		return fmt.Errorf("failed to gather candidates: %w", err)
	}

	// 2. Send candidates to relay
	if err := m.sendCandidatesToRelay(candidates); err != nil {
		return fmt.Errorf("failed to send candidates to relay: %w", err)
	}

	// 3. Get remote candidates from relay
	remoteCandidates, err := m.getRemoteCandidatesFromRelay(targetPeerID)
	if err != nil {
		return fmt.Errorf("failed to get remote candidates: %w", err)
	}

	// 4. Add remote candidates
	for _, candidate := range remoteCandidates {
		if err := m.iceAgent.AddRemoteCandidate(candidate); err != nil {
			m.logger.Warn("Failed to add remote candidate", "candidate", candidate.String(), "error", err)
		}
	}

	// 5. Start connectivity checks
	if err := m.iceAgent.StartConnectivityChecks(); err != nil {
		return fmt.Errorf("failed to start connectivity checks: %w", err)
	}

	// 6. Wait for connection establishment
	if err := m.waitForConnection(); err != nil {
		return fmt.Errorf("failed to establish connection: %w", err)
	}

	// 7. Establish QUIC connection
	return m.establishQUICConnection(targetPeerID)
}

// sendCandidatesToRelay sends ICE candidates to the relay server
func (m *Manager) sendCandidatesToRelay(candidates []pionice.Candidate) error {
	if m.apiManager == nil {
		return fmt.Errorf("API manager not available")
	}

	// Convert ICE candidates to API format
	apiCandidates := make([]*api.ICECandidate, len(candidates))
	for i, candidate := range candidates {
		apiCandidates[i] = &api.ICECandidate{
			Foundation: candidate.Foundation(),
			Component:  int(candidate.Component()),
			Transport:  candidate.NetworkType().String(),
			Priority:   int(candidate.Priority()),
			Address:    candidate.Address(),
			Port:       candidate.Port(),
			Type:       string(candidate.Type()),
		}
	}

	// Send to relay
	req := &api.ICESignalingRequest{
		SessionID:  m.sessionID,
		PeerID:     m.peerID,
		Candidates: apiCandidates,
	}

	return m.apiManager.SendICESignaling(req)
}

// getRemoteCandidatesFromRelay gets remote ICE candidates from relay
func (m *Manager) getRemoteCandidatesFromRelay(targetPeerID string) ([]pionice.Candidate, error) {
	if m.apiManager == nil {
		return nil, fmt.Errorf("API manager not available")
	}

	// Request remote candidates
	req := &api.ICECandidateRequest{
		SessionID:    m.sessionID,
		TargetPeerID: targetPeerID,
	}

	resp, err := m.apiManager.GetRemoteICECandidates(req)
	if err != nil {
		return nil, err
	}

	// Convert API candidates to ICE candidates
	candidates := make([]pionice.Candidate, len(resp.Candidates))
	for i, apiCandidate := range resp.Candidates {
		// Create candidate string in SDP format
		candidateStr := fmt.Sprintf("candidate:%s %d %s %d %s %d typ %s",
			apiCandidate.Foundation,
			apiCandidate.Component,
			apiCandidate.Transport,
			apiCandidate.Priority,
			apiCandidate.Address,
			apiCandidate.Port,
			apiCandidate.Type,
		)

		candidate, err := pionice.UnmarshalCandidate(candidateStr)
		if err != nil {
			m.logger.Error("Failed to unmarshal candidate", "error", err, "candidate", candidateStr)
			continue
		}
		candidates[i] = candidate
	}

	return candidates, nil
}

// waitForConnection waits for ICE connection to be established
func (m *Manager) waitForConnection() error {
	timeout := time.After(30 * time.Second)
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			return fmt.Errorf("ICE connection timeout")
		case <-ticker.C:
			state := m.iceAgent.GetConnectionState()
			if state == pionice.ConnectionStateConnected {
				m.logger.Info("ICE connection established")
				return nil
			}
		}
	}
}

// establishQUICConnection establishes QUIC connection to peer
func (m *Manager) establishQUICConnection(targetPeerID string) error {
	// Get selected candidate pair
	pair, err := m.iceAgent.GetSelectedCandidatePair()
	if err != nil {
		return fmt.Errorf("failed to get selected candidate pair: %w", err)
	}

	if pair == nil {
		return fmt.Errorf("no candidate pair selected")
	}

	// Connect to remote peer via QUIC
	remoteAddr := fmt.Sprintf("%s:%d", pair.Remote.Address(), pair.Remote.Port())

	stream, err := m.quicConn.CreateStream(m.ctx, fmt.Sprintf("peer_%s", targetPeerID))
	if err != nil {
		return fmt.Errorf("failed to create QUIC stream: %w", err)
	}

	// Store connection
	conn := &PeerConnection{
		PeerID:      targetPeerID,
		SessionID:   m.sessionID,
		Stream:      stream,
		ConnectedAt: time.Now(),
		LastSeen:    time.Now(),
	}

	m.mu.Lock()
	m.connections[targetPeerID] = conn
	m.mu.Unlock()

	m.logger.Info("QUIC connection established", "peer_id", targetPeerID, "remote_addr", remoteAddr)
	return nil
}

// GetStatus returns the current P2P status
func (m *Manager) GetStatus() *P2PStatus {
	m.mu.RLock()
	defer m.mu.RUnlock()

	status := *m.status
	status.ActiveConnections = len(m.connections)
	return &status
}

// GetActivePeers returns the number of active peers
func (m *Manager) GetActivePeers() int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	return len(m.connections)
}

// GetTotalPeers returns the total number of discovered peers
func (m *Manager) GetTotalPeers() int {
	if m.mesh != nil {
		return m.mesh.GetActivePeers()
	}
	return 0
}

// startPeerDiscovery starts the peer discovery process
func (m *Manager) startPeerDiscovery() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			return
		case <-ticker.C:
			if m.apiManager != nil {
				resp, err := m.apiManager.DiscoverPeers()
				if err != nil {
					m.logger.Error("Failed to discover peers", "error", err)
					continue
				}

				if resp.Success {
					m.logger.Info("Discovered peers", "count", len(resp.Peers))

					// Update mesh network
					if m.mesh != nil {
						for _, peer := range resp.Peers {
							p2pPeer := &Peer{
								ID:          peer.PeerID,
								PublicKey:   peer.PublicKey,
								Endpoint:    peer.Endpoint,
								AllowedIPs:  peer.AllowedIPs,
								LastSeen:    time.Now().Unix(),
								IsConnected: peer.IsOnline,
							}
							m.mesh.AddPeer(p2pPeer)
						}
					}
				}
			}
		}
	}
}

// ExtractP2PConfigFromToken extracts P2P configuration from JWT token
func ExtractP2PConfigFromToken(authManager *auth.AuthManager, token *jwt.Token) (*P2PConfig, error) {
	// Extract connection type
	connectionType, err := authManager.ExtractConnectionType(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract connection type: %w", err)
	}

	// Extract network configuration
	networkConfig, err := authManager.ExtractNetworkConfig(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract network config: %w", err)
	}

	// Extract mesh configuration
	meshConfig, err := authManager.ExtractMeshConfig(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract mesh config: %w", err)
	}

	// Extract peer whitelist
	peerWhitelist, err := authManager.ExtractPeerWhitelist(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract peer whitelist: %w", err)
	}

	// Extract permissions
	permissions, err := authManager.ExtractPermissions(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract permissions: %w", err)
	}

	// Extract tenant ID
	tenantID, err := authManager.ExtractTenantID(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract tenant ID: %w", err)
	}

	// Convert auth types to p2p types
	var p2pMeshConfig *MeshConfig
	if meshConfig != nil {
		p2pMeshConfig = &MeshConfig{
			AutoDiscovery: meshConfig.AutoDiscovery,
			Persistent:    meshConfig.Persistent,
			Routing:       meshConfig.Routing,
			Encryption:    meshConfig.Encryption,
		}
	}

	var p2pPeerWhitelist *PeerWhitelist
	if peerWhitelist != nil {
		p2pPeerWhitelist = &PeerWhitelist{
			AllowedPeers: peerWhitelist.AllowedPeers,
			AutoApprove:  peerWhitelist.AutoApprove,
			MaxPeers:     peerWhitelist.MaxPeers,
		}
	}

	var p2pNetworkConfig *NetworkConfig
	if networkConfig != nil {
		p2pNetworkConfig = &NetworkConfig{
			Subnet:      networkConfig.Subnet,
			DNS:         networkConfig.DNS,
			MTU:         networkConfig.MTU,
			STUNServers: []string{"edge.2gc.ru:19302"},
			TURNServers: []string{},
			QUICPort:    5553,
			ICEPort:     19302,
		}
	}

	return &P2PConfig{
		ConnectionType: ConnectionType(connectionType),
		MeshConfig:     p2pMeshConfig,
		PeerWhitelist:  p2pPeerWhitelist,
		NetworkConfig:  p2pNetworkConfig,
		TenantID:       tenantID,
		Permissions:    permissions,
	}, nil
}

// startHeartbeat starts the heartbeat routine to maintain connection with relay
func (m *Manager) startHeartbeat() {
	if m.config.HeartbeatInterval <= 0 {
		m.logger.Warn("Heartbeat interval not configured, skipping heartbeat")
		return
	}

	m.heartbeatTicker = time.NewTicker(m.config.HeartbeatInterval)

	go func() {
		defer m.heartbeatTicker.Stop()

		for {
			select {
			case <-m.ctx.Done():
				m.logger.Info("Heartbeat routine stopped")
				return
			case <-m.heartbeatTicker.C:
				if err := m.sendHeartbeat(); err != nil {
					m.logger.Error("Failed to send heartbeat", "error", err)
				}
			}
		}
	}()

	m.logger.Info("Heartbeat routine started", "interval", m.config.HeartbeatInterval)
}

// sendHeartbeat sends a heartbeat to the relay server
func (m *Manager) sendHeartbeat() error {
	if m.tenantID == "" || m.peerID == "" || m.token == "" {
		return fmt.Errorf("missing required fields for heartbeat: tenantID=%s, peerID=%s, token=%s",
			m.tenantID, m.peerID, m.token)
	}

	req := &api.HeartbeatRequest{
		Status:         "active",
		RelaySessionID: m.relaySessionID,
	}

	ctx, cancel := context.WithTimeout(m.ctx, m.config.HeartbeatTimeout)
	defer cancel()

	resp, err := m.apiManager.SendHeartbeat(ctx, m.tenantID, m.peerID, m.token, req)
	if err != nil {
		return fmt.Errorf("failed to send heartbeat: %w", err)
	}

	if !resp.Success {
		return fmt.Errorf("heartbeat failed: %s", resp.Error)
	}

	m.logger.Debug("Heartbeat sent successfully", "relay_session_id", m.relaySessionID)
	return nil
}
