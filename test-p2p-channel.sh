#!/bin/bash

# Тест P2P канала между двумя компьютерами
# Локальная машина (Mac) <-> Relay Server <-> Удаленный сервер (zabbix-server)

echo "🚀 Тест P2P канала между двумя компьютерами"
echo "============================================="
echo "Локальная машина: $(hostname)"
echo "Удаленный сервер: zabbix-server (212.233.79.160)"
echo "Relay сервер: edge.2gc.ru:8083"
echo "Время: $(date)"
echo

# Конфигурация
LOCAL_CLIENT_PATH="./cloudbridge-client"
REMOTE_HOST="zabbix-server"
LOCAL_CONFIG="config-dev.yaml"
REMOTE_CONFIG="config-remote.yaml"
LOCAL_TOKEN="token-correct.txt"
REMOTE_TOKEN="token-remote.txt"
LOG_LEVEL="debug"
WAIT_TIME=30

# Функции логирования
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

# Остановка предыдущих процессов
log_info "🛑 Останавливаем предыдущие процессы..."
pkill -f "cloudbridge-client" || true
ssh -F ~/.ssh/config "$REMOTE_HOST" "pkill -f 'cloudbridge-client' || true"
sleep 3

# Запуск локального клиента
log_info "🚀 Запускаем локальный клиент..."
cat "$LOCAL_TOKEN" | xargs -I {} "$LOCAL_CLIENT_PATH" p2p --config "$LOCAL_CONFIG" --token {} --log-level "$LOG_LEVEL" > local-client.log 2>&1 &
LOCAL_PID=$!
log_info "Локальный клиент PID: $LOCAL_PID"

# Запуск удаленного клиента
log_info "🚀 Запускаем удаленный клиент..."
ssh -F ~/.ssh/config "$REMOTE_HOST" "cd /home/ubuntu && cat $(basename "$REMOTE_TOKEN") | xargs -I {} ./cloudbridge-client-remote p2p --config $(basename "$REMOTE_CONFIG") --token {} --log-level $LOG_LEVEL > remote-client.log 2>&1 & echo \$!" > remote_pid.txt
REMOTE_PID=$(cat remote_pid.txt)
log_info "Удаленный клиент PID: $REMOTE_PID"

# Ожидание установки соединений
log_info "⏳ Ждем $WAIT_TIME секунд для установки соединений..."
sleep "$WAIT_TIME"

# Проверка статуса клиентов
echo
log_info "📊 Проверяем статус клиентов..."
echo "================================"

# Локальный клиент
if ps -p "$LOCAL_PID" > /dev/null; then
    log_success "Локальный клиент (PID: $LOCAL_PID): ✅ Работает"
    echo "Последние 10 строк лога:"
    tail -n 10 local-client.log
else
    log_error "Локальный клиент (PID: $LOCAL_PID): ❌ Остановлен"
    echo "Последние 10 строк лога:"
    tail -n 10 local-client.log
fi

echo

# Удаленный клиент
REMOTE_STATUS=$(ssh -F ~/.ssh/config "$REMOTE_HOST" "ps -p $REMOTE_PID > /dev/null && echo 'running' || echo 'stopped'")
if [ "$REMOTE_STATUS" == "running" ]; then
    log_success "Удаленный клиент (PID: $REMOTE_PID): ✅ Работает"
    echo "Последние 10 строк лога:"
    ssh -F ~/.ssh/config "$REMOTE_HOST" "tail -n 10 remote-client.log"
else
    log_error "Удаленный клиент (PID: $REMOTE_PID): ❌ Остановлен"
    echo "Последние 10 строк лога:"
    ssh -F ~/.ssh/config "$REMOTE_HOST" "tail -n 10 remote-client.log"
fi

# Проверка регистрации пиров
echo
log_info "🔍 Проверяем зарегистрированных пиров..."
echo "=========================================="
curl -s -X GET "http://edge.2gc.ru:8083/api/v1/tenants/tenant-216420165/peers/discover" \
  -H "Authorization: Bearer $(cat "$LOCAL_TOKEN")" | python3 -m json.tool 2>/dev/null || echo "Не удалось получить JSON"

# Тест P2P соединения через QUIC
echo
log_info "🧪 Тестируем P2P соединение через QUIC..."
echo "============================================"

# Создаем простой тест для проверки QUIC соединения
cat > test-quic-connection.py << 'EOF'
#!/usr/bin/env python3
import socket
import time
import json

def test_quic_connection():
    print("🧪 Тест QUIC соединения через relay сервер")
    print("===========================================")
    
    RELAY_HOST = "edge.2gc.ru"
    QUIC_PORT = 9090
    
    # Создаем UDP сокет для QUIC
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(10)
    
    try:
        # Отправляем тестовое сообщение на QUIC порт
        test_message = {
            "type": "quic_test",
            "from": "local-machine",
            "to": "remote-server",
            "message": "QUIC connection test",
            "timestamp": time.time()
        }
        
        message_json = json.dumps(test_message)
        print(f"📤 Отправляем QUIC тест на {RELAY_HOST}:{QUIC_PORT}")
        print(f"Сообщение: {message_json}")
        
        sock.sendto(message_json.encode(), (RELAY_HOST, QUIC_PORT))
        print("✅ QUIC сообщение отправлено")
        
        # Пытаемся получить ответ
        try:
            data, addr = sock.recvfrom(65507)
            response = json.loads(data.decode())
            print(f"📥 Получен ответ от {addr}: {response}")
            return True
        except socket.timeout:
            print("⏰ Timeout при получении QUIC ответа")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка при тестировании QUIC: {e}")
        return False
    finally:
        sock.close()

if __name__ == "__main__":
    success = test_quic_connection()
    if success:
        print("✅ QUIC соединение работает")
    else:
        print("❌ QUIC соединение не работает")
EOF

python3 test-quic-connection.py

# Проверка сетевых интерфейсов
echo
log_info "🌐 Проверяем сетевые интерфейсы..."
echo "===================================="
echo "Локальные интерфейсы:"
ip -4 a show | grep -A 2 -B 1 '10\.' || ifconfig | grep -A 2 -B 1 '10\.'

echo
echo "Удаленные интерфейсы:"
ssh -F ~/.ssh/config "$REMOTE_HOST" "ip -4 a show | grep -A 2 -B 1 '10\.' || ifconfig | grep -A 2 -B 1 '10\.'"

# Остановка клиентов
echo
log_info "🛑 Останавливаем клиентов..."
kill "$LOCAL_PID" || true
ssh -F ~/.ssh/config "$REMOTE_HOST" "kill $REMOTE_PID || true"
sleep 2

# Финальный отчет
echo
log_info "📋 ФИНАЛЬНЫЙ ОТЧЕТ"
echo "=================="
echo "Время завершения: $(date)"
echo
echo "Логи локального клиента: local-client.log"
echo "Логи удаленного клиента: проверьте на сервере $REMOTE_HOST"
echo
echo "Для просмотра полных логов:"
echo "  cat local-client.log"
echo "  ssh -F ~/.ssh/config $REMOTE_HOST 'cat remote-client.log'"
echo
echo "Для поиска ошибок:"
echo "  grep -i error local-client.log"
echo "  ssh -F ~/.ssh/config $REMOTE_HOST 'grep -i error remote-client.log'"
echo
log_success "✅ Тест P2P канала между двумя компьютерами завершен!"
