#!/bin/bash
# CloudBridge Client WireGuard Setup Script for Linux
# This script sets up WireGuard prerequisites for CloudBridge fallback functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_info "Running as root - full WireGuard setup available"
        return 0
    else
        log_warn "Not running as root - some features may be limited"
        return 1
    fi
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    log_info "Detected distribution: $DISTRO $VERSION"
}

# Install WireGuard tools
install_wireguard() {
    log_info "Installing WireGuard tools..."
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y wireguard-tools iproute2 iptables
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y wireguard-tools iproute iptables
            else
                yum install -y wireguard-tools iproute iptables
            fi
            ;;
        arch)
            pacman -Sy --noconfirm wireguard-tools iproute2 iptables
            ;;
        *)
            log_error "Unsupported distribution: $DISTRO"
            log_info "Please install wireguard-tools, iproute2, and iptables manually"
            exit 1
            ;;
    esac
    
    log_info "WireGuard tools installed successfully"
}

# Check WireGuard kernel module
check_kernel_module() {
    log_info "Checking WireGuard kernel support..."
    
    if modinfo wireguard &> /dev/null; then
        log_info "WireGuard kernel module is available"
        
        # Try to load the module
        if modprobe wireguard 2>/dev/null; then
            log_info "WireGuard kernel module loaded successfully"
        else
            log_warn "Failed to load WireGuard kernel module"
            log_info "WireGuard will use userspace implementation (slower)"
        fi
    else
        log_warn "WireGuard kernel module not found"
        log_info "WireGuard will use userspace implementation"
    fi
}

# Set up capabilities for non-root usage
setup_capabilities() {
    log_info "Setting up capabilities for non-root WireGuard usage..."
    
    # Find cloudbridge-client binary
    BINARY_PATH=""
    if [[ -f "./cloudbridge-client" ]]; then
        BINARY_PATH="./cloudbridge-client"
    elif [[ -f "./cloudbridge-client-enhanced" ]]; then
        BINARY_PATH="./cloudbridge-client-enhanced"
    elif command -v cloudbridge-client &> /dev/null; then
        BINARY_PATH=$(which cloudbridge-client)
    else
        log_warn "CloudBridge client binary not found"
        log_info "You'll need to set capabilities manually after building:"
        log_info "  sudo setcap cap_net_admin+ep /path/to/cloudbridge-client"
        return
    fi
    
    log_info "Setting CAP_NET_ADMIN capability on $BINARY_PATH"
    setcap cap_net_admin+ep "$BINARY_PATH"
    
    # Verify capabilities
    if getcap "$BINARY_PATH" | grep -q cap_net_admin; then
        log_info "Capabilities set successfully"
    else
        log_error "Failed to set capabilities"
    fi
}

# Configure iptables for WireGuard
setup_iptables() {
    log_info "Configuring iptables for WireGuard..."
    
    # Allow WireGuard traffic
    iptables -A INPUT -p udp --dport 51820 -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -i wg+ -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -o wg+ -j ACCEPT 2>/dev/null || true
    
    # Enable IP forwarding
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-wireguard.conf
    sysctl -p /etc/sysctl.d/99-wireguard.conf
    
    log_info "iptables rules configured"
}

# Test WireGuard functionality
test_wireguard() {
    log_info "Testing WireGuard functionality..."
    
    # Test wg command
    if command -v wg &> /dev/null; then
        log_info "✓ wg command available"
    else
        log_error "✗ wg command not found"
        return 1
    fi
    
    # Test ip command
    if command -v ip &> /dev/null; then
        log_info "✓ ip command available"
    else
        log_error "✗ ip command not found"
        return 1
    fi
    
    # Test interface creation (requires root)
    if [[ $EUID -eq 0 ]]; then
        TEST_INTERFACE="wg-test-$$"
        if ip link add dev "$TEST_INTERFACE" type wireguard 2>/dev/null; then
            log_info "✓ WireGuard interface creation works"
            ip link del dev "$TEST_INTERFACE" 2>/dev/null || true
        else
            log_warn "✗ WireGuard interface creation failed"
            log_info "This may work with proper capabilities or kernel module"
        fi
    else
        log_info "Skipping interface test (requires root)"
    fi
    
    log_info "WireGuard test completed"
}

# Print usage information
print_usage() {
    log_info "WireGuard setup completed!"
    echo
    echo "Usage with CloudBridge Client:"
    echo "  1. Enable WireGuard in config:"
    echo "     wireguard:"
    echo "       enabled: true"
    echo "       interface_name: \"wg-cloudbridge\""
    echo "       port: 51820"
    echo
    echo "  2. Run client with WireGuard fallback:"
    echo "     ./cloudbridge-client --config config.yaml"
    echo
    echo "  3. Test UDP blocking (in another terminal):"
    echo "     sudo iptables -A OUTPUT -p udp --dport 8443 -j DROP"
    echo "     # Watch logs for 'SwitchedToWG' message"
    echo "     sudo iptables -D OUTPUT -p udp --dport 8443 -j DROP"
    echo
    echo "Troubleshooting:"
    echo "  - If permission denied: run as root or set capabilities"
    echo "  - If module not found: install wireguard-dkms package"
    echo "  - Check logs: journalctl -f | grep wireguard"
}

# Main execution
main() {
    log_info "CloudBridge WireGuard Setup Script"
    log_info "=================================="
    
    IS_ROOT=false
    if check_root; then
        IS_ROOT=true
    fi
    
    detect_distro
    
    if [[ "$IS_ROOT" == "true" ]]; then
        install_wireguard
        check_kernel_module
        setup_iptables
        setup_capabilities
    else
        log_warn "Running without root privileges"
        log_info "Please install WireGuard tools manually:"
        log_info "  Ubuntu/Debian: sudo apt install wireguard-tools"
        log_info "  CentOS/RHEL:   sudo yum install wireguard-tools"
        log_info "  Fedora:        sudo dnf install wireguard-tools"
        log_info "  Arch:          sudo pacman -S wireguard-tools"
    fi
    
    test_wireguard
    print_usage
    
    log_info "Setup complete! WireGuard fallback is ready."
}

# Run main function
main "$@"
