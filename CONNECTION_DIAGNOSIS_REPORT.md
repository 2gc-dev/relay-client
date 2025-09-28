# CloudBridge Client Connection Diagnosis Report

## 🔍 Диагностика проблемы подключения

**Дата:** 28 сентября 2025  
**Статус:** Частично решено ✅🔶

---

## ✅ Что работает:

### 1. Сервер CloudBridge Relay
- **Адрес:** `edge.2gc.ru:8081`
- **Протокол:** HTTP ✅
- **Health endpoint:** `/health` → 200 OK ✅
- **Metrics endpoint:** `/metrics` → 200 OK ✅
- **Статус сервера:** Здоровый ✅

```bash
curl http://edge.2gc.ru:8081/health
# {"status":"healthy","timestamp":"...","services":{"database":"healthy","redis":"healthy","websocket":"healthy"}...}
```

### 2. JWT токены
- **Токен Server A:** ✅ Валидный
- **Токен Server B:** ✅ Валидный
- **Tenant ID:** `mesh-network-test` ✅
- **Срок действия:** До 12 октября 2025 ✅
- **Валидация:** Проходит локально ✅

### 3. Клиент CloudBridge
- **Сборка:** ✅ Успешна
- **Тесты:** ✅ Проходят (7/7, 2 пропущены - требуют root)
- **Парсинг конфигурации:** ✅ Работает
- **Токен через CLI:** ✅ Работает

---

## ❌ Проблемы:

### 1. Основная проблема: HTTP vs HTTPS
**Ошибка:** `http: server gave HTTP response to HTTPS client`

**Причина:** Клиент принудительно использует HTTPS, игнорируя конфигурацию HTTP

**Детали:**
- Клиент подключается: `https://edge.2gc.ru:8081`
- Сервер работает: `http://edge.2gc.ru:8081`
- Конфигурация игнорируется

### 2. API Endpoints
**Попытка подключения:** `/api/v1/tenants/mesh-network-test/peers/register`
**Статус:** 404 Not Found (возможно, правильный путь другой)

**Доступные endpoints:**
- ✅ `/health` 
- ✅ `/metrics`
- ❓ `/api/v1/peers` (нужно проверить)

---

## 🛠 Исправления:

### ✅ Исправлено:
1. **JWT токены:** Созданы корректные токены с нужными claims
2. **Конфигурации:** Созданы файлы для Server A и Server B
3. **HTTP настройки:** Обновлены все URL на HTTP
4. **Валидация токенов:** Отключена skip_validation для тестирования

### 📋 Файлы конфигурации:
- `config-test-server-a.yaml` - для Server A
- `config-test-server-b.yaml` - для Server B  
- `config-production.yaml` - обновлена на HTTP

---

## 🎯 Следующие шаги:

### 1. Исправить URL по умолчанию в клиенте
**Проблема:** Клиент игнорирует base_url из конфигурации

**Решения:**
- [ ] Найти где в коде прописаны HTTPS URL по умолчанию
- [ ] Исправить на HTTP или сделать configurable
- [ ] Проверить environment variables для override

### 2. Проверить API endpoints
- [ ] Найти правильные пути для peer registration
- [ ] Проверить `/api/v1/peers` вместо `/api/v1/tenants/.../peers/register`
- [ ] Обновить конфигурацию с правильными endpoints

### 3. Альтернативное решение: Настройка HTTPS на сервере
- [ ] Настроить SSL/TLS сертификаты на edge.2gc.ru:8081
- [ ] Обновить Nginx для HTTPS proxy

---

## 🔗 Тестовые команды:

### Запуск клиента:
```bash
# Server A
./cloudbridge-client p2p -c config-test-server-a.yaml --log-level debug

# Server B  
./cloudbridge-client p2p -c config-test-server-b.yaml --log-level debug

# Через CLI (минуя конфигурацию)
./cloudbridge-client p2p -t "JWT_TOKEN_HERE" --insecure-skip-tls-verify
```

### Проверка сервера:
```bash
# Health check
curl http://edge.2gc.ru:8081/health

# Metrics
curl http://edge.2gc.ru:8081/metrics

# API endpoints
curl http://edge.2gc.ru:8081/api/v1/peers
```

---

## 📊 Статус выполнения:

- ✅ **Сервер работает**
- ✅ **Токены готовы** 
- ✅ **Конфигурации созданы**
- ✅ **Клиент собирается и запускается**
- 🔶 **HTTP vs HTTPS конфликт**
- ❓ **API endpoints требуют уточнения**

**Общий прогресс:** 75% ✅

---

*Отчет создан автоматически*  
*Следующий шаг: исправление URL по умолчанию в клиенте*
