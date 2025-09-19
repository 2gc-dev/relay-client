#!/bin/bash

# Скрипт для быстрого тестирования сборки

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "🚀 Быстрое тестирование CloudBridge Client"
echo "=============================================="

# Проверка зависимостей
log_info "Проверка зависимостей..."
if ! command -v go &> /dev/null; then
    log_error "Go не найден. Установите Go для продолжения."
    exit 1
fi

if ! command -v make &> /dev/null; then
    log_warning "Make не найден. Используем прямую сборку."
    USE_MAKE=false
else
    USE_MAKE=true
fi

log_success "Зависимости проверены"

# Сборка тестовой версии
log_info "Сборка тестовой версии..."
if [ "$USE_MAKE" = true ]; then
    make build-test VERSION=test-$(date +%Y%m%d-%H%M%S)
else
    chmod +x scripts/build-with-config.sh
    ./scripts/build-with-config.sh \
        --os $(go env GOOS) \
        --arch $(go env GOARCH) \
        --type test \
        --version "test-$(date +%Y%m%d-%H%M%S)" \
        --output-dir dist
fi

if [[ $? -eq 0 ]]; then
    log_success "Сборка завершена успешно"
else
    log_error "Ошибка сборки"
    exit 1
fi

# Поиск собранного файла
BINARY_PATH=$(find dist -name "cloudbridge-client-*" -type f -not -name "*.tar.gz" | head -1)
if [[ -z "$BINARY_PATH" ]]; then
    log_error "Собранный файл не найден"
    exit 1
fi

log_info "Найден бинарный файл: $BINARY_PATH"

# Тест версии
log_info "Тестирование команды version..."
"$BINARY_PATH" version

if [[ $? -eq 0 ]]; then
    log_success "Команда version работает"
else
    log_error "Ошибка команды version"
    exit 1
fi

# Тест help
log_info "Тестирование команды help..."
"$BINARY_PATH" --help > /dev/null

if [[ $? -eq 0 ]]; then
    log_success "Команда help работает"
else
    log_error "Ошибка команды help"
    exit 1
fi

# Тест P2P команды (без реального подключения)
log_info "Тестирование P2P команды..."
"$BINARY_PATH" p2p --help > /dev/null

if [[ $? -eq 0 ]]; then
    log_success "P2P команда работает"
else
    log_error "Ошибка P2P команды"
    exit 1
fi

# Проверка размера файла
FILE_SIZE=$(du -h "$BINARY_PATH" | cut -f1)
log_info "Размер файла: $FILE_SIZE"

# Проверка зависимостей
log_info "Проверка зависимостей бинарного файла..."
if command -v ldd &> /dev/null; then
    ldd "$BINARY_PATH" 2>/dev/null || log_info "Статически скомпилированный бинарный файл"
elif command -v otool &> /dev/null; then
    otool -L "$BINARY_PATH" 2>/dev/null || log_info "Статически скомпилированный бинарный файл"
else
    log_info "Не удалось проверить зависимости (ldd/otool не найден)"
fi

# Поиск конфигурационного файла
CONFIG_PATH=$(find dist -name "config-*.yaml" | head -1)
if [[ -n "$CONFIG_PATH" ]]; then
    log_info "Найден конфигурационный файл: $CONFIG_PATH"
    
    # Проверка конфигурации
    log_info "Проверка конфигурации..."
    if grep -q "demo-secret-key-for-testing-only" "$CONFIG_PATH"; then
        log_success "Конфигурация содержит тестовые данные"
    else
        log_warning "Конфигурация может содержать реальные данные"
    fi
else
    log_warning "Конфигурационный файл не найден"
fi

# Поиск пакета развертывания
PACKAGE_PATH=$(find dist -name "*.tar.gz" | head -1)
if [[ -n "$PACKAGE_PATH" ]]; then
    log_info "Найден пакет развертывания: $PACKAGE_PATH"
    PACKAGE_SIZE=$(du -h "$PACKAGE_PATH" | cut -f1)
    log_info "Размер пакета: $PACKAGE_SIZE"
else
    log_warning "Пакет развертывания не найден"
fi

echo ""
log_success "🎉 Быстрое тестирование завершено успешно!"
echo "=============================================="
echo "Бинарный файл: $BINARY_PATH"
if [[ -n "$CONFIG_PATH" ]]; then
    echo "Конфигурация: $CONFIG_PATH"
fi
if [[ -n "$PACKAGE_PATH" ]]; then
    echo "Пакет: $PACKAGE_PATH"
fi
echo "=============================================="
echo ""
echo "Для тестирования с реальными данными:"
echo "1. Получите JWT токен от DevOps команды"
echo "2. Создайте config.yaml с реальными данными"
echo "3. Запустите: $BINARY_PATH p2p --token YOUR_TOKEN --config config.yaml"
echo ""
