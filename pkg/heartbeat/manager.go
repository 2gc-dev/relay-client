package heartbeat

import (
	"fmt"
	"sync"
	"time"

	"github.com/2gc-dev/cloudbridge-client/pkg/interfaces"
)

// Manager handles heartbeat operations
type Manager struct {
	client    interfaces.ClientInterface
	interval  time.Duration
	ticker    *time.Ticker
	stopChan  chan struct{}
	running   bool
	mu        sync.RWMutex
	lastBeat  time.Time
	failCount int
	maxFails  int
}

// NewManager creates a new heartbeat manager
func NewManager(client interfaces.ClientInterface) *Manager {
	return &Manager{
		client:   client,
		interval: 30 * time.Second, // Default heartbeat interval
		stopChan: make(chan struct{}),
		maxFails: 3, // Maximum consecutive failures
	}
}

// Start starts the heartbeat mechanism
func (m *Manager) Start() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.running {
		return fmt.Errorf("heartbeat manager is already running")
	}

	if !m.client.IsConnected() {
		return fmt.Errorf("client is not connected")
	}

	m.running = true
	m.ticker = time.NewTicker(m.interval)
	m.failCount = 0

	go m.heartbeatLoop()

	return nil
}

// Stop stops the heartbeat mechanism
func (m *Manager) Stop() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.running {
		return
	}

	m.running = false
	if m.ticker != nil {
		m.ticker.Stop()
	}
	close(m.stopChan)
}

// SetInterval sets the heartbeat interval
func (m *Manager) SetInterval(interval time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.interval = interval
	if m.ticker != nil {
		m.ticker.Reset(interval)
	}
}

// GetInterval returns the current heartbeat interval
func (m *Manager) GetInterval() time.Duration {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.interval
}

// IsRunning returns true if the heartbeat manager is running
func (m *Manager) IsRunning() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.running
}

// GetLastBeat returns the time of the last successful heartbeat
func (m *Manager) GetLastBeat() time.Time {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.lastBeat
}

// GetFailCount returns the number of consecutive failures
func (m *Manager) GetFailCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.failCount
}

// heartbeatLoop is the main heartbeat loop
func (m *Manager) heartbeatLoop() {
	for {
		select {
		case <-m.ticker.C:
			if err := m.sendHeartbeat(); err != nil {
				m.handleHeartbeatFailure(err)
			} else {
				m.handleHeartbeatSuccess()
			}

		case <-m.stopChan:
			return
		}
	}
}

// sendHeartbeat sends a heartbeat message
func (m *Manager) sendHeartbeat() error {
	if !m.client.IsConnected() {
		return fmt.Errorf("client is not connected")
	}

	return m.client.SendHeartbeat()
}

// handleHeartbeatSuccess handles a successful heartbeat
func (m *Manager) handleHeartbeatSuccess() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.lastBeat = time.Now()
	m.failCount = 0

	// Log success (in production, use proper logging)
	fmt.Printf("Heartbeat sent successfully at %s\n", m.lastBeat.Format(time.RFC3339))
}

// handleHeartbeatFailure handles a failed heartbeat
func (m *Manager) handleHeartbeatFailure(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.failCount++

	// Log failure (in production, use proper logging)
	fmt.Printf("Heartbeat failed (attempt %d/%d): %v\n", m.failCount, m.maxFails, err)

	// Check if we should stop due to too many failures
	if m.failCount >= m.maxFails {
		fmt.Printf("Too many heartbeat failures (%d), stopping heartbeat manager\n", m.failCount)
		m.running = false
		if m.ticker != nil {
			m.ticker.Stop()
		}
	}
}

// SendManualHeartbeat sends a manual heartbeat (for testing)
func (m *Manager) SendManualHeartbeat() error {
	if !m.IsRunning() {
		return fmt.Errorf("heartbeat manager is not running")
	}

	return m.sendHeartbeat()
}

// GetStats returns heartbeat statistics
func (m *Manager) GetStats() map[string]interface{} {
	m.mu.RLock()
	defer m.mu.RUnlock()

	stats := make(map[string]interface{})
	stats["running"] = m.running
	stats["interval"] = m.interval.String()
	stats["last_beat"] = m.lastBeat
	stats["fail_count"] = m.failCount
	stats["max_fails"] = m.maxFails

	if !m.lastBeat.IsZero() {
		stats["time_since_last_beat"] = time.Since(m.lastBeat).String()
	}

	return stats
}

// ResetFailCount resets the failure counter
func (m *Manager) ResetFailCount() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.failCount = 0
}

// SetMaxFails sets the maximum number of consecutive failures
func (m *Manager) SetMaxFails(maxFails int) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.maxFails = maxFails
}
