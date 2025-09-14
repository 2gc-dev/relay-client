package p2p

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"net"
	"sync"
	"time"
)

// WireGuardClient represents a WireGuard P2P client
type WireGuardClient struct {
	config     *WireGuardConfig
	connection *net.UDPConn
	peers      map[string]*Peer
	status     *WireGuardStatus
	ctx        context.Context
	cancel     context.CancelFunc
	mu         sync.RWMutex
	logger     Logger
}

// WireGuardStatus represents the status of WireGuard client
type WireGuardStatus struct {
	IsConnected   bool      `json:"is_connected"`
	PublicKey     string    `json:"public_key"`
	ListenPort    int       `json:"listen_port"`
	ActivePeers   int       `json:"active_peers"`
	LastHandshake time.Time `json:"last_handshake"`
	BytesIn       int64     `json:"bytes_in"`
	BytesOut      int64     `json:"bytes_out"`
}

// NewWireGuardClient creates a new WireGuard client
func NewWireGuardClient(config *WireGuardConfig, logger Logger) *WireGuardClient {
	ctx, cancel := context.WithCancel(context.Background())

	return &WireGuardClient{
		config: config,
		peers:  make(map[string]*Peer),
		status: &WireGuardStatus{
			PublicKey:  config.PublicKey,
			ListenPort: config.ListenPort,
		},
		ctx:    ctx,
		cancel: cancel,
		logger: logger,
	}
}

// Start starts the WireGuard client
func (wg *WireGuardClient) Start() error {
	wg.mu.Lock()
	defer wg.mu.Unlock()

	wg.logger.Info("Starting WireGuard client", "public_key", wg.config.PublicKey)

	// Validate configuration
	if err := wg.validateConfig(); err != nil {
		return fmt.Errorf("invalid WireGuard configuration: %w", err)
	}

	// Start listening on the configured port
	if err := wg.startListening(); err != nil {
		return fmt.Errorf("failed to start listening: %w", err)
	}

	// Start peer management
	go wg.managePeers()

	wg.status.IsConnected = true
	wg.logger.Info("WireGuard client started successfully", "port", wg.config.ListenPort)
	return nil
}

// Close closes the WireGuard client
func (wg *WireGuardClient) Close() error {
	wg.mu.Lock()
	defer wg.mu.Unlock()

	wg.logger.Info("Closing WireGuard client")

	// Cancel context
	wg.cancel()

	// Close connection
	if wg.connection != nil {
		if err := wg.connection.Close(); err != nil {
			wg.logger.Error("Failed to close WireGuard connection", "error", err)
		}
	}

	wg.status.IsConnected = false
	wg.logger.Info("WireGuard client closed")
	return nil
}

// GetStatus returns the current WireGuard status
func (wg *WireGuardClient) GetStatus() *WireGuardStatus {
	wg.mu.RLock()
	defer wg.mu.RUnlock()

	// Create a copy to avoid race conditions
	status := *wg.status
	status.ActivePeers = len(wg.peers)
	return &status
}

// AddPeer adds a new peer to the WireGuard configuration
func (wg *WireGuardClient) AddPeer(peer *Peer) error {
	wg.mu.Lock()
	defer wg.mu.Unlock()

	wg.logger.Info("Adding WireGuard peer", "peer_id", peer.ID, "public_key", peer.PublicKey)

	// Validate peer
	if err := wg.validatePeer(peer); err != nil {
		return fmt.Errorf("invalid peer: %w", err)
	}

	// Add peer to the map
	wg.peers[peer.ID] = peer

	// Send handshake to the new peer
	if err := wg.sendHandshake(peer); err != nil {
		wg.logger.Error("Failed to send handshake to peer", "peer_id", peer.ID, "error", err)
		return err
	}

	wg.logger.Info("WireGuard peer added successfully", "peer_id", peer.ID)
	return nil
}

// RemovePeer removes a peer from the WireGuard configuration
func (wg *WireGuardClient) RemovePeer(peerID string) error {
	wg.mu.Lock()
	defer wg.mu.Unlock()

	wg.logger.Info("Removing WireGuard peer", "peer_id", peerID)

	if peer, exists := wg.peers[peerID]; exists {
		// Send disconnect message
		if err := wg.sendDisconnect(peer); err != nil {
			wg.logger.Error("Failed to send disconnect to peer", "peer_id", peerID, "error", err)
		}

		// Remove from map
		delete(wg.peers, peerID)
		wg.logger.Info("WireGuard peer removed successfully", "peer_id", peerID)
		return nil
	}

	return fmt.Errorf("peer not found: %s", peerID)
}

// GetPeers returns all configured peers
func (wg *WireGuardClient) GetPeers() map[string]*Peer {
	wg.mu.RLock()
	defer wg.mu.RUnlock()

	// Create a copy to avoid race conditions
	peers := make(map[string]*Peer)
	for id, peer := range wg.peers {
		peers[id] = peer
	}
	return peers
}

// validateConfig validates the WireGuard configuration
func (wg *WireGuardClient) validateConfig() error {
	if wg.config.PrivateKey == "" {
		return fmt.Errorf("private key is required")
	}
	if wg.config.PublicKey == "" {
		return fmt.Errorf("public key is required")
	}
	if wg.config.ListenPort <= 0 || wg.config.ListenPort > 65535 {
		return fmt.Errorf("invalid listen port: %d", wg.config.ListenPort)
	}
	return nil
}

// validatePeer validates a peer configuration
func (wg *WireGuardClient) validatePeer(peer *Peer) error {
	if peer.ID == "" {
		return fmt.Errorf("peer ID is required")
	}
	if peer.PublicKey == "" {
		return fmt.Errorf("peer public key is required")
	}
	if peer.Endpoint == "" {
		return fmt.Errorf("peer endpoint is required")
	}
	return nil
}

// startListening starts listening for incoming connections
func (wg *WireGuardClient) startListening() error {
	// Create UDP listener
	addr, err := net.ResolveUDPAddr("udp", fmt.Sprintf(":%d", wg.config.ListenPort))
	if err != nil {
		return fmt.Errorf("failed to resolve UDP address: %w", err)
	}

	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		return fmt.Errorf("failed to listen on UDP: %w", err)
	}

	wg.connection = conn

	// Start receiving messages
	go wg.receiveMessages()

	return nil
}

// receiveMessages handles incoming WireGuard messages
func (wg *WireGuardClient) receiveMessages() {
	buffer := make([]byte, 65536)

	for {
		select {
		case <-wg.ctx.Done():
			return
		default:
			// Set read timeout
			if err := wg.connection.SetReadDeadline(time.Now().Add(1 * time.Second)); err != nil {
				wg.logger.Error("Failed to set read deadline", "error", err)
				continue
			}

			n, addr, err := wg.connection.ReadFromUDP(buffer)
			if err != nil {
				if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
					continue // Timeout is expected
				}
				wg.logger.Error("Failed to read from UDP", "error", err)
				continue
			}

			// Process the received message
			if err := wg.processMessage(buffer[:n], addr); err != nil {
				wg.logger.Error("Failed to process message", "error", err)
			}
		}
	}
}

// processMessage processes an incoming WireGuard message
func (wg *WireGuardClient) processMessage(data []byte, addr *net.UDPAddr) error {
	// Update statistics
	wg.status.BytesIn += int64(len(data))

	// Parse message type (simplified WireGuard protocol)
	if len(data) < 4 {
		return fmt.Errorf("message too short")
	}

	messageType := data[0]

	switch messageType {
	case 1: // Initiation
		return wg.handleInitiation(data, addr)
	case 2: // Response
		return wg.handleResponse(data, addr)
	case 3: // Cookie Reply
		return wg.handleCookieReply(data, addr)
	case 4: // Transport Data
		return wg.handleTransportData(data, addr)
	default:
		wg.logger.Debug("Unknown message type", "type", messageType)
		return nil
	}
}

// handleInitiation handles WireGuard initiation messages
func (wg *WireGuardClient) handleInitiation(data []byte, addr *net.UDPAddr) error {
	wg.logger.Debug("Received initiation message", "from", addr.String())

	// Update last handshake time
	wg.status.LastHandshake = time.Now()

	// Send response (simplified)
	response := []byte{2, 0, 0, 0} // Response message type
	_, err := wg.connection.WriteToUDP(response, addr)
	if err != nil {
		return fmt.Errorf("failed to send response: %w", err)
	}

	return nil
}

// handleResponse handles WireGuard response messages
func (wg *WireGuardClient) handleResponse(data []byte, addr *net.UDPAddr) error {
	wg.logger.Debug("Received response message", "from", addr.String())
	wg.status.LastHandshake = time.Now()
	return nil
}

// handleCookieReply handles WireGuard cookie reply messages
func (wg *WireGuardClient) handleCookieReply(data []byte, addr *net.UDPAddr) error {
	wg.logger.Debug("Received cookie reply message", "from", addr.String())
	return nil
}

// handleTransportData handles WireGuard transport data messages
func (wg *WireGuardClient) handleTransportData(data []byte, addr *net.UDPAddr) error {
	wg.logger.Debug("Received transport data", "from", addr.String(), "size", len(data))
	// Forward data to the appropriate peer
	return nil
}

// sendHandshake sends a handshake message to a peer
func (wg *WireGuardClient) sendHandshake(peer *Peer) error {
	// Parse peer endpoint
	addr, err := net.ResolveUDPAddr("udp", peer.Endpoint)
	if err != nil {
		return fmt.Errorf("failed to resolve peer endpoint: %w", err)
	}

	// Create initiation message (simplified)
	message := []byte{1, 0, 0, 0} // Initiation message type

	_, err = wg.connection.WriteToUDP(message, addr)
	if err != nil {
		return fmt.Errorf("failed to send handshake: %w", err)
	}

	wg.logger.Debug("Sent handshake to peer", "peer_id", peer.ID, "endpoint", peer.Endpoint)
	return nil
}

// sendDisconnect sends a disconnect message to a peer
func (wg *WireGuardClient) sendDisconnect(peer *Peer) error {
	// Parse peer endpoint
	addr, err := net.ResolveUDPAddr("udp", peer.Endpoint)
	if err != nil {
		return fmt.Errorf("failed to resolve peer endpoint: %w", err)
	}

	// Create disconnect message (simplified)
	message := []byte{0, 0, 0, 0} // Disconnect message type

	_, err = wg.connection.WriteToUDP(message, addr)
	if err != nil {
		return fmt.Errorf("failed to send disconnect: %w", err)
	}

	wg.logger.Debug("Sent disconnect to peer", "peer_id", peer.ID)
	return nil
}

// managePeers manages peer connections and health checks
func (wg *WireGuardClient) managePeers() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-wg.ctx.Done():
			return
		case <-ticker.C:
			wg.performHealthChecks()
		}
	}
}

// performHealthChecks performs health checks on all peers
func (wg *WireGuardClient) performHealthChecks() {
	wg.mu.RLock()
	peers := make(map[string]*Peer)
	for id, peer := range wg.peers {
		peers[id] = peer
	}
	wg.mu.RUnlock()

	for id, peer := range peers {
		// Check if peer is still responsive
		if time.Since(time.Unix(peer.LastSeen, 0)) > 5*time.Minute {
			wg.logger.Warn("Peer appears to be unresponsive", "peer_id", id)
			peer.IsConnected = false
		}
	}
}

// GenerateKeyPair generates a new WireGuard key pair
func GenerateKeyPair() (privateKey, publicKey string, err error) {
	// Generate 32 random bytes for private key
	privateKeyBytes := make([]byte, 32)
	if _, err := rand.Read(privateKeyBytes); err != nil {
		return "", "", fmt.Errorf("failed to generate private key: %w", err)
	}

	// For simplicity, we'll use the private key as the public key
	// In a real implementation, you would perform cryptographic operations
	publicKeyBytes := make([]byte, 32)
	copy(publicKeyBytes, privateKeyBytes)

	// Encode as base64
	privateKey = base64.StdEncoding.EncodeToString(privateKeyBytes)
	publicKey = base64.StdEncoding.EncodeToString(publicKeyBytes)

	return privateKey, publicKey, nil
}
