# CloudBridge Client WireGuard Setup Script for Windows
# This script sets up WireGuard prerequisites for CloudBridge fallback functionality

param(
    [switch]$Force,
    [switch]$Quiet,
    [string]$InstallPath = "$env:ProgramFiles\WireGuard"
)

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output (if supported)
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Reset = "`e[0m"

# Logging functions
function Write-Info {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "${Green}[INFO]${Reset} $Message" -ForegroundColor Green
    }
}

function Write-Warn {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "${Yellow}[WARN]${Reset} $Message" -ForegroundColor Yellow
    }
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "${Red}[ERROR]${Reset} $Message" -ForegroundColor Red
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Download file with progress
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    Write-Info "Downloading from $Url..."
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        Write-Info "Download completed: $OutputPath"
    }
    catch {
        throw "Failed to download file: $_"
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

# Check if WireGuard is installed
function Test-WireGuardInstalled {
    $wgPath = Get-Command "wg.exe" -ErrorAction SilentlyContinue
    if ($wgPath) {
        Write-Info "WireGuard found at: $($wgPath.Source)"
        return $true
    }
    
    # Check common installation paths
    $commonPaths = @(
        "$env:ProgramFiles\WireGuard\wg.exe",
        "$env:ProgramFiles(x86)\WireGuard\wg.exe",
        "$env:LOCALAPPDATA\WireGuard\wg.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Info "WireGuard found at: $path"
            return $true
        }
    }
    
    return $false
}

# Install WireGuard for Windows
function Install-WireGuard {
    Write-Info "Installing WireGuard for Windows..."
    
    # Check if already installed
    if (Test-WireGuardInstalled -and -not $Force) {
        Write-Info "WireGuard is already installed. Use -Force to reinstall."
        return
    }
    
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "wireguard-setup"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    
    try {
        # Download WireGuard installer
        $installerUrl = "https://download.wireguard.com/windows-client/wireguard-installer.exe"
        $installerPath = Join-Path $tempDir "wireguard-installer.exe"
        
        Download-File -Url $installerUrl -OutputPath $installerPath
        
        # Run installer silently
        Write-Info "Running WireGuard installer..."
        $process = Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Info "WireGuard installed successfully"
        }
        else {
            throw "WireGuard installer failed with exit code: $($process.ExitCode)"
        }
    }
    finally {
        # Clean up temporary files
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Configure Windows Firewall for WireGuard
function Configure-Firewall {
    Write-Info "Configuring Windows Firewall for WireGuard..."
    
    try {
        # Allow WireGuard through Windows Firewall
        $ruleName = "CloudBridge WireGuard"
        
        # Remove existing rule if it exists
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if ($existingRule) {
            Remove-NetFirewallRule -DisplayName $ruleName
            Write-Info "Removed existing firewall rule"
        }
        
        # Create new firewall rule for WireGuard
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol UDP -LocalPort 51820 -Action Allow | Out-Null
        New-NetFirewallRule -DisplayName "$ruleName Outbound" -Direction Outbound -Protocol UDP -LocalPort 51820 -Action Allow | Out-Null
        
        Write-Info "Firewall rules configured for WireGuard (UDP port 51820)"
    }
    catch {
        Write-Warn "Failed to configure firewall: $_"
        Write-Info "You may need to manually configure Windows Firewall to allow WireGuard traffic"
    }
}

# Test WireGuard functionality
function Test-WireGuard {
    Write-Info "Testing WireGuard functionality..."
    
    # Test wg.exe command
    try {
        $wgVersion = & wg.exe --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✓ wg.exe command available: $wgVersion"
        }
        else {
            Write-Error-Custom "✗ wg.exe command failed"
            return $false
        }
    }
    catch {
        Write-Error-Custom "✗ wg.exe command not found"
        return $false
    }
    
    # Test wg-quick.exe command
    try {
        & wg-quick.exe --help >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✓ wg-quick.exe command available"
        }
        else {
            Write-Warn "✗ wg-quick.exe command failed (may not be critical)"
        }
    }
    catch {
        Write-Warn "✗ wg-quick.exe command not found (may not be critical)"
    }
    
    Write-Info "WireGuard test completed"
    return $true
}

# Set up PATH environment variable
function Update-Path {
    Write-Info "Updating PATH environment variable..."
    
    $wireguardPath = "$env:ProgramFiles\WireGuard"
    if (Test-Path $wireguardPath) {
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($currentPath -notlike "*$wireguardPath*") {
            $newPath = "$currentPath;$wireguardPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
            Write-Info "Added WireGuard to system PATH"
            
            # Update current session PATH
            $env:PATH += ";$wireguardPath"
        }
        else {
            Write-Info "WireGuard already in system PATH"
        }
    }
}

# Print usage information
function Show-Usage {
    Write-Info "WireGuard setup completed!"
    Write-Host ""
    Write-Host "Usage with CloudBridge Client:"
    Write-Host "  1. Enable WireGuard in config:"
    Write-Host "     wireguard:"
    Write-Host "       enabled: true"
    Write-Host "       interface_name: `"wg-cloudbridge`""
    Write-Host "       port: 51820"
    Write-Host ""
    Write-Host "  2. Run client with WireGuard fallback:"
    Write-Host "     .\cloudbridge-client.exe --config config.yaml"
    Write-Host ""
    Write-Host "  3. Test UDP blocking (in Administrator PowerShell):"
    Write-Host "     netsh advfirewall firewall add rule name=`"Block UDP 8443`" dir=out action=block protocol=UDP localport=8443"
    Write-Host "     # Watch logs for 'SwitchedToWG' message"
    Write-Host "     netsh advfirewall firewall delete rule name=`"Block UDP 8443`""
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  - If permission denied: run as Administrator"
    Write-Host "  - If WireGuard service issues: restart WireGuard service"
    Write-Host "  - Check Windows Event Viewer for WireGuard logs"
    Write-Host "  - Verify Windows Firewall allows WireGuard traffic"
}

# Main execution
function Main {
    Write-Info "CloudBridge WireGuard Setup Script for Windows"
    Write-Info "=============================================="
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        Write-Error-Custom "This script must be run as Administrator"
        Write-Info "Please run PowerShell as Administrator and try again"
        exit 1
    }
    
    try {
        # Install WireGuard
        Install-WireGuard
        
        # Update PATH
        Update-Path
        
        # Configure firewall
        Configure-Firewall
        
        # Test installation
        if (Test-WireGuard) {
            Write-Info "WireGuard setup successful!"
        }
        else {
            Write-Error-Custom "WireGuard setup failed validation"
            exit 1
        }
        
        # Show usage information
        Show-Usage
        
        Write-Info "Setup complete! WireGuard fallback is ready for CloudBridge Client."
    }
    catch {
        Write-Error-Custom "Setup failed: $_"
        exit 1
    }
}

# Run main function
Main
