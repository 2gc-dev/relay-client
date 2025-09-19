#!/bin/bash

# Скрипт для тестирования скорости P2P канала через relay сервер
# Использует iperf3 для измерения пропускной способности

echo "🚀 Тестирование скорости P2P канала через relay сервер"
echo "=================================================="

# Конфигурация
RELAY_HOST="edge.2gc.ru"
RELAY_PORT="9090"  # QUIC порт
LOCAL_IP="192.168.1.119"  # IP локальной машины
REMOTE_IP="212.233.79.160"  # IP удаленного сервера

echo "📊 Параметры тестирования:"
echo "  Relay сервер: $RELAY_HOST:$RELAY_PORT"
echo "  Локальная машина: $LOCAL_IP"
echo "  Удаленный сервер: $REMOTE_IP"
echo

# Функция для тестирования UDP
test_udp_speed() {
    echo "🔵 Тест 1: UDP скорость (через relay)"
    echo "----------------------------------------"
    
    # Запускаем iperf3 сервер на удаленной машине
    echo "Запускаем iperf3 сервер на удаленном сервере..."
    ssh -F ~/.ssh/config zabbix-server "iperf3 -s -p 5201 -D" 2>/dev/null
    
    sleep 2
    
    # Тестируем UDP с разными размерами пакетов
    echo "Тестируем UDP с разными размерами пакетов..."
    
    for packet_size in 1470 1024 512 256; do
        echo "  📦 Размер пакета: $packet_size байт"
        iperf3 -c $REMOTE_IP -p 5201 -u -l $packet_size -t 10 -b 10M 2>/dev/null | grep -E "(Mbits/sec|KBytes/sec|lost)"
    done
    
    # Останавливаем сервер
    ssh -F ~/.ssh/config zabbix-server "pkill iperf3" 2>/dev/null
    echo
}

# Функция для тестирования TCP
test_tcp_speed() {
    echo "🟢 Тест 2: TCP скорость (через relay)"
    echo "----------------------------------------"
    
    # Запускаем iperf3 сервер на удаленной машине
    echo "Запускаем iperf3 сервер на удаленном сервере..."
    ssh -F ~/.ssh/config zabbix-server "iperf3 -s -p 5201 -D" 2>/dev/null
    
    sleep 2
    
    # Тестируем TCP
    echo "Тестируем TCP соединение..."
    iperf3 -c $REMOTE_IP -p 5201 -t 30 2>/dev/null | grep -E "(Mbits/sec|KBytes/sec|retr)"
    
    # Останавливаем сервер
    ssh -F ~/.ssh/config zabbix-server "pkill iperf3" 2>/dev/null
    echo
}

# Функция для тестирования через relay сервер напрямую
test_relay_direct() {
    echo "🟡 Тест 3: Прямое тестирование через relay"
    echo "----------------------------------------"
    
    echo "Тестируем доступность relay сервера..."
    nc -u -w 3 $RELAY_HOST $RELAY_PORT < /dev/null 2>/dev/null && echo "✅ Relay доступен" || echo "❌ Relay недоступен"
    
    echo "Тестируем задержку до relay..."
    ping -c 3 $RELAY_HOST 2>/dev/null | grep "round-trip"
    echo
}

# Функция для тестирования P2P туннеля (если доступен)
test_p2p_tunnel() {
    echo "🟣 Тест 4: P2P туннель (если доступен)"
    echo "----------------------------------------"
    
    # Проверяем туннельные интерфейсы на удаленном сервере
    echo "Проверяем туннельные интерфейсы на удаленном сервере..."
    ssh -F ~/.ssh/config zabbix-server "ip addr show | grep -A 2 '10\.' | grep inet"
    
    # Проверяем туннельные интерфейсы на локальной машине
    echo "Проверяем туннельные интерфейсы на локальной машине..."
    ifconfig | grep -A 2 "inet 10\." || echo "Туннельные интерфейсы не найдены"
    echo
}

# Основная функция
main() {
    echo "Начинаем тестирование..."
    echo
    
    # Проверяем доступность iperf3
    if ! command -v iperf3 &> /dev/null; then
        echo "❌ iperf3 не установлен на локальной машине"
        exit 1
    fi
    
    if ! ssh -F ~/.ssh/config zabbix-server "command -v iperf3" &> /dev/null; then
        echo "❌ iperf3 не установлен на удаленном сервере"
        exit 1
    fi
    
    echo "✅ iperf3 доступен на обеих машинах"
    echo
    
    # Запускаем тесты
    test_relay_direct
    test_p2p_tunnel
    
    # Тестируем скорость (если прямое соединение возможно)
    echo "Попытка тестирования скорости..."
    if ping -c 1 -W 3 $REMOTE_IP &> /dev/null; then
        test_tcp_speed
        test_udp_speed
    else
        echo "⚠️  Прямое соединение недоступно, тестируем через relay..."
        echo "Для полного тестирования P2P канала нужно дождаться установки туннеля"
    fi
    
    echo "\n🧪 Дополнительно: E2E QUIC тест (9091)"
    echo "----------------------------------------"
    # 1) Поднимаем приемник на удаленной машине
    ssh -F ~/.ssh/config zabbix-server '
      set -e
      cd ~/cloudbridge-test || exit 1
      pkill -f quic-tester || true
      chmod +x ./quic-tester || true
      nohup ./quic-tester --mode=recv --token="$(cat token.txt)" --host=edge.2gc.ru --port=9091 --timeout=25s > recv.log 2>&1 &
      echo $! > recv.pid
      sleep 2
      echo -n "REMOTE PID: "; cat recv.pid
      tail -n 5 recv.log || true
    '

    # 2) Отправляем локально сообщение A -> B
    if [ -x "./bin/quic-tester" ]; then
      TOKEN1=$(cat token-client1.txt 2>/dev/null)
      if [ -n "$TOKEN1" ]; then
        echo "\nОтправляем сообщение через quic-tester (локально -> удаленный peer)..."
        ./bin/quic-tester --mode=send --token="$TOKEN1" --host=edge.2gc.ru --port=9091 --to=peer_server-1758248075566 --msg="hello-from-A" --timeout=25s || true
      else
        echo "⚠️  Не найден token-client1.txt для локальной отправки"
      fi
    else
      echo "⚠️  quic-tester не найден в ./bin/quic-tester — пропускаем отправку"
    fi

    # 3) Читаем логи приемника
    echo "\nЛоги приемника на удаленной машине:"
    ssh -F ~/.ssh/config zabbix-server 'cd ~/cloudbridge-test && tail -n 50 recv.log || true'

    echo "\n🏁 Тестирование завершено"
}

# Запускаем основную функцию
main "$@"
