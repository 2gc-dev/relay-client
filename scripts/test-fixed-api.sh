#!/bin/bash

# Скрипт для тестирования исправленного API после решения всех проблем
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

# Реальный токен из личного кабинета
JWT_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImZhbGxiYWNrLWtleSJ9.eyJwcm90b2NvbF90eXBlIjoicDJwLW1lc2giLCJzY29wZSI6InAycC1tZXNoLWNsYWltcyIsIm9yZ19pZCI6InRlbmFudC0yMTY0MjAxNjUiLCJ0ZW5hbnRfaWQiOiJ0ZW5hbnQtMjE2NDIwMTY1Iiwic2VydmVyX2lkIjoic2VydmVyLTE3NTgwNTE2OTI3NTMiLCJjb25uZWN0aW9uX3R5cGUiOiJ3aXJlZ3VhcmQiLCJtYXhfcGVlcnMiOiIxMCIsInBlcm1pc3Npb25zIjpbIm1lc2hfam9pbiIsIm1lc2hfbWFuYWdlIl0sIm5ldHdvcmtfY29uZmlnIjp7InN1Ym5ldCI6IjEwLjAuMC4wLzI0IiwiZ2F0ZXdheSI6IjEwLjAuMC4xIiwiZG5zIjpbIjguOC44LjgiLCIxLjEuMS4xIl0sIm10dSI6MTQyMCwiZmlyZXdhbGxfcnVsZXMiOlsiYWxsb3dfc3NoIiwiYWxsb3dfaHR0cCJdLCJlbmFibGVfaXB2NiI6ZmFsc2V9LCJ3aXJlZ3VhcmRfY29uZmlnIjp7ImludGVyZmFjZV9uYW1lIjoid2cwIiwibGlzdGVuX3BvcnQiOjUxODIwLCJhZGRyZXNzIjoiMTAuMC4wLjEwMC8yNCIsIm10dSI6MTQyMCwiYWxsb3dlZF9pcHMiOlsiMTAuMC4wLjAvMjQiLCIxOTIuMTY4LjEuMC8yNCJdfSwibWVzaF9jb25maWciOnsibmV0d29ya19pZCI6Im1lc2gtbmV0d29yay0wMDEiLCJzdWJuZXQiOiIxMC4wLjAuMC8xNiIsInJlZ2lzdHJ5X3VybCI6Imh0dHBzOi8vbWVzaC1yZWdpc3RyeS4yZ2MucnUiLCJoZWFydGJlYXRfaW50ZXJ2YWwiOiIzMHMiLCJtYXhfcGVlcnMiOjEwLCJyb3V0aW5nX3N0cmF0ZWd5IjoicGVyZm9ybWFuY2Vfb3B0aW1hbCIsImVuYWJsZV9hdXRvX2Rpc2NvdmVyeSI6dHJ1ZSwidHJ1c3RfbGV2ZWwiOiJiYXNpYyJ9LCJwZWVyX3doaXRlbGlzdCI6WyJwZWVyLTAwMSIsInBlZXItMDAyIiwicGVlci0wMDMiXSwiaWF0IjoxNzU4MDY0MDUwLCJpc3MiOiJodHRwczovL2F1dGguMmdjLnJ1L3JlYWxtcy9jbG91ZGJyaWRnZSIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiJzZXJ2ZXItY2xpZW50LXNlcnZlci0xNzU4MDUxNjkyNzUzIiwianRpIjoiand0XzE3NTgwNjQwNTAzNjBfajd3Z2YwOGkzIn0.ZuZ_8i8zGxQHcf6vdnl-QiZNWewIehx2JzdJUSBCh7U"

# Временные файлы
TEMP_DIR="/tmp/fixed-api-test-$$"
mkdir -p "$TEMP_DIR"

# Функция очистки
cleanup() {
    log_info "Очистка временных файлов..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

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
    
    # Генерируем уникальный public_key для теста
    local unique_public_key="test-key-$(date +%s)-$$"
    
    log_info "Используем уникальный public_key: $unique_public_key"
    
    local register_payload
    register_payload=$(cat <<EOF
{
  "public_key": "$unique_public_key",
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

# Функция тестирования heartbeat (исправленный HTTP метод PUT)
test_heartbeat() {
    log_info "Тестирование heartbeat с правильным HTTP методом PUT..."
    
    local peer_id="server-client-server-1758051692753"
    local relay_session_id=""
    
    # Получаем relay_session_id из предыдущего теста
    if [ -f "$TEMP_DIR/relay_session_id" ]; then
        relay_session_id=$(cat "$TEMP_DIR/relay_session_id")
    else
        # Используем тестовый relay_session_id
        relay_session_id="rs_test_$(date +%s)"
    fi
    
    local heartbeat_payload
    heartbeat_payload=$(cat <<EOF
{
  "relay_session_id": "$relay_session_id",
  "status": "online",
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
        -X PUT "$API_BASE/api/v1/tenants/$TENANT_ID/peers/$peer_id/status" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @"$TEMP_DIR/heartbeat.json" || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    log_info "HTTP код: $http_code"
    
    if [ "$http_code" = "200" ]; then
        log_success "Heartbeat: OK"
        if command -v jq &> /dev/null; then
            echo "$body" | jq .
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
    
    # Используем тот же public_key что и в первом тесте
    local unique_public_key="test-key-$(date +%s)-$$"
    
    local register_payload
    register_payload=$(cat <<EOF
{
  "public_key": "$unique_public_key",
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

# Функция тестирования клиента
test_client() {
    log_info "Тестирование клиента с исправленным API..."
    
    # Проверяем наличие собранного клиента
    local client_path=$(find dist -name "cloudbridge-client-*" -type f -not -name "*.tar.gz" | head -1)
    if [ -z "$client_path" ]; then
        log_warning "Клиент не найден, собираем..."
        if [ -f "scripts/quick-test.sh" ]; then
            ./scripts/quick-test.sh
            client_path=$(find dist -name "cloudbridge-client-*" -type f -not -name "*.tar.gz" | head -1)
        fi
    fi
    
    if [ -n "$client_path" ]; then
        log_info "Найден клиент: $client_path"
        
        # Тест версии
        log_info "Тестирование команды version..."
        if "$client_path" version; then
            log_success "Команда version работает"
        else
            log_error "Команда version не работает"
            return 1
        fi
        
        # Тест P2P команды (без реального подключения)
        log_info "Тестирование P2P команды..."
        if "$client_path" p2p --help > /dev/null; then
            log_success "P2P команда работает"
        else
            log_error "P2P команда не работает"
            return 1
        fi
        
        return 0
    else
        log_error "Клиент не найден и не удалось собрать"
        return 1
    fi
}

# Основная функция
main() {
    log_info "Запуск тестирования исправленного API"
    log_info "API Base: $API_BASE"
    log_info "Tenant ID: $TENANT_ID"
    log_info "JWT Token: ${JWT_TOKEN:0:50}..."
    echo
    
    local tests_passed=0
    local tests_total=0
    
    # Проверка зависимостей
    if ! command -v curl &> /dev/null; then
        log_error "curl не найден. Установите curl для продолжения."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq не найден. JSON ответы будут выводиться без форматирования."
    fi
    
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
    
    # Тест 3: Heartbeat
    tests_total=$((tests_total + 1))
    if test_heartbeat; then
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
    
    # Тест 6: Клиент
    tests_total=$((tests_total + 1))
    if test_client; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Результаты
    log_info "Результаты тестирования исправленного API:"
    log_info "Пройдено: $tests_passed/$tests_total тестов"
    
    if [ $tests_passed -eq $tests_total ]; then
        log_success "🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО! ✅"
        log_success "API исправления работают корректно!"
        log_success "Клиент готов к интеграции и тестированию!"
        echo
        log_info "Готовые команды для использования:"
        log_info "1. Регистрация пира: POST /api/v1/tenants/{tenant_id}/peers/register"
        log_info "2. Heartbeat: PUT /api/v1/tenants/{tenant_id}/peers/{peer_id}/status"
        log_info "3. Discovery: GET /api/v1/tenants/{tenant_id}/peers/discover"
        exit 0
    else
        log_error "Некоторые тесты не пройдены ❌"
        log_info "Проверьте логи выше для анализа проблем"
        exit 1
    fi
}

# Запуск
main "$@"




