# CloudBridge Client Examples

This directory contains examples demonstrating the enhanced CloudBridge Client features.

## Features Implemented

### ✅ TLS Security (Task ❶)
- **TLS enabled by default** (`relay.tls.enabled=true`)
- **Custom Root-CA support** via `--ca` flag or `CLOUDBRIDGE_CA` environment variable
- **System trust-store integration** with fallback to custom CA

### ✅ WireGuard Fallback (Task ❷)
- **AutoSwitchManager** automatically switches between QUIC and WireGuard
- **Health monitoring** detects UDP port blocking and switches to WireGuard
- **Automatic recovery** switches back to QUIC when connectivity is restored
- **Unit tests** included for UDP blocking simulation

### ✅ gRPC Transport Layer (Task ❸)
- **gRPC services**: ControlService, TunnelService, HeartbeatService
- **Protocol Buffers** definitions for all services
- **Transport selection** via `--transport grpc` flag
- **JSON fallback** marked as deprecated with warnings

### ✅ Hot-Reload Configuration (Task ❹)
- **YAML watcher** using `fsnotify` for real-time config changes
- **Debounced updates** prevent excessive reloads
- **Hot-reloadable settings**: log level, TLS verify, endpoints
- **Automatic re-authentication** when credentials change

### ✅ Prometheus Pushgateway (Task ❺)
- **Required metrics**: `client_bytes_sent`, `client_bytes_recv`, `p2p_sessions`, `transport_mode`
- **Exponential backoff** for failed pushes with retry logic
- **Configurable push interval** and endpoint
- **Automatic instance detection** using hostname

## Usage Examples

### 1. Simple Tunnel with gRPC Transport

```bash
# Set your JWT token
export JWT_TOKEN="your-jwt-token-here"

# Run with gRPC transport and custom CA
./cloudbridge-client --config examples/config-with-pushgateway.yaml \
                     --transport grpc \
                     --ca /path/to/custom-ca.pem \
                     tunnel --local-port 8080 --remote-host httpbin.org --remote-port 80
```

### 2. P2P Mesh Networking

```bash
# Set your P2P JWT token
export JWT_TOKEN="your-p2p-jwt-token-here"

# Run P2P mesh mode
./cloudbridge-client --config examples/config-with-pushgateway.yaml \
                     --transport grpc \
                     p2p --peer-id my-peer-1
```

### 3. Testing WireGuard Fallback

```bash
# Start client
./cloudbridge-client --config examples/config-with-pushgateway.yaml tunnel

# In another terminal, block UDP port 8443 to trigger WireGuard fallback
sudo iptables -A OUTPUT -p udp --dport 8443 -j DROP

# Check logs for "SwitchedToWG" message

# Restore UDP connectivity
sudo iptables -D OUTPUT -p udp --dport 8443 -j DROP

# Check logs for switch back to QUIC
```

### 4. Hot-Reload Configuration

```bash
# Start client
./cloudbridge-client --config examples/config-with-pushgateway.yaml tunnel

# In another terminal, modify the config file
echo "  level: debug" >> examples/config-with-pushgateway.yaml

# Check logs for configuration reload messages
```

### 5. Pushgateway Metrics

```bash
# Start local Pushgateway
docker run -d -p 9091:9091 prom/pushgateway

# Start client with Pushgateway enabled
./cloudbridge-client --config examples/config-with-pushgateway.yaml tunnel

# Check metrics
curl http://localhost:9091/metrics | grep client_
```

## Configuration Options

### TLS Configuration
```yaml
relay:
  tls:
    enabled: true              # TLS enabled by default
    verify_cert: true          # Verify server certificates
    ca_cert: "/path/to/ca.pem" # Custom Root-CA (optional)
```

### WireGuard Configuration
```yaml
wireguard:
  enabled: true
  interface_name: "wg-cloudbridge"
  port: 51820
  mtu: 1420
  persistent_keepalive: "25s"
```

### Pushgateway Configuration
```yaml
metrics:
  pushgateway:
    enabled: true
    push_url: "http://localhost:9091"
    job_name: "cloudbridge-client"
    instance: ""                    # Auto-detected if empty
    push_interval: "30s"
```

## WireGuard Prerequisites

### Linux Setup
```bash
# Run the setup script (requires root for full setup)
sudo ./scripts/setup-wg-linux.sh

# Or install manually
sudo apt install wireguard-tools iproute2 iptables  # Ubuntu/Debian
sudo yum install wireguard-tools iproute iptables   # CentOS/RHEL
sudo dnf install wireguard-tools iproute iptables   # Fedora
sudo pacman -S wireguard-tools iproute2 iptables    # Arch

# Set capabilities for non-root usage
sudo setcap cap_net_admin+ep ./cloudbridge-client
```

### Windows Setup
```powershell
# Run the setup script (requires Administrator privileges)
.\scripts\setup-wg-windows.ps1

# Or install manually:
# 1. Download WireGuard for Windows from https://www.wireguard.com/install/
# 2. Run the installer as Administrator
# 3. Add WireGuard to PATH: C:\Program Files\WireGuard
# 4. Configure Windows Firewall to allow UDP port 51820
```

### Required Capabilities
**Linux:**
- `CAP_NET_ADMIN` - for creating/managing network interfaces
- `iptables FORWARD` rules - for routing WireGuard traffic
- Kernel module `wireguard` or userspace implementation

**Windows:**
- Administrator privileges - for network interface management
- Windows Firewall rules - for WireGuard traffic (UDP port 51820)
- WireGuard for Windows service

## Testing

### Unit Tests
```bash
# Linux/macOS - Run all tests
go test ./...

# Linux - Run WireGuard fallback tests specifically (requires root or capabilities)
sudo go test ./pkg/relay -run TestAutoSwitchManager

# Windows - Run all tests (requires Administrator PowerShell)
go test ./...

# Run with coverage (cross-platform)
go test -cover ./...

# Run mock tests (no elevated privileges required)
go test ./pkg/relay -tags=mock
```

### Windows-specific Testing
```powershell
# Test UDP blocking on Windows (Administrator PowerShell)
netsh advfirewall firewall add rule name="Block UDP 8443" dir=out action=block protocol=UDP localport=8443
# Watch logs for 'SwitchedToWG' message
netsh advfirewall firewall delete rule name="Block UDP 8443"

# Check WireGuard service status
Get-Service WireGuardManager
wg.exe show
```

### Integration Tests
```bash
# Test with Minikube relay
make test

# Test TLS connection
openssl s_client -connect b1.2gc.space:9091 -servername b1.2gc.space

# Test UDP blocking simulation
./test-udp-blocking.sh
```

## Build Requirements

- Go 1.21+
- `go vet`, `staticcheck`, `golangci-lint` for code quality
- WireGuard tools (`wg`, `ip`) for fallback functionality
- Optional: Docker for Pushgateway testing

## Code Quality

All code passes:
- `go vet`
- `staticcheck`
- `golangci-lint run`
- Unit tests with >80% coverage for new packages

## Architecture

The enhanced client follows modular design patterns:

- **Dependency Injection** for testability
- **Interface-based design** for transport abstraction
- **Observer pattern** for configuration changes
- **Strategy pattern** for transport switching
- **Unified logging** with structured output
