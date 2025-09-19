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
REMOTE_USER="ubuntu"
SSH_KEY="~/Desktop/2GC/key/2GC-RELAY-SERVER-hz0QxPy8.pem"
LOCAL_CONFIG="config-dev.yaml"
REMOTE_CONFIG="config-remote.yaml"
LOCAL_TOKEN="token-correct.txt"
REMOTE_TOKEN="token-remote.txt"  # Нужен второй токен
LOG_LEVEL="debug"
WAIT_TIME=30

# Функции логирования
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

# Проверка SSH соединения
log_info "🔍 Проверяем SSH соединение с удаленным сервером..."
if ssh -F ~/.ssh/config "$REMOTE_HOST" "echo 'SSH connection OK'" >/dev/null 2>&1; then
    log_success "SSH соединение с $REMOTE_HOST работает"
else
    log_error "SSH соединение с $REMOTE_HOST не работает"
    log_info "Проверьте SSH конфигурацию в ~/.ssh/config"
    exit 1
fi

# Проверка наличия токенов
log_info "🔑 Проверяем наличие JWT токенов..."
if [ ! -f "$LOCAL_TOKEN" ]; then
    log_error "Локальный токен не найден: $LOCAL_TOKEN"
    exit 1
fi

if [ ! -f "$REMOTE_TOKEN" ]; then
    log_warn "Удаленный токен не найден: $REMOTE_TOKEN"
    log_info "Создаем тестовый удаленный токен (копия локального)..."
    cp "$LOCAL_TOKEN" "$REMOTE_TOKEN"
    log_success "Создан тестовый удаленный токен"
fi

# Компиляция клиента для Linux
log_info "🛠️ Компилируем клиент для Linux..."
GOOS=linux GOARCH=amd64 go build -o cloudbridge-client-linux ./cmd/cloudbridge-client
if [ $? -ne 0 ]; then
    log_error "Ошибка компиляции клиента для Linux"
    exit 1
fi
log_success "Клиент для Linux скомпилирован"

# Создание конфигурации для удаленного сервера
log_info "📝 Создаем конфигурацию для удаленного сервера..."
cat > "$REMOTE_CONFIG" << 'EOF'
# CloudBridge Client Configuration for Remote Server - QUIC + ICE Testing
relay:
  host: "edge.2gc.ru"
  port: 9090
  timeout: "30s"
  tls:
    enabled: false
    min_version: "1.3"
    verify_cert: false
    server_name: "edge.2gc.ru"
  ports:
    http_api: 8083
    p2p_api: 8083
    quic: 9090
    stun: 19302
    masque: 8443
    enhanced_quic: 9092

auth:
  type: "jwt"
  secret: "fallback-key"
  fallback_secret: "fallback-key"
  skip_validation: true
  keycloak:
    enabled: false
    server_url: "https://auth.2gc.ru"
    realm: "cloudbridge"
    client_id: "cloudbridge-client"

api:
  base_url: "http://edge.2gc.ru:8083"
  p2p_api_url: "http://edge.2gc.ru:8083"
  heartbeat_url: "http://edge.2gc.ru:8083"
  insecure_skip_verify: true
  timeout: "30s"
  max_retries: 3
  backoff_multiplier: 2.0
  max_backoff: "60s"

logging:
  level: "debug"
  format: "text"
  output: "stdout"

metrics:
  enabled: true
  prometheus_port: 9091
  tenant_metrics: true
  buffer_metrics: true
  connection_metrics: true

rate_limiting:
  enabled: true
  max_retries: 3
  backoff_multiplier: 2.0
  max_backoff: "60s"

performance:
  enabled: true
  optimization_mode: "high_throughput"
  gc_percent: 100
  memory_ballast: false

ice:
  stun_servers:
    - "edge.2gc.ru:19302"
  turn_servers: []
  timeout: "30s"
  max_binding_requests: 7
  connection_timeout: "10s"
  gathering_timeout: "5s"

quic:
  handshake_timeout: "10s"
  idle_timeout: "30s"
  max_streams: 100
  max_stream_data: 1048576
  keep_alive_period: "15s"
  insecure_skip_verify: true

p2p:
  max_connections: 10
  session_timeout: "300s"
  peer_discovery_interval: "30s"
  connection_retry_interval: "5s"
  max_retry_attempts: 3
  heartbeat_interval: "30s"
  heartbeat_timeout: "10s"

tunnel:
  max_connections: 10
  buffer_size: 4096
  keepalive_interval: "30s"
EOF
log_success "Конфигурация для удаленного сервера создана"

# Копирование файлов на удаленный сервер
log_info "📤 Копируем файлы на удаленный сервер..."
scp -F ~/.ssh/config cloudbridge-client-linux "$REMOTE_HOST":/home/ubuntu/cloudbridge-client-remote
scp -F ~/.ssh/config "$REMOTE_CONFIG" "$REMOTE_HOST":/home/ubuntu/
scp -F ~/.ssh/config "$REMOTE_TOKEN" "$REMOTE_HOST":/home/ubuntu/
log_success "Файлы скопированы на удаленный сервер"

# Установка прав на удаленном сервере
log_info "⚙️ Устанавливаем права на удаленном сервере..."
ssh -F ~/.ssh/config "$REMOTE_HOST" "chmod +x /home/ubuntu/cloudbridge-client-remote"
log_success "Права установлены"

# Остановка предыдущих процессов
log_info "🛑 Останавливаем предыдущие процессы..."
pkill -f "cloudbridge-client" || true
ssh -F ~/.ssh/config "$REMOTE_HOST" "pkill -f 'cloudbridge-client-remote' || true"
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

# Тест P2P соединения
echo
log_info "🧪 Тестируем P2P соединение..."
echo "==============================="

# Создаем простой тест для проверки P2P соединения
cat > test-p2p-connection.py << 'EOF'
#!/usr/bin/env python3
import socket
import time
import json
import threading

RELAY_HOST = "edge.2gc.ru"
RELAY_PORT = 9090
BUFFER_SIZE = 65507
TIMEOUT = 5

def test_p2p_connection():
    print("🧪 Тест P2P соединения через relay сервер")
    print("=========================================")
    
    # Создаем UDP сокет для тестирования
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(TIMEOUT)
    
    try:
        # Отправляем тестовое сообщение
        test_message = {
            "type": "p2p_test",
            "from": "local-machine",
            "to": "remote-server",
            "message": "Hello from local machine!",
            "timestamp": time.time()
        }
        
        message_json = json.dumps(test_message)
        print(f"📤 Отправляем тестовое сообщение: {message_json}")
        
        sock.sendto(message_json.encode(), (RELAY_HOST, RELAY_PORT))
        print("✅ Сообщение отправлено на relay сервер")
        
        # Пытаемся получить ответ
        try:
            data, addr = sock.recvfrom(BUFFER_SIZE)
            response = json.loads(data.decode())
            print(f"📥 Получен ответ от {addr}: {response}")
            return True
        except socket.timeout:
            print("⏰ Timeout при получении ответа")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка при тестировании P2P: {e}")
        return False
    finally:
        sock.close()

if __name__ == "__main__":
    success = test_p2p_connection()
    if success:
        print("✅ P2P соединение работает")
    else:
        print("❌ P2P соединение не работает")
EOF

python3 test-p2p-connection.py

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
