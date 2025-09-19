package p2p

import "time"

// ConnectionType represents the type of P2P connection
type ConnectionType string

const (
	ConnectionTypeClientServer ConnectionType = "client-server"
	ConnectionTypeServerServer ConnectionType = "server-server"
	ConnectionTypeP2PMesh      ConnectionType = "p2p-mesh"
)

// QUICConfig represents QUIC configuration
type QUICConfig struct {
	ListenPort        int    `json:"listen_port,omitempty"`
	HandshakeTimeout  string `json:"handshake_timeout,omitempty"`
	IdleTimeout       string `json:"idle_timeout,omitempty"`
	MaxStreams        int    `json:"max_streams,omitempty"`
	MaxStreamData     int    `json:"max_stream_data,omitempty"`
	KeepAlivePeriod   string `json:"keep_alive_period,omitempty"`
	InsecureSkipVerify bool  `json:"insecure_skip_verify,omitempty"`
}

// MeshConfig represents mesh network configuration from JWT
type MeshConfig struct {
	AutoDiscovery    bool        `json:"auto_discovery"`
	Persistent       bool        `json:"persistent"`
	Routing          string      `json:"routing"`    // "hybrid", "direct", "relay"
	Encryption       string      `json:"encryption"` // "quic", "tls"
	HeartbeatInterval interface{} `json:"heartbeat_interval"`
}

// PeerWhitelist represents peer whitelist configuration from JWT
type PeerWhitelist struct {
	AllowedPeers []string `json:"allowed_peers"`
	AutoApprove  bool     `json:"auto_approve"`
	MaxPeers     int      `json:"max_peers"`
}

// NetworkConfig represents network configuration from JWT
type NetworkConfig struct {
	Subnet      string   `json:"subnet"`
	DNS         []string `json:"dns"`
	MTU         int      `json:"mtu"`
	STUNServers []string `json:"stun_servers,omitempty"`
	TURNServers []string `json:"turn_servers,omitempty"`
	QUICPort    int      `json:"quic_port,omitempty"`
	ICEPort     int      `json:"ice_port,omitempty"`
}

// P2PConfig represents complete P2P configuration
type P2PConfig struct {
	ConnectionType    ConnectionType   `json:"connection_type"`
	QUICConfig        *QUICConfig      `json:"quic_config,omitempty"`
	MeshConfig        *MeshConfig      `json:"mesh_config,omitempty"`
	PeerWhitelist     *PeerWhitelist   `json:"peer_whitelist,omitempty"`
	NetworkConfig     *NetworkConfig   `json:"network_config,omitempty"`
	TenantID          string           `json:"tenant_id,omitempty"`
	Permissions       []string         `json:"permissions,omitempty"`
	HeartbeatInterval time.Duration    `json:"heartbeat_interval,omitempty"`
	HeartbeatTimeout  time.Duration    `json:"heartbeat_timeout,omitempty"`
}

// Peer represents a discovered peer in the mesh network
type Peer struct {
	ID          string   `json:"id"`
	PublicKey   string   `json:"public_key"`
	Endpoint    string   `json:"endpoint"`
	AllowedIPs  []string `json:"allowed_ips"`
	QUICPort    int      `json:"quic_port,omitempty"`
	ICEPort     int      `json:"ice_port,omitempty"`
	Persistent  bool     `json:"persistent"`
	LastSeen    int64    `json:"last_seen"`
	Latency     int64    `json:"latency_ms"`
	IsConnected bool     `json:"is_connected"`
}

// MeshTopology represents the current mesh network topology
type MeshTopology struct {
	LocalPeerID     string              `json:"local_peer_id"`
	ConnectedPeers  map[string]*Peer    `json:"connected_peers"`
	DiscoveredPeers map[string]*Peer    `json:"discovered_peers"`
	RoutingTable    map[string][]string `json:"routing_table"`
}

// P2PStatus represents the current status of P2P connection
type P2PStatus struct {
	IsConnected      bool           `json:"is_connected"`
	ConnectionType   ConnectionType `json:"connection_type"`
	ActivePeers      int            `json:"active_peers"`
	TotalPeers       int            `json:"total_peers"`
	MeshEnabled      bool           `json:"mesh_enabled"`
	QUICReady        bool           `json:"quic_ready"`
	ICEReady         bool           `json:"ice_ready"`
	ActiveConnections int           `json:"active_connections"`
	LastError        string         `json:"last_error,omitempty"`
}

// P2PMessage represents a P2P protocol message
type P2PMessage struct {
	Type      string      `json:"type"`
	Data      interface{} `json:"data,omitempty"`
	Timestamp int64       `json:"timestamp"`
	PeerID    string      `json:"peer_id,omitempty"`
}

// P2PHandshake represents a P2P handshake message
type P2PHandshake struct {
	Type        string   `json:"type"`
	PublicKey   string   `json:"public_key"`
	ListenPort  int      `json:"listen_port"`
	Mode        string   `json:"mode"`
	Peers       []*Peer  `json:"peers,omitempty"`
	Timestamp   int64    `json:"timestamp"`
	TenantID    string   `json:"tenant_id,omitempty"`
	Permissions []string `json:"permissions,omitempty"`
}

// P2PHandshakeResponse represents a P2P handshake response
type P2PHandshakeResponse struct {
	Type         string      `json:"type"`
	Status       string      `json:"status"`
	Message      string      `json:"message,omitempty"`
	PeerID       string      `json:"peer_id,omitempty"`
	MeshConfig   *MeshConfig `json:"mesh_config,omitempty"`
	AllowedPeers []string    `json:"allowed_peers,omitempty"`
}

// PeerDiscoveryRequest represents a peer discovery request
type PeerDiscoveryRequest struct {
	Type      string `json:"type"`
	TenantID  string `json:"tenant_id"`
	PublicKey string `json:"public_key"`
	Endpoint  string `json:"endpoint"`
}

// PeerDiscoveryResponse represents a peer discovery response
type PeerDiscoveryResponse struct {
	Type  string  `json:"type"`
	Peers []*Peer `json:"peers"`
}

// MeshRouteRequest represents a mesh routing request
type MeshRouteRequest struct {
	Type        string `json:"type"`
	Destination string `json:"destination"`
	Source      string `json:"source"`
}

// MeshRouteResponse represents a mesh routing response
type MeshRouteResponse struct {
	Type    string   `json:"type"`
	Route   []string `json:"route"`
	Latency int64    `json:"latency_ms"`
}
