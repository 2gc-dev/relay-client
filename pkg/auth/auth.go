package auth

import (
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/2gc-dev/cloudbridge-client/pkg/errors"
	"github.com/golang-jwt/jwt/v5"
)

// Claims represents JWT claims with tenant and P2P support
type Claims struct {
	Subject         string           `json:"sub"`
	TenantID        string           `json:"tenant_id,omitempty"`
	OrgID           string           `json:"org_id,omitempty"`
	Permissions     []string         `json:"permissions,omitempty"`
	ConnectionType  string           `json:"connection_type,omitempty"`
	QUICConfig      *QUICConfig      `json:"quic_config,omitempty"`
	MeshConfig      *MeshConfig      `json:"mesh_config,omitempty"`
	PeerWhitelist   *PeerWhitelist   `json:"peer_whitelist,omitempty"`
	NetworkConfig   *NetworkConfig   `json:"network_config,omitempty"`
	Issuer          string           `json:"iss,omitempty"`
	Audience        string           `json:"aud,omitempty"`
	ExpiresAt       int64            `json:"exp,omitempty"`
	IssuedAt        int64            `json:"iat,omitempty"`
	NotBefore       int64            `json:"nbf,omitempty"`
	jwt.RegisteredClaims
}


// QUICConfig represents QUIC configuration from JWT
type QUICConfig struct {
	PublicKey  string   `json:"public_key"`
	AllowedIPs []string `json:"allowed_ips"`
}

// MeshConfig represents mesh network configuration from JWT
type MeshConfig struct {
	AutoDiscovery    bool        `json:"auto_discovery"`
	Persistent       bool        `json:"persistent"`
	Routing          string      `json:"routing"`
	Encryption       string      `json:"encryption"`
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
	Subnet string   `json:"subnet"`
	DNS    []string `json:"dns"`
	MTU    int      `json:"mtu"`
}

// AuthManager handles authentication with relay server
type AuthManager struct {
	config     *AuthConfig
	jwtSecret  []byte
	publicKey  *rsa.PublicKey
	httpClient *http.Client
}

// AuthConfig contains authentication configuration
type AuthConfig struct {
	Type           string          `json:"type"`
	Secret         string          `json:"secret"`
	FallbackSecret string          `json:"fallback_secret,omitempty"`
	SkipValidation bool            `json:"skip_validation,omitempty"`
	Keycloak       *KeycloakConfig `json:"keycloak,omitempty"`
}

// KeycloakConfig contains Keycloak-specific configuration
type KeycloakConfig struct {
	ServerURL string `json:"server_url"`
	Realm     string `json:"realm"`
	ClientID  string `json:"client_id"`
	JWKSURL   string `json:"jwks_url"`
}

// JWKS represents JSON Web Key Set
type JWKS struct {
	Keys []JWK `json:"keys"`
}

// JWK represents a JSON Web Key
type JWK struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	N   string `json:"n"`
	E   string `json:"e"`
}

// NewAuthManager creates a new authentication manager
func NewAuthManager(config *AuthConfig) (*AuthManager, error) {
	am := &AuthManager{
		config: config,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}

	switch config.Type {
	case "jwt":
		if config.Secret == "" {
			return nil, fmt.Errorf("jwt secret is required")
		}
		// Support both plain and base64-encoded secrets
		if decoded, err := base64.StdEncoding.DecodeString(config.Secret); err == nil && len(decoded) > 0 {
			am.jwtSecret = decoded
		} else {
			am.jwtSecret = []byte(config.Secret)
		}

	case "keycloak":
		if config.Keycloak == nil {
			return nil, fmt.Errorf("keycloak configuration is required")
		}
		if err := am.setupKeycloak(); err != nil {
			return nil, fmt.Errorf("failed to setup keycloak: %w", err)
		}

	default:
		return nil, fmt.Errorf("unsupported authentication type: %s", config.Type)
	}

	return am, nil
}

// setupKeycloak initializes Keycloak authentication
func (am *AuthManager) setupKeycloak() error {
	if am.config.Keycloak.JWKSURL == "" {
		am.config.Keycloak.JWKSURL = fmt.Sprintf(
			"%s/realms/%s/protocol/openid-connect/certs",
			am.config.Keycloak.ServerURL,
			am.config.Keycloak.Realm,
		)
	}

	// Fetch JWKS
	jwks, err := am.fetchJWKS()
	if err != nil {
		return fmt.Errorf("failed to fetch jwks: %w", err)
	}

	// Convert first key to RSA public key
	if len(jwks.Keys) == 0 {
		return fmt.Errorf("no keys found in jwks")
	}

	key := jwks.Keys[0]
	publicKey, err := am.jwkToRSAPublicKey(key)
	if err != nil {
		return fmt.Errorf("failed to convert jwk to RSA public key: %w", err)
	}

	am.publicKey = publicKey
	return nil
}

// fetchJWKS fetches JSON Web Key Set from Keycloak
func (am *AuthManager) fetchJWKS() (*JWKS, error) {
	resp, err := am.httpClient.Get(am.config.Keycloak.JWKSURL)
	if err != nil {
		return nil, err
	}
	defer func() {
		if cerr := resp.Body.Close(); cerr != nil {
			_ = cerr // Игнорируем ошибку закрытия response body
		}
	}()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch jwks: %s", resp.Status)
	}

	var jwks JWKS
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("failed to decode jwks: %w", err)
	}

	return &jwks, nil
}

// jwkToRSAPublicKey converts JWK to RSA public key
func (am *AuthManager) jwkToRSAPublicKey(jwk JWK) (*rsa.PublicKey, error) {
	// This is a simplified implementation
	// In production, you should use a proper JWK library
	return nil, fmt.Errorf("JWK to RSA conversion not implemented")
}

// ValidateToken validates a JWT token
func (am *AuthManager) ValidateToken(tokenString string) (*jwt.Token, error) {
	switch am.config.Type {
	case "jwt":
		return am.validateJWTToken(tokenString)
	case "keycloak":
		return am.validateKeycloakToken(tokenString)
	default:
		return nil, fmt.Errorf("unsupported authentication type")
	}
}

// validateJWTToken validates a JWT token with HMAC
func (am *AuthManager) validateJWTToken(tokenString string) (*jwt.Token, error) {
    // Skip validation if configured
    if am.config.SkipValidation {
        // Check if token has proper JWT format (3 parts)
        parts := strings.Split(tokenString, ".")
        if len(parts) != 3 {
            // For development, handle non-standard JWT format
            if len(parts) == 2 {
                // This appears to be a non-standard format: header+payload.signature
                // Try to decode the first part as header+payload
                headerPayloadBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
                if err != nil {
                    return nil, errors.NewRelayError(errors.ErrInvalidToken, fmt.Sprintf("Failed to decode header+payload: %v", err))
                }
                
                // The first part contains both header and payload, so we need to extract the payload
                // For now, let's assume the entire first part is the payload (claims)
                var claims jwt.MapClaims
                if err := json.Unmarshal(headerPayloadBytes, &claims); err != nil {
                    return nil, errors.NewRelayError(errors.ErrInvalidToken, fmt.Sprintf("Failed to unmarshal claims: %v", err))
                }
                
                // Create a mock token
                token := &jwt.Token{
                    Raw:    tokenString,
                    Method: jwt.SigningMethodHS256,
                    Claims: claims,
                    Valid:  true,
                }
                return token, nil
            }
            return nil, errors.NewRelayError(errors.ErrInvalidToken, "token is malformed: token contains an invalid number of segments")
        }
        
        // Parse token without validation
        parser := jwt.Parser{}
        token, _, err := parser.ParseUnverified(tokenString, jwt.MapClaims{})
        if err != nil {
            return nil, errors.NewRelayError(errors.ErrInvalidToken, fmt.Sprintf("JWT parsing failed: %v", err))
        }
        return token, nil
    }
    
    // Prepare candidate keys based on kid and configured secrets
    var candidates [][]byte

    // Helper to append decoded and raw versions in order
    addSecretCandidates := func(secret string) {
        if secret == "" {
            return
        }
        if decoded, err := base64.StdEncoding.DecodeString(secret); err == nil && len(decoded) > 0 {
            candidates = append(candidates, decoded)
        }
        candidates = append(candidates, []byte(secret))
    }

    // If kid==fallback-key and fallback secret provided, try it first
    {
        // Parse header to inspect kid without verifying signature
        parser := jwt.Parser{}
        if unverifiedToken, _, _ := parser.ParseUnverified(tokenString, jwt.MapClaims{}); unverifiedToken != nil {
            if kid, ok := unverifiedToken.Header["kid"].(string); ok && kid == "fallback-key" && am.config.FallbackSecret != "" {
                addSecretCandidates(am.config.FallbackSecret)
            }
        }
    }

    // If no candidates yet, fall back to primary secret
    if len(candidates) == 0 {
        // Prefer using configured secret directly to preserve exact bytes
        addSecretCandidates(am.config.Secret)
    }

    var lastErr error
    for _, key := range candidates {
        token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
            // Validate algorithm
            if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
            }
            return key, nil
        })
        if err == nil && token != nil && token.Valid {
            return token, nil
        }
        lastErr = err
    }

    if lastErr != nil {
        return nil, errors.NewRelayError(errors.ErrInvalidToken, fmt.Sprintf("JWT validation failed: %v", lastErr))
    }
    return nil, errors.NewRelayError(errors.ErrInvalidToken, "invalid JWT token")
}

// validateKeycloakToken validates a Keycloak token
func (am *AuthManager) validateKeycloakToken(tokenString string) (*jwt.Token, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		// Validate algorithm
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return am.publicKey, nil
	})

	if err != nil {
		return nil, errors.NewRelayError(errors.ErrInvalidToken, fmt.Sprintf("keycloak token validation failed: %v", err))
	}

	if !token.Valid {
		return nil, errors.NewRelayError(errors.ErrInvalidToken, "Invalid Keycloak token")
	}

	// Validate claims
	if err := am.validateKeycloakClaims(token.Claims); err != nil {
		return nil, errors.NewRelayError(errors.ErrInvalidToken, fmt.Sprintf("Invalid claims: %v", err))
	}

	return token, nil
}

// validateKeycloakClaims validates Keycloak-specific claims
func (am *AuthManager) validateKeycloakClaims(claims jwt.Claims) error {
	// Validate issuer
	if issuer, ok := claims.(jwt.MapClaims)["iss"]; ok { //nolint:errcheck
		expectedIssuer := fmt.Sprintf("%s/realms/%s", am.config.Keycloak.ServerURL, am.config.Keycloak.Realm)
		if issuer != expectedIssuer {
			return fmt.Errorf("invalid issuer: expected %s, got %s", expectedIssuer, issuer)
		}
	}

	// Validate audience
	if aud, ok := claims.(jwt.MapClaims)["aud"]; ok { //nolint:errcheck
		if aud != am.config.Keycloak.ClientID {
			return fmt.Errorf("invalid audience: expected %s, got %s", am.config.Keycloak.ClientID, aud)
		}
	}

	return nil
}

// ExtractSubject extracts subject from token
func (am *AuthManager) ExtractSubject(token *jwt.Token) (string, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", fmt.Errorf("invalid token claims")
	}

	subject, ok := claims["sub"].(string)
	if !ok {
		return "", fmt.Errorf("subject claim not found or invalid")
	}

	return subject, nil
}

// ExtractTenantID extracts tenant_id from token
func (am *AuthManager) ExtractTenantID(token *jwt.Token) (string, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", fmt.Errorf("invalid token claims")
	}

	tenantID, ok := claims["tenant_id"].(string)
	if !ok {
		// Return empty string if tenant_id is not present (backward compatibility)
		return "", nil
	}

	return tenantID, nil
}

// ExtractClaims extracts both subject and tenant_id from token
func (am *AuthManager) ExtractClaims(token *jwt.Token) (string, string, error) {
	subject, err := am.ExtractSubject(token)
	if err != nil {
		return "", "", err
	}

	tenantID, err := am.ExtractTenantID(token)
	if err != nil {
		return "", "", err
	}

	return subject, tenantID, nil
}

// CreateAuthMessage creates an authentication message for relay server
func (am *AuthManager) CreateAuthMessage(tokenString string) (map[string]interface{}, error) {
	// Validate token first
	token, err := am.ValidateToken(tokenString)
	if err != nil {
		return nil, err
	}

	// Extract subject for rate limiting
	subject, err := am.ExtractSubject(token)
	if err != nil {
		return nil, err
	}

	return map[string]interface{}{
		"type":  "auth",
		"token": tokenString,
		"sub":   subject,
	}, nil
}

// ExtractConnectionType extracts connection type from token
func (am *AuthManager) ExtractConnectionType(token *jwt.Token) (string, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", fmt.Errorf("invalid token claims")
	}

	connectionType, ok := claims["connection_type"].(string)
	if !ok {
		// Fallback: determine from roles/permissions
		return am.determineConnectionTypeFromClaims(claims)
	}

	// Map JWT connection types to P2P connection types
	switch connectionType {
	case "wireguard":
		return "p2p-mesh", nil
	case "p2p-mesh":
		return "p2p-mesh", nil
	case "client-server":
		return "client-server", nil
	case "server-server":
		return "server-server", nil
	default:
		// Default to p2p-mesh for wireguard connections
		return "p2p-mesh", nil
	}
}

// ExtractQUICConfig extracts QUIC configuration from token
func (am *AuthManager) ExtractQUICConfig(token *jwt.Token) (*QUICConfig, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	quicConfig, ok := claims["quic_config"].(map[string]interface{})
	if !ok {
		// Return default QUIC config if not specified
		return &QUICConfig{
			PublicKey:  fmt.Sprintf("generated-quic-key-%d", time.Now().UnixNano()),
			AllowedIPs: []string{"10.0.0.0/24"},
		}, nil
	}

	config := &QUICConfig{}
	if publicKey, ok := quicConfig["public_key"].(string); ok {
		config.PublicKey = publicKey
	}
	if allowedIPs, ok := quicConfig["allowed_ips"].([]interface{}); ok {
		for _, ip := range allowedIPs {
			if ipStr, ok := ip.(string); ok {
				config.AllowedIPs = append(config.AllowedIPs, ipStr)
			}
		}
	}

	// Set defaults if not specified
	if config.PublicKey == "" {
		config.PublicKey = fmt.Sprintf("generated-quic-key-%d", time.Now().UnixNano())
	}
	if len(config.AllowedIPs) == 0 {
		config.AllowedIPs = []string{"10.0.0.0/24"}
	}

	return config, nil
}


// ExtractMeshConfig extracts mesh configuration from token
func (am *AuthManager) ExtractMeshConfig(token *jwt.Token) (*MeshConfig, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	meshConfig, ok := claims["mesh_config"].(map[string]interface{})
	if !ok {
		return nil, nil // Mesh not configured
	}

	config := &MeshConfig{}
	if autoDiscovery, ok := meshConfig["auto_discovery"].(bool); ok {
		config.AutoDiscovery = autoDiscovery
	}
	if persistent, ok := meshConfig["persistent"].(bool); ok {
		config.Persistent = persistent
	}
	if routing, ok := meshConfig["routing"].(string); ok {
		config.Routing = routing
	}
	if encryption, ok := meshConfig["encryption"].(string); ok {
		config.Encryption = encryption
	}
	if heartbeatInterval, ok := meshConfig["heartbeat_interval"]; ok {
		config.HeartbeatInterval = heartbeatInterval
	}

	return config, nil
}

// ExtractPeerWhitelist extracts peer whitelist from token
func (am *AuthManager) ExtractPeerWhitelist(token *jwt.Token) (*PeerWhitelist, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	whitelist, ok := claims["peer_whitelist"].(map[string]interface{})
	if !ok {
		return nil, nil // No whitelist configured
	}

	config := &PeerWhitelist{}
	if allowedPeers, ok := whitelist["allowed_peers"].([]interface{}); ok {
		for _, peer := range allowedPeers {
			if peerStr, ok := peer.(string); ok {
				config.AllowedPeers = append(config.AllowedPeers, peerStr)
			}
		}
	}
	if autoApprove, ok := whitelist["auto_approve"].(bool); ok {
		config.AutoApprove = autoApprove
	}
	if maxPeers, ok := whitelist["max_peers"].(float64); ok {
		config.MaxPeers = int(maxPeers)
	}

	return config, nil
}

// ExtractNetworkConfig extracts network configuration from token
func (am *AuthManager) ExtractNetworkConfig(token *jwt.Token) (*NetworkConfig, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	networkConfig, ok := claims["network_config"].(map[string]interface{})
	if !ok {
		return nil, nil // No network config
	}

	config := &NetworkConfig{}
	if subnet, ok := networkConfig["subnet"].(string); ok {
		config.Subnet = subnet
	}
	if dns, ok := networkConfig["dns"].([]interface{}); ok {
		for _, dnsServer := range dns {
			if dnsStr, ok := dnsServer.(string); ok {
				config.DNS = append(config.DNS, dnsStr)
			}
		}
	}
	if mtu, ok := networkConfig["mtu"].(float64); ok {
		config.MTU = int(mtu)
	}

	return config, nil
}

// ExtractPermissions extracts permissions from token
func (am *AuthManager) ExtractPermissions(token *jwt.Token) ([]string, error) {
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	permissions, ok := claims["permissions"].([]interface{})
	if !ok {
		return []string{}, nil // No permissions
	}

	var result []string
	for _, perm := range permissions {
		if permStr, ok := perm.(string); ok {
			result = append(result, permStr)
		}
	}

	return result, nil
}

// determineConnectionTypeFromClaims determines connection type from claims when not explicitly set
func (am *AuthManager) determineConnectionTypeFromClaims(claims jwt.MapClaims) (string, error) {
	// Check permissions for P2P capabilities
	if permissions, ok := claims["permissions"].([]interface{}); ok {
		for _, perm := range permissions {
			if permStr, ok := perm.(string); ok {
				if permStr == "mesh:connect" || permStr == "mesh:discover" {
					return "p2p-mesh", nil
				}
			}
		}
	}

	// Default to client-server
	return "client-server", nil
}

// GetTokenFromHeader extracts token from Authorization header
func (am *AuthManager) GetTokenFromHeader(header string) (string, error) {
	if header == "" {
		return "", fmt.Errorf("authorization header is empty")
	}

	parts := strings.Split(header, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		return "", fmt.Errorf("invalid authorization header format")
	}

	return parts[1], nil
}
