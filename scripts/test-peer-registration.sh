#!/bin/bash

# Скрипт для тестирования регистрации пира и диагностики проблемы "Peer already exists"
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
JWT_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImZhbGxiYWNrLWtleSJ9.eyJwcm90b2NvbF90eXBlIjoicDJwLW1lc2giLCJzY29wZSI6InAycC1tZXNoLWNsYWltcyIsIm9yZ19pZCI6InRlbmFudC0yMTY0MjAxNjUiLCJ0ZW5hbnRfaWQiOiJ0ZW5hbnQtMjE2NDIwMTY1Iiwic2VydmVyX2lkIjoic2VydmVyLTE3NTgwNTE2OTI3NTMiLCJjb25uZWN0aW9uX3R5cGUiOiJ3aXJlZ3VhcmQiLCJtYXhfcGVlcnMiOiIxMCIsInBlcm1pc3Npb25zIjpbIm1lc2hfam9pbiIsIm1lc2hfbWFuYWdlIl0sIm5ldHdvcmtfY29uZmlnIjp7InN1Ym5ldCI6IjEwLjAuMC4wLzI0IiwiZ2F0ZXdheSI6IjEwLjAuMC4xIiwiZG5zIjpbIjguOC44LjgiLCIxLjEuMS4xIl0sIm10dSI6MTQyMCwiZmlyZXdhbGxfcnVsZXMiOlsiYWxsb3dfc3NoIiwiYWxsb3dfaHR0cCJdLCJlbmFibGVfaXB2NiI6ZmFsc2V9LCJ3aXJlZ3VhcmRfY29uZmlnIjp7ImludGVyZmFjZV9uYW1lIjoid2cwIiwibGlzdGVuX3BvcnQiOjUxODIwLCJhZGRyZXNzIjoiMTAuMC4wLjEwMC8yNCIsIm10dSI6MTQyMCwiYWxsb3dlZF9pcHMiOlsiMTAuMC4wLjAvMjQiLCIxOTIuMTY4LjEuMC8yNCJdfSwibWVzaF9jb25maWciOnsibmV0d29ya19pZCI6Im1lc2gtbmV0d29yay0wMDEiLCJzdWJuZXQiOiIxMC4wLjAuMC8xNiIsInJlZ2lzdHJ5X3VybCI6Imh0dHBzOi8vbWVzaC1yZWdpc3RyeS4yZ2MucnUiLCJoZWFydGJlYXRfaW50ZXJ2YWwiOiIzMHMiLCJtYXhfcGVlcnMiOjEwLCJyb3V0aW5nX3N0cmF0ZWd5IjoicGVyZm9ybWFuY2Vfb3B0aW1hbCIsImVuYWJsZV9hdXRvX2Rpc2NvdmVyeSI6dHJ1ZSwidHJ1c3RfbGV2ZWwiOiJiYXNpYyJ9LCJwZWVyX3doaXRlbGlzdCI6WyJwZWVyLTAwMSIsInBlZXItMDAyIiwicGVlci0wMDMiXSwiaWF0IjoxNzU4MDUxNjk2LCJpc3MiOiJodHRwczovL2F1dGguMmdjLnJ1L3JlYWxtcy9jbG91ZGJyaWRnZSIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiJzZXJ2ZXItY2xpZW50LXNlcnZlci0xNzU4MDUxNjkyNzUzIiwianRpIjoiand0XzE3NTgwNTE2OTYzNzBfMXBxbWp3dDE4In0.wSN6xF2xkPr-deUJAQHCJyNeduT3SQ5C2I35Oxt1LbE"

# Временные файлы
TEMP_DIR="/tmp/peer-registration-test-$$"
mkdir -p "$TEMP_DIR"

# Функция очистки
cleanup() {
    log_info "Очистка временных файлов..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Функция декодирования JWT токена
decode_jwt() {
    log_info "Анализ JWT токена..."
    
    # Извлекаем payload (вторая часть токена)
    local payload=$(echo "$JWT_TOKEN" | cut -d'.' -f2)
    
    # Добавляем padding если нужно
    local padding=$((4 - ${#payload} % 4))
    if [ $padding -ne 4 ]; then
        payload="${payload}$(printf '%*s' $padding | tr ' ' '=')"
    fi
    
    # Декодируем base64
    local decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "Failed to decode")
    
    if [ "$decoded" != "Failed to decode" ]; then
        log_success "JWT токен декодирован успешно"
        echo "$decoded" | jq . 2>/dev/null || echo "$decoded"
        
        # Извлекаем ключевые поля
        local sub=$(echo "$decoded" | jq -r '.sub // "not found"')
        local tenant_id=$(echo "$decoded" | jq -r '.tenant_id // "not found"')
        local connection_type=$(echo "$decoded" | jq -r '.connection_type // "not found"')
        
        log_info "Ключевые поля JWT:"
        log_info "  sub: $sub"
        log_info "  tenant_id: $tenant_id"
        log_info "  connection_type: $connection_type"
    else
        log_error "Не удалось декодировать JWT токен"
    fi
}

# Функция тестирования регистрации с разными public_key
test_registration_variants() {
    log_info "Тестирование регистрации с разными public_key..."
    
    # Вариант 1: Статичный ключ из тестового скрипта
    test_single_registration "JtkxMo0BPMc8T8ln7J6GpM9NXSGOelrxphPF0PPsuzs=" "static-key"
    
    # Вариант 2: Ключ на основе JWT sub
    local jwt_sub=$(echo "$JWT_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.sub // "unknown"' 2>/dev/null || echo "unknown")
    local sub_based_key=$(echo -n "$jwt_sub" | sha256sum | cut -d' ' -f1 | base64)
    test_single_registration "$sub_based_key" "sub-based-key"
    
    # Вариант 3: Уникальный ключ для каждой попытки
    local unique_key="unique-key-$(date +%s)-$$"
    test_single_registration "$unique_key" "unique-key"
}

# Функция тестирования одной регистрации
test_single_registration() {
    local public_key="$1"
    local test_name="$2"
    
    log_info "Тестирование регистрации: $test_name"
    log_info "Public key: $public_key"
    
    local register_payload
    register_payload=$(cat <<EOF
{
  "public_key": "$public_key",
  "allowed_ips": ["10.0.0.0/24"]
}
EOF
)
    
    echo "$register_payload" > "$TEMP_DIR/register_${test_name}.json"
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        -X POST "$API_BASE/api/v1/tenants/$TENANT_ID/peers/register" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary @"$TEMP_DIR/register_${test_name}.json" || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    log_info "HTTP код: $http_code"
    
    case $http_code in
        200|201)
            log_success "Регистрация успешна: $test_name"
            if command -v jq &> /dev/null; then
                echo "$body" | jq .
                # Проверяем наличие relay_session_id
                if echo "$body" | jq -e '.relay_session_id' > /dev/null 2>&1; then
                    log_success "relay_session_id получен: $(echo "$body" | jq -r '.relay_session_id')"
                else
                    log_warning "relay_session_id отсутствует в ответе"
                fi
            else
                echo "$body"
            fi
            ;;
        409)
            log_warning "Peer already exists: $test_name"
            if command -v jq &> /dev/null; then
                echo "$body" | jq .
            else
                echo "$body"
            fi
            ;;
        400)
            log_error "Bad Request: $test_name"
            echo "$body"
            ;;
        401)
            log_error "Unauthorized: $test_name"
            echo "$body"
            ;;
        *)
            log_error "Неожиданный HTTP код $http_code: $test_name"
            echo "$body"
            ;;
    esac
    
    echo "----------------------------------------"
}

# Функция тестирования повторной регистрации
test_repeated_registration() {
    log_info "Тестирование повторной регистрации..."
    
    local public_key="test-repeated-$(date +%s)"
    
    # Первая регистрация
    log_info "Первая регистрация..."
    test_single_registration "$public_key" "first-attempt"
    
    # Ждем 2 секунды
    sleep 2
    
    # Вторая регистрация с тем же ключом
    log_info "Вторая регистрация с тем же ключом..."
    test_single_registration "$public_key" "second-attempt"
}

# Функция тестирования discovery после регистрации
test_discovery_after_registration() {
    log_info "Тестирование discovery после регистрации..."
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        "$API_BASE/api/v1/tenants/$TENANT_ID/peers/discover" \
        -H "Authorization: Bearer $JWT_TOKEN" || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        log_success "Discovery успешен"
        if command -v jq &> /dev/null; then
            echo "$body" | jq .
            local peer_count=$(echo "$body" | jq '.peers | length' 2>/dev/null || echo "0")
            log_info "Найдено пиров: $peer_count"
        else
            echo "$body"
        fi
    else
        log_error "Discovery failed: HTTP $http_code"
        echo "$body"
    fi
}

# Функция тестирования с неверным токеном
test_invalid_token() {
    log_info "Тестирование с неверным токеном..."
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        -X POST "$API_BASE/api/v1/tenants/$TENANT_ID/peers/register" \
        -H "Authorization: Bearer invalid-token" \
        -H "Content-Type: application/json" \
        -d '{"public_key": "test", "allowed_ips": ["10.0.0.0/24"]}' || echo "000")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "401" ]; then
        log_success "Неверный токен правильно отклонен (401)"
    else
        log_error "Неверный токен: неожиданный ответ HTTP $http_code"
        echo "$body"
    fi
}

# Основная функция
main() {
    log_info "Запуск тестирования регистрации пира"
    log_info "API Base: $API_BASE"
    log_info "Tenant ID: $TENANT_ID"
    echo
    
    # Проверка зависимостей
    if ! command -v curl &> /dev/null; then
        log_error "curl не найден. Установите curl для продолжения."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq не найден. JSON ответы будут выводиться без форматирования."
    fi
    
    # Анализ JWT токена
    decode_jwt
    echo
    
    # Тестирование регистрации с разными ключами
    test_registration_variants
    echo
    
    # Тестирование повторной регистрации
    test_repeated_registration
    echo
    
    # Тестирование discovery
    test_discovery_after_registration
    echo
    
    # Тестирование с неверным токеном
    test_invalid_token
    echo
    
    log_info "Тестирование завершено"
    log_info "Проверьте результаты выше для анализа проблемы 'Peer already exists'"
}

# Запуск
main "$@"




