#!/bin/bash

# Тест двух реальных клиентов с разными токенами
# Цель: проверить P2P соединение между клиентами через relay

echo "🚀 Тест двух клиентов CloudBridge"
echo "=================================="
echo "Время: $(date)"
echo

# Останавливаем все предыдущие процессы
echo "🛑 Останавливаем предыдущие процессы..."
pkill -f cloudbridge-client 2>/dev/null || true
sleep 2

# Создаем конфигурацию для второго клиента
echo "📝 Создаем конфигурацию для второго клиента..."
cat > config-client2.yaml << 'EOF'
# CloudBridge Client Configuration - Client 2
relay:
  host: "edge.2gc.ru"
  port: 9090
  timeout: "30s"
  tls:
    enabled: true
    min_version: "1.3"
    verify_cert: false
    server_name: "edge.2gc.ru"
  ports:
    http_api: 8080
    p2p_api: 8082
    quic: 9090
    stun: 19302
    masque: 8443
    enhanced_quic: 9092

auth:
  type: "jwt"
  secret: "fallback-key"
  fallback_secret: "fallback-key"
  skip_validation: true

api:
  base_url: "http://edge.2gc.ru:8082"
  p2p_api_url: "http://edge.2gc.ru:8082"
  insecure_skip_verify: true
  timeout: "30s"
  max_retries: 3
  backoff_multiplier: 2.0
  max_backoff: "60s"

logging:
  level: "debug"
  format: "text"
  output: "stdout"

# ICE Configuration
ice:
  stun_servers:
    - "edge.2gc.ru:19302"
  turn_servers: []
  timeout: "30s"
  max_binding_requests: 7
  connection_timeout: "10s"
  gathering_timeout: "5s"

# QUIC Configuration
quic:
  handshake_timeout: "10s"
  idle_timeout: "30s"
  max_streams: 100
  max_stream_data: 1048576
  keep_alive_period: "15s"
  insecure_skip_verify: true

# P2P Configuration
p2p:
  max_connections: 10
  session_timeout: "300s"
  peer_discovery_interval: "30s"
  connection_retry_interval: "5s"
  max_retry_attempts: 3
EOF

echo "✅ Конфигурация создана"

# Запускаем первый клиент в фоне
echo "🚀 Запускаем Client 1 (token-fixed.txt)..."
./cloudbridge-client p2p --config config-test-quic.yaml --token token-fixed.txt --log-level debug > client1.log 2>&1 &
CLIENT1_PID=$!
echo "Client 1 PID: $CLIENT1_PID"

# Ждем немного
sleep 5

# Запускаем второй клиент в фоне
echo "🚀 Запускаем Client 2 (token2.txt)..."
./cloudbridge-client p2p --config config-client2.yaml --token token2.txt --log-level debug > client2.log 2>&1 &
CLIENT2_PID=$!
echo "Client 2 PID: $CLIENT2_PID"

echo
echo "⏳ Ждем 30 секунд для установки соединений..."
sleep 30

# Проверяем логи клиентов
echo
echo "📊 Проверяем статус клиентов..."
echo "================================"

echo "Client 1 (PID: $CLIENT1_PID):"
if ps -p $CLIENT1_PID > /dev/null; then
    echo "✅ Client 1 работает"
    echo "Последние 10 строк лога:"
    tail -10 client1.log
else
    echo "❌ Client 1 остановлен"
    echo "Последние 10 строк лога:"
    tail -10 client1.log
fi

echo
echo "Client 2 (PID: $CLIENT2_PID):"
if ps -p $CLIENT2_PID > /dev/null; then
    echo "✅ Client 2 работает"
    echo "Последние 10 строк лога:"
    tail -10 client2.log
else
    echo "❌ Client 2 остановлен"
    echo "Последние 10 строк лога:"
    tail -10 client2.log
fi

# Проверяем сетевые интерфейсы
echo
echo "🌐 Проверяем сетевые интерфейсы..."
echo "=================================="

echo "Локальные интерфейсы с IP 10.x.x.x:"
ifconfig | grep -A 2 "inet 10\." || echo "Нет интерфейсов с IP 10.x.x.x"

echo
echo "Активные UDP соединения на порту 9090:"
netstat -an | grep ":9090" | grep UDP || echo "Нет активных UDP соединений на порту 9090"

# Проверяем, могут ли клиенты общаться
echo
echo "🧪 Тестируем связь между клиентами..."
echo "====================================="

# Создаем простой тест связи
cat > test-client-communication.py << 'EOF'
#!/usr/bin/env python3
import socket
import time
import json

def test_communication():
    print("🧪 Тест связи между клиентами через relay...")
    
    # Отправляем тестовое сообщение через relay
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(5)
    
    try:
        # Тестовое сообщение
        message = {
            "type": "test",
            "from": "test-client",
            "message": "Hello from test client",
            "timestamp": time.time()
        }
        
        data = json.dumps(message).encode('utf-8')
        sock.sendto(data, ("edge.2gc.ru", 9090))
        print("✅ Отправлено тестовое сообщение на relay")
        
        # Ждем ответ
        try:
            response, addr = sock.recvfrom(1024)
            print(f"✅ Получен ответ от {addr}: {response.decode('utf-8')[:100]}...")
            return True
        except socket.timeout:
            print("⏰ Timeout при ожидании ответа")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        return False
    finally:
        sock.close()

if __name__ == "__main__":
    test_communication()
EOF

python3 test-client-communication.py

# Останавливаем клиентов
echo
echo "🛑 Останавливаем клиентов..."
kill $CLIENT1_PID 2>/dev/null || true
kill $CLIENT2_PID 2>/dev/null || true
sleep 2

# Финальный отчет
echo
echo "📋 ФИНАЛЬНЫЙ ОТЧЕТ"
echo "=================="
echo "Время завершения: $(date)"
echo
echo "Логи Client 1 сохранены в: client1.log"
echo "Логи Client 2 сохранены в: client2.log"
echo
echo "Для просмотра полных логов используйте:"
echo "  cat client1.log"
echo "  cat client2.log"
echo
echo "Для поиска ошибок:"
echo "  grep -i error client1.log client2.log"
echo "  grep -i "peer" client1.log client2.log"
echo "  grep -i "connection" client1.log client2.log"

# Очистка
rm -f config-client2.yaml test-client-communication.py

echo
echo "✅ Тест завершен!"


