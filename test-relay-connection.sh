#!/bin/bash

# Тестирование подключения к CloudBridge Relay серверу
# Автор: Developer Team
# Дата: 2025-09-18

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
RELAY_HOST="edge.2gc.ru"
HTTP_API_PORT="8080"
P2P_API_PORT="8082"
STUN_PORT="19302"
QUIC_PORT="9090"
MASQUE_PORT="8443"
ENHANCED_QUIC_PORT="9092"

log_info "🔍 Тестирование подключения к CloudBridge Relay серверу"
log_info "Сервер: $RELAY_HOST"
echo "=============================================="

# Функция проверки TCP порта
check_tcp_port() {
    local host=$1
    local port=$2
    local service_name=$3
    
    log_info "Проверка $service_name ($host:$port)..."
    
    if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        log_success "$service_name доступен"
        return 0
    else
        log_error "$service_name недоступен"
        return 1
    fi
}

# Функция проверки UDP порта
check_udp_port() {
    local host=$1
    local port=$2
    local service_name=$3
    
    log_info "Проверка $service_name UDP ($host:$port)..."
    
    # Отправляем простой UDP пакет
    if echo "test" | timeout 5 nc -u -w 3 "$host" "$port" 2>/dev/null; then
        log_success "$service_name UDP доступен"
        return 0
    else
        log_warning "$service_name UDP не отвечает (нормально для UDP)"
        return 1
    fi
}

# Функция проверки HTTP API
check_http_api() {
    local host=$1
    local port=$2
    local service_name=$3
    
    log_info "Проверка $service_name HTTP API..."
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" --connect-timeout 5 "https://$host:$port/health" 2>/dev/null || echo "000")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        log_success "$service_name HTTP API работает (HTTP $http_code)"
        if [ -n "$body" ]; then
            echo "Ответ: $body"
        fi
        return 0
    else
        log_error "$service_name HTTP API не работает (HTTP $http_code)"
        return 1
    fi
}

# Функция проверки STUN сервера
check_stun_server() {
    local host=$1
    local port=$2
    
    log_info "Проверка STUN сервера ($host:$port)..."
    
    # Создаем STUN Binding Request
    local stun_request="\x00\x01\x00\x00\x21\x12\xa4\x42\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    
    # Отправляем STUN запрос
    if echo -e "$stun_request" | timeout 5 nc -u -w 3 "$host" "$port" 2>/dev/null; then
        log_success "STUN сервер отвечает"
        return 0
    else
        log_warning "STUN сервер не отвечает (возможно, нормально)"
        return 1
    fi
}

# Основные проверки
log_info "Начинаем проверки..."
echo

# 1. DNS резолвинг
log_info "1. Проверка DNS резолвинга..."
if nslookup "$RELAY_HOST" >/dev/null 2>&1; then
    ip=$(nslookup "$RELAY_HOST" | grep "Address:" | tail -1 | awk '{print $2}')
    log_success "DNS резолвинг работает: $RELAY_HOST -> $ip"
else
    log_error "DNS резолвинг не работает"
    exit 1
fi
echo

# 2. Проверка TCP портов
log_info "2. Проверка TCP портов..."
check_tcp_port "$RELAY_HOST" "$HTTP_API_PORT" "HTTP API"
check_tcp_port "$RELAY_HOST" "$P2P_API_PORT" "P2P API"
check_tcp_port "$RELAY_HOST" "$MASQUE_PORT" "MASQUE Proxy"
echo

# 3. Проверка UDP портов
log_info "3. Проверка UDP портов..."
check_udp_port "$RELAY_HOST" "$STUN_PORT" "STUN Server"
check_udp_port "$RELAY_HOST" "$QUIC_PORT" "QUIC Transport"
check_udp_port "$RELAY_HOST" "$ENHANCED_QUIC_PORT" "Enhanced QUIC"
echo

# 4. Проверка HTTP API
log_info "4. Проверка HTTP API..."
check_http_api "$RELAY_HOST" "$HTTP_API_PORT" "HTTP API"
check_http_api "$RELAY_HOST" "$P2P_API_PORT" "P2P API"
echo

# 5. Проверка STUN сервера
log_info "5. Проверка STUN сервера..."
check_stun_server "$RELAY_HOST" "$STUN_PORT"
echo

# 6. Проверка клиента
log_info "6. Проверка клиента..."
if [ -f "./cloudbridge-client" ]; then
    log_success "Клиент найден"
    
    # Проверка версии
    if ./cloudbridge-client version >/dev/null 2>&1; then
        log_success "Клиент работает"
        ./cloudbridge-client version
    else
        log_error "Клиент не работает"
    fi
else
    log_error "Клиент не найден"
fi
echo

# Результаты
log_info "=============================================="
log_info "Тестирование завершено"
log_info "=============================================="

log_info "Для тестирования с реальным токеном:"
log_info "1. Получите JWT токен от DevOps команды"
log_info "2. Запустите: ./cloudbridge-client p2p --token YOUR_TOKEN --config config-test-quic.yaml"
log_info "3. Проверьте логи подключения"

echo
log_info "Если все проверки пройдены, сервер готов к работе! 🚀"
