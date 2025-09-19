#!/bin/bash

# Скрипт для тестирования скорости через QUIC Transport
# Использует UDP для имитации QUIC трафика

echo "🚀 Тестирование скорости через QUIC Transport"
echo "=============================================="

RELAY_HOST="edge.2gc.ru"
QUIC_PORT="9090"
ENHANCED_QUIC_PORT="9092"
STUN_PORT="19302"
TEST_DURATION=10
PACKET_SIZES=(1470 1024 512 256 128)

# Функция для тестирования UDP скорости
test_udp_speed() {
    local port=$1
    local port_name=$2
    
    echo "🔵 Тест UDP скорости через $port_name (порт $port)"
    echo "------------------------------------------------"
    
    for size in "${PACKET_SIZES[@]}"; do
        echo "📦 Тестируем пакеты размером $size байт..."
        
        # Отправляем UDP пакеты
        local start_time=$(date +%s)
        local packets_sent=0
        
        (
            for i in $(seq 1 $((TEST_DURATION * 10))); do
                dd if=/dev/zero bs=$size count=1 2>/dev/null
                packets_sent=$((packets_sent + 1))
                sleep 0.1
            done
        ) | nc -u -w 1 $RELAY_HOST $port 2>/dev/null &
        
        local nc_pid=$!
        sleep $TEST_DURATION
        kill $nc_pid 2>/dev/null
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local total_bytes=$((packets_sent * size))
        local speed_mbps=$((total_bytes * 8 / duration / 1024 / 1024))
        
        echo "  ✅ Отправлено $packets_sent пакетов за ${duration}с"
        echo "  📊 Скорость: ~${speed_mbps} Mbps"
        echo
    done
}

# Функция для тестирования задержки
test_latency() {
    echo "🟡 Тест задержки до relay сервера"
    echo "---------------------------------"
    
    echo "Измеряем задержку до relay сервера..."
    ping -c 5 $RELAY_HOST 2>/dev/null | grep "round-trip" || echo "Ping недоступен, но это нормально для серверов"
    echo
}

# Функция для тестирования STUN сервера
test_stun_server() {
    echo "🟢 Тест STUN сервера"
    echo "--------------------"
    
    echo "Тестируем STUN сервер на порту $STUN_PORT..."
    
    # Простая проверка доступности STUN порта
    if nc -u -z -w 3 $RELAY_HOST $STUN_PORT 2>/dev/null; then
        echo "✅ STUN сервер доступен"
        
        # Отправляем тестовые данные на STUN
        echo "Отправляем тестовые данные на STUN сервер..."
        echo "STUN_TEST_$(date +%s)" | nc -u -w 1 $RELAY_HOST $STUN_PORT 2>/dev/null
        echo "✅ Данные отправлены на STUN сервер"
    else
        echo "❌ STUN сервер недоступен"
    fi
    echo
}

# Функция для тестирования P2P API
test_p2p_api() {
    echo "🟣 Тест P2P API"
    echo "---------------"
    
    echo "Тестируем P2P API на порту 8083..."
    
    # Проверяем доступность P2P API
    if nc -z -w 3 $RELAY_HOST 8083 2>/dev/null; then
        echo "✅ P2P API доступен"
        
        # Тестируем HTTP запрос
        echo "Тестируем HTTP запрос к P2P API..."
        curl -s -w "Время ответа: %{time_total}с\n" -o /dev/null "http://$RELAY_HOST:8083/health" 2>/dev/null || echo "HTTP запрос не удался"
    else
        echo "❌ P2P API недоступен"
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

# Функция для тестирования с iperf3 (если доступен)
test_with_iperf3() {
    echo "🔴 Тест с iperf3 (если доступен)"
    echo "--------------------------------"
    
    if command -v iperf3 &> /dev/null; then
        echo "iperf3 доступен, тестируем UDP скорость..."
        
        # Тестируем UDP с разными размерами пакетов
        for size in 1470 1024 512; do
            echo "📦 Тест с размером пакета $size байт:"
            timeout 10s iperf3 -c $RELAY_HOST -p $QUIC_PORT -u -l $size -t 5 -b 10M 2>/dev/null | grep -E "(Mbits/sec|KBytes/sec|lost)" || echo "Тест не удался"
        done
    else
        echo "iperf3 недоступен, пропускаем тест"
    fi
    echo
}

# Основная функция
main() {
    echo "Начинаем тестирование скорости через QUIC Transport..."
    echo
    
    # Проверяем доступность relay сервера
    if ! nc -u -z -w 3 $RELAY_HOST $QUIC_PORT 2>/dev/null; then
        echo "❌ QUIC порт $QUIC_PORT недоступен"
        exit 1
    fi
    
    echo "✅ QUIC порт $QUIC_PORT доступен"
    echo
    
    # Запускаем тесты
    test_latency
    test_stun_server
    test_p2p_api
    test_udp_speed $QUIC_PORT "QUIC Transport"
    test_udp_speed $ENHANCED_QUIC_PORT "Enhanced QUIC"
    test_with_iperf3
    monitor_network_traffic
    
    echo "⚠️  Для полного тестирования P2P канала нужно:"
    echo "   1. Дождаться создания туннельных интерфейсов на локальной машине"
    echo "   2. Использовать внутренние IP адреса (10.100.77.x)"
    echo "   3. Настроить маршрутизацию через туннель"
    echo
    
    echo "🏁 Тестирование завершено"
}

# Запускаем основную функцию
main "$@"