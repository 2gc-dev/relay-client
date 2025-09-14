package config

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"
	"regexp"

	"github.com/2gc-dev/cloudbridge-client/pkg/types"
	"github.com/spf13/viper"
)

// LoadConfig loads configuration from file and environment variables
func LoadConfig(configPath string) (*types.Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")
	viper.AddConfigPath("/etc/cloudbridge-client")
	viper.AddConfigPath("$HOME/.cloudbridge-client")

	// Set defaults
	setDefaults()

	// Read config file if specified
	if configPath != "" {
		viper.SetConfigFile(configPath)
	}

	// Read environment variables
	viper.AutomaticEnv()
	viper.SetEnvPrefix("CLOUDBRIDGE")

	// Read config
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config: %w", err)
		}
	}

	var config types.Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Substitute environment variables in string fields
	substituteEnvVars(&config)

	// Validate configuration
	if err := validateConfig(&config); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return &config, nil
}

// setDefaults sets default configuration values
func setDefaults() {
	viper.SetDefault("relay.host", "relay.2gc.ru")
	viper.SetDefault("relay.port", 9090)
	viper.SetDefault("relay.timeout", "30s")
	viper.SetDefault("relay.tls.enabled", true)
	viper.SetDefault("relay.tls.min_version", "1.3")
	viper.SetDefault("relay.tls.verify_cert", true)
	viper.SetDefault("auth.type", "jwt")
	viper.SetDefault("auth.fallback_secret", "")
	viper.SetDefault("auth.keycloak.enabled", false)
	viper.SetDefault("rate_limiting.enabled", true)
	viper.SetDefault("rate_limiting.max_retries", 3)
	viper.SetDefault("rate_limiting.backoff_multiplier", 2.0)
	viper.SetDefault("rate_limiting.max_backoff", "30s")
	viper.SetDefault("logging.level", "info")
	viper.SetDefault("logging.format", "json")
	viper.SetDefault("logging.output", "stdout")
}

// validateConfig validates the configuration
func validateConfig(c *types.Config) error {
	if c.Relay.Host == "" {
		return fmt.Errorf("relay host is required")
	}

	if c.Relay.Port <= 0 || c.Relay.Port > 65535 {
		return fmt.Errorf("invalid relay port")
	}

	if c.Relay.TLS.Enabled && c.Relay.TLS.MinVersion != "1.3" {
		return fmt.Errorf("only TLS 1.3 is supported")
	}

	if c.Relay.TLS.Enabled && c.Relay.TLS.CACert != "" {
		if _, err := os.Stat(c.Relay.TLS.CACert); os.IsNotExist(err) {
			return fmt.Errorf("CA certificate file not found: %s", c.Relay.TLS.CACert)
		}
	}

	if c.Relay.TLS.Enabled && c.Relay.TLS.ClientCert != "" && c.Relay.TLS.ClientKey == "" {
		return fmt.Errorf("client key is required when client certificate is provided")
	}

	if c.Relay.TLS.Enabled && c.Relay.TLS.ClientKey != "" && c.Relay.TLS.ClientCert == "" {
		return fmt.Errorf("client certificate is required when client key is provided")
	}

	if c.Auth.Type == "jwt" && c.Auth.Secret == "" {
		return fmt.Errorf("JWT secret is required for JWT authentication")
	}

	if c.Auth.Keycloak.Enabled {
		if c.Auth.Keycloak.ServerURL == "" {
			return fmt.Errorf("keycloak server URL is required")
		}
		if c.Auth.Keycloak.Realm == "" {
			return fmt.Errorf("keycloak realm is required")
		}
		if c.Auth.Keycloak.ClientID == "" {
			return fmt.Errorf("keycloak client ID is required")
		}
	}

	if c.RateLimiting.MaxRetries < 0 {
		return fmt.Errorf("max retries cannot be negative")
	}

	if c.RateLimiting.BackoffMultiplier <= 0 {
		return fmt.Errorf("backoff multiplier must be positive")
	}

	return nil
}

// CreateTLSConfig creates a TLS configuration from the config
func CreateTLSConfig(c *types.Config) (*tls.Config, error) {
	if !c.Relay.TLS.Enabled {
		return nil, nil
	}

	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS13,
		CipherSuites: []uint16{
			tls.TLS_AES_256_GCM_SHA384,
			tls.TLS_CHACHA20_POLY1305_SHA256,
			tls.TLS_AES_128_GCM_SHA256,
		},
		InsecureSkipVerify: !c.Relay.TLS.VerifyCert,
	}

	// Set server name for SNI
	if c.Relay.TLS.ServerName != "" {
		tlsConfig.ServerName = c.Relay.TLS.ServerName
	} else {
		tlsConfig.ServerName = c.Relay.Host
	}

	// Load CA certificate if provided
	if c.Relay.TLS.CACert != "" {
		caCert, readErr := os.ReadFile(c.Relay.TLS.CACert)
		if readErr != nil {
			return nil, fmt.Errorf("failed to read CA certificate: %w", readErr)
		}

		caCertPool := x509.NewCertPool()
		if !caCertPool.AppendCertsFromPEM(caCert) {
			return nil, fmt.Errorf("failed to append CA certificate")
		}

		tlsConfig.RootCAs = caCertPool
	}

	// Load client certificate if provided
	if c.Relay.TLS.ClientCert != "" && c.Relay.TLS.ClientKey != "" {
		cert, certErr := tls.LoadX509KeyPair(c.Relay.TLS.ClientCert, c.Relay.TLS.ClientKey)
		if certErr != nil {
			return nil, fmt.Errorf("failed to load client certificate: %w", certErr)
		}
		tlsConfig.Certificates = []tls.Certificate{cert}
	}

	return tlsConfig, nil
}

// substituteEnvVars substitutes environment variables in configuration strings
func substituteEnvVars(config *types.Config) {
	// Substitute in auth config
	config.Auth.Secret = substituteEnvVar(config.Auth.Secret)
	config.Auth.FallbackSecret = substituteEnvVar(config.Auth.FallbackSecret)
	config.Auth.Keycloak.ServerURL = substituteEnvVar(config.Auth.Keycloak.ServerURL)
	config.Auth.Keycloak.Realm = substituteEnvVar(config.Auth.Keycloak.Realm)
	config.Auth.Keycloak.ClientID = substituteEnvVar(config.Auth.Keycloak.ClientID)
	config.Auth.Keycloak.JWKSURL = substituteEnvVar(config.Auth.Keycloak.JWKSURL)

	// Substitute in relay config
	config.Relay.Host = substituteEnvVar(config.Relay.Host)
	config.Relay.TLS.CACert = substituteEnvVar(config.Relay.TLS.CACert)
	config.Relay.TLS.ClientCert = substituteEnvVar(config.Relay.TLS.ClientCert)
	config.Relay.TLS.ClientKey = substituteEnvVar(config.Relay.TLS.ClientKey)
	config.Relay.TLS.ServerName = substituteEnvVar(config.Relay.TLS.ServerName)

	// Substitute in logging config
	config.Logging.Output = substituteEnvVar(config.Logging.Output)
}

// substituteEnvVar substitutes environment variables in a string
// Supports format: ${VAR_NAME} or ${VAR_NAME:default_value}
func substituteEnvVar(value string) string {
	if value == "" {
		return value
	}

	// Regular expression to match ${VAR_NAME} or ${VAR_NAME:default_value}
	re := regexp.MustCompile(`\$\{([^}:]+)(?::([^}]*))?\}`)

	return re.ReplaceAllStringFunc(value, func(match string) string {
		// Extract variable name and default value
		matches := re.FindStringSubmatch(match)
		if len(matches) < 2 {
			return match
		}

		varName := matches[1]
		defaultValue := ""
		if len(matches) > 2 {
			defaultValue = matches[2]
		}

		// Get environment variable value
		envValue := os.Getenv(varName)
		if envValue == "" {
			envValue = defaultValue
		}

		return envValue
	})
}
