#!/bin/bash

# Скрипт для создания Windows установщика

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Параметры
PACKAGE_DIR="$1"
if [[ -z "$PACKAGE_DIR" ]]; then
    log_error "Usage: $0 <package-directory>"
    exit 1
fi

log_info "Creating Windows installer for: $PACKAGE_DIR"

# Создание install.bat для Windows
cat > "$PACKAGE_DIR/install.bat" << 'EOF'
@echo off
setlocal enabledelayedexpansion

echo 🚀 Installing CloudBridge Client for Windows...
echo ================================================

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ Please run as Administrator
    pause
    exit /b 1
)

REM Create installation directory
set "INSTALL_DIR=C:\Program Files\CloudBridge Client"
set "CONFIG_DIR=%APPDATA%\CloudBridge Client"

echo 📁 Creating directories...
mkdir "%INSTALL_DIR%" 2>nul
mkdir "%CONFIG_DIR%" 2>nul

echo 📦 Installing files...
copy "cloudbridge-client.exe" "%INSTALL_DIR%\" >nul
copy "config.yaml" "%CONFIG_DIR%\" >nul

echo 🔧 Creating Windows Service...
sc create "CloudBridge Client" binPath="\"%INSTALL_DIR%\cloudbridge-client.exe\" p2p --config \"%CONFIG_DIR%\config.yaml\"" start=auto >nul 2>&1

echo 🔗 Adding to PATH...
setx PATH "%PATH%;%INSTALL_DIR%" /M >nul 2>&1

echo ✅ CloudBridge Client installed successfully!
echo ================================================
echo Installation directory: %INSTALL_DIR%
echo Configuration: %CONFIG_DIR%\config.yaml
echo ================================================
echo.
echo Next steps:
echo 1. Edit configuration: notepad "%CONFIG_DIR%\config.yaml"
echo 2. Add your JWT token and secrets
echo 3. Test: "%INSTALL_DIR%\cloudbridge-client.exe" version
echo 4. Start service: sc start "CloudBridge Client"
echo.
echo Service commands:
echo   Start:   sc start "CloudBridge Client"
echo   Stop:    sc stop "CloudBridge Client"
echo   Status:  sc query "CloudBridge Client"
echo   Remove:  sc delete "CloudBridge Client"
echo.
pause
EOF

# Создание uninstall.bat
cat > "$PACKAGE_DIR/uninstall.bat" << 'EOF'
@echo off
setlocal enabledelayedexpansion

echo 🗑️ Uninstalling CloudBridge Client...
echo =====================================

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ Please run as Administrator
    pause
    exit /b 1
)

echo 🛑 Stopping service...
sc stop "CloudBridge Client" >nul 2>&1

echo 🗑️ Removing service...
sc delete "CloudBridge Client" >nul 2>&1

echo 📁 Removing files...
set "INSTALL_DIR=C:\Program Files\CloudBridge Client"
set "CONFIG_DIR=%APPDATA%\CloudBridge Client"

rmdir /s /q "%INSTALL_DIR%" 2>nul
rmdir /s /q "%CONFIG_DIR%" 2>nul

echo ✅ CloudBridge Client uninstalled successfully!
echo ================================================
echo.
pause
EOF

# Создание README для Windows
cat > "$PACKAGE_DIR/README-Windows.md" << 'EOF'
# CloudBridge Client for Windows

## 🚀 Quick Installation

1. **Run as Administrator:**
   - Right-click on `install.bat`
   - Select "Run as administrator"

2. **Configure:**
   - Edit configuration: `%APPDATA%\CloudBridge Client\config.yaml`
   - Add your JWT token and secrets

3. **Test:**
   ```cmd
   "C:\Program Files\CloudBridge Client\cloudbridge-client.exe" version
   ```

4. **Start Service:**
   ```cmd
   sc start "CloudBridge Client"
   ```

## 🔧 Configuration

Edit the configuration file:
```
%APPDATA%\CloudBridge Client\config.yaml
```

Add your JWT token and secrets:
```yaml
auth:
  type: "jwt"
  secret: "YOUR_JWT_SECRET_HERE"

api:
  base_url: "https://edge.2gc.ru:30082"
  insecure_skip_verify: true
```

## 🚀 Usage

### Command Line
```cmd
# Check version
"C:\Program Files\CloudBridge Client\cloudbridge-client.exe" version

# Start P2P mode
"C:\Program Files\CloudBridge Client\cloudbridge-client.exe" p2p --token YOUR_TOKEN --config "%APPDATA%\CloudBridge Client\config.yaml"
```

### Windows Service
```cmd
# Start service
sc start "CloudBridge Client"

# Stop service
sc stop "CloudBridge Client"

# Check status
sc query "CloudBridge Client"

# View logs
eventvwr.msc
```

## 🗑️ Uninstallation

1. **Run as Administrator:**
   - Right-click on `uninstall.bat`
   - Select "Run as administrator"

## 📚 Documentation

- [Quick Start Guide](https://github.com/2gc-dev/relay-client/blob/main/QUICK_START.md)
- [Build System](https://github.com/2gc-dev/relay-client/blob/main/BUILD_SYSTEM.md)
- [Production Requirements](https://github.com/2gc-dev/relay-client/blob/main/PRODUCTION_REQUIREMENTS.md)

## 🆘 Support

**Contacts:**
- DevOps: for JWT tokens and secrets
- Developers: for code issues
- Network team: for WireGuard issues
EOF

log_success "Windows installer created successfully"
log_info "Files created:"
log_info "  - install.bat (Windows installer)"
log_info "  - uninstall.bat (Windows uninstaller)"
log_info "  - README-Windows.md (Windows documentation)"





