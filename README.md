# CloudBridge Relay Client

Cross-platform client for CloudBridge Relay P2P mesh networking.

## Quick Start

1. **Get JWT Token**: Contact your CloudBridge Relay administrator for a JWT token.

2. **Configure**: Copy `config-example.yaml` to `config.yaml` and update:
   ```yaml
   relay:
     host: "your-relay-server.com"
     port: 8081
   
   auth:
     token: "YOUR_JWT_TOKEN_HERE"
   
   p2p:
     server_id: "my-server-001"
     tenant_id: "my-organization"
   ```

3. **Run**:
   ```bash
   # P2P mesh mode with L3-overlay network
   ./cloudbridge-client p2p --config config.yaml --server-id my-server-001
   
   # Tunnel mode
   ./cloudbridge-client tunnel --config config.yaml --local-port 3389 --remote-host target.com --remote-port 3389
   
   # WireGuard L3-overlay network management
   ./cloudbridge-client wireguard config --config config.yaml --token YOUR_JWT_TOKEN
   ./cloudbridge-client wireguard status --config config.yaml --token YOUR_JWT_TOKEN
   ```

## Configuration Files

- `config-example.yaml` - Configuration template
- `config-production.yaml` - Production template for edge.2gc.ru
- `config.yaml` - Your configuration (create from example)

## Transport Protocols

- **QUIC** - Primary high-performance transport
- **WebSocket** - Fallback for restricted networks
- **gRPC** - API communication
- **WireGuard** - L3-overlay network support

## L3-overlay Network Features

- **Per-peer IPAM** - Automatic IP address allocation for each peer
- **WireGuard Integration** - Ready-to-use WireGuard configurations
- **Tenant Isolation** - Complete network isolation between tenants
- **Hybrid Architecture** - SCORE for tenant subnets, local DB for per-peer IPs
- **Event-driven Sync** - Real-time configuration updates

## Build

```bash
make build          # Current platform
make build-all      # Cross-platform
make build-windows  # Windows
```

## Requirements

- Go 1.25+
- Valid JWT token from CloudBridge Relay
- Network access to relay server

## License

See LICENSE file for details.