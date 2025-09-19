#!/bin/bash

# Скрипт для тестирования скорости через relay сервер
# Использует UDP для тестирования пропускной способности

echo "🚀 Тестирование скорости через relay сервер"
echo "============================================="

RELAY_HOST="edge.2gc.ru"
RELAY_PORT="9090"  # QUIC порт
TEST_DURATION=10
PACKET_SIZES=(1470 1024 512 256 128)

# Функция для тестирования UDP через relay
test_udp_via_relay() {
    echo "🔵 Тест UDP через relay сервер"
    echo "------------------------------"
    
    for size in "${PACKET_SIZES[@]}"; do
        echo "📦 Тестируем пакеты размером $size байт..."
        
        # Отправляем UDP пакеты на relay сервер
        echo "Отправляем $TEST_DURATION секунд трафика на relay..."
        
        # Используем nc для отправки данных
        (
            for i in $(seq 1 $((TEST_DURATION * 10))); do
                dd if=/dev/zero bs=$size count=1 2>/dev/null
                sleep 0.1
            done
        ) | nc -u -w 1 $RELAY_HOST $RELAY_PORT 2>/dev/null &
        
        local nc_pid=$!
        sleep $TEST_DURATION
        kill $nc_pid 2>/dev/null
        
        echo "✅ Тест завершен для размера $size байт"
        echo
    done
}

# Функция для тестирования задержки
test_latency() {
    echo "🟡 Тест задержки до relay сервера"
    echo "---------------------------------"
    
    echo "Измеряем задержку до relay сервера..."
    ping -c 10 $RELAY_HOST 2>/dev/null | grep "round-trip" || echo "Ping недоступен"
    echo
}

# Функция для тестирования доступности портов
test_port_availability() {
    echo "🟢 Тест доступности портов relay сервера"
    echo "----------------------------------------"
    
    local ports=(8080 8082 8083 9090 9092 19302 8443 9444)
    
    for port in "${ports[@]}"; do
        echo -n "Порт $port: "
        if nc -z -w 3 $RELAY_HOST $port 2>/dev/null; then
            echo "✅ Открыт"
        else
            echo "❌ Закрыт"
        fi
    done
    echo
}

# Функция для тестирования QUIC соединения
test_quic_connection() {
    echo "🟣 Тест QUIC соединения"
    echo "-----------------------"
    
    echo "Попытка установить QUIC соединение с relay..."
    
    # Простая проверка доступности QUIC порта
    if nc -u -z -w 3 $RELAY_HOST $RELAY_PORT 2>/dev/null; then
        echo "✅ QUIC порт $RELAY_PORT доступен"
        
        # Отправляем тестовые данные
        echo "Отправляем тестовые данные..."
        echo "TEST_DATA_$(date +%s)" | nc -u -w 1 $RELAY_HOST $RELAY_PORT 2>/dev/null
        echo "✅ Данные отправлены"
    else
        echo "❌ QUIC порт $RELAY_PORT недоступен"
    fi
    echo
}

# Функция для мониторинга сетевого трафика
monitor_network_traffic() {
    echo "📊 Мониторинг сетевого трафика"
    echo "------------------------------"
    
    echo "Активные соединения к relay серверу:"
    netstat -an | grep "$RELAY_HOST" | head -5
    echo
    
    echo "UDP соединения:"
    netstat -an | grep "udp.*$RELAY_HOST" | head -3
    echo
}

# Основная функция
main() {
    echo "Начинаем тестирование скорости через relay сервер..."
    echo
    
    # Проверяем доступность relay сервера
    if ! ping -c 1 -W 3 $RELAY_HOST &> /dev/null; then
        echo "❌ Relay сервер $RELAY_HOST недоступен"
        exit 1
    fi
    
    echo "✅ Relay сервер $RELAY_HOST доступен"
    echo
    
    # Запускаем тесты
    test_port_availability
    test_latency
    test_quic_connection
    monitor_network_traffic
    
    echo "⚠️  Для полного тестирования P2P канала нужно:"
    echo "   1. Дождаться установки туннельных интерфейсов"
    echo "   2. Использовать внутренние IP адреса туннеля"
    echo "   3. Настроить маршрутизацию через туннель"
    echo
    
    echo "🏁 Тестирование завершено"
}

# Запускаем основную функцию
main "$@"
