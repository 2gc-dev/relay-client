# 🖥️ CloudBridge Client Windows Service

## 📋 Обзор

CloudBridge Client поддерживает работу в качестве Windows службы с автоматическим запуском при старте системы, логированием в Windows Event Log и управлением через Services.msc.

## 🚀 Установка службы

### Предварительные требования

1. **NSSM (Non-Sucking Service Manager)** - для управления службой
   - Скачать с: https://nssm.cc/download
   - Распаковать в `C:\nssm\`
   - Добавить `C:\nssm\win64\` в PATH

2. **Права администратора** - для установки службы

### Команды установки

```cmd
# 1. Собрать клиент для Windows
make build-all

# 2. Установить службу
cloudbridge-client.exe service install --config config-service.yaml --token "REAL_JWT_TOKEN"

# 3. Запустить службу
cloudbridge-client.exe service start

# Или использовать Windows команды:
net start CloudBridgeClient
```

## 🔧 Управление службой

### Основные команды

```cmd
# Установка службы
cloudbridge-client.exe service install --config config-service.yaml --token "JWT_TOKEN"

# Запуск службы
cloudbridge-client.exe service start
# или
net start CloudBridgeClient

# Остановка службы
cloudbridge-client.exe service stop
# или
net stop CloudBridgeClient

# Перезапуск службы
cloudbridge-client.exe service restart

# Проверка статуса
cloudbridge-client.exe service status

# Удаление службы
cloudbridge-client.exe service uninstall
```

### Управление через Services.msc

1. Открыть `services.msc`
2. Найти службу "CloudBridge Client"
3. Щелкнуть правой кнопкой для управления:
   - Start (Запустить)
   - Stop (Остановить)
   - Restart (Перезапустить)
   - Properties (Свойства)

## 📁 Структура файлов

После установки службы создается следующая структура:

```
C:\ProgramData\cloudbridge-client\
├── config.yaml          # Конфигурация службы
├── logs\                # Логи службы
│   └── cloudbridge-client.log
└── cloudbridge-client.exe  # Исполняемый файл
```

## ⚙️ Конфигурация службы

### Основные параметры

```yaml
# config-service.yaml
relay:
  host: "relay.2gc.ru"
  port: 9090
  tls:
    enabled: true

auth:
  type: "jwt"
  secret: "YOUR_JWT_SECRET"
  fallback_secret: "YOUR_FALLBACK_SECRET"

logging:
  level: "info"
  format: "json"
  output: "file"
  file_path: "C:\\ProgramData\\cloudbridge-client\\logs\\cloudbridge-client.log"
```

### P2P Mesh конфигурация

```yaml
p2p:
  peer_id: "server-001"
  endpoint: "192.168.1.100:51820"
  public_key: "WG_PUBLIC_KEY"
  private_key: "WG_PRIVATE_KEY"
  mesh_port: 51820
```

## 📊 Мониторинг и логирование

### Логи службы

- **Расположение**: `C:\ProgramData\cloudbridge-client\logs\`
- **Формат**: JSON для удобного парсинга
- **Ротация**: Автоматическая ротация логов

### Windows Event Log

Служба интегрируется с Windows Event Log:
- **Источник**: CloudBridge Client
- **Категории**: Information, Warning, Error
- **Просмотр**: Event Viewer (eventvwr.msc)

### Метрики Prometheus

```yaml
metrics:
  enabled: true
  prometheus_port: 9091
  tenant_metrics: true
  buffer_metrics: true
  connection_metrics: true
```

Доступ к метрикам: `http://localhost:9091/metrics`

## 🔒 Безопасность

### Права доступа

- Служба запускается от имени `SYSTEM`
- Конфигурационные файлы защищены от записи
- JWT токены хранятся в зашифрованном виде

### Сетевая безопасность

- TLS 1.3 для всех соединений
- Проверка сертификатов сервера
- Firewall правила для P2P mesh

## 🚨 Устранение неполадок

### Проверка статуса службы

```cmd
# Через CLI
cloudbridge-client.exe service status

# Через PowerShell
Get-Service -Name "CloudBridgeClient"

# Через Services.msc
services.msc
```

### Просмотр логов

```cmd
# Логи службы
type "C:\ProgramData\cloudbridge-client\logs\cloudbridge-client.log"

# Windows Event Log
eventvwr.msc
```

### Частые проблемы

1. **Служба не запускается**
   - Проверить права администратора
   - Проверить конфигурацию
   - Проверить доступность relay сервера

2. **Ошибки аутентификации**
   - Проверить JWT токен
   - Проверить fallback секрет
   - Проверить срок действия токена

3. **Проблемы с сетью**
   - Проверить firewall правила
   - Проверить доступность relay.2gc.ru:9090
   - Проверить TLS сертификаты

## 📝 Примеры использования

### Установка с P2P Mesh

```cmd
cloudbridge-client.exe service install \
  --config config-service.yaml \
  --token "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImZhbGxiYWNrLWtleSJ9..."
```

### Установка с туннелем

```cmd
cloudbridge-client.exe service install \
  --config config-tunnel.yaml \
  --token "JWT_TOKEN"
```

### Обновление конфигурации

1. Остановить службу: `net stop CloudBridgeClient`
2. Обновить `config.yaml`
3. Запустить службу: `net start CloudBridgeClient`

## 🔄 Автоматическое обновление

Для автоматического обновления службы:

1. Остановить службу
2. Заменить исполняемый файл
3. Запустить службу

```cmd
net stop CloudBridgeClient
copy new-cloudbridge-client.exe "C:\ProgramData\cloudbridge-client\cloudbridge-client.exe"
net start CloudBridgeClient
```

## 📞 Поддержка

При возникновении проблем:

1. Проверить логи службы
2. Проверить Windows Event Log
3. Проверить конфигурацию
4. Обратиться к DevOps команде

---

**Примечание**: Для работы службы требуется действительный JWT токен с правами `mesh_join` и `mesh_manage` для P2P mesh режима.


