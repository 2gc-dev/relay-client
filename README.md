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
   # P2P mesh mode
   ./cloudbridge-client p2p --config config.yaml --server-id my-server-001
   
   # Tunnel mode
   ./cloudbridge-client tunnel --config config.yaml --local-port 3389 --remote-host target.com --remote-port 3389
   ```

## Configuration Files

- `config-example.yaml` - Configuration template
- `config-production.yaml` - Production template for edge.2gc.ru
- `config.yaml` - Your configuration (create from example)

## Transport Protocols

- **QUIC** - Primary high-performance transport
- **WebSocket** - Fallback for restricted networks
- **gRPC** - API communication
- **WireGuard** - Legacy VPN support

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