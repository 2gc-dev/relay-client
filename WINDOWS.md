# CloudBridge Client - Windows Support

This document covers Windows-specific features, setup, and troubleshooting for the CloudBridge Client.

## System Requirements

- **Windows 10** (version 1903 or later) or **Windows 11**
- **Administrator privileges** for WireGuard setup and network interface management
- **PowerShell 5.1** or later (for setup scripts)
- **WireGuard for Windows** (automatically installed by setup script)

## Quick Start

### 1. Download and Setup

```powershell
# Download the latest Windows release
# Extract cloudbridge-client-windows-amd64.exe to your desired location

# Run the setup script as Administrator
.\scripts\setup-wg-windows.ps1
```

### 2. Basic Usage

```powershell
# Check version
.\cloudbridge-client-windows-amd64.exe version

# Run with configuration file
.\cloudbridge-client-windows-amd64.exe --config config.yaml tunnel

# Enable WireGuard fallback
.\cloudbridge-client-windows-amd64.exe --config config-with-wireguard.yaml tunnel
```

## Windows-Specific Features

### WireGuard Integration

The Windows version uses the native WireGuard for Windows service:

- **Interface Management**: Uses `netsh` and WireGuard service APIs
- **Firewall Integration**: Automatically configures Windows Firewall rules
- **Service Integration**: Works with the WireGuard Windows service
- **Network Adapter**: Creates virtual network adapters for tunneling

### Privilege Management

Unlike Linux, Windows uses a different privilege model:

- **Administrator Check**: Uses Windows-specific privilege detection
- **UAC Integration**: Respects User Account Control settings
- **Service Permissions**: Can run as a Windows service with proper permissions

### Signal Handling

Windows signal handling is limited compared to Unix systems:

- **Supported Signals**: `SIGINT` (Ctrl+C), `SIGTERM`
- **Service Signals**: Proper Windows service stop/start signals
- **Console Events**: Handles console close events gracefully

## Configuration

### Windows-Specific Config Options

```yaml
# Example Windows configuration
relay:
  host: "relay.example.com"
  port: 9091
  tls:
    enabled: true
    verify_cert: true

wireguard:
  enabled: true
  interface_name: "wg-cloudbridge"  # Windows adapter name
  port: 51820
  mtu: 1420

metrics:
  pushgateway:
    enabled: true
    push_url: "http://localhost:9091/metrics"
```

### Environment Variables

```powershell
# Set custom CA certificate
$env:CLOUDBRIDGE_CA = "C:\certs\custom-ca.pem"

# Set log level
$env:CLOUDBRIDGE_LOG_LEVEL = "debug"

# Set config path
$env:CLOUDBRIDGE_CONFIG = "C:\config\cloudbridge.yaml"
```

## WireGuard Setup Details

### Automatic Setup

The `setup-wg-windows.ps1` script performs:

1. **Downloads WireGuard**: Gets the latest WireGuard for Windows installer
2. **Installs Silently**: Runs installer with `/S` flag for unattended installation
3. **Configures PATH**: Adds WireGuard tools to system PATH
4. **Firewall Rules**: Creates Windows Firewall rules for UDP port 51820
5. **Validation**: Tests WireGuard tools availability

### Manual Setup

If you prefer manual installation:

```powershell
# 1. Download WireGuard for Windows
Invoke-WebRequest -Uri "https://download.wireguard.com/windows-client/wireguard-installer.exe" -OutFile "wireguard-installer.exe"

# 2. Install as Administrator
Start-Process -FilePath "wireguard-installer.exe" -ArgumentList "/S" -Wait

# 3. Add to PATH
$env:PATH += ";C:\Program Files\WireGuard"

# 4. Configure firewall
New-NetFirewallRule -DisplayName "CloudBridge WireGuard" -Direction Inbound -Protocol UDP -LocalPort 51820 -Action Allow
```

## Building from Source

### Prerequisites

```powershell
# Install Go 1.21 or later
# Download from https://golang.org/dl/

# Verify installation
go version
```

### Build Commands

```powershell
# Build for Windows AMD64
$env:GOOS = "windows"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "0"
go build -o cloudbridge-client.exe ./cmd/cloudbridge-client

# Or use Makefile (if you have make installed)
make build-windows-amd64
```

### Cross-Compilation from Linux/macOS

```bash
# Build Windows binary from Linux/macOS
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o cloudbridge-client.exe ./cmd/cloudbridge-client
```

## Troubleshooting

### Common Issues

#### 1. WireGuard Not Found

```
Error: WireGuard for Windows not found
```

**Solution:**
```powershell
# Check if WireGuard is installed
Get-Command wg.exe -ErrorAction SilentlyContinue

# If not found, run setup script
.\scripts\setup-wg-windows.ps1

# Or add to PATH manually
$env:PATH += ";C:\Program Files\WireGuard"
```

#### 2. Permission Denied

```
Error: Access denied creating network interface
```

**Solution:**
```powershell
# Run as Administrator
# Right-click PowerShell -> "Run as Administrator"

# Or check current privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Running as Administrator: $isAdmin"
```

#### 3. Firewall Blocking

```
Error: Connection timeout / UDP blocked
```

**Solution:**
```powershell
# Check Windows Firewall rules
Get-NetFirewallRule -DisplayName "*CloudBridge*"

# Add firewall rule manually
New-NetFirewallRule -DisplayName "CloudBridge WireGuard" -Direction Inbound -Protocol UDP -LocalPort 51820 -Action Allow
New-NetFirewallRule -DisplayName "CloudBridge QUIC" -Direction Inbound -Protocol UDP -LocalPort 8443 -Action Allow
```

#### 4. Service Issues

```
Error: WireGuard service not running
```

**Solution:**
```powershell
# Check WireGuard service status
Get-Service WireGuardManager

# Start service if stopped
Start-Service WireGuardManager

# Restart service
Restart-Service WireGuardManager
```

### Debug Mode

Enable debug logging for troubleshooting:

```powershell
# Run with debug logging
.\cloudbridge-client.exe --log-level debug --config config.yaml tunnel

# Or set environment variable
$env:CLOUDBRIDGE_LOG_LEVEL = "debug"
.\cloudbridge-client.exe --config config.yaml tunnel
```

### Network Diagnostics

```powershell
# Test UDP connectivity
Test-NetConnection -ComputerName relay.example.com -Port 8443 -InformationLevel Detailed

# Check network interfaces
Get-NetAdapter | Where-Object {$_.Name -like "*WireGuard*"}

# Check routing table
Get-NetRoute | Where-Object {$_.InterfaceAlias -like "*WireGuard*"}

# Test WireGuard interface
wg.exe show
```

## Windows Service Installation

To run CloudBridge Client as a Windows service:

```powershell
# Install as service (requires NSSM - Non-Sucking Service Manager)
# Download NSSM from https://nssm.cc/

# Install service
nssm install CloudBridgeClient "C:\path\to\cloudbridge-client.exe"
nssm set CloudBridgeClient AppParameters "--config C:\config\cloudbridge.yaml service"
nssm set CloudBridgeClient DisplayName "CloudBridge Client"
nssm set CloudBridgeClient Description "CloudBridge Relay Client Service"
nssm set CloudBridgeClient Start SERVICE_AUTO_START

# Start service
nssm start CloudBridgeClient

# Check service status
nssm status CloudBridgeClient
```

## Performance Considerations

### Windows-Specific Optimizations

1. **Network Buffer Sizes**: Windows has different default buffer sizes
2. **Thread Scheduling**: Windows thread scheduler behaves differently
3. **Memory Management**: Windows memory management patterns
4. **Antivirus Exclusions**: Add CloudBridge to antivirus exclusions

### Recommended Settings

```yaml
performance:
  enabled: true
  optimization_mode: "balanced"  # Windows works well with balanced mode
  gc_percent: 100
  memory_ballast: true

wireguard:
  mtu: 1420  # Recommended for Windows
  persistent_keepalive: 25  # Helps with Windows NAT
```

## Security Considerations

### Windows Defender

Add CloudBridge to Windows Defender exclusions:

```powershell
# Add executable to exclusions
Add-MpPreference -ExclusionPath "C:\path\to\cloudbridge-client.exe"

# Add config directory to exclusions
Add-MpPreference -ExclusionPath "C:\config\"
```

### Network Security

- **Windows Firewall**: Properly configure inbound/outbound rules
- **Network Isolation**: Use Windows network isolation features
- **Certificate Store**: Integrate with Windows certificate store for TLS

## Support and Resources

- **GitHub Issues**: Report Windows-specific issues with `[Windows]` tag
- **Documentation**: This file and main README.md
- **WireGuard Windows**: https://www.wireguard.com/install/
- **PowerShell Help**: `Get-Help about_*` for PowerShell topics

## Version History

- **v1.0.0**: Initial Windows support with WireGuard integration
- **v1.1.0**: Added Windows service support and improved privilege handling
- **v1.2.0**: Enhanced firewall integration and setup automation
