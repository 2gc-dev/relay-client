# CloudBridge Client

CloudBridge Client is a production-ready relay client for establishing secure tunnel connections through CloudBridge Relay servers. Built with Go, it provides enterprise-grade security, reliability, and performance for network tunneling applications.

## Overview

CloudBridge Client enables secure communication between local services and remote endpoints through encrypted relay connections. The client supports multiple operational modes including direct tunneling, P2P mesh networking, and service management capabilities.

### Key Features

- **Secure Communication**: TLS 1.3 encryption for all connections
- **JWT Authentication**: Token-based authentication with fallback secret support
- **P2P Mesh Networking**: WireGuard-based peer-to-peer mesh capabilities
- **Service Management**: Systemd and Windows service integration
- **Cross-Platform**: Support for Linux, macOS, and Windows (amd64/arm64)
- **Metrics Integration**: Prometheus metrics for monitoring and observability
- **Retry Logic**: Built-in resilience with configurable retry strategies

## Architecture

The CloudBridge Client operates as a secure relay client that establishes encrypted connections to CloudBridge Relay servers. The client supports multiple operational modes:

### Tunnel Mode
Direct port forwarding through the relay server to remote endpoints. Ideal for accessing remote services securely.

### P2P Mesh Mode
Peer-to-peer networking using WireGuard technology. Enables direct communication between clients in a mesh network.

### Service Mode
System service integration for automated deployment and management in production environments.

## How It Works

1. **Connection Establishment**: Client connects to the configured CloudBridge Relay server using TLS 1.3
2. **Authentication**: JWT token validation with the relay server
3. **Tunnel Creation**: Establishes encrypted tunnel for data transmission
4. **Data Forwarding**: Secure forwarding of network traffic between local and remote endpoints
5. **Heartbeat Monitoring**: Continuous health monitoring and automatic reconnection

## Building

### Prerequisites

- Go 1.25 or later
- Git

### Build Instructions

#### Using Make (Recommended)

```bash
# Clone the repository
git clone https://github.com/2gc-dev/relay-client.git
cd relay-client

# Build the application
make build

# The binary will be available as ./cloudbridge-client
```

#### Manual Build

```bash
# Clone the repository
git clone https://github.com/2gc-dev/relay-client.git
cd relay-client

# Download dependencies
go mod download

# Build the application
go build -o cloudbridge-client ./cmd/cloudbridge-client
```

#### Cross-Platform Builds

```bash
# Build for multiple platforms
make build-all

# Or build for specific platform
GOOS=linux GOARCH=amd64 go build -o cloudbridge-client-linux-amd64 ./cmd/cloudbridge-client
GOOS=windows GOARCH=amd64 go build -o cloudbridge-client-windows-amd64.exe ./cmd/cloudbridge-client
GOOS=darwin GOARCH=arm64 go build -o cloudbridge-client-darwin-arm64 ./cmd/cloudbridge-client
```

### Docker Build

```bash
# Build Docker image
docker build -t cloudbridge-client .

# Run container
docker run -v $(pwd)/config.yaml:/app/config.yaml cloudbridge-client
```

## Configuration

The client uses YAML configuration files. Create a `config.yaml` file with the following structure:

```yaml
relay:
  host: "relay.example.com"
  port: 443
  tls:
    enabled: true
    insecure_skip_verify: false

auth:
  secret: "your-jwt-secret-key"
  fallback_secret: "fallback-secret-key"

tunnel:
  remote_host: "target.example.com"
  remote_port: 3389

p2p:
  enabled: false
  mesh_port: 51820

metrics:
  enabled: true
  port: 9090
  path: "/metrics"

logging:
  level: "info"
  format: "json"
```

## Usage

### Basic Tunnel Mode

```bash
./cloudbridge-client --config config.yaml --token "your-jwt-token" \
  --tunnel-id "tunnel_001" \
  --local-port 3389 \
  --remote-host "192.168.1.100" \
  --remote-port 3389
```

### P2P Mesh Mode

```bash
./cloudbridge-client p2p --config config.yaml --token "your-jwt-token" \
  --peer-id "peer_001" \
  --endpoint "10.0.0.1:51820" \
  --public-key "public-key" \
  --private-key "private-key"
```

### Service Management

```bash
# Install as system service
./cloudbridge-client service install --config config.yaml --token "your-jwt-token"

# Start service
./cloudbridge-client service start

# Check status
./cloudbridge-client service status

# Stop service
./cloudbridge-client service stop
```

## Development

### Running Tests

```bash
# Run all tests
go test ./...

# Run tests with race detection
go test -race ./...

# Run tests with coverage
go test -cover ./...

# Run integration tests
go test -tags=integration ./...
```

### Code Quality

```bash
# Run linter
golangci-lint run

# Format code
go fmt ./...

# Run security scan
gosec ./...

# Check for vulnerabilities
govulncheck ./...
```

### Building for Development

```bash
# Build with debug information
go build -gcflags="all=-N -l" -o cloudbridge-client ./cmd/cloudbridge-client

# Build with race detector
go build -race -o cloudbridge-client ./cmd/cloudbridge-client
```

## Deployment

### Production Deployment

1. **Build the application**:
   ```bash
   make build
   ```

2. **Configure the service**:
   ```bash
   cp config-production.yaml config.yaml
   # Edit config.yaml with production settings
   ```

3. **Install as service**:
   ```bash
   sudo ./cloudbridge-client service install --config config.yaml --token "production-token"
   ```

4. **Start the service**:
   ```bash
   sudo ./cloudbridge-client service start
   ```

### Docker Deployment

```bash
# Build production image
docker build -t cloudbridge-client:latest .

# Run with production config
docker run -d \
  --name cloudbridge-client \
  -v /path/to/config.yaml:/app/config.yaml \
  -v /path/to/logs:/app/logs \
  cloudbridge-client:latest
```

## Monitoring

The client exposes Prometheus metrics on the configured port (default: 9090). Key metrics include:

- Connection status and duration
- Tunnel creation success/failure rates
- Authentication attempts and results
- Network throughput and latency
- Error rates and types

Access metrics at: `http://localhost:9090/metrics`

## Security Considerations

- All connections use TLS 1.3 encryption
- JWT tokens should be rotated regularly
- Store configuration files with appropriate permissions (600)
- Use strong, unique secrets for authentication
- Monitor logs for suspicious activity
- Keep the client updated to the latest version

## Troubleshooting

### Common Issues

1. **Connection failures**: Check network connectivity and relay server availability
2. **Authentication errors**: Verify JWT token validity and secret configuration
3. **Tunnel creation failures**: Ensure remote host is accessible and ports are available
4. **Service installation issues**: Check system permissions and service configuration

### Logging

Enable verbose logging for debugging:

```bash
./cloudbridge-client --config config.yaml --token "token" --verbose
```

Or configure in config.yaml:

```yaml
logging:
  level: "debug"
  format: "text"
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For technical support and questions:
- Create an issue in the GitHub repository
- Review the documentation and troubleshooting guide
- Check the logs for error details

---

Copyright (c) 2024 2GC Development Team. All rights reserved.