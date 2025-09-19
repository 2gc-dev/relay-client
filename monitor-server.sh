#!/bin/bash

# Скрипт для мониторинга доступности relay сервера
# Проверяет порт 8083 и запускает клиент, когда сервер станет доступен

echo "🔍 Мониторинг доступности Relay сервера на порту 8083"
echo "======================================================"
echo "Время: $(date)"
echo

# Функция для проверки доступности сервера
check_server() {
    local url=$1
    local name=$2
    
    if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        echo "✅ $name доступен"
        return 0
    else
        echo "❌ $name недоступен"
        return 1
    fi
}

# Ждем доступности сервера
echo "⏳ Ждем доступности Relay сервера на порту 8083..."
while ! check_server "http://edge.2gc.ru:8083/health" "Relay Server (8083)"; do
    echo "Сервер недоступен, ждем 10 секунд..."
    sleep 10
done

echo
echo "🎉 Relay сервер доступен! Проверяем детали..."
echo

# Проверяем health endpoint
echo "📊 Проверка Health Endpoint:"
curl -s "http://edge.2gc.ru:8083/health" | python3 -m json.tool 2>/dev/null || echo "Не удалось получить JSON"

echo
echo "🚀 Запускаем клиент..."
echo

# Запускаем клиент
./cloudbridge-client p2p --config config-test-quic.yaml --token "$(cat token1-clean.txt)" --log-level debug

