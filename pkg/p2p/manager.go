package p2p

import (
	"context"
	"fmt"
	"sync"

	"github.com/2gc-dev/cloudbridge-client/pkg/auth"
	"github.com/golang-jwt/jwt/v5"
)

// Manager handles P2P connections and mesh network management
type Manager struct {
	config    *P2PConfig
	wireguard *WireGuardClient
	mesh      *MeshNetwork
	status    *P2PStatus
	ctx       context.Context
	cancel    context.CancelFunc
	mu        sync.RWMutex
	logger    Logger
}

// Logger interface for P2P manager logging
type Logger interface {
	Info(msg string, fields ...interface{})
	Error(msg string, fields ...interface{})
	Debug(msg string, fields ...interface{})
	Warn(msg string, fields ...interface{})
}

// NewManager creates a new P2P manager
func NewManager(config *P2PConfig, logger Logger) *Manager {
	ctx, cancel := context.WithCancel(context.Background())

	return &Manager{
		config: config,
		status: &P2PStatus{
			ConnectionType: config.ConnectionType,
			MeshEnabled:    config.MeshConfig != nil && config.MeshConfig.AutoDiscovery,
		},
		ctx:    ctx,
		cancel: cancel,
		logger: logger,
	}
}

// Start initializes and starts the P2P manager
func (m *Manager) Start() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logger.Info("Starting P2P manager", "connection_type", m.config.ConnectionType)

	switch m.config.ConnectionType {
	case ConnectionTypeP2PMesh:
		return m.startP2PMesh()
	case ConnectionTypeServerServer:
		return m.startServerServer()
	case ConnectionTypeClientServer:
		return m.startClientServer()
	default:
		return fmt.Errorf("unsupported connection type: %s", m.config.ConnectionType)
	}
}

// Stop stops the P2P manager and cleans up resources
func (m *Manager) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logger.Info("Stopping P2P manager")

	// Cancel context to stop all goroutines
	m.cancel()

	// Stop WireGuard client
	if m.wireguard != nil {
		if err := m.wireguard.Close(); err != nil {
			m.logger.Error("Failed to close WireGuard client", "error", err)
		}
	}

	// Peer discovery is handled by the relay server

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

// GetStatus returns the current P2P status
func (m *Manager) GetStatus() *P2PStatus {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Create a copy to avoid race conditions
	status := *m.status
	return &status
}

// GetTopology returns the current mesh topology
func (m *Manager) GetTopology() *MeshTopology {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.mesh == nil {
		return nil
	}

	return m.mesh.GetTopology()
}

// startP2PMesh initializes P2P mesh network
func (m *Manager) startP2PMesh() error {
	m.logger.Info("Starting P2P mesh network")

	// Initialize WireGuard client
	if m.config.WireGuardConfig != nil {
		wgClient := NewWireGuardClient(m.config.WireGuardConfig, m.logger)
		m.wireguard = wgClient
		m.status.WireGuardReady = true
	}

	// Peer discovery is handled by the relay server via API

	// Create mesh network
	if m.config.MeshConfig != nil {
		m.mesh = NewMeshNetwork(m.config.MeshConfig, m.logger)
		if err := m.mesh.Start(); err != nil {
			return fmt.Errorf("failed to start mesh network: %w", err)
		}
	}

	m.status.IsConnected = true
	m.status.MeshEnabled = true
	m.logger.Info("P2P mesh network started successfully")
	return nil
}

// startServerServer initializes server-to-server connection
func (m *Manager) startServerServer() error {
	m.logger.Info("Starting server-to-server connection")

	// Initialize WireGuard for server-to-server
	if m.config.WireGuardConfig != nil {
		wgClient := NewWireGuardClient(m.config.WireGuardConfig, m.logger)
		m.wireguard = wgClient
		m.status.WireGuardReady = true
	}

	m.status.IsConnected = true
	m.logger.Info("Server-to-server connection started successfully")
	return nil
}

// startClientServer initializes client-to-server connection (fallback)
func (m *Manager) startClientServer() error {
	m.logger.Info("Starting client-to-server connection (fallback mode)")

	// For client-server mode, we don't need P2P components
	// This is handled by the main relay client
	m.status.IsConnected = true
	m.logger.Info("Client-to-server connection ready")
	return nil
}

// UpdateConfig updates the P2P configuration
func (m *Manager) UpdateConfig(config *P2PConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logger.Info("Updating P2P configuration")

	// Stop current components
	if err := m.Stop(); err != nil {
		m.logger.Error("Failed to stop current P2P components", "error", err)
	}

	// Update configuration
	m.config = config
	m.status.ConnectionType = config.ConnectionType

	// Restart with new configuration
	return m.Start()
}

// IsP2PEnabled returns true if P2P functionality is enabled
func (m *Manager) IsP2PEnabled() bool {
	return m.config.ConnectionType == ConnectionTypeP2PMesh ||
		m.config.ConnectionType == ConnectionTypeServerServer
}

// GetActivePeers returns the number of active peers
func (m *Manager) GetActivePeers() int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.mesh != nil {
		return m.mesh.GetActivePeers()
	}
	return 0
}

// GetTotalPeers returns the total number of discovered peers
func (m *Manager) GetTotalPeers() int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Peer discovery is handled by the relay server
	// This would be populated via API calls to the relay server
	return 0
}

// ExtractP2PConfigFromToken extracts P2P configuration from JWT token
func ExtractP2PConfigFromToken(authManager *auth.AuthManager, token *jwt.Token) (*P2PConfig, error) {
	// Extract connection type
	connectionType, err := authManager.ExtractConnectionType(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract connection type: %w", err)
	}

	// Extract WireGuard configuration
	wgConfig, err := authManager.ExtractWireGuardConfig(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract WireGuard config: %w", err)
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

	// Extract network configuration
	networkConfig, err := authManager.ExtractNetworkConfig(token)
	if err != nil {
		return nil, fmt.Errorf("failed to extract network config: %w", err)
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
	var p2pWGConfig *WireGuardConfig
	if wgConfig != nil {
		p2pWGConfig = &WireGuardConfig{
			PrivateKey: wgConfig.PrivateKey,
			PublicKey:  wgConfig.PublicKey,
			AllowedIPs: wgConfig.AllowedIPs,
			Endpoint:   wgConfig.Endpoint,
			ListenPort: wgConfig.ListenPort,
			MTU:        wgConfig.MTU,
		}
	}

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
			Subnet: networkConfig.Subnet,
			DNS:    networkConfig.DNS,
			MTU:    networkConfig.MTU,
		}
	}

	return &P2PConfig{
		ConnectionType:  ConnectionType(connectionType),
		WireGuardConfig: p2pWGConfig,
		MeshConfig:      p2pMeshConfig,
		PeerWhitelist:   p2pPeerWhitelist,
		NetworkConfig:   p2pNetworkConfig,
		TenantID:        tenantID,
		Permissions:     permissions,
	}, nil
}
