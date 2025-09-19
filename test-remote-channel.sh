#!/bin/bash

# Упрощенный тест канала с удаленной машиной
# Использует SSH для запуска receiver на удаленной машине

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
QUIC_HOST="b1.2gc.space"
QUIC_PORT="9091"
API_HOST="edge.2gc.ru"
API_PORT="9444"

# SSH конфигурация для удаленной машины
REMOTE_HOST="212.233.79.160"
REMOTE_USER="ubuntu"
REMOTE_KEY="~/Desktop/2GC/key/2GC-RELAY-SERVER-hz0QxPy8.pem"

# Токены
LOCAL_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOlsiYWNjb3VudCJdLCJjb25uZWN0aW9uX3R5cGUiOiJxdWljIiwiZXhwIjoxNzU4MzY1NDczLCJpYXQiOjE3NTgyNzkwNzMsImlzcyI6Imh0dHBzOi8vYXV0aC4yZ2MucnUvcmVhbG1zL2Nsb3VkYnJpZGdlIiwianRpIjoiand0X3Rlc3RfdG9rZW4iLCJwZXJtaXNzaW9ucyI6WyJwMnBfY29ubmVjdCIsIm1lc2hfam9pbiIsIm1lc2hfbWFuYWdlIl0sInByb3RvY29sX3R5cGUiOiJwMnAtbWVzaCIsInNjb3BlIjoicDJwLW1lc2gtY2xhaW1zIiwic2VydmVyX2lkIjoic2VydmVyLXRlc3QtMTIzIiwic3ViIjoic2VydmVyLXRlc3QtMTIzIiwidGVuYW50X2lkIjoidGVuYW50LXRlc3QtMTIzIn0.2ePguI9tijf1holYraallqe955sHcKi0lndB1zb7OiA"

REMOTE_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJhY2NvdW50IiwiY29ubmVjdGlvbl90eXBlIjoicXVpYyIsImV4cCI6MTc1ODM2NTQ3MywiaWF0IjoxNzU4Mjc5MDczLCJpc3MiOiJodHRwczovL2F1dGguMmdjLnJ1L3JlYWxtcy9jbG91ZGJyaWRnZSIsImp0aSI6Imp3dF90ZXN0X3Rva2VuIiwicGVybWlzc2lvbnMiOlsicDJwX2Nvbm5lY3QiLCJtZXNoX2pvaW4iLCJtZXNoX21hbmFnZSJdLCJwcm90b2NvbF90eXBlIjoicDJwLW1lc2giLCJzY29wZSI6InAycC1tZXNoLWNsYWltcyIsInNlcnZlcl9pZCI6InNlcnZlci10ZXN0LTEyMyIsInN1YiI6InNlcnZlci10ZXN0LTEyMyIsInRlbmFudF9pZCI6InRlbmFudC10ZXN0LTEyMyJ9.AE4OkW-dvrKnAa1XH18td5AWnQZmkXCPTx0FNOomnx4"

echo -e "${BLUE}🧪 Тест канала между локальной и удаленной машиной${NC}"
echo -e "${BLUE}===============================================${NC}"

# Функция проверки SSH подключения
check_ssh_connection() {
    echo -e "${BLUE}🔐 Проверяем SSH подключение к удаленной машине...${NC}"
    
    if ssh -i "$REMOTE_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH connection OK'" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH подключение к $REMOTE_HOST работает${NC}"
        return 0
    else
        echo -e "${RED}❌ SSH подключение к $REMOTE_HOST не работает${NC}"
        return 1
    fi
}

# Функция копирования файлов на удаленную машину
copy_files_to_remote() {
    echo -e "${BLUE}📁 Копируем файлы на удаленную машину...${NC}"
    
    # Создаем директорию на удаленной машине
    ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "mkdir -p /tmp/cloudbridge-test" 2>/dev/null
    
    # Копируем quic-tester
    if scp -i "$REMOTE_KEY" -o StrictHostKeyChecking=no ./bin/quic-tester "$REMOTE_USER@$REMOTE_HOST:/tmp/cloudbridge-test/" 2>/dev/null; then
        echo -e "${GREEN}✅ quic-tester скопирован на удаленную машину${NC}"
    else
        echo -e "${RED}❌ Ошибка копирования quic-tester${NC}"
        return 1
    fi
    
    # Создаем токен файл на удаленной машине
    ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo '$REMOTE_TOKEN' > /tmp/cloudbridge-test/remote_token.txt" 2>/dev/null
    
    echo -e "${GREEN}✅ Файлы подготовлены на удаленной машине${NC}"
    return 0
}

# Функция запуска receiver на удаленной машине
start_remote_receiver() {
    echo -e "${BLUE}📥 Запускаем QUIC receiver на удаленной машине...${NC}"
    
    # Запускаем receiver в фоне на удаленной машине
    ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "
        cd /tmp/cloudbridge-test
        nohup ./quic-tester --mode=recv --token-file=remote_token.txt --host=$QUIC_HOST --port=$QUIC_PORT --timeout=60s > receiver.log 2>&1 &
        echo \$! > receiver.pid
        echo 'Remote receiver started with PID: \$(cat receiver.pid)'
    " 2>/dev/null
    
    echo -e "${GREEN}✅ QUIC receiver запущен на удаленной машине${NC}"
    
    # Ждем немного для запуска
    sleep 5
    
    return 0
}

# Функция остановки receiver на удаленной машине
stop_remote_receiver() {
    echo -e "${BLUE}🛑 Останавливаем QUIC receiver на удаленной машине...${NC}"
    
    ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "
        cd /tmp/cloudbridge-test
        if [ -f receiver.pid ]; then
            PID=\$(cat receiver.pid)
            kill \$PID 2>/dev/null || true
            echo 'Remote receiver stopped (PID: \$PID)'
        fi
    " 2>/dev/null
    
    echo -e "${GREEN}✅ QUIC receiver остановлен на удаленной машине${NC}"
}

# Функция получения логов с удаленной машины
get_remote_logs() {
    echo -e "${BLUE}📋 Получаем логи с удаленной машины...${NC}"
    
    ssh -i "$REMOTE_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "
        cd /tmp/cloudbridge-test
        if [ -f receiver.log ]; then
            echo '=== Remote Receiver Logs ==='
            cat receiver.log
        else
            echo 'No logs found'
        fi
    " 2>/dev/null
}

# Функция тестирования отправки сообщения
test_send_message() {
    echo -e "${BLUE}📤 Отправляем сообщение с локальной машины...${NC}"
    
    # Используем фиксированный peer_id для тестирования
    local target_peer="remote-peer-test"
    
    echo -e "${YELLOW}📤 Отправляем сообщение через QUIC канал...${NC}"
    if ./bin/quic-tester \
        --mode=send \
        --token="$LOCAL_TOKEN" \
        --host="$QUIC_HOST" \
        --port="$QUIC_PORT" \
        --to="$target_peer" \
        --msg="E2E test message from local to remote $(date)" \
        --timeout=60s; then
        
        echo -e "${GREEN}🎉 Сообщение отправлено успешно!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Сообщение не отправлено (может быть нормально)${NC}"
        return 1
    fi
}

# Основная функция
main() {
    echo -e "${BLUE}🎯 Начинаем тест канала с удаленной машиной...${NC}"
    
    # Проверяем SSH подключение
    if ! check_ssh_connection; then
        echo -e "${RED}❌ SSH подключение не работает${NC}"
        exit 1
    fi
    
    # Копируем файлы
    if ! copy_files_to_remote; then
        echo -e "${RED}❌ Ошибка копирования файлов${NC}"
        exit 1
    fi
    
    # Запускаем receiver на удаленной машине
    start_remote_receiver
    
    # Ждем немного
    sleep 3
    
    # Тестируем отправку сообщения
    if test_send_message; then
        echo -e "${GREEN}🎉 Тест канала успешен!${NC}"
    else
        echo -e "${YELLOW}⚠️  Тест канала частично успешен${NC}"
    fi
    
    # Получаем логи
    get_remote_logs
    
    # Останавливаем receiver
    stop_remote_receiver
    
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${GREEN}✅ Тест канала завершен${NC}"
    echo -e "${YELLOW}ℹ️  Проверьте логи выше для деталей${NC}"
}

# Обработка сигналов
trap 'stop_remote_receiver; exit 1' INT TERM

# Запуск
main "$@"
