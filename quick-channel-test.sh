#!/bin/bash

# Быстрый тест канала между машинами
# Простой и быстрый способ проверить работу

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Быстрый тест канала между машинами${NC}"
echo -e "${BLUE}====================================${NC}"

# Конфигурация
QUIC_HOST="b1.2gc.space"
QUIC_PORT="9091"
LOCAL_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOlsiYWNjb3VudCJdLCJjb25uZWN0aW9uX3R5cGUiOiJxdWljIiwiZXhwIjoxNzU4MzY1NDczLCJpYXQiOjE3NTgyNzkwNzMsImlzcyI6Imh0dHBzOi8vYXV0aC4yZ2MucnUvcmVhbG1zL2Nsb3VkYnJpZGdlIiwianRpIjoiand0X3Rlc3RfdG9rZW4iLCJwZXJtaXNzaW9ucyI6WyJwMnBfY29ubmVjdCIsIm1lc2hfam9pbiIsIm1lc2hfbWFuYWdlIl0sInByb3RvY29sX3R5cGUiOiJwMnAtbWVzaCIsInNjb3BlIjoicDJwLW1lc2gtY2xhaW1zIiwic2VydmVyX2lkIjoic2VydmVyLXRlc3QtMTIzIiwic3ViIjoic2VydmVyLXRlc3QtMTIzIiwidGVuYW50X2lkIjoidGVuYW50LXRlc3QtMTIzIn0.2ePguI9tijf1holYraallqe955sHcKi0lndB1zb7OiA"

echo -e "${BLUE}1️⃣ Проверяем доступность QUIC сервера...${NC}"
if nc -zvu "$QUIC_HOST" "$QUIC_PORT" 2>/dev/null; then
    echo -e "${GREEN}✅ QUIC сервер доступен${NC}"
else
    echo -e "${RED}❌ QUIC сервер недоступен${NC}"
    exit 1
fi

echo -e "${BLUE}2️⃣ Тестируем QUIC подключение...${NC}"
if ./bin/quic-tester \
    --mode=send \
    --token="$LOCAL_TOKEN" \
    --host="$QUIC_HOST" \
    --port="$QUIC_PORT" \
    --to="test-peer-123" \
    --msg="Quick test message $(date)" \
    --timeout=30s; then
    
    echo -e "${GREEN}🎉 QUIC подключение работает!${NC}"
else
    echo -e "${YELLOW}⚠️  QUIC подключение не отвечает (может быть нормально)${NC}"
fi

echo -e "${BLUE}3️⃣ Запускаем receiver в фоне...${NC}"
./bin/quic-tester \
    --mode=recv \
    --token="$LOCAL_TOKEN" \
    --host="$QUIC_HOST" \
    --port="$QUIC_PORT" \
    --timeout=30s &
RECEIVER_PID=$!

echo -e "${GREEN}✅ Receiver запущен (PID: $RECEIVER_PID)${NC}"

# Ждем немного
sleep 3

echo -e "${BLUE}4️⃣ Отправляем тестовое сообщение...${NC}"
if ./bin/quic-tester \
    --mode=send \
    --token="$LOCAL_TOKEN" \
    --host="$QUIC_HOST" \
    --port="$QUIC_PORT" \
    --to="test-peer-123" \
    --msg="Test message to receiver $(date)" \
    --timeout=30s; then
    
    echo -e "${GREEN}🎉 Сообщение отправлено!${NC}"
else
    echo -e "${YELLOW}⚠️  Сообщение не отправлено${NC}"
fi

# Останавливаем receiver
echo -e "${BLUE}5️⃣ Останавливаем receiver...${NC}"
kill $RECEIVER_PID 2>/dev/null || true
echo -e "${GREEN}✅ Receiver остановлен${NC}"

echo -e "${BLUE}====================================${NC}"
echo -e "${GREEN}✅ Быстрый тест завершен${NC}"
echo -e "${YELLOW}ℹ️  Для полного теста с удаленной машиной используйте:${NC}"
echo -e "${YELLOW}   ./test-remote-channel.sh${NC}"
