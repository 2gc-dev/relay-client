#!/bin/bash

# Скрипт для сборки с подстановкой конфигурации
# Использует ldflags для подстановки значений во время сборки

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

# Параметры по умолчанию
OS=""
ARCH=""
OUTPUT_DIR="dist"
VERSION="dev"
BUILD_TYPE="test"  # test, production, demo

# Функция помощи
show_help() {
    echo "Использование: $0 [OPTIONS]"
    echo ""
    echo "Опции:"
    echo "  -o, --os OS           Целевая ОС (linux, windows, darwin)"
    echo "  -a, --arch ARCH       Архитектура (amd64, arm64, 386)"
    echo "  -t, --type TYPE       Тип сборки (test, production, demo)"
    echo "  -v, --version VER     Версия (по умолчанию: dev)"
    echo "  -d, --output-dir DIR  Директория вывода (по умолчанию: dist)"
    echo "  -h, --help           Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 --os linux --arch amd64 --type test"
    echo "  $0 --os windows --arch amd64 --type production --version 1.0.0"
    echo "  $0 --os darwin --arch arm64 --type demo"
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--os)
            OS="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -d|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Неизвестный параметр: $1"
            show_help
            exit 1
            ;;
    esac
done

# Проверка обязательных параметров
if [[ -z "$OS" || -z "$ARCH" ]]; then
    log_error "Необходимо указать --os и --arch"
    show_help
    exit 1
fi

# Валидация параметров
case $BUILD_TYPE in
    test|production|demo)
        ;;
    *)
        log_error "Неверный тип сборки: $BUILD_TYPE. Допустимые: test, production, demo"
        exit 1
        ;;
esac

log_info "Начинаем сборку..."
log_info "ОС: $OS"
log_info "Архитектура: $ARCH"
log_info "Тип сборки: $BUILD_TYPE"
log_info "Версия: $VERSION"
log_info "Директория вывода: $OUTPUT_DIR"

# Создание директории вывода
mkdir -p "$OUTPUT_DIR"

# Определение расширения файла
case $OS in
    windows)
        EXT=".exe"
        ;;
    *)
        EXT=""
        ;;
esac

# Определение имени файла
BINARY_NAME="cloudbridge-client-${OS}-${ARCH}${EXT}"
OUTPUT_PATH="$OUTPUT_DIR/$BINARY_NAME"

# Настройка переменных окружения для сборки
export GOOS="$OS"
export GOARCH="$ARCH"
export CGO_ENABLED=0

# Определение значений в зависимости от типа сборки
case $BUILD_TYPE in
    test)
        JWT_SECRET="demo-secret-key-for-testing-only"
        JWT_FALLBACK_SECRET="demo-fallback-secret-for-testing-only"
        API_BASE="https://demo-api.example.com:30082"
        TENANT_ID="demo-tenant"
        WIREGUARD_PUBLIC_KEY="demo-public-key-for-testing-only"
        ;;
    production)
        JWT_SECRET="REAL_JWT_SECRET_FROM_DEVOPS"
        JWT_FALLBACK_SECRET="REAL_FALLBACK_SECRET_FROM_DEVOPS"
        API_BASE="https://edge.2gc.ru:30082"
        TENANT_ID="REAL_TENANT_ID"
        WIREGUARD_PUBLIC_KEY="REAL_WIREGUARD_PUBLIC_KEY"
        ;;
    demo)
        JWT_SECRET="demo-secret-for-demo-only"
        JWT_FALLBACK_SECRET="demo-fallback-for-demo-only"
        API_BASE="https://demo.2gc.ru:30082"
        TENANT_ID="demo-tenant"
        WIREGUARD_PUBLIC_KEY="demo-public-key"
        ;;
esac

# Сборка с ldflags
log_info "Сборка бинарного файла..."
go build \
    -ldflags="
        -X main.version=$VERSION
        -X main.buildType=$BUILD_TYPE
        -X main.buildOS=$OS
        -X main.buildArch=$ARCH
        -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        -X main.jwtSecret=$JWT_SECRET
        -X main.jwtFallbackSecret=$JWT_FALLBACK_SECRET
        -X main.buildApiBase=$API_BASE
        -X main.buildTenantID=$TENANT_ID
        -X main.buildWireguardPublicKey=$WIREGUARD_PUBLIC_KEY
        -w -s
    " \
    -o "$OUTPUT_PATH" \
    ./cmd/cloudbridge-client

if [[ $? -eq 0 ]]; then
    log_success "Бинарный файл собран: $OUTPUT_PATH"
else
    log_error "Ошибка сборки"
    exit 1
fi

# Создание конфигурационного файла
CONFIG_FILE="$OUTPUT_DIR/config-${BUILD_TYPE}.yaml"
log_info "Создание конфигурационного файла: $CONFIG_FILE"

cat > "$CONFIG_FILE" << EOF
# CloudBridge Client Configuration - $BUILD_TYPE build
# Generated on: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Version: $VERSION
# OS: $OS
# Arch: $ARCH

relay:
  host: "$(echo $API_BASE | sed 's|https\?://||' | cut -d: -f1)"
  port: $(echo $API_BASE | cut -d: -f3)
  timeout: "30s"
  tls:
    enabled: true
    min_version: "1.3"
    verify_cert: $([ "$BUILD_TYPE" = "production" ] && echo "true" || echo "false")
    server_name: "$(echo $API_BASE | sed 's|https\?://||' | cut -d: -f1)"

auth:
  type: "jwt"
  secret: "$JWT_SECRET"
  fallback_secret: "$JWT_FALLBACK_SECRET"
  keycloak:
    enabled: false
    server_url: "https://auth.2gc.ru"
    realm: "cloudbridge"
    client_id: "cloudbridge-client"

api:
  base_url: "$API_BASE"
  insecure_skip_verify: $([ "$BUILD_TYPE" = "production" ] && echo "false" || echo "true")
  timeout: "30s"
  max_retries: 3
  backoff_multiplier: 2.0
  max_backoff: "60s"

logging:
  level: "$([ "$BUILD_TYPE" = "production" ] && echo "info" || echo "debug")"
  format: "json"
  output: "stdout"

metrics:
  enabled: true
  prometheus_port: 9091
  tenant_metrics: true
  buffer_metrics: true
  connection_metrics: true

rate_limiting:
  enabled: true
  max_retries: 3
  backoff_multiplier: 2.0
  max_backoff: "60s"

performance:
  enabled: true
  optimization_mode: "high_throughput"
  gc_percent: 100
  memory_ballast: $([ "$BUILD_TYPE" = "production" ] && echo "true" || echo "false")

p2p:
  mesh_port: 51820
  interface_name: "wg0"
  allowed_ips: ["10.0.0.0/24"]
  mtu: 1420
  persistent_keepalive: "25s"

tunnel:
  max_connections: 10
  buffer_size: 4096
  keepalive_interval: "30s"
EOF

log_success "Конфигурационный файл создан: $CONFIG_FILE"

# Создание пакета для развертывания
PACKAGE_NAME="cloudbridge-client-${BUILD_TYPE}-${OS}-${ARCH}-${VERSION}"
PACKAGE_DIR="$OUTPUT_DIR/$PACKAGE_NAME"

log_info "Создание пакета развертывания: $PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Копирование файлов в пакет
cp "$OUTPUT_PATH" "$PACKAGE_DIR/cloudbridge-client$EXT"
cp "$CONFIG_FILE" "$PACKAGE_DIR/config.yaml"
cp README.md "$PACKAGE_DIR/" 2>/dev/null || true
cp PRODUCTION_REQUIREMENTS.md "$PACKAGE_DIR/" 2>/dev/null || true

# Создание скрипта установки в зависимости от ОС
if [[ "$OS" == "windows" ]]; then
    # Windows установщик
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

    # Windows деинсталлятор
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

else
    # Linux/macOS установщик
    cat > "$PACKAGE_DIR/install.sh" << 'EOF'
#!/bin/bash
set -e

echo "🚀 Installing CloudBridge Client..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit 1
fi

# Create user
useradd -r -s /bin/false cloudbridge 2>/dev/null || true

# Create directories
mkdir -p /opt/cloudbridge-client
mkdir -p /var/log/cloudbridge-client

# Install files
cp cloudbridge-client /opt/cloudbridge-client/
cp config.yaml /opt/cloudbridge-client/
chown -R cloudbridge:cloudbridge /opt/cloudbridge-client
chmod +x /opt/cloudbridge-client/cloudbridge-client

# Create systemd service
cat > /etc/systemd/system/cloudbridge-client.service << 'SERVICE_EOF'
[Unit]
Description=CloudBridge Client
After=network.target

[Service]
Type=simple
User=cloudbridge
Group=cloudbridge
WorkingDirectory=/opt/cloudbridge-client
ExecStart=/opt/cloudbridge-client/cloudbridge-client p2p --config /opt/cloudbridge-client/config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable and start service
systemctl daemon-reload
systemctl enable cloudbridge-client

echo "✅ CloudBridge Client installed successfully"
echo "📊 Start service: systemctl start cloudbridge-client"
echo "📋 Status: systemctl status cloudbridge-client"
echo "📝 Logs: journalctl -u cloudbridge-client -f"
EOF

    chmod +x "$PACKAGE_DIR/install.sh"
fi

# Создание архива
log_info "Создание архива..."
cd "$OUTPUT_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"
cd - > /dev/null

log_success "Пакет создан: $OUTPUT_DIR/${PACKAGE_NAME}.tar.gz"

# Вывод информации о сборке
echo ""
echo "🎉 Сборка завершена успешно!"
echo "================================"
echo "Бинарный файл: $OUTPUT_PATH"
echo "Конфигурация: $CONFIG_FILE"
echo "Пакет: $OUTPUT_DIR/${PACKAGE_NAME}.tar.gz"
echo "================================"
echo ""
echo "Для установки:"
echo "  tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "  cd $PACKAGE_NAME"
echo "  sudo ./install.sh"
echo ""
