#!/bin/bash

# Скрипт для тестирования P2P соединения между локальной и удаленной машинами
# Автор: DevOps Team
# Дата: 2025-09-20

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
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

# Конфигурация
LOCAL_TOKEN_FILE="local-token.txt"
REMOTE_HOST="212.233.79.160"
REMOTE_USER="ubuntu"
REMOTE_KEY="/home/ubuntu/.ssh/2GC-RELAY-SERVER-hz0QxPy8.pem"
RELAY_HOST="b1.2gc.space"
QUIC_PORT="5553"

log_info "🚀 Тестирование P2P соединения CloudBridge Relay"
log_info "=================================================="
log_info "Локальная машина: $(hostname -I | awk '{print $1}')"
log_info "Удаленная машина: $REMOTE_HOST"
log_info "Relay сервер: $RELAY_HOST:$QUIC_PORT"
echo

# Проверка локального токена
if [ ! -f "$LOCAL_TOKEN_FILE" ]; then
    log_error "Локальный токен не найден: $LOCAL_TOKEN_FILE"
    log_info "Пожалуйста, сохраните токен в файл $LOCAL_TOKEN_FILE"
    exit 1
fi

LOCAL_TOKEN=$(cat "$LOCAL_TOKEN_FILE")
log_success "Локальный токен загружен"

# Проверка подключения к удаленной машине
log_info "Проверка подключения к удаленной машине..."
if ssh -i "$REMOTE_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo 'Connection successful'" 2>/dev/null; then
    log_success "Подключение к удаленной машине успешно"
else
    log_error "Не удается подключиться к удаленной машине"
    log_info "Проверьте:"
    log_info "1. Доступность машины $REMOTE_HOST"
    log_info "2. Правильность SSH ключа: $REMOTE_KEY"
    log_info "3. Настройки firewall"
    exit 1
fi

# Проверка доступности relay сервера
log_info "Проверка доступности relay сервера..."
if nc -u -w 3 "$RELAY_HOST" "$QUIC_PORT" < /dev/null 2>/dev/null; then
    log_success "Relay сервер $RELAY_HOST:$QUIC_PORT доступен"
else
    log_error "Relay сервер $RELAY_HOST:$QUIC_PORT недоступен"
    exit 1
fi

# Создание конфигурации для удаленной машины
log_info "Создание конфигурации для удаленной машины..."
REMOTE_CONFIG=$(cat << 'EOF'
# CloudBridge Client Remote Test Configuration
relay:
  host: "b1.2gc.space"
  ports:
    quic: 5553
    stun: 19302
  tls:
    enabled: true
    verify_cert: false
    server_name: "b1.2gc.space"

auth:
  type: "jwt"
  secret: "85Sk/NfLq3gqzCXzmBKbJCpL+f5BssXz3G8dVi3sPiE="
  skip_validation: true

logging:
  level: "debug"
  format: "json"
  output: "stdout"

quic:
  handshake_timeout: "10s"
  idle_timeout: "30s"
  insecure_skip_verify: true

p2p:
  max_connections: 1000
  session_timeout: "300s"
  peer_discovery_interval: "30s"
  connection_retry_interval: "5s"
  max_retry_attempts: 3

api:
  base_url: "http://b1.2gc.space:8080"
  p2p_api_url: "http://b1.2gc.space:8082"
  insecure_skip_verify: true
  timeout: "30s"
EOF
)

# Загрузка конфигурации на удаленную машину
echo "$REMOTE_CONFIG" | ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "cat > config-remote.yaml"
log_success "Конфигурация загружена на удаленную машину"

# Проверка наличия клиента на удаленной машине
log_info "Проверка наличия клиента на удаленной машине..."
if ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "test -f cloudbridge-client-linux"; then
    log_success "Клиент найден на удаленной машине"
else
    log_warning "Клиент не найден на удаленной машине"
    log_info "Пожалуйста, загрузите клиент на удаленную машину"
    exit 1
fi

# Загрузка токена для удаленной машины
if [ ! -f "remote-token.txt" ]; then
    log_error "Токен для удаленной машины не найден: remote-token.txt"
    log_info "Пожалуйста, сохраните токен в файл remote-token.txt"
    exit 1
fi

REMOTE_TOKEN=$(cat "remote-token.txt")
log_success "Токен для удаленной машины загружен"

# Сохранение токена на удаленной машине
echo "$REMOTE_TOKEN" | ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "cat > remote-token.txt"
log_success "Токен сохранен на удаленной машине"

# Запуск клиентов
log_info "Запуск клиентов..."
echo

# Запуск локального клиента в фоне
log_info "Запуск локального клиента..."
./cloudbridge-client-linux p2p \
    --token "$LOCAL_TOKEN" \
    --config config-b1-test.yaml \
    --log-level debug \
    --verbose > local-client.log 2>&1 &
LOCAL_PID=$!

# Запуск удаленного клиента
log_info "Запуск удаленного клиента..."
ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "
    ./cloudbridge-client-linux p2p \
        --token \$(cat remote-token.txt) \
        --config config-remote.yaml \
        --log-level debug \
        --verbose > remote-client.log 2>&1 &
    echo \$! > remote-client.pid
    sleep 5
    echo 'Remote client started'
" &
REMOTE_PID=$!

# Ожидание запуска клиентов
log_info "Ожидание запуска клиентов..."
sleep 10

# Проверка статуса клиентов
log_info "Проверка статуса клиентов..."

if kill -0 $LOCAL_PID 2>/dev/null; then
    log_success "Локальный клиент работает (PID: $LOCAL_PID)"
else
    log_error "Локальный клиент не запущен"
fi

if ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "kill -0 \$(cat remote-client.pid) 2>/dev/null"; then
    log_success "Удаленный клиент работает"
else
    log_error "Удаленный клиент не запущен"
fi

# Мониторинг соединения
log_info "Мониторинг соединения в течение 30 секунд..."
log_info "Проверьте логи клиентов для подтверждения P2P соединения"
echo

# Показ логов
log_info "Логи локального клиента:"
tail -10 local-client.log 2>/dev/null || log_warning "Логи локального клиента недоступны"

echo
log_info "Логи удаленного клиента:"
ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "tail -10 remote-client.log 2>/dev/null" || log_warning "Логи удаленного клиента недоступны"

# Ожидание
sleep 30

# Остановка клиентов
log_info "Остановка клиентов..."
kill $LOCAL_PID 2>/dev/null || true
ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "kill \$(cat remote-client.pid) 2>/dev/null || true"

# Результаты
log_info "=================================================="
log_info "Тестирование завершено"
log_info "=================================================="

log_info "Для анализа результатов проверьте:"
log_info "1. local-client.log - логи локального клиента"
log_info "2. remote-client.log - логи удаленного клиента (на удаленной машине)"
log_info "3. /var/log/nginx/error.log - логи nginx (на сервере)"

log_info "Критерии успеха:"
log_info "✅ Оба клиента подключаются к серверу"
log_info "✅ Клиенты видят друг друга в P2P mesh"
log_info "✅ Устанавливается прямое соединение"
log_info "✅ Передача данных работает"

echo
log_success "Тестирование P2P соединения завершено! 🚀"
