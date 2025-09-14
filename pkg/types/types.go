package types

import (
	"time"
)

// Platform constants
const (
	PlatformLinux   = "linux"
	PlatformWindows = "windows"
	PlatformDarwin  = "darwin"
)

// Status constants
const (
	StatusInactive = "inactive"
)

// Config represents the complete client configuration
type Config struct {
	Relay        RelayConfig        `mapstructure:"relay"`
	Auth         AuthConfig         `mapstructure:"auth"`
	RateLimiting RateLimitingConfig `mapstructure:"rate_limiting"`
	Logging      LoggingConfig      `mapstructure:"logging"`
	Metrics      MetricsConfig      `mapstructure:"metrics"`
	Performance  PerformanceConfig  `mapstructure:"performance"`
}

// RelayConfig contains relay server connection settings
type RelayConfig struct {
	Host    string        `mapstructure:"host"`
	Port    int           `mapstructure:"port"`
	Timeout time.Duration `mapstructure:"timeout"`
	TLS     TLSConfig     `mapstructure:"tls"`
}

// TLSConfig contains TLS-specific settings
type TLSConfig struct {
	Enabled    bool   `mapstructure:"enabled"`
	MinVersion string `mapstructure:"min_version"`
	VerifyCert bool   `mapstructure:"verify_cert"`
	CACert     string `mapstructure:"ca_cert"`
	ClientCert string `mapstructure:"client_cert"`
	ClientKey  string `mapstructure:"client_key"`
	ServerName string `mapstructure:"server_name"`
}

// AuthConfig contains authentication settings
type AuthConfig struct {
	Type           string         `mapstructure:"type"`
	Secret         string         `mapstructure:"secret"`
	FallbackSecret string         `mapstructure:"fallback_secret"`
	Keycloak       KeycloakConfig `mapstructure:"keycloak"`
}

// KeycloakConfig contains Keycloak integration settings
type KeycloakConfig struct {
	Enabled   bool   `mapstructure:"enabled"`
	ServerURL string `mapstructure:"server_url"`
	Realm     string `mapstructure:"realm"`
	ClientID  string `mapstructure:"client_id"`
	JWKSURL   string `mapstructure:"jwks_url"`
}

// RateLimitingConfig contains rate limiting settings
type RateLimitingConfig struct {
	Enabled           bool          `mapstructure:"enabled"`
	MaxRetries        int           `mapstructure:"max_retries"`
	BackoffMultiplier float64       `mapstructure:"backoff_multiplier"`
	MaxBackoff        time.Duration `mapstructure:"max_backoff"`
}

// LoggingConfig contains logging settings
type LoggingConfig struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"`
	Output string `mapstructure:"output"`
}

// MetricsConfig contains metrics configuration
type MetricsConfig struct {
	Enabled           bool `mapstructure:"enabled"`
	PrometheusPort    int  `mapstructure:"prometheus_port"`
	TenantMetrics     bool `mapstructure:"tenant_metrics"`
	BufferMetrics     bool `mapstructure:"buffer_metrics"`
	ConnectionMetrics bool `mapstructure:"connection_metrics"`
}

// PerformanceConfig contains performance optimization settings
type PerformanceConfig struct {
	Enabled          bool   `mapstructure:"enabled"`
	OptimizationMode string `mapstructure:"optimization_mode"`
	GCPercent        int    `mapstructure:"gc_percent"`
	MemoryBallast    bool   `mapstructure:"memory_ballast"`
}
