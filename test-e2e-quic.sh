#!/bin/bash

# E2E тест для QUIC 9091
# Тестирует полный флоу: Register -> Discover -> QUIC Dial -> AUTH -> TO message

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
QUIC_HOST="109.120.180.160"
QUIC_PORT="9091"
API_HOST="edge.2gc.ru"
API_PORT="9444"
TOKEN_FILE="token-valid.txt"

# Создаем валидный токен
create_valid_token() {
    echo -e "${BLUE}🔑 Создаем валидный JWT токен...${NC}"
    
    # Валидный токен с правильным секретом
    cat > "$TOKEN_FILE" << 'EOF'
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOlsiYWNjb3VudCJdLCJjb25uZWN0aW9uX3R5cGUiOiJxdWljIiwiZXhwIjoxNzU4MzY1NDczLCJpYXQiOjE3NTgyNzkwNzMsImlzcyI6Imh0dHBzOi8vYXV0aC4yZ2MucnUvcmVhbG1zL2Nsb3VkYnJpZGdlIiwianRpIjoiand0X3Rlc3RfdG9rZW4iLCJwZXJtaXNzaW9ucyI6WyJwMnBfY29ubmVjdCIsIm1lc2hfam9pbiIsIm1lc2hfbWFuYWdlIl0sInByb3RvY29sX3R5cGUiOiJwMnAtbWVzaCIsInNjb3BlIjoicDJwLW1lc2gtY2xhaW1zIiwic2VydmVyX2lkIjoic2VydmVyLXRlc3QtMTIzIiwic3ViIjoic2VydmVyLXRlc3QtMTIzIiwidGVuYW50X2lkIjoidGVuYW50LXRlc3QtMTIzIn0.2ePguI9tijf1holYraallqe955sHcKi0lndB1zb7OiA
EOF
    
    echo -e "${GREEN}✅ Токен создан: $TOKEN_FILE${NC}"
}

# Проверяем доступность UDP порта
check_udp_connectivity() {
    echo -e "${BLUE}🌐 Проверяем UDP доступность $QUIC_HOST:$QUIC_PORT...${NC}"
    
    if nc -zvu "$QUIC_HOST" "$QUIC_PORT" 2>/dev/null; then
        echo -e "${GREEN}✅ UDP порт доступен${NC}"
        return 0
    else
        echo -e "${RED}❌ UDP порт недоступен${NC}"
        return 1
    fi
}

# Проверяем доступность API
check_api_connectivity() {
    echo -e "${BLUE}🌐 Проверяем API доступность $API_HOST:$API_PORT...${NC}"
    
    if curl -s --connect-timeout 5 --insecure "https://$API_HOST:$API_PORT/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API доступен${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  API недоступен, но продолжаем тест${NC}"
        return 0  # Не прерываем тест
    fi
}

# Собираем quic-tester
build_quic_tester() {
    echo -e "${BLUE}🔨 Собираем quic-tester...${NC}"
    
    if go build -o bin/quic-tester ./cmd/quic-tester; then
        echo -e "${GREEN}✅ quic-tester собран${NC}"
        return 0
    else
        echo -e "${RED}❌ Ошибка сборки quic-tester${NC}"
        return 1
    fi
}

# Тестируем QUIC соединение
test_quic_connection() {
    echo -e "${BLUE}🚀 Тестируем QUIC соединение...${NC}"
    
    # Тест отправки сообщения
    echo -e "${YELLOW}📤 Тест отправки сообщения...${NC}"
    if ./bin/quic-tester \
        --mode=send \
        --token-file="$TOKEN_FILE" \
        --host="$QUIC_HOST" \
        --port="$QUIC_PORT" \
        --to="peer_server-1758276186397" \
        --msg="E2E test message" \
        --timeout=30s; then
        echo -e "${GREEN}✅ QUIC отправка успешна${NC}"
        return 0
    else
        echo -e "${RED}❌ QUIC отправка неуспешна${NC}"
        return 1
    fi
}

# Тестируем QUIC прием
test_quic_receiver() {
    echo -e "${BLUE}📥 Тестируем QUIC прием...${NC}"
    
    # Запускаем receiver в фоне
    ./bin/quic-tester \
        --mode=recv \
        --token-file="$TOKEN_FILE" \
        --host="$QUIC_HOST" \
        --port="$QUIC_PORT" \
        --timeout=30s &
    
    RECEIVER_PID=$!
    sleep 2
    
    # Отправляем сообщение
    echo -e "${YELLOW}📤 Отправляем тестовое сообщение...${NC}"
    ./bin/quic-tester \
        --mode=send \
        --token-file="$TOKEN_FILE" \
        --host="$QUIC_HOST" \
        --port="$QUIC_PORT" \
        --to="peer_server-1758276186397" \
        --msg="E2E receiver test" \
        --timeout=30s
    
    # Ждем завершения receiver
    wait $RECEIVER_PID 2>/dev/null || true
    
    echo -e "${GREEN}✅ QUIC прием тестирован${NC}"
}

# Основная функция
main() {
    echo -e "${BLUE}🧪 E2E тест для QUIC 9091${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # Создаем токен
    create_valid_token
    
    # Проверяем доступность
    if ! check_udp_connectivity; then
        echo -e "${RED}❌ UDP недоступен, тест прерван${NC}"
        exit 1
    fi
    
    check_api_connectivity
    
    # Собираем quic-tester
    if ! build_quic_tester; then
        echo -e "${RED}❌ Ошибка сборки, тест прерван${NC}"
        exit 1
    fi
    
    # Тестируем QUIC
    if test_quic_connection; then
        echo -e "${GREEN}🎉 E2E тест успешен!${NC}"
        echo -e "${GREEN}✅ QUIC 9091 работает корректно${NC}"
    else
        echo -e "${RED}❌ E2E тест неуспешен${NC}"
        echo -e "${RED}❌ QUIC 9091 не работает${NC}"
        exit 1
    fi
    
    # Очистка
    rm -f "$TOKEN_FILE"
    
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}🏁 Тест завершен${NC}"
}

# Запуск
main "$@"
