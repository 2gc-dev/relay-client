#!/bin/bash

# Тест обновленного Relay сервера с P2P маршрутизацией
# Проверяет новую функциональность: heartbeat, P2P маршрутизацию, QUIC relay

echo "🚀 Тест обновленного Relay сервера с P2P маршрутизацией"
echo "======================================================"
echo "Время: $(date)"
echo

# Функция для проверки доступности сервера
check_server_availability() {
    local url=$1
    local name=$2
    
    echo "🔍 Проверяем $name..."
    if curl -s --connect-timeout 10 "$url" > /dev/null 2>&1; then
        echo "✅ $name доступен"
        return 0
    else
        echo "❌ $name недоступен"
        return 1
    fi
}

# Ждем доступности сервера
echo "⏳ Ждем доступности Relay сервера..."
while ! check_server_availability "http://edge.2gc.ru:8082/health" "P2P API"; do
    echo "Сервер недоступен, ждем 30 секунд..."
    sleep 30
done

echo
echo "🎉 Relay сервер доступен! Начинаем тестирование..."
echo

# 1. Проверяем Health endpoints
echo "📊 1. ПРОВЕРКА HEALTH ENDPOINTS"
echo "================================"

echo "HTTP API Health:"
curl -s "http://edge.2gc.ru:8080/health" | python3 -m json.tool 2>/dev/null || echo "HTTP API недоступен"

echo
echo "P2P API Health:"
curl -s "http://edge.2gc.ru:8082/health" | python3 -m json.tool 2>/dev/null || echo "P2P API недоступен"

# 2. Тестируем Heartbeat API
echo
echo "💓 2. ТЕСТИРОВАНИЕ HEARTBEAT API"
echo "================================"

# Создаем тестовый JWT токен (для демонстрации)
TEST_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImZhbGxiYWNrLWtleSJ9.eyJwcm90b2NvbF90eXBlIjoicDJwLW1lc2giLCJzY29wZSI6InAycC1tZXNoLWNsYWltcyIsIm9yZ19pZCI6InRlbmFudC0yMTY0MjAxNjUiLCJ0ZW5hbnRfaWQiOiJ0ZW5hbnQtMjE2NDIwMTY1Iiwic2VydmVyX2lkIjoic2VydmVyLTE3NTgyMTkxOTU3MDMiLCJjb25uZWN0aW9uX3R5cGUiOiJxdWljLWljZSIsIm1heF9wZWVycyI6IjEwIiwicGVybWlzc2lvbnMiOlsibWVzaF9qb2luIiwibWVzaF9tYW5hZ2UiXSwibmV0d29ya19jb25maWciOnsic3VibmV0IjoiMTAuMC4wLjAvMjQiLCJnYXRld2F5IjoiMTAuMC4wLjEiLCJkbnMiOlsiOC44LjguOCIsIjEuMS4xLjEiXSwibXR1IjoxNDIwLCJmaXJld2FsbF9ydWxlcyI6WyJhbGxvd19zc2giLCJhbGxvd19odHRwIl0sImVuYWJsZV9pcHY2IjpmYWxzZX0sInF1aWNfY29uZmlnIjp7ImhhbmRzaGFrZV90aW1lb3V0IjoiMTBzIiwiaWRsZV90aW1lb3V0IjoiMzBzIiwibWF4X3N0cmVhbXMiOjEwMCwiY29ubmVjdGlvbl9taWdyYXRpb24iOnRydWUsIm11bHRpcGxleGluZyI6dHJ1ZX0sImljZV9jb25maWciOnsic3R1bl9zZXJ2ZXJzIjpbImVkZ2UuMmdjLnJ1OjE5MzAyIl0sInR1cm5fc2VydmVycyI6W10sImljZV90aW1lb3V0IjoiMzBzIiwiY29ubmVjdGlvbl90aW1lb3V0IjoiMTBzIiwiZ2F0aGVyaW5nX3RpbWVvdXQiOiI1cyIsImNhbmRpZGF0ZV90eXBlcyI6WyJob3N0Iiwic3JmbHgiLCJyZWxheSJdfSwibWFzcXVlX2NvbmZpZyI6eyJlbmFibGVkIjp0cnVlLCJwcm94eV91cmwiOiJodHRwczovL2VkZ2UuMmdjLnJ1Ojg0NDMiLCJhbHBuX3Byb3RvY29scyI6WyJoMyIsImgzLTI5Il0sImZhbGxiYWNrX2VuYWJsZWQiOnRydWV9LCJtZXNoX2NvbmZpZyI6eyJuZXR3b3JrX2lkIjoibWVzaC1uZXR3b3JrLTAwMSIsInN1Ym5ldCI6IjEwLjAuMC4wLzE2IiwicmVnaXN0cnlfdXJsIjoiaHR0cHM6Ly9lZGdlLjJnYy5ydTo4MDgwIiwiaGVhcnRiZWF0X2ludGVydmFsIjoiMzBzIiwibWF4X3BlZXJzIjoxMCwicm91dGluZ19zdHJhdGVneSI6InBlcmZvcm1hbmNlX29wdGltYWwiLCJlbmFibGVfYXV0b19kaXNjb3ZlcnkiOnRydWUsInRydXN0X2xldmVsIjoiYmFzaWMifSwicGVlcl93aGl0ZWxpc3QiOlsicGVlci0wMDEiLCJwZWVyLTAwMiIsInBlZXItMDAzIl0sInJlbGF5X2VuZHBvaW50cyI6eyJodHRwX2FwaSI6ImVkZ2UuMmdjLnJ1OjgwODAiLCJwMnBfYXBpIjoiZWRnZS4yZ2MucnU6ODA4MiIsInF1aWNfdHJhbnNwb3J0IjoiZWRnZS4yZ2MucnU6OTA5MCIsInN0dW5fc2VydmVyIjoiZWRnZS4yZ2MucnU6MTkzMDIiLCJtYXNxdWVfcHJveHkiOiJlZGdlLjJnYy5ydTo4NDQzIiwiZW5oYW5jZWRfcXVpYyI6ImVkZ2UuMmdjLnJ1OjkwOTIifSwiaWF0IjoxNzU4MjE5MTk4LCJpc3MiOiJodHRwczovL2F1dGguMmdjLnJ1L3JlYWxtcy9jbG91ZGJyaWRnZSIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiJzZXJ2ZXItY2xpZW50LXNlcnZlci0xNzU4MjE5MTk1NzAzIiwianRpIjoiand0XzE3NTgyMTkxOTgxMDlfbXoxdDhyc2RhIn0.d-o1yXtZOlnyv53Uhg5zEI3l3IRbQV27VdnEQIn5w_4"

echo "Тестируем Heartbeat API..."
echo "Отправляем heartbeat для тестового пира..."

# Тестируем heartbeat endpoint
curl -X POST "http://edge.2gc.ru:8080/api/v1/tenants/tenant-216420165/peers/test-peer/heartbeat" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -d '{"status": "online", "last_seen": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
  -w "\nHTTP Status: %{http_code}\n" 2>/dev/null || echo "Heartbeat API недоступен"

echo
echo "Получаем статус пира..."
curl -s "http://edge.2gc.ru:8080/api/v1/tenants/tenant-216420165/peers/test-peer/status" \
  -H "Authorization: Bearer $TEST_TOKEN" | python3 -m json.tool 2>/dev/null || echo "Status API недоступен"

echo
echo "Получаем статистику tenant'а..."
curl -s "http://edge.2gc.ru:8080/api/v1/tenants/tenant-216420165/stats" \
  -H "Authorization: Bearer $TEST_TOKEN" | python3 -m json.tool 2>/dev/null || echo "Stats API недоступен"

# 3. Тестируем P2P API
echo
echo "🔗 3. ТЕСТИРОВАНИЕ P2P API"
echo "=========================="

echo "Регистрируем тестового пира..."
curl -X POST "http://edge.2gc.ru:8082/api/v1/tenants/tenant-216420165/peers/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -d '{
    "peer_id": "test-peer-1",
    "public_key": "test-public-key-1",
    "endpoint": "192.168.1.100:9090",
    "capabilities": ["quic", "ice"]
  }' \
  -w "\nHTTP Status: %{http_code}\n" 2>/dev/null || echo "Register API недоступен"

echo
echo "Обнаруживаем пиры..."
curl -s "http://edge.2gc.ru:8082/api/v1/tenants/tenant-216420165/peers/discover" \
  -H "Authorization: Bearer $TEST_TOKEN" | python3 -m json.tool 2>/dev/null || echo "Discover API недоступен"

# 4. Тестируем QUIC соединения
echo
echo "🚀 4. ТЕСТИРОВАНИЕ QUIC СОЕДИНЕНИЙ"
echo "=================================="

echo "Тестируем QUIC порт 9090..."
python3 -c "
import socket
import time
import json

def test_quic_connection():
    print('Отправляем тестовое сообщение на QUIC порт...')
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(5)
    
    try:
        message = {
            'type': 'test',
            'from': 'test-client',
            'message': 'Hello from updated relay test',
            'timestamp': time.time()
        }
        
        data = json.dumps(message).encode('utf-8')
        sock.sendto(data, ('edge.2gc.ru', 9090))
        print('✅ Сообщение отправлено')
        
        response, addr = sock.recvfrom(1024)
        print(f'✅ Получен ответ от {addr}: {response.decode(\"utf-8\")[:100]}...')
        return True
        
    except Exception as e:
        print(f'❌ Ошибка: {e}')
        return False
    finally:
        sock.close()

test_quic_connection()
"

# 5. Запускаем клиенты для тестирования P2P маршрутизации
echo
echo "👥 5. ТЕСТИРОВАНИЕ P2P МАРШРУТИЗАЦИИ"
echo "===================================="

echo "Запускаем клиенты для тестирования P2P соединения..."

# Останавливаем предыдущие клиенты
pkill -f cloudbridge-client 2>/dev/null || true

# Запускаем локальный клиент
echo "Запускаем локальный клиент..."
TOKEN1=$(cat token1-clean.txt)
./cloudbridge-client p2p --config config-test-quic.yaml --token "$TOKEN1" --log-level debug > client-local-updated.log 2>&1 &
LOCAL_PID=$!
echo "Локальный клиент PID: $LOCAL_PID"

# Ждем немного
sleep 10

# Запускаем удаленный клиент
echo "Запускаем удаленный клиент..."
ssh -F ~/.ssh/config zabbix-server << 'EOF'
cd ~
pkill -f cloudbridge-client 2>/dev/null || true
./cloudbridge-client p2p --config config.yaml --token $(cat token.txt) --log-level debug > client-remote-updated.log 2>&1 &
CLIENT_PID=$!
echo "Удаленный клиент PID: $CLIENT_PID"
echo $CLIENT_PID > client-updated.pid
EOF

# Ждем установки соединений
echo "Ждем 30 секунд для установки соединений..."
sleep 30

# Проверяем статус клиентов
echo
echo "📊 СТАТУС КЛИЕНТОВ"
echo "=================="

echo "Локальный клиент:"
if ps -p $LOCAL_PID > /dev/null; then
    echo "✅ Локальный клиент работает"
    echo "Последние 10 строк лога:"
    tail -10 client-local-updated.log
else
    echo "❌ Локальный клиент остановлен"
    echo "Лог ошибок:"
    cat client-local-updated.log
fi

echo
echo "Удаленный клиент:"
ssh -F ~/.ssh/config zabbix-server << 'EOF'
if [ -f client-updated.pid ]; then
    CLIENT_PID=$(cat client-updated.pid)
    if ps -p $CLIENT_PID > /dev/null; then
        echo "✅ Удаленный клиент работает (PID: $CLIENT_PID)"
        echo "Последние 10 строк лога:"
        tail -10 client-remote-updated.log
    else
        echo "❌ Удаленный клиент остановлен"
        echo "Лог ошибок:"
        cat client-remote-updated.log
    fi
else
    echo "❌ PID файл не найден"
fi
EOF

# Проверяем онлайн пиров
echo
echo "👥 ПРОВЕРКА ОНЛАЙН ПИРОВ"
echo "========================"

echo "Проверяем онлайн пиров через P2P API..."
curl -s "http://edge.2gc.ru:8082/health" | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    print(f'Онлайн пиров: {data.get(\"metrics\", {}).get(\"online_peers\", \"N/A\")}')
    print(f'Всего пиров: {data.get(\"metrics\", {}).get(\"total_peers\", \"N/A\")}')
    print(f'Активных соединений: {data.get(\"metrics\", {}).get(\"active_connections\", \"N/A\")}')
except:
    print('Не удалось получить метрики')
" 2>/dev/null || echo "Не удалось получить метрики"

# Останавливаем клиентов
echo
echo "🛑 ОСТАНОВКА КЛИЕНТОВ"
echo "====================="

kill $LOCAL_PID 2>/dev/null || true
ssh -F ~/.ssh/config zabbix-server "if [ -f client-updated.pid ]; then kill \$(cat client-updated.pid) 2>/dev/null || true; fi"

# Финальный отчет
echo
echo "📋 ФИНАЛЬНЫЙ ОТЧЕТ"
echo "=================="
echo "Время завершения: $(date)"
echo
echo "Логи локального клиента: client-local-updated.log"
echo "Логи удаленного клиента: проверьте на сервере zabbix-server"
echo
echo "Для просмотра логов удаленного сервера:"
echo "  ssh -F ~/.ssh/config zabbix-server 'cat client-remote-updated.log'"

echo
echo "✅ Тест обновленного Relay сервера завершен!"

