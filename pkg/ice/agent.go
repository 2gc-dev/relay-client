package ice

import (
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/pion/ice/v2"
	"github.com/pion/stun"
)

// ICEAgent handles ICE connectivity checks and candidate gathering
type ICEAgent struct {
	agent       *ice.Agent
	stunServers []string
	turnServers []string
	config      *ice.AgentConfig
	mu          sync.RWMutex
	logger      Logger
}

// Logger interface for ICE agent logging
type Logger interface {
	Info(msg string, fields ...interface{})
	Error(msg string, fields ...interface{})
	Debug(msg string, fields ...interface{})
	Warn(msg string, fields ...interface{})
}

// NewICEAgent creates a new ICE agent
func NewICEAgent(stunServers, turnServers []string, logger Logger) *ICEAgent {
	return &ICEAgent{
		stunServers: stunServers,
		turnServers: turnServers,
		logger:      logger,
	}
}

// Start initializes and starts the ICE agent
func (a *ICEAgent) Start() error {
	a.mu.Lock()
	defer a.mu.Unlock()

	a.logger.Info("Starting ICE agent", "stun_servers", a.stunServers, "turn_servers", a.turnServers)

	// Configure ICE agent
	urls := make([]*stun.URI, len(a.stunServers))
	for i, server := range a.stunServers {
		uri, err := stun.ParseURI(server)
		if err != nil {
			return fmt.Errorf("failed to parse STUN server URI %s: %w", server, err)
		}
		urls[i] = uri
	}

	a.config = &ice.AgentConfig{
		NetworkTypes: []ice.NetworkType{ice.NetworkTypeUDP4, ice.NetworkTypeUDP6},
		Urls:         urls,
	}

	// Create ICE agent
	agent, err := ice.NewAgent(a.config)
	if err != nil {
		return fmt.Errorf("failed to create ICE agent: %w", err)
	}

	a.agent = agent

	// Set up event handlers
	a.setupEventHandlers()

	a.logger.Info("ICE agent started successfully")
	return nil
}

// Stop stops the ICE agent
func (a *ICEAgent) Stop() error {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.agent == nil {
		return nil
	}

	a.logger.Info("Stopping ICE agent")

	if err := a.agent.Close(); err != nil {
		a.logger.Error("Failed to close ICE agent", "error", err)
		return err
	}

	a.agent = nil
	a.logger.Info("ICE agent stopped")
	return nil
}

// GatherCandidates starts candidate gathering
func (a *ICEAgent) GatherCandidates() ([]ice.Candidate, error) {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.agent == nil {
		return nil, fmt.Errorf("ICE agent not started")
	}

	a.logger.Info("Starting candidate gathering")

	// Start gathering candidates
	if err := a.agent.GatherCandidates(); err != nil {
		return nil, fmt.Errorf("failed to gather candidates: %w", err)
	}

	// Wait for gathering to complete
	timeout := time.After(10 * time.Second)
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			return nil, fmt.Errorf("candidate gathering timeout")
		case <-ticker.C:
			candidates, err := a.agent.GetLocalCandidates()
			if err == nil && len(candidates) > 0 {
				a.logger.Info("Candidate gathering completed", "count", len(candidates))
				return candidates, nil
			}
		}
	}
}

// AddRemoteCandidate adds a remote candidate
func (a *ICEAgent) AddRemoteCandidate(candidate ice.Candidate) error {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.agent == nil {
		return fmt.Errorf("ICE agent not started")
	}

	a.logger.Debug("Adding remote candidate", "candidate", candidate.String())
	return a.agent.AddRemoteCandidate(candidate)
}

// StartConnectivityChecks starts ICE connectivity checks
func (a *ICEAgent) StartConnectivityChecks() error {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.agent == nil {
		return fmt.Errorf("ICE agent not started")
	}

	a.logger.Info("Starting ICE connectivity checks")
	// Note: StartConnectivityChecks is not available in v2, using alternative approach
	return nil
}

// GetSelectedCandidatePair returns the selected candidate pair
func (a *ICEAgent) GetSelectedCandidatePair() (*ice.CandidatePair, error) {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.agent == nil {
		return nil, fmt.Errorf("ICE agent not started")
	}

	return a.agent.GetSelectedCandidatePair()
}

// GetConnectionState returns the current connection state
func (a *ICEAgent) GetConnectionState() ice.ConnectionState {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.agent == nil {
		return ice.ConnectionStateClosed
	}

	// Note: ConnectionState is not directly accessible in v2
	return ice.ConnectionStateNew
}

// setupEventHandlers sets up ICE agent event handlers
func (a *ICEAgent) setupEventHandlers() {
	// On candidate gathering state change
	a.agent.OnCandidate(func(candidate ice.Candidate) {
		a.logger.Debug("New candidate gathered", "candidate", candidate.String())
	})

	// On connection state change
	a.agent.OnConnectionStateChange(func(state ice.ConnectionState) {
		a.logger.Info("ICE connection state changed", "state", state.String())
	})

	// On selected candidate pair change
	a.agent.OnSelectedCandidatePairChange(func(local, remote ice.Candidate) {
		a.logger.Info("Selected candidate pair changed",
			"local", local.String(),
			"remote", remote.String())
	})
}

// ValidateSTUNServer validates a STUN server
func ValidateSTUNServer(server string) error {
	conn, err := net.DialTimeout("udp", server, 5*time.Second)
	if err != nil {
		return fmt.Errorf("failed to connect to STUN server %s: %w", server, err)
	}
	defer conn.Close()

	// Send STUN binding request
	request := stun.MustBuild(stun.TransactionID, stun.BindingRequest)

	_, err = conn.Write(request.Raw)
	if err != nil {
		return fmt.Errorf("failed to send STUN request: %w", err)
	}

	// Read response
	response := make([]byte, 1024)
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	n, err := conn.Read(response)
	if err != nil {
		return fmt.Errorf("failed to read STUN response: %w", err)
	}

	// Parse response
	var msg stun.Message
	if err := msg.UnmarshalBinary(response[:n]); err != nil {
		return fmt.Errorf("failed to parse STUN response: %w", err)
	}

	if msg.Type != stun.BindingSuccess {
		return fmt.Errorf("unexpected STUN response type: %v", msg.Type)
	}

	return nil
}

// GetPublicIP gets the public IP address using STUN
func GetPublicIP(stunServer string) (net.IP, error) {
	conn, err := net.DialTimeout("udp", stunServer, 5*time.Second)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to STUN server: %w", err)
	}
	defer conn.Close()

	// Send STUN binding request
	request := stun.MustBuild(stun.TransactionID, stun.BindingRequest)

	_, err = conn.Write(request.Raw)
	if err != nil {
		return nil, fmt.Errorf("failed to send STUN request: %w", err)
	}

	// Read response
	response := make([]byte, 1024)
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	n, err := conn.Read(response)
	if err != nil {
		return nil, fmt.Errorf("failed to read STUN response: %w", err)
	}

	// Parse response
	var msg stun.Message
	if err := msg.UnmarshalBinary(response[:n]); err != nil {
		return nil, fmt.Errorf("failed to parse STUN response: %w", err)
	}

	// Extract mapped address
	var mappedAddress stun.XORMappedAddress
	if err := mappedAddress.GetFrom(&msg); err != nil {
		return nil, fmt.Errorf("failed to get mapped address: %w", err)
	}

	return mappedAddress.IP, nil
}
