# 🚀 GitHub Actions Setup Guide

## 📋 **Настройка CI/CD для CloudBridge Client**

Этот документ описывает, как настроить GitHub Actions для автоматической сборки, тестирования и развертывания CloudBridge Client.

---

## 🔧 **Настройка Секретов в GitHub**

### **1. Перейдите в настройки репозитория:**
```
Settings → Secrets and variables → Actions
```

### **2. Добавьте следующие секреты:**

#### **🔐 Обязательные секреты:**
- **`JWT_SECRET`** - Основной JWT секрет для валидации токенов
- **`FALLBACK_SECRET`** - Fallback секрет для токенов с `kid: "fallback-key"`

#### **🌐 Опциональные секреты:**
- **`RELAY_HOST`** - Хост relay сервера (например: `edge.2gc.ru`)
- **`TEST_JWT_TOKEN`** - Тестовый JWT токен для валидации
- **`STAGING_HOST`** - Хост для staging развертывания
- **`PRODUCTION_HOST`** - Хост для production развертывания

### **3. Добавьте переменные окружения:**
```
Settings → Secrets and variables → Actions → Variables
```

#### **📊 Переменные:**
- **`GO_VERSION`** - Версия Go (по умолчанию: `1.25`)
- **`RELAY_PORT`** - Порт relay сервера (по умолчанию: `9090`)

---

## 🏗️ **Workflow Файлы**

### **1. `build.yml` - Сборка и тестирование**
- ✅ Автоматическая сборка для Linux, Windows, macOS
- ✅ Запуск тестов и линтера
- ✅ Сканирование безопасности
- ✅ Создание релизов

### **2. `deploy.yml` - Развертывание**
- ✅ Ручное развертывание в staging/production
- ✅ Использование секретов для конфигурации
- ✅ Создание deployment пакетов
- ✅ Автоматическое создание systemd сервисов

### **3. `test-with-secrets.yml` - Тестирование с секретами**
- ✅ Тестирование JWT валидации
- ✅ Тестирование подключения к relay серверу
- ✅ Полное интеграционное тестирование

---

## 🚀 **Запуск Workflows**

### **Автоматические триггеры:**
- **Push в main/develop** → Запуск сборки и тестов
- **Pull Request** → Запуск сборки и тестов
- **Release** → Создание релиза с артефактами

### **Ручные триггеры:**
- **Deploy** → Развертывание в выбранную среду
- **Test with Secrets** → Тестирование с секретными ключами

---

## 🔒 **Безопасность**

### **✅ Что защищено:**
- Все секреты хранятся в GitHub Secrets
- Секреты не логируются в выводе
- Доступ к секретам только для authorized workflows
- Environment-specific секреты

### **⚠️ Важные моменты:**
- Никогда не коммитьте секреты в код
- Используйте environment-specific секреты
- Регулярно ротируйте секреты
- Мониторьте доступ к секретам

---

## 📊 **Мониторинг**

### **Статус сборок:**
- Проверяйте статус в разделе "Actions"
- Настройте уведомления о failed builds
- Мониторьте время выполнения

### **Логи:**
- Все логи доступны в GitHub Actions
- Секреты автоматически маскируются
- Детальная информация о каждом шаге

---

## 🛠️ **Локальная разработка**

### **Тестирование workflows локально:**
```bash
# Установите act для локального тестирования
npm install -g @nektos/act

# Запустите workflow локально
act -s JWT_SECRET="your-secret" -s FALLBACK_SECRET="your-fallback"
```

### **Проверка конфигурации:**
```bash
# Проверьте синтаксис YAML
yamllint .github/workflows/*.yml

# Проверьте Go код
golangci-lint run
```

---

## 🎯 **Примеры использования**

### **1. Развертывание в staging:**
```
Actions → Deploy CloudBridge Client → Run workflow
Environment: staging
Version: latest
```

### **2. Тестирование JWT:**
```
Actions → Test with Secrets → Run workflow
Test Type: jwt
```

### **3. Полное тестирование:**
```
Actions → Test with Secrets → Run workflow
Test Type: full
```

---

## 🔧 **Troubleshooting**

### **Частые проблемы:**

#### **1. Секреты не доступны:**
- Проверьте, что секреты добавлены в репозиторий
- Убедитесь, что workflow имеет доступ к секретам
- Проверьте права доступа к репозиторию

#### **2. Сборка не проходит:**
- Проверьте версию Go
- Убедитесь, что все зависимости установлены
- Проверьте синтаксис Go кода

#### **3. Тесты не проходят:**
- Проверьте, что все секреты установлены
- Убедитесь, что тестовые данные корректны
- Проверьте доступность внешних сервисов

---

## 📚 **Дополнительные ресурсы**

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Go GitHub Actions](https://github.com/actions/setup-go)
- [Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

## 🎉 **Готово!**

После настройки секретов и переменных, ваш CloudBridge Client будет автоматически:
- ✅ Собираться при каждом push
- ✅ Тестироваться с реальными секретами
- ✅ Развертываться в staging/production
- ✅ Создавать релизы с артефактами

**Удачной разработки!** 🚀
