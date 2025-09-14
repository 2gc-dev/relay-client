# Локальное тестирование GitHub Actions Workflows

Этот документ описывает различные способы локального тестирования GitHub Actions workflows для проекта CloudBridge Client.

## 🚀 Быстрый старт

### 1. Ручное тестирование (рекомендуется)

Самый простой и надежный способ - запустить команды из workflow вручную:

```bash
# Запустить все тесты локально
make test-workflows
```

Этот скрипт выполняет все основные шаги из ваших workflows:
- ✅ Проверка Go версии
- ✅ Загрузка зависимостей
- ✅ Запуск тестов
- ✅ Сборка бинарника
- ✅ Тестирование команд
- ✅ Сборка для разных платформ
- ✅ Создание deployment пакета

### 2. Тестирование с act (требует Docker)

Для более точного воспроизведения GitHub Actions окружения:

```bash
# Установить Docker Desktop
brew install --cask docker

# Запустить Docker Desktop
open /Applications/Docker.app

# Протестировать workflows с act
make test-workflows-act
```

## 📋 Доступные команды

### Makefile команды

```bash
# Ручное тестирование (без Docker)
make test-workflows

# Тестирование с act (требует Docker)
make test-workflows-act

# Просмотр доступных workflows
make list-workflows

# Dry run с act
make test-workflows-dry-run
```

### Прямые команды

```bash
# Ручное тестирование
./test-workflow-local.sh

# Тестирование с act
./test-workflows-with-act.sh

# Список workflows
act -l

# Запуск конкретного job
act -j test-build --container-architecture linux/amd64
```

## 🔧 Настройка act

### 1. Установка

```bash
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

### 2. Конфигурация

Создайте файлы `.secrets` и `.env`:

```bash
# .secrets
JWT_SECRET=test-jwt-secret-for-local-testing
FALLBACK_SECRET=test-fallback-secret-for-local-testing
GITHUB_TOKEN=test-github-token

# .env
GO_VERSION=1.25
CGO_ENABLED=0
```

### 3. Docker настройки

Для Apple Silicon Mac:

```bash
# Используйте linux/amd64 архитектуру
act --container-architecture linux/amd64
```

## 🧪 Тестируемые Workflows

### 1. Build and Test CloudBridge Client (`build.yml`)

**Триггеры:** push, pull_request, release

**Jobs:**
- `test` - запуск тестов
- `build` - сборка для разных платформ
- `security` - сканирование безопасности
- `release` - создание релиза

**Локальное тестирование:**
```bash
# Тест job
act -j test --container-architecture linux/amd64

# Build job
act -j build --container-architecture linux/amd64

# Security job
act -j security --container-architecture linux/amd64
```

### 2. Deploy CloudBridge Client (`deploy.yml`)

**Триггеры:** workflow_dispatch (ручной запуск)

**Параметры:**
- `environment`: staging/production
- `version`: версия для деплоя

**Локальное тестирование:**
```bash
# Deploy в staging
act -j deploy --container-architecture linux/amd64 \
  -e <(echo '{"inputs":{"environment":"staging","version":"test"}}')
```

### 3. Release (`release.yml`)

**Триггеры:** push tags (v*)

**Локальное тестирование:**
```bash
# Release workflow
act -j release --container-architecture linux/amd64 \
  -e <(echo '{"ref":"refs/tags/v1.0.0"}')
```

### 4. Test Build (`test-build.yml`)

**Триггеры:** push, pull_request

**Локальное тестирование:**
```bash
# Test Build job
act -j test-build --container-architecture linux/amd64
```

## 🐛 Решение проблем

### Docker не запускается

```bash
# Перезапустить Docker Desktop
killall Docker && open /Applications/Docker.app

# Проверить статус
docker info
```

### Ошибки с credentials

```bash
# Очистить Docker credentials
docker logout

# Или использовать без credentials
act --container-architecture linux/amd64 --pull=false
```

### Проблемы с архитектурой на Apple Silicon

```bash
# Всегда указывайте архитектуру
act --container-architecture linux/amd64
```

### Workflow не найден

```bash
# Указать конкретный workflow файл
act -W .github/workflows/build.yml -j test
```

## 📊 Сравнение методов

| Метод | Требования | Точность | Скорость | Сложность |
|-------|------------|----------|----------|-----------|
| Ручное тестирование | Go | Средняя | Быстро | Низкая |
| act | Docker + Go | Высокая | Медленно | Средняя |
| GitHub Actions | - | Максимальная | Медленно | Низкая |

## 💡 Рекомендации

1. **Для быстрой проверки** - используйте `make test-workflows`
2. **Для точного воспроизведения** - используйте `act`
3. **Для финальной проверки** - запускайте в GitHub Actions
4. **Для отладки** - используйте `act` с verbose режимом: `act --verbose`

## 🔗 Полезные ссылки

- [act документация](https://github.com/nektos/act)
- [GitHub Actions документация](https://docs.github.com/en/actions)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
