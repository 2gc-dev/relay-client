package interfaces

import (
	"time"

	"github.com/2gc-dev/cloudbridge-client/pkg/types"
)

// ClientInterface defines the interface that relay client must implement
type ClientInterface interface {
	IsConnected() bool
	SendHeartbeat() error
	GetConfig() *types.Config
	GetClientID() string
	GetTenantID() string
}

// ConfigInterface defines the interface for configuration
type ConfigInterface interface {
	GetRelayHost() string
	GetRelayPort() int
	GetRelayTimeout() time.Duration
	GetTLSEnabled() bool
	GetTLSMinVersion() string
	GetTLSVerifyCert() bool
	GetTLSCACert() string
	GetTLSClientCert() string
	GetTLSClientKey() string
	GetTLSServerName() string
	GetAuthType() string
	GetAuthSecret() string
	GetRateLimitingEnabled() bool
	GetRateLimitingMaxRetries() int
	GetRateLimitingBackoffMultiplier() float64
	GetRateLimitingMaxBackoff() time.Duration
}
