#!/bin/bash

# Скрипт для тестирования обновленного API после исправлений DevOps команды
# Автор: Developer Team
# Дата: 2025-01-16

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
API_BASE="https://edge.2gc.ru:30082"
TENANT_ID="tenant-216420165"
JWT_SECRET="eozy96a8+j125pOpIhCyytge1rR0MTiG4wBi/J9zpew="

# Временные файлы
TEMP_DIR="/tmp/updated-api-test-$$"
mkdir -p "$TEMP_DIR"

# Функция очистки
cleanup() {
    log_info "Очистка временных файлов..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Функция генерации JWT токена
generate_jwt_token() {
    log_info "Генерация JWT токена с правильным secret..."
    
    # Генерируем токен
    JWT_TOKEN=$(go run scripts/generate-jwt.go 2>/dev/null | tail -n +2 | head -n 1)
    
    if [ -z "$JWT_TOKEN" ]; then
        log_error "Не удалось сгенерировать JWT токен"
        return 1
    fi
    
    log_success "JWT токен сгенерирован"
    log_info "Токен: ${JWT_TOKEN:0:50}..."
    return 0
}

# Функция тестирования Health Check
test_health() {
    log_info "Тестирование Health Check..."
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" "$API_BASE/health" || echo "000")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        log_success "Health Check: OK"
        if command -v jq &> /dev/null; then
            echo "$body" | jq . 2>/dev/null || echo "$body"
        else
            echo "$body"
        fi
        return 0
    else
        log_error "Health Check failed: HTTP $http_code"
        echo "$body"
        return 1
    fi
}

# Функция тестирования регистрации пира
test_peer_registration() {
    log_info "Тестирование регистрации пира (исправленный API)..."
    
    # Генерируем стабильный public_key на основе JWT sub
    local jwt_sub="server-client-server-1758051692753"
    local stable_public_key=$(echo -n "$jwt_sub" | sha256sum | cut -d' ' -f1 | base64)
    
    log_info "Используем стабильный public_key: $stable_public_key"
    
    local register_payload
    register_payload=$(cat <<EOF
{
  "public_key": "$stable_public_key",
  "allowed_ips": ["10.0.0.0/24"]
}
EOF
)
    
    echo "$register_payload" > "$TEMP_DIR/register.json"
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        -X POST "$API_BASE/api/v1/tenants/$TENANT_ID/peers/register" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @"$TEMP_DIR/register.json" || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    log_info "HTTP код: $http_code"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_success "Регистрация пира: OK"
        if command -v jq &> /dev/null; then
            echo "$body" | jq .
            # Проверяем наличие relay_session_id
            if echo "$body" | jq -e '.relay_session_id' > /dev/null 2>&1; then
                local relay_session_id=$(echo "$body" | jq -r '.relay_session_id')
                log_success "relay_session_id получен: $relay_session_id"
                echo "$relay_session_id" > "$TEMP_DIR/relay_session_id"
            else
                log_warning "relay_session_id отсутствует в ответе"
            fi
        else
            echo "$body"
        fi
        return 0
    else
        log_error "Регистрация пира failed: HTTP $http_code"
        echo "$body"
        return 1
    fi
}

# Функция тестирования heartbeat (автоматическая регистрация)
test_heartbeat_auto_registration() {
    log_info "Тестирование heartbeat с автоматической регистрацией..."
    
    local peer_id="server-client-server-1758051692753"
    local heartbeat_payload
    heartbeat_payload=$(cat <<EOF
{
  "status": "online",
  "latency_ms": 50,
  "metrics": {
    "timestamp": $(date +%s),
    "uptime": 3600,
    "cpu_usage": 0.5,
    "memory_usage": 0.7
  }
}
EOF
)
    
    echo "$heartbeat_payload" > "$TEMP_DIR/heartbeat.json"
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        -X POST "$API_BASE/api/v1/tenants/$TENANT_ID/peers/$peer_id/status" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @"$TEMP_DIR/heartbeat.json" || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    log_info "HTTP код: $http_code"
    
    if [ "$http_code" = "200" ]; then
        log_success "Heartbeat (автоматическая регистрация): OK"
        if command -v jq &> /dev/null; then
            echo "$body" | jq .
            # Проверяем наличие relay_session_id
            if echo "$body" | jq -e '.relay_session_id' > /dev/null 2>&1; then
                local relay_session_id=$(echo "$body" | jq -r '.relay_session_id')
                log_success "relay_session_id получен через heartbeat: $relay_session_id"
                echo "$relay_session_id" > "$TEMP_DIR/heartbeat_relay_session_id"
            else
                log_warning "relay_session_id отсутствует в heartbeat ответе"
            fi
        else
            echo "$body"
        fi
        return 0
    else
        log_error "Heartbeat failed: HTTP $http_code"
        echo "$body"
        return 1
    fi
}

# Функция тестирования discovery
test_discovery() {
    log_info "Тестирование discovery пиров..."
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        "$API_BASE/api/v1/tenants/$TENANT_ID/peers/discover" \
        -H "Authorization: Bearer $JWT_TOKEN" || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        log_success "Discovery: OK"
        if command -v jq &> /dev/null; then
            echo "$body" | jq .
            local peer_count=$(echo "$body" | jq '.peers | length' 2>/dev/null || echo "0")
            log_info "Найдено пиров: $peer_count"
        else
            echo "$body"
        fi
        return 0
    else
        log_error "Discovery failed: HTTP $http_code"
        echo "$body"
        return 1
    fi
}

# Функция тестирования повторной регистрации
test_repeated_registration() {
    log_info "Тестирование повторной регистрации (должна работать без HTTP 409)..."
    
    # Используем тот же стабильный public_key
    local jwt_sub="server-client-server-1758051692753"
    local stable_public_key=$(echo -n "$jwt_sub" | sha256sum | cut -d' ' -f1 | base64)
    
    local register_payload
    register_payload=$(cat <<EOF
{
  "public_key": "$stable_public_key",
  "allowed_ips": ["10.0.0.0/24"]
}
EOF
)
    
    echo "$register_payload" > "$TEMP_DIR/register_repeat.json"
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        -X POST "$API_BASE/api/v1/tenants/$TENANT_ID/peers/register" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @"$TEMP_DIR/register_repeat.json" || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    log_info "HTTP код при повторной регистрации: $http_code"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_success "Повторная регистрация: OK (HTTP 409 больше не возникает!)"
        if command -v jq &> /dev/null; then
            echo "$body" | jq .
        else
            echo "$body"
        fi
        return 0
    elif [ "$http_code" = "409" ]; then
        log_error "HTTP 409 все еще возникает - проблема не решена"
        echo "$body"
        return 1
    else
        log_warning "Неожиданный HTTP код: $http_code"
        echo "$body"
        return 1
    fi
}

# Основная функция
main() {
    log_info "Запуск тестирования обновленного API"
    log_info "API Base: $API_BASE"
    log_info "Tenant ID: $TENANT_ID"
    echo
    
    local tests_passed=0
    local tests_total=0
    
    # Проверка зависимостей
    if ! command -v curl &> /dev/null; then
        log_error "curl не найден. Установите curl для продолжения."
        exit 1
    fi
    
    if ! command -v go &> /dev/null; then
        log_error "Go не найден. Установите Go для генерации JWT токена."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq не найден. JSON ответы будут выводиться без форматирования."
    fi
    
    # Генерация JWT токена
    if ! generate_jwt_token; then
        log_error "Не удалось сгенерировать JWT токен"
        exit 1
    fi
    echo
    
    # Тест 1: Health Check
    tests_total=$((tests_total + 1))
    if test_health; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Тест 2: Регистрация пира
    tests_total=$((tests_total + 1))
    if test_peer_registration; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Тест 3: Heartbeat с автоматической регистрацией
    tests_total=$((tests_total + 1))
    if test_heartbeat_auto_registration; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Тест 4: Discovery
    tests_total=$((tests_total + 1))
    if test_discovery; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Тест 5: Повторная регистрация
    tests_total=$((tests_total + 1))
    if test_repeated_registration; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Результаты
    log_info "Результаты тестирования обновленного API:"
    log_info "Пройдено: $tests_passed/$tests_total тестов"
    
    if [ $tests_passed -eq $tests_total ]; then
        log_success "Все тесты пройдены успешно! ✅"
        log_success "API исправления работают корректно!"
        exit 0
    else
        log_error "Некоторые тесты не пройдены ❌"
        log_info "Проверьте логи выше для анализа проблем"
        exit 1
    fi
}

# Запуск
main "$@"




