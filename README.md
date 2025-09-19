# CloudBridge Client

Go client for connecting to P2P mesh network through relay server with WireGuard and HTTP API support.

## Quick Start

### Option 1: Automatic Installation (Recommended)

**Linux/macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/2gc-dev/relay-client/main/install.sh | bash
```

**Windows:**
```powershell
# Download installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/2gc-dev/relay-client/main/install.sh" -OutFile "install.sh"
# Run with Git Bash or WSL
bash install.sh
```

### Option 2: Manual Download

1. **Go to [Releases](https://github.com/2gc-dev/relay-client/releases)**
2. **Download binary for your platform:**
   - Linux: `cloudbridge-client-linux-amd64`
   - Windows: `cloudbridge-client-windows-amd64.exe`
   - macOS: `cloudbridge-client-darwin-amd64` or `cloudbridge-client-darwin-arm64`

3. **Make executable (Linux/macOS):**
   ```bash
   chmod +x cloudbridge-client-linux-amd64
   sudo mv cloudbridge-client-linux-amd64 /usr/local/bin/cloudbridge-client
   ```

4. **Test installation:**
   ```bash
   cloudbridge-client version
   ```

### Option 3: Build from Source

1. **Clone repository:**
   ```bash
   git clone https://github.com/2gc-dev/relay-client.git
   cd relay-client
   ```

2. **Build client:**
   ```bash
   make build-test
   # or
   ./scripts/quick-test.sh
   ```

## Configuration

### 1. Get JWT Token
Contact DevOps team to obtain JWT token and secrets.

### 2. Create Configuration File
```bash
sudo nano /etc/cloudbridge-client/config.yaml
```

### 3. Basic Configuration
```yaml
relay:
  host: "edge.2gc.ru"
  port: 30082

auth:
  type: "jwt"
  secret: "YOUR_JWT_SECRET_HERE"

api:
  base_url: "https://edge.2gc.ru:30082"
  insecure_skip_verify: true
```

## Usage

### Check Version
```bash
cloudbridge-client version
```

### Start P2P Mode
```bash
cloudbridge-client p2p --token YOUR_JWT_TOKEN --config /etc/cloudbridge-client/config.yaml
```

### Run as Service (Linux)
```bash
sudo systemctl start cloudbridge-client
sudo systemctl status cloudbridge-client
```

## Documentation

### For Users
- **[Quick Start Guide](QUICK_START.md)** - Quick start
- **[Build System](BUILD_SYSTEM.md)** - Build system
- **[Production Requirements](PRODUCTION_REQUIREMENTS.md)** - Production requirements

### For Developers
- **[Developer Setup](DEVELOPER_SETUP.md)** - Developer setup
- **[Security Strategy](SECURITY_STRATEGY.md)** - Security strategy
- **[Production Deployment Guide](PRODUCTION_DEPLOYMENT_GUIDE.md)** - Deployment guide

## Architecture

CloudBridge Client supports two operation modes:

- **Tunnel mode**: TCP tunneling through relay server
- **P2P mode**: Relay-assisted P2P mesh networking through WireGuard

### Relay-Assisted P2P Mode

```
┌─────────────────┐    HTTPS API      ┌─────────────────┐
│   Go Client     │◄─────────────────►│  Relay Server   │
│                 │   30082/TCP       │  edge.2gc.ru    │
│  - HTTP API     │                   │                 │
│  - WireGuard    │                   │  - Registration │
│  - JWT Auth     │                   │  - Discovery    │
└─────────────────┘                   │  - Heartbeat    │
         │                            │  - Relay Routing│
         │ WireGuard through Relay    └─────────────────┘
         ▼ (relay_session_id)                    │
┌─────────────────┐                              │
│   Other Peers   │◄─────────────────────────────┘
│  (10.0.0.0/24)  │    Routing through Relay
└─────────────────┘
```

## Main Commands

```bash
# P2P mode (relay-assisted)
./cloudbridge-client p2p --token "$JWT_TOKEN" --insecure-skip-tls-verify

# Tunnel mode (legacy)
./cloudbridge-client tunnel --token "$JWT_TOKEN" --tunnel-id "test-001"

# With configuration file
./cloudbridge-client p2p --token "$JWT_TOKEN" --config config.yaml

# Help
./cloudbridge-client --help
```

## Development

### Project Structure
```
relay-client/
├── cmd/cloudbridge-client/     # CLI application
├── pkg/                        # Go packages
│   ├── api/                    # HTTP API client
│   ├── auth/                   # JWT authentication
│   ├── config/                 # Configuration
│   ├── p2p/                    # P2P mesh manager
│   └── relay/                  # Relay client
├── scripts/                    # Build scripts
└── config*.yaml               # Configuration files
```

### Testing
```bash
# Quick testing
./scripts/quick-test.sh

# Run Go tests
go test ./...

# Build and test
make build test
```

## Important Notes

1. **Port 30082** - use correct port for HTTP API
2. **Relay-assisted mode** - registration WITHOUT endpoint
3. **relay_session_id** - must be present in registration response
4. **Routing through relay** - all P2P traffic goes through server

## License

See [LICENSE](LICENSE) file for details.

## Support

For developers:
1. Study documentation in project files
2. Run `./scripts/quick-test.sh` for diagnostics
3. Create issue in repository