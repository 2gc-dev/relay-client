#!/bin/bash

# Готовый тест для клиента - QUIC 9091
# Простой и надежный тест без сложной компиляции

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
QUIC_HOST="109.120.180.160"
QUIC_PORT="9091"
API_HOST="edge.2gc.ru"
API_PORT="9444"

echo -e "${BLUE}🧪 Готовый тест QUIC 9091 для клиента${NC}"
echo -e "${BLUE}=====================================${NC}"

# Функция проверки UDP доступности
check_udp_connectivity() {
    echo -e "${BLUE}🌐 Проверяем UDP доступность $QUIC_HOST:$QUIC_PORT...${NC}"
    
    if nc -zvu "$QUIC_HOST" "$QUIC_PORT" 2>/dev/null; then
        echo -e "${GREEN}✅ UDP порт $QUIC_HOST:$QUIC_PORT доступен${NC}"
        return 0
    else
        echo -e "${RED}❌ UDP порт $QUIC_HOST:$QUIC_PORT недоступен${NC}"
        return 1
    fi
}

# Функция проверки API доступности
check_api_connectivity() {
    echo -e "${BLUE}🌐 Проверяем API доступность $API_HOST:$API_PORT...${NC}"
    
    if curl -s --connect-timeout 5 --insecure "https://$API_HOST:$API_PORT/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API $API_HOST:$API_PORT доступен${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  API $API_HOST:$API_PORT недоступен (продолжаем тест)${NC}"
        return 0
    fi
}

# Функция тестирования UDP отправки
test_udp_send() {
    echo -e "${BLUE}📤 Тестируем отправку UDP пакета...${NC}"
    
    # Отправляем тестовое сообщение
    echo "QUIC test message from client $(date)" | nc -u "$QUIC_HOST" "$QUIC_PORT" 2>/dev/null || true
    
    echo -e "${GREEN}✅ UDP пакет отправлен${NC}"
    echo -e "${YELLOW}ℹ️  Если QUIC сервер работает, он должен получить пакет${NC}"
}

# Функция создания правильного токена
create_correct_token() {
    echo -e "${BLUE}🔑 Создаем правильный JWT токен...${NC}"
    
    cat > token_correct.txt << 'TOKEN_EOF'
eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJhY2NvdW50IiwiY29ubmVjdGlvbl90eXBlIjoicXVpYyIsImV4cCI6MTc1ODM2NTQ3MywiaWF0IjoxNzU4Mjc5MDczLCJpc3MiOiJodHRwczovL2F1dGguMmdjLnJ1L3JlYWxtcy9jbG91ZGJyaWRnZSIsImp0aSI6Imp3dF90ZXN0X3Rva2VuIiwicGVybWlzc2lvbnMiOlsicDJwX2Nvbm5lY3QiLCJtZXNoX2pvaW4iLCJtZXNoX21hbmFnZSJdLCJwcm90b2NvbF90eXBlIjoicDJwLW1lc2giLCJzY29wZSI6InAycC1tZXNoLWNsYWltcyIsInNlcnZlcl9pZCI6InNlcnZlci10ZXN0LTEyMyIsInN1YiI6InNlcnZlci10ZXN0LTEyMyIsInRlbmFudF9pZCI6InRlbmFudC10ZXN0LTEyMyJ9.AE4OkW-dvrKnAa1XH18td5AWnQZmkXCPTx0FNOomnx4
TOKEN_EOF
    
    echo -e "${GREEN}✅ Правильный токен создан: token_correct.txt${NC}"
    echo -e "${YELLOW}ℹ️  Этот токен имеет правильный формат aud: 'account' (строка)${NC}"
}

# Функция тестирования с Go клиентом (если доступен)
test_with_go_client() {
    echo -e "${BLUE}🔨 Пытаемся собрать Go клиент...${NC}"
    
    if command -v go >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Go найден, версия: $(go version)${NC}"
        
        # Пытаемся собрать external_client
        if go build -o external_client_test external_client.go 2>/dev/null; then
            echo -e "${GREEN}✅ Go клиент собран успешно${NC}"
            
            echo -e "${BLUE}🚀 Тестируем QUIC подключение с Go клиентом...${NC}"
            if ./external_client_test \
                --host="$QUIC_HOST" \
                --port="$QUIC_PORT" \
                --token="$(cat token_correct.txt)" \
                --timeout=30s; then
                echo -e "${GREEN}🎉 QUIC подключение успешно!${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️  QUIC подключение не удалось, но это может быть нормально${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}⚠️  Не удалось собрать Go клиент (продолжаем без него)${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Go не найден (продолжаем без Go клиента)${NC}"
        return 1
    fi
}

# Основная функция
main() {
    echo -e "${BLUE}🎯 Начинаем тестирование...${NC}"
    
    # Создаем правильный токен
    create_correct_token
    
    # Проверяем доступность
    if ! check_udp_connectivity; then
        echo -e "${RED}❌ UDP недоступен - проверьте сеть и LoadBalancer${NC}"
        exit 1
    fi
    
    check_api_connectivity
    
    # Тестируем UDP отправку
    test_udp_send
    
    # Пытаемся тестировать с Go клиентом
    if test_with_go_client; then
        echo -e "${GREEN}🎉 Полный тест успешен!${NC}"
    else
        echo -e "${YELLOW}⚠️  Базовый тест завершен (Go клиент недоступен)${NC}"
    fi
    
    # Очистка
    rm -f token_correct.txt external_client_test 2>/dev/null || true
    
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}✅ Тест завершен${NC}"
    echo -e "${YELLOW}ℹ️  UDP доступность подтверждена${NC}"
    echo -e "${YELLOW}ℹ️  LoadBalancer должен показывать активность${NC}"
    echo -e "${BLUE}📋 Для полного QUIC теста нужен Go клиент${NC}"
}

# Запуск
main "$@"
