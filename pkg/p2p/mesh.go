package p2p

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// MeshNetwork manages the mesh network topology and routing
type MeshNetwork struct {
	config   *MeshConfig
	topology *MeshTopology
	router   *MeshRouter
	ctx      context.Context
	cancel   context.CancelFunc
	mu       sync.RWMutex
	logger   Logger
}

// MeshRouter handles mesh network routing
type MeshRouter struct {
	routingTable map[string][]string // destination -> route
	latencyTable map[string]int64    // destination -> latency
	mu           sync.RWMutex
}

// NewMeshNetwork creates a new mesh network manager
func NewMeshNetwork(config *MeshConfig, logger Logger) *MeshNetwork {
	ctx, cancel := context.WithCancel(context.Background())

	return &MeshNetwork{
		config: config,
		topology: &MeshTopology{
			LocalPeerID:     "local-peer",
			ConnectedPeers:  make(map[string]*Peer),
			DiscoveredPeers: make(map[string]*Peer),
			RoutingTable:    make(map[string][]string),
		},
		router: &MeshRouter{
			routingTable: make(map[string][]string),
			latencyTable: make(map[string]int64),
		},
		ctx:    ctx,
		cancel: cancel,
		logger: logger,
	}
}

// Start starts the mesh network
func (mn *MeshNetwork) Start() error {
	mn.mu.Lock()
	defer mn.mu.Unlock()

	mn.logger.Info("Starting mesh network", "routing", mn.config.Routing, "encryption", mn.config.Encryption)

	// Initialize routing based on configuration
	if err := mn.initializeRouting(); err != nil {
		return fmt.Errorf("failed to initialize routing: %w", err)
	}

	// Start mesh management goroutines
	go mn.topologyUpdateLoop()
	go mn.routingUpdateLoop()
	go mn.healthCheckLoop()

	mn.logger.Info("Mesh network started successfully")
	return nil
}

// Stop stops the mesh network
func (mn *MeshNetwork) Stop() error {
	mn.mu.Lock()
	defer mn.mu.Unlock()

	mn.logger.Info("Stopping mesh network")

	// Cancel context to stop all goroutines
	mn.cancel()

	mn.logger.Info("Mesh network stopped")
	return nil
}

// GetTopology returns the current mesh topology
func (mn *MeshNetwork) GetTopology() *MeshTopology {
	mn.mu.RLock()
	defer mn.mu.RUnlock()

	// Create a copy to avoid race conditions
	topology := &MeshTopology{
		LocalPeerID:     mn.topology.LocalPeerID,
		ConnectedPeers:  make(map[string]*Peer),
		DiscoveredPeers: make(map[string]*Peer),
		RoutingTable:    make(map[string][]string),
	}

	// Copy connected peers
	for id, peer := range mn.topology.ConnectedPeers {
		peerCopy := *peer
		topology.ConnectedPeers[id] = &peerCopy
	}

	// Copy discovered peers
	for id, peer := range mn.topology.DiscoveredPeers {
		peerCopy := *peer
		topology.DiscoveredPeers[id] = &peerCopy
	}

	// Copy routing table
	for dest, route := range mn.topology.RoutingTable {
		routeCopy := make([]string, len(route))
		copy(routeCopy, route)
		topology.RoutingTable[dest] = routeCopy
	}

	return topology
}

// GetActivePeers returns the number of active peers in the mesh
func (mn *MeshNetwork) GetActivePeers() int {
	mn.mu.RLock()
	defer mn.mu.RUnlock()

	active := 0
	for _, peer := range mn.topology.ConnectedPeers {
		if peer.IsConnected {
			active++
		}
	}
	return active
}

// AddPeer adds a peer to the mesh network
func (mn *MeshNetwork) AddPeer(peer *Peer) error {
	mn.mu.Lock()
	defer mn.mu.Unlock()

	mn.logger.Info("Adding peer to mesh network", "peer_id", peer.ID)

	// Add to connected peers
	mn.topology.ConnectedPeers[peer.ID] = peer

	// Update routing table
	if err := mn.updateRoutingForPeer(peer); err != nil {
		mn.logger.Error("Failed to update routing for peer", "peer_id", peer.ID, "error", err)
	}

	mn.logger.Info("Peer added to mesh network successfully", "peer_id", peer.ID)
	return nil
}

// RemovePeer removes a peer from the mesh network
func (mn *MeshNetwork) RemovePeer(peerID string) error {
	mn.mu.Lock()
	defer mn.mu.Unlock()

	mn.logger.Info("Removing peer from mesh network", "peer_id", peerID)

	// Remove from connected peers
	if _, exists := mn.topology.ConnectedPeers[peerID]; exists {
		delete(mn.topology.ConnectedPeers, peerID)

		// Update routing table
		mn.removeRoutingForPeer(peerID)

		mn.logger.Info("Peer removed from mesh network successfully", "peer_id", peerID)
		return nil
	}

	return fmt.Errorf("peer not found: %s", peerID)
}

// GetOptimalRoute returns the optimal route to a destination
func (mn *MeshNetwork) GetOptimalRoute(destination string) ([]string, error) {
	mn.router.mu.RLock()
	defer mn.router.mu.RUnlock()

	if route, exists := mn.router.routingTable[destination]; exists {
		// Return a copy to avoid race conditions
		routeCopy := make([]string, len(route))
		copy(routeCopy, route)
		return routeCopy, nil
	}

	return nil, fmt.Errorf("no route found to destination: %s", destination)
}

// GetRouteLatency returns the latency to a destination
func (mn *MeshNetwork) GetRouteLatency(destination string) (int64, error) {
	mn.router.mu.RLock()
	defer mn.router.mu.RUnlock()

	if latency, exists := mn.router.latencyTable[destination]; exists {
		return latency, nil
	}

	return 0, fmt.Errorf("no latency information for destination: %s", destination)
}

// initializeRouting initializes the routing based on mesh configuration
func (mn *MeshNetwork) initializeRouting() error {
	mn.logger.Info("Initializing mesh routing", "strategy", mn.config.Routing)

	switch mn.config.Routing {
	case "hybrid":
		return mn.initializeHybridRouting()
	case "direct":
		return mn.initializeDirectRouting()
	case "relay":
		return mn.initializeRelayRouting()
	default:
		return fmt.Errorf("unsupported routing strategy: %s", mn.config.Routing)
	}
}

// initializeHybridRouting initializes hybrid routing (direct + relay)
func (mn *MeshNetwork) initializeHybridRouting() error {
	mn.logger.Info("Initializing hybrid routing")

	// Hybrid routing tries direct connections first, falls back to relay
	// This is the default and most flexible approach
	return nil
}

// initializeDirectRouting initializes direct routing (peer-to-peer only)
func (mn *MeshNetwork) initializeDirectRouting() error {
	mn.logger.Info("Initializing direct routing")

	// Direct routing only uses direct peer-to-peer connections
	// No relay fallback
	return nil
}

// initializeRelayRouting initializes relay routing (through relay server)
func (mn *MeshNetwork) initializeRelayRouting() error {
	mn.logger.Info("Initializing relay routing")

	// Relay routing uses the relay server as an intermediary
	// All traffic goes through the relay
	return nil
}

// updateRoutingForPeer updates routing table when a peer is added
func (mn *MeshNetwork) updateRoutingForPeer(peer *Peer) error {
	mn.router.mu.Lock()
	defer mn.router.mu.Unlock()

	// Add direct route to the peer
	mn.router.routingTable[peer.ID] = []string{peer.ID}
	mn.router.latencyTable[peer.ID] = peer.Latency

	// Add routes to the peer's allowed IPs
	for _, allowedIP := range peer.AllowedIPs {
		mn.router.routingTable[allowedIP] = []string{peer.ID}
		mn.router.latencyTable[allowedIP] = peer.Latency
	}

	mn.logger.Debug("Updated routing for peer", "peer_id", peer.ID, "allowed_ips", peer.AllowedIPs)
	return nil
}

// removeRoutingForPeer removes routing entries when a peer is removed
func (mn *MeshNetwork) removeRoutingForPeer(peerID string) {
	mn.router.mu.Lock()
	defer mn.router.mu.Unlock()

	// Remove direct route to the peer
	delete(mn.router.routingTable, peerID)
	delete(mn.router.latencyTable, peerID)

	// Remove routes to the peer's allowed IPs
	for dest, route := range mn.router.routingTable {
		if len(route) > 0 && route[0] == peerID {
			delete(mn.router.routingTable, dest)
			delete(mn.router.latencyTable, dest)
		}
	}

	mn.logger.Debug("Removed routing for peer", "peer_id", peerID)
}

// topologyUpdateLoop continuously updates the mesh topology
func (mn *MeshNetwork) topologyUpdateLoop() {
	ticker := time.NewTicker(30 * time.Second) // Update topology every 30 seconds
	defer ticker.Stop()

	for {
		select {
		case <-mn.ctx.Done():
			return
		case <-ticker.C:
			mn.updateTopology()
		}
	}
}

// routingUpdateLoop continuously updates routing information
func (mn *MeshNetwork) routingUpdateLoop() {
	ticker := time.NewTicker(60 * time.Second) // Update routing every minute
	defer ticker.Stop()

	for {
		select {
		case <-mn.ctx.Done():
			return
		case <-ticker.C:
			mn.updateRouting()
		}
	}
}

// healthCheckLoop performs health checks on mesh connections
func (mn *MeshNetwork) healthCheckLoop() {
	ticker := time.NewTicker(2 * time.Minute) // Health check every 2 minutes
	defer ticker.Stop()

	for {
		select {
		case <-mn.ctx.Done():
			return
		case <-ticker.C:
			mn.performHealthChecks()
		}
	}
}

// updateTopology updates the mesh topology information
func (mn *MeshNetwork) updateTopology() {
	mn.mu.Lock()
	defer mn.mu.Unlock()

	// Update topology based on current peer status
	for id, peer := range mn.topology.ConnectedPeers {
		// Check if peer is still responsive
		if time.Since(time.Unix(peer.LastSeen, 0)) > 5*time.Minute {
			peer.IsConnected = false
			mn.logger.Warn("Peer appears to be unresponsive", "peer_id", id)
		}
	}

	mn.logger.Debug("Updated mesh topology", "connected_peers", len(mn.topology.ConnectedPeers))
}

// updateRouting updates the routing table based on current topology
func (mn *MeshNetwork) updateRouting() {
	mn.router.mu.Lock()
	defer mn.router.mu.Unlock()

	// Recalculate optimal routes based on current peer status
	for dest, route := range mn.router.routingTable {
		if len(route) > 0 {
			peerID := route[0]
			if peer, exists := mn.topology.ConnectedPeers[peerID]; exists {
				if !peer.IsConnected {
					// Find alternative route
					if altRoute := mn.findAlternativeRoute(dest, peerID); altRoute != nil {
						mn.router.routingTable[dest] = altRoute
						mn.logger.Info("Updated route due to peer unavailability", "destination", dest, "new_route", altRoute)
					}
				}
			}
		}
	}

	mn.logger.Debug("Updated mesh routing table", "routes", len(mn.router.routingTable))
}

// performHealthChecks performs health checks on all mesh connections
func (mn *MeshNetwork) performHealthChecks() {
	mn.mu.RLock()
	peers := make(map[string]*Peer)
	for id, peer := range mn.topology.ConnectedPeers {
		peers[id] = peer
	}
	mn.mu.RUnlock()

	for id, peer := range peers {
		// Perform health check (simplified)
		if time.Since(time.Unix(peer.LastSeen, 0)) > 10*time.Minute {
			mn.logger.Warn("Peer failed health check", "peer_id", id)
			// In a real implementation, you might want to remove the peer
		}
	}
}

// findAlternativeRoute finds an alternative route to a destination
func (mn *MeshNetwork) findAlternativeRoute(destination, excludePeerID string) []string {
	// Simple implementation: find any other connected peer
	for id, peer := range mn.topology.ConnectedPeers {
		if id != excludePeerID && peer.IsConnected {
			// Check if this peer can reach the destination
			for _, allowedIP := range peer.AllowedIPs {
				if allowedIP == destination {
					return []string{id}
				}
			}
		}
	}
	return nil
}

// GetMeshStats returns statistics about the mesh network
func (mn *MeshNetwork) GetMeshStats() map[string]interface{} {
	mn.mu.RLock()
	defer mn.mu.RUnlock()

	connectedCount := 0
	totalLatency := int64(0)

	for _, peer := range mn.topology.ConnectedPeers {
		if peer.IsConnected {
			connectedCount++
			totalLatency += peer.Latency
		}
	}

	avgLatency := int64(0)
	if connectedCount > 0 {
		avgLatency = totalLatency / int64(connectedCount)
	}

	return map[string]interface{}{
		"total_peers":      len(mn.topology.ConnectedPeers),
		"connected_peers":  connectedCount,
		"routing_strategy": mn.config.Routing,
		"encryption":       mn.config.Encryption,
		"average_latency":  avgLatency,
		"routes":           len(mn.router.routingTable),
	}
}
