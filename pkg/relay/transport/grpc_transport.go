package transport

import (
	"context"
	"fmt"
	"time"

	"github.com/2gc-dev/cloudbridge-client/pkg/relay/transport/proto"
)

// GRPCTransport implements the Transport interface using gRPC
type GRPCTransport struct {
	client *GRPCClient
	logger Logger
}

// NewGRPCTransport creates a new gRPC transport
func NewGRPCTransport(client *GRPCClient, logger Logger) *GRPCTransport {
	return &GRPCTransport{
		client: client,
		logger: logger,
	}
}

// Connect establishes connection to the relay server
func (gt *GRPCTransport) Connect() error {
	return gt.client.Connect()
}

// Disconnect closes the connection
func (gt *GRPCTransport) Disconnect() error {
	return gt.client.Disconnect()
}

// Hello performs initial handshake
func (gt *GRPCTransport) Hello(version string, features []string) (*HelloResult, error) {
	if !gt.client.IsConnected() {
		return nil, fmt.Errorf("not connected")
	}

	gt.logger.Debug("Sending gRPC Hello request", "version", version, "features", features)

	// Create gRPC client
	client := proto.NewControlServiceClient(gt.client.GetConnection())

	// Create request
	req := &proto.HelloRequest{
		Version:   version,
		Features:  features,
		ClientId:  "client-id",
		Timestamp: timestampNow(),
	}

	// Make gRPC call with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	resp, err := client.Hello(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("gRPC Hello failed: %w", err)
	}

	// Convert response
	result := &HelloResult{
		Status:            resp.Status,
		ServerVersion:     resp.ServerVersion,
		SupportedFeatures: resp.SupportedFeatures,
		SessionID:         resp.SessionId,
		ErrorMessage:      resp.ErrorMessage,
	}

	gt.logger.Info("gRPC Hello completed", "status", result.Status, "session_id", result.SessionID)
	return result, nil
}

// Authenticate performs authentication
func (gt *GRPCTransport) Authenticate(token string) (*AuthResult, error) {
	if !gt.client.IsConnected() {
		return nil, fmt.Errorf("not connected")
	}

	gt.logger.Debug("Sending gRPC Auth request")

	// Create gRPC client
	client := proto.NewControlServiceClient(gt.client.GetConnection())

	// Create request
	req := &proto.AuthRequest{
		Token:     token,
		AuthType:  "jwt",
		ClientId:  "client-id",
		Timestamp: timestampNow(),
	}

	// Make gRPC call with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	resp, err := client.Authenticate(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("gRPC Authenticate failed: %w", err)
	}

	// Convert response
	result := &AuthResult{
		Status:       resp.Status,
		ClientID:     resp.ClientId,
		TenantID:     resp.TenantId,
		SessionToken: resp.SessionToken,
		ExpiresAt:    resp.ExpiresAt.AsTime(),
		ErrorMessage: resp.ErrorMessage,
	}

	gt.logger.Info("gRPC Authentication completed", "status", result.Status, "client_id", result.ClientID)
	return result, nil
}

// CreateTunnel creates a new tunnel
func (gt *GRPCTransport) CreateTunnel(tunnelID, tenantID string, localPort int, remoteHost string, remotePort int) (*TunnelResult, error) {
	if !gt.client.IsConnected() {
		return nil, fmt.Errorf("not connected")
	}

	gt.logger.Debug("Sending gRPC CreateTunnel request",
		"tunnel_id", tunnelID,
		"tenant_id", tenantID,
		"local_port", localPort,
		"remote_host", remoteHost,
		"remote_port", remotePort)

	// Create gRPC client
	client := proto.NewTunnelServiceClient(gt.client.GetConnection())

	// Create request
	req := &proto.CreateTunnelRequest{
		TunnelId:   tunnelID,
		TenantId:   tenantID,
		LocalPort:  int32(localPort),
		RemoteHost: remoteHost,
		RemotePort: int32(remotePort),
		Config: &proto.TunnelConfig{
			BufferSize:         4096,
			MaxBuffers:         100,
			TimeoutSeconds:     30,
			CompressionEnabled: false,
			EncryptionEnabled:  true,
		},
		Timestamp: timestampNow(),
	}

	// Make gRPC call with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	resp, err := client.CreateTunnel(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("gRPC CreateTunnel failed: %w", err)
	}

	// Convert response
	result := &TunnelResult{
		Status:       resp.Status,
		TunnelID:     resp.TunnelId,
		Endpoint:     resp.Endpoint,
		ErrorMessage: resp.ErrorMessage,
	}

	gt.logger.Info("gRPC Tunnel created", "status", result.Status, "tunnel_id", result.TunnelID)
	return result, nil
}

// SendHeartbeat sends a heartbeat
func (gt *GRPCTransport) SendHeartbeat(clientID, tenantID string, metrics *ClientMetrics) (*HeartbeatResult, error) {
	if !gt.client.IsConnected() {
		return nil, fmt.Errorf("not connected")
	}

	gt.logger.Debug("Sending gRPC Heartbeat", "client_id", clientID, "tenant_id", tenantID)

	// Create gRPC client
	client := proto.NewHeartbeatServiceClient(gt.client.GetConnection())

	// Convert metrics
	var protoMetrics *proto.ClientMetrics
	if metrics != nil {
		protoMetrics = &proto.ClientMetrics{
			BytesSent:         metrics.BytesSent,
			BytesReceived:     metrics.BytesReceived,
			PacketsSent:       metrics.PacketsSent,
			PacketsReceived:   metrics.PacketsReceived,
			ActiveTunnels:     metrics.ActiveTunnels,
			ActiveP2pSessions: metrics.ActiveP2PSessions,
			CpuUsage:          metrics.CPUUsage,
			MemoryUsage:       metrics.MemoryUsage,
			TransportMode:     metrics.TransportMode,
			LastSwitch:        timestampFromTime(metrics.LastSwitch),
		}
	}

	// Create request
	req := &proto.HeartbeatRequest{
		ClientId:      clientID,
		TenantId:      tenantID,
		Timestamp:     timestampNow(),
		Metrics:       protoMetrics,
		TransportMode: "grpc",
	}

	// Make gRPC call with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resp, err := client.SendHeartbeat(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("gRPC SendHeartbeat failed: %w", err)
	}

	// Convert response
	result := &HeartbeatResult{
		Status:          resp.Status,
		ServerTimestamp: resp.ServerTimestamp.AsTime(),
		IntervalSeconds: resp.IntervalSeconds,
		ErrorMessage:    resp.ErrorMessage,
	}

	gt.logger.Debug("gRPC Heartbeat completed", "status", result.Status)
	return result, nil
}

// IsConnected returns connection status
func (gt *GRPCTransport) IsConnected() bool {
	return gt.client.IsConnected()
}

// Close closes the transport and cleans up resources
func (gt *GRPCTransport) Close() error {
	return gt.client.Close()
}

// GetClient returns the underlying gRPC client
func (gt *GRPCTransport) GetClient() *GRPCClient {
	return gt.client
}

// Utility functions for timestamp conversion

func timestampNow() *proto.Timestamp {
	now := time.Now()
	return &proto.Timestamp{
		Seconds: now.Unix(),
		Nanos:   int32(now.Nanosecond()),
	}
}

func timestampFromTime(t time.Time) *proto.Timestamp {
	if t.IsZero() {
		return nil
	}
	return &proto.Timestamp{
		Seconds: t.Unix(),
		Nanos:   int32(t.Nanosecond()),
	}
}

// Note: In a real implementation, you would generate the proto files using protoc:
//
// protoc --go_out=. --go_opt=paths=source_relative \
//        --go-grpc_out=. --go-grpc_opt=paths=source_relative \
//        pkg/relay/transport/proto/*.proto
//
// This would generate the following files:
// - pkg/relay/transport/proto/control.pb.go
// - pkg/relay/transport/proto/control_grpc.pb.go
// - pkg/relay/transport/proto/tunnel.pb.go
// - pkg/relay/transport/proto/tunnel_grpc.pb.go
// - pkg/relay/transport/proto/heartbeat.pb.go
// - pkg/relay/transport/proto/heartbeat_grpc.pb.go
//
// Then you would import and use the generated client stubs:
// import pb "github.com/2gc-dev/cloudbridge-client/pkg/relay/transport/proto"
//
// And replace the mock implementations above with real gRPC calls
