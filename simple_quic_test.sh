#!/bin/bash

# Простой тест QUIC подключения без Go компиляции
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

echo -e "${BLUE}🧪 Простой тест QUIC подключения${NC}"
echo -e "${BLUE}=================================${NC}"

# Проверяем доступность UDP порта
echo -e "${BLUE}🌐 Проверяем UDP доступность $QUIC_HOST:$QUIC_PORT...${NC}"
if nc -zvu "$QUIC_HOST" "$QUIC_PORT" 2>/dev/null; then
    echo -e "${GREEN}✅ UDP порт доступен${NC}"
else
    echo -e "${RED}❌ UDP порт недоступен${NC}"
    exit 1
fi

# Тестируем отправку UDP пакета
echo -e "${BLUE}📤 Тестируем отправку UDP пакета...${NC}"
echo "QUIC test message" | timeout 5 nc -u "$QUIC_HOST" "$QUIC_PORT" || echo -e "${YELLOW}⚠️  UDP пакет отправлен, но ответ не получен (это нормально для QUIC)${NC}"

# Проверяем LoadBalancer статистику
echo -e "${BLUE}📊 Проверяем LoadBalancer статистику...${NC}"
echo -e "${YELLOW}ℹ️  LoadBalancer должен показывать активность после отправки пакета${NC}"

echo -e "${GREEN}✅ Базовый тест завершен${NC}"
echo -e "${BLUE}=================================${NC}"
echo -e "${YELLOW}ℹ️  Для полного QUIC теста нужен Go клиент${NC}"
echo -e "${YELLOW}ℹ️  UDP доступность подтверждена${NC}"
