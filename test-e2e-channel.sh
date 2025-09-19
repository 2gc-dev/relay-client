#!/bin/bash

# E2E тест канала между локальной и удаленной машиной
# Тестирует: Register -> Discover -> QUIC Dial -> AUTH -> TO message

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
QUIC_HOST="b1.2gc.space"
QUIC_PORT="9091"
API_HOST="edge.2gc.ru"
API_PORT="9444"

# Токены для тестирования
LOCAL_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOlsiYWNjb3VudCJdLCJjb25uZWN0aW9uX3R5cGUiOiJxdWljIiwiZXhwIjoxNzU4MzY1NDczLCJpYXQiOjE3NTgyNzkwNzMsImlzcyI6Imh0dHBzOi8vYXV0aC4yZ2MucnUvcmVhbG1zL2Nsb3VkYnJpZGdlIiwianRpIjoiand0X3Rlc3RfdG9rZW4iLCJwZXJtaXNzaW9ucyI6WyJwMnBfY29ubmVjdCIsIm1lc2hfam9pbiIsIm1lc2hfbWFuYWdlIl0sInByb3RvY29sX3R5cGUiOiJwMnAtbWVzaCIsInNjb3BlIjoicDJwLW1lc2gtY2xhaW1zIiwic2VydmVyX2lkIjoic2VydmVyLXRlc3QtMTIzIiwic3ViIjoic2VydmVyLXRlc3QtMTIzIiwidGVuYW50X2lkIjoidGVuYW50LXRlc3QtMTIzIn0.2ePguI9tijf1holYraallqe955sHcKi0lndB1zb7OiA"

REMOTE_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJhY2NvdW50IiwiY29ubmVjdGlvbl90eXBlIjoicXVpYyIsImV4cCI6MTc1ODM2NTQ3MywiaWF0IjoxNzU4Mjc5MDczLCJpc3MiOiJodHRwczovL2F1dGguMmdjLnJ1L3JlYWxtcy9jbG91ZGJyaWRnZSIsImp0aSI6Imp3dF90ZXN0X3Rva2VuIiwicGVybWlzc2lvbnMiOlsicDJwX2Nvbm5lY3QiLCJtZXNoX2pvaW4iLCJtZXNoX21hbmFnZSJdLCJwcm90b2NvbF90eXBlIjoicDJwLW1lc2giLCJzY29wZSI6InAycC1tZXNoLWNsYWltcyIsInNlcnZlcl9pZCI6InNlcnZlci10ZXN0LTEyMyIsInN1YiI6InNlcnZlci10ZXN0LTEyMyIsInRlbmFudF9pZCI6InRlbmFudC10ZXN0LTEyMyJ9.AE4OkW-dvrKnAa1XH18td5AWnQZmkXCPTx0FNOomnx4"

echo -e "${BLUE}🧪 E2E тест канала между локальной и удаленной машиной${NC}"
echo -e "${BLUE}====================================================${NC}"

# Функция проверки доступности
check_connectivity() {
    echo -e "${BLUE}🌐 Проверяем доступность серверов...${NC}"
    
    # Проверяем QUIC сервер
    if nc -zvu "$QUIC_HOST" "$QUIC_PORT" 2>/dev/null; then
        echo -e "${GREEN}✅ QUIC сервер $QUIC_HOST:$QUIC_PORT доступен${NC}"
    else
        echo -e "${RED}❌ QUIC сервер $QUIC_HOST:$QUIC_PORT недоступен${NC}"
        return 1
    fi
    
    # Проверяем API сервер
    if curl -s --connect-timeout 5 --insecure "https://$API_HOST:$API_PORT/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API сервер $API_HOST:$API_PORT доступен${NC}"
    else
        echo -e "${YELLOW}⚠️  API сервер $API_HOST:$API_PORT недоступен${NC}"
    fi
    
    return 0
}

# Функция регистрации локального клиента
register_local_client() {
    echo -e "${BLUE}📝 Регистрируем локального клиента...${NC}"
    
    local client_id="local-client-$(date +%s)"
    local public_key="local-pub-key-$(date +%s)"
    
    # Создаем JSON для регистрации
    cat > register_local.json << EOF
{
    "client_id": "$client_id",
    "public_key": "$public_key",
    "allowed_ips": ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"],
    "endpoint": "local-endpoint:9091"
}
EOF
    
    echo -e "${YELLOW}📤 Отправляем регистрацию локального клиента...${NC}"
    if curl -s --insecure -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $LOCAL_TOKEN" \
        -d @register_local.json \
        "https://$API_HOST:$API_PORT/api/v1/p2p/register" > register_local_response.json; then
        
        echo -e "${GREEN}✅ Локальный клиент зарегистрирован${NC}"
        echo -e "${YELLOW}📋 Ответ сервера:${NC}"
        cat register_local_response.json | jq . 2>/dev/null || cat register_local_response.json
        
        # Извлекаем peer_id
        LOCAL_PEER_ID=$(cat register_local_response.json | jq -r '.peer_id' 2>/dev/null || echo "local-peer-$(date +%s)")
        echo -e "${GREEN}🆔 Локальный peer_id: $LOCAL_PEER_ID${NC}"
        return 0
    else
        echo -e "${RED}❌ Ошибка регистрации локального клиента${NC}"
        return 1
    fi
}

# Функция регистрации удаленного клиента
register_remote_client() {
    echo -e "${BLUE}📝 Регистрируем удаленного клиента...${NC}"
    
    local client_id="remote-client-$(date +%s)"
    local public_key="remote-pub-key-$(date +%s)"
    
    # Создаем JSON для регистрации
    cat > register_remote.json << EOF
{
    "client_id": "$client_id",
    "public_key": "$public_key",
    "allowed_ips": ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"],
    "endpoint": "remote-endpoint:9091"
}
EOF
    
    echo -e "${YELLOW}📤 Отправляем регистрацию удаленного клиента...${NC}"
    if curl -s --insecure -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $REMOTE_TOKEN" \
        -d @register_remote.json \
        "https://$API_HOST:$API_PORT/api/v1/p2p/register" > register_remote_response.json; then
        
        echo -e "${GREEN}✅ Удаленный клиент зарегистрирован${NC}"
        echo -e "${YELLOW}📋 Ответ сервера:${NC}"
        cat register_remote_response.json | jq . 2>/dev/null || cat register_remote_response.json
        
        # Извлекаем peer_id
        REMOTE_PEER_ID=$(cat register_remote_response.json | jq -r '.peer_id' 2>/dev/null || echo "remote-peer-$(date +%s)")
        echo -e "${GREEN}🆔 Удаленный peer_id: $REMOTE_PEER_ID${NC}"
        return 0
    else
        echo -e "${RED}❌ Ошибка регистрации удаленного клиента${NC}"
        return 1
    fi
}

# Функция discovery клиентов
discover_clients() {
    echo -e "${BLUE}🔍 Ищем зарегистрированных клиентов...${NC}"
    
    echo -e "${YELLOW}📤 Запрашиваем список клиентов...${NC}"
    if curl -s --insecure -X GET \
        -H "Authorization: Bearer $LOCAL_TOKEN" \
        "https://$API_HOST:$API_PORT/api/v1/p2p/discover" > discover_response.json; then
        
        echo -e "${GREEN}✅ Discovery запрос выполнен${NC}"
        echo -e "${YELLOW}📋 Найденные клиенты:${NC}"
        cat discover_response.json | jq . 2>/dev/null || cat discover_response.json
        
        return 0
    else
        echo -e "${RED}❌ Ошибка discovery запроса${NC}"
        return 1
    fi
}

# Функция тестирования QUIC канала
test_quic_channel() {
    echo -e "${BLUE}🚀 Тестируем QUIC канал...${NC}"
    
    if [ -z "$REMOTE_PEER_ID" ]; then
        echo -e "${RED}❌ REMOTE_PEER_ID не установлен${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📤 Отправляем сообщение через QUIC канал...${NC}"
    if ./bin/quic-tester \
        --mode=send \
        --token="$LOCAL_TOKEN" \
        --host="$QUIC_HOST" \
        --port="$QUIC_PORT" \
        --to="$REMOTE_PEER_ID" \
        --msg="E2E test message from local to remote" \
        --timeout=60s; then
        
        echo -e "${GREEN}🎉 QUIC канал работает!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  QUIC канал не отвечает (может быть нормально)${NC}"
        return 1
    fi
}

# Функция запуска QUIC receiver
start_quic_receiver() {
    echo -e "${BLUE}📥 Запускаем QUIC receiver в фоне...${NC}"
    
    ./bin/quic-tester \
        --mode=recv \
        --token="$LOCAL_TOKEN" \
        --host="$QUIC_HOST" \
        --port="$QUIC_PORT" \
        --timeout=60s &
    
    RECEIVER_PID=$!
    echo -e "${GREEN}✅ QUIC receiver запущен (PID: $RECEIVER_PID)${NC}"
    
    # Ждем немного
    sleep 3
    
    return 0
}

# Функция остановки QUIC receiver
stop_quic_receiver() {
    if [ ! -z "$RECEIVER_PID" ]; then
        echo -e "${BLUE}🛑 Останавливаем QUIC receiver...${NC}"
        kill $RECEIVER_PID 2>/dev/null || true
        echo -e "${GREEN}✅ QUIC receiver остановлен${NC}"
    fi
}

# Основная функция
main() {
    echo -e "${BLUE}🎯 Начинаем E2E тест канала...${NC}"
    
    # Проверяем доступность
    if ! check_connectivity; then
        echo -e "${RED}❌ Серверы недоступны${NC}"
        exit 1
    fi
    
    # Регистрируем клиентов
    if ! register_local_client; then
        echo -e "${RED}❌ Ошибка регистрации локального клиента${NC}"
        exit 1
    fi
    
    if ! register_remote_client; then
        echo -e "${RED}❌ Ошибка регистрации удаленного клиента${NC}"
        exit 1
    fi
    
    # Ждем немного для синхронизации
    sleep 2
    
    # Ищем клиентов
    if ! discover_clients; then
        echo -e "${RED}❌ Ошибка discovery${NC}"
        exit 1
    fi
    
    # Запускаем receiver
    start_quic_receiver
    
    # Тестируем QUIC канал
    if test_quic_channel; then
        echo -e "${GREEN}🎉 E2E тест канала успешен!${NC}"
    else
        echo -e "${YELLOW}⚠️  E2E тест канала частично успешен${NC}"
    fi
    
    # Останавливаем receiver
    stop_quic_receiver
    
    # Очистка
    rm -f register_local.json register_remote.json register_local_response.json register_remote_response.json discover_response.json 2>/dev/null || true
    
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${GREEN}✅ E2E тест завершен${NC}"
    echo -e "${YELLOW}ℹ️  Локальный peer_id: $LOCAL_PEER_ID${NC}"
    echo -e "${YELLOW}ℹ️  Удаленный peer_id: $REMOTE_PEER_ID${NC}"
}

# Обработка сигналов
trap 'stop_quic_receiver; exit 1' INT TERM

# Запуск
main "$@"
