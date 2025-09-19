#!/bin/bash

# Скрипт для развертывания клиента на удаленном сервере и тестирования P2P соединения
# Цель: протестировать связь между локальной машиной и удаленным сервером через relay

echo "🚀 Развертывание и тестирование P2P соединения между серверами"
echo "=============================================================="
echo "Локальная машина: $(hostname)"
echo "Удаленный сервер: zabbix-server (212.233.79.160)"
echo "Relay сервер: edge.2gc.ru"
echo "Время: $(date)"
echo

# Проверяем, что файлы существуют
if [ ! -f "cloudbridge-client-linux-amd64" ]; then
    echo "❌ Ошибка: cloudbridge-client-linux-amd64 не найден"
    echo "Сначала скомпилируйте клиент для Linux:"
    echo "GOOS=linux GOARCH=amd64 go build -o cloudbridge-client-linux-amd64 ./cmd/cloudbridge-client"
    exit 1
fi

if [ ! -f "token2-clean.txt" ]; then
    echo "❌ Ошибка: token2-clean.txt не найден"
    exit 1
fi

if [ ! -f "config-remote-server.yaml" ]; then
    echo "❌ Ошибка: config-remote-server.yaml не найден"
    exit 1
fi

echo "✅ Все необходимые файлы найдены"

# Копируем файлы на удаленный сервер
echo
echo "📤 Копируем файлы на удаленный сервер..."
scp -F ~/.ssh/config cloudbridge-client-linux-amd64 zabbix-server:~/cloudbridge-client
scp -F ~/.ssh/config config-remote-server.yaml zabbix-server:~/config.yaml
scp -F ~/.ssh/config token2-clean.txt zabbix-server:~/token.txt

echo "✅ Файлы скопированы на удаленный сервер"

# Запускаем клиент на удаленном сервере
echo
echo "🚀 Запускаем клиент на удаленном сервере..."
ssh -F ~/.ssh/config zabbix-server << 'EOF'
cd ~
chmod +x cloudbridge-client
echo "Запускаем клиент на удаленном сервере..."
./cloudbridge-client p2p --config config.yaml --token $(cat token.txt) --log-level debug > client-remote.log 2>&1 &
CLIENT_PID=$!
echo "Client PID: $CLIENT_PID"
echo $CLIENT_PID > client.pid
sleep 10
echo "Проверяем статус клиента..."
if ps -p $CLIENT_PID > /dev/null; then
    echo "✅ Клиент работает на удаленном сервере (PID: $CLIENT_PID)"
    echo "Последние 10 строк лога:"
    tail -10 client-remote.log
else
    echo "❌ Клиент остановлен на удаленном сервере"
    echo "Лог ошибок:"
    cat client-remote.log
fi
EOF

# Ждем немного
sleep 5

# Запускаем клиент на локальной машине
echo
echo "🚀 Запускаем клиент на локальной машине..."
TOKEN=$(cat token1-clean.txt)
./cloudbridge-client p2p --config config-test-quic.yaml --token "$TOKEN" --log-level debug > client-local.log 2>&1 &
LOCAL_CLIENT_PID=$!
echo "Local Client PID: $LOCAL_CLIENT_PID"

# Ждем установки соединений
echo
echo "⏳ Ждем 30 секунд для установки соединений..."
sleep 30

# Проверяем статус клиентов
echo
echo "📊 Проверяем статус клиентов..."
echo "================================"

echo "Локальный клиент (PID: $LOCAL_CLIENT_PID):"
if ps -p $LOCAL_CLIENT_PID > /dev/null; then
    echo "✅ Локальный клиент работает"
    echo "Последние 10 строк лога:"
    tail -10 client-local.log
else
    echo "❌ Локальный клиент остановлен"
    echo "Лог ошибок:"
    cat client-local.log
fi

echo
echo "Удаленный клиент:"
ssh -F ~/.ssh/config zabbix-server << 'EOF'
if [ -f client.pid ]; then
    CLIENT_PID=$(cat client.pid)
    if ps -p $CLIENT_PID > /dev/null; then
        echo "✅ Удаленный клиент работает (PID: $CLIENT_PID)"
        echo "Последние 10 строк лога:"
        tail -10 client-remote.log
    else
        echo "❌ Удаленный клиент остановлен"
        echo "Лог ошибок:"
        cat client-remote.log
    fi
else
    echo "❌ PID файл не найден"
fi
EOF

# Проверяем сетевые интерфейсы
echo
echo "🌐 Проверяем сетевые интерфейсы..."
echo "=================================="

echo "Локальные интерфейсы с IP 10.x.x.x:"
ifconfig | grep -A 2 "inet 10\." || echo "Нет интерфейсов с IP 10.x.x.x"

echo
echo "Удаленные интерфейсы с IP 10.x.x.x:"
ssh -F ~/.ssh/config zabbix-server "ip addr show | grep -A 2 'inet 10\.' || echo 'Нет интерфейсов с IP 10.x.x.x'"

# Тестируем связь между серверами
echo
echo "🧪 Тестируем связь между серверами..."
echo "====================================="

# Создаем тест связи
cat > test-server-communication.py << 'EOF'
#!/usr/bin/env python3
import socket
import time
import json
import sys

def test_communication():
    print("🧪 Тест связи между серверами через relay...")
    
    # Отправляем тестовое сообщение через relay
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(10)
    
    try:
        # Тестовое сообщение для удаленного сервера
        message = {
            "type": "server_test",
            "from": "local-server",
            "to": "remote-server",
            "message": "Hello from local server to remote server",
            "timestamp": time.time()
        }
        
        data = json.dumps(message).encode('utf-8')
        sock.sendto(data, ("edge.2gc.ru", 9090))
        print("✅ Отправлено тестовое сообщение на relay для удаленного сервера")
        
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

python3 test-server-communication.py

# Останавливаем клиентов
echo
echo "🛑 Останавливаем клиентов..."
kill $LOCAL_CLIENT_PID 2>/dev/null || true
ssh -F ~/.ssh/config zabbix-server "if [ -f client.pid ]; then kill \$(cat client.pid) 2>/dev/null || true; fi"

# Финальный отчет
echo
echo "📋 ФИНАЛЬНЫЙ ОТЧЕТ"
echo "=================="
echo "Время завершения: $(date)"
echo
echo "Логи локального клиента: client-local.log"
echo "Логи удаленного клиента: проверьте на сервере zabbix-server"
echo
echo "Для просмотра логов удаленного сервера:"
echo "  ssh -F ~/.ssh/config zabbix-server 'cat client-remote.log'"
echo
echo "Для поиска ошибок:"
echo "  grep -i error client-local.log"
echo "  ssh -F ~/.ssh/config zabbix-server 'grep -i error client-remote.log'"

# Очистка
rm -f test-server-communication.py

echo
echo "✅ Тест завершен!"


