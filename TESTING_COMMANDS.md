# CloudBridge Client - Testing Commands

## 🧪 Команды для тестирования текущего состояния

### ✅ Рабочие тесты:

#### 1. Проверка health endpoint:
```bash
curl http://edge.2gc.ru:8081/health
# Ожидается: {"status":"healthy",...}
```

#### 2. Проверка Minikube P2P API:
```bash
curl http://192.168.49.2:32500/api/v1/tenants/mesh-network-test/peers/register \
  -H "Content-Type: application/json" \
  -d '{"public_key":"test","allowed_ips":["10.0.0.1/32"]}'
# Ожидается: 400 Bad Request (endpoint работает)
```

#### 3. Сборка клиента:
```bash
cd /home/ubuntu/cloudbridge-relay-installer/test/relay-client
go build -o cloudbridge-client cmd/cloudbridge-client/main.go
```

#### 4. Проверка токена (локально):
```bash
# Токен имеет 3 сегмента (правильно)
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzZXJ2ZXItYSIsImlzcyI6ImNsb3VkYnJpZGdlLXJlbGF5IiwiYXVkIjoiY2xvdWRicmlkZ2UtcmVsYXkiLCJpYXQiOjE3NTkwODQ4NjgsImV4cCI6MTc2MDI5NDQ2OCwidGVuYW50X2lkIjoibWVzaC1uZXR3b3JrLXRlc3QiLCJzZXJ2ZXJfaWQiOiJzZXJ2ZXItYSIsInByb3RvY29sIjoicDJwLW1lc2giLCJjb25uZWN0aW9uX3R5cGUiOiJxdWljIiwicGVybWlzc2lvbnMiOlsicmVsYXlfY29ubmVjdCIsInJlbGF5X3R1bm5lbCJdLCJzY29wZXMiOlsicmVsYXlfcDJwIl19.fohpUrOjdPFPWIX4wJWuavHGqLGoXSUnfkET8jSQ6ic"
echo $TOKEN | tr '.' '\n' | wc -l
# Ожидается: 3
```

### ❌ Проблемные тесты:

#### 1. JWT авторизация:
```bash
curl -X POST http://192.168.49.2:32500/api/v1/tenants/mesh-network-test/peers/register \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzZXJ2ZXItYSIsImlzcyI6ImNsb3VkYnJpZGdlLXJlbGF5IiwiYXVkIjoiY2xvdWRicmlkZ2UtcmVsYXkiLCJpYXQiOjE3NTkwODQ4NjgsImV4cCI6MTc2MDI5NDQ2OCwidGVuYW50X2lkIjoibWVzaC1uZXR3b3JrLXRlc3QiLCJzZXJ2ZXJfaWQiOiJzZXJ2ZXItYSIsInByb3RvY29sIjoicDJwLW1lc2giLCJjb25uZWN0aW9uX3R5cGUiOiJxdWljIiwicGVybWlzc2lvbnMiOlsicmVsYXlfY29ubmVjdCIsInJlbGF5X3R1bm5lbCJdLCJzY29wZXMiOlsicmVsYXlfcDJwIl19.fohpUrOjdPFPWIX4wJWuavHGqLGoXSUnfkET8jSQ6ic" \
  -H "Content-Type: application/json" \
  -d '{"public_key":"test_key","allowed_ips":["10.0.0.1/32"]}'
# Текущий результат: {"error":"Invalid token","code":401,"message":"invalid token: invalid token: token signature is invalid: signature is invalid"}
```

#### 2. P2P клиент:
```bash
cd /home/ubuntu/cloudbridge-relay-installer/test/relay-client
./cloudbridge-client p2p -c config-test-server-a.yaml --log-level debug
# Текущий результат: token is malformed (проблема с парсингом YAML)
```

## 🔧 Конфигурационные файлы:

### Готовые файлы:
- ✅ `config-test-server-a.yaml` - для первого клиента
- ✅ `config-test-server-b.yaml` - для второго клиента  
- ✅ `config-production.yaml` - обновлен на HTTP
- ✅ `config.yaml` - обновлен на HTTP
- ✅ `config-example.yaml` - обновлен на HTTP

### Токены:
- ✅ **Server A:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...fohpUrOjdPFPWIX4wJWuavHGqLGoXSUnfkET8jSQ6ic`
- ✅ **Server B:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...qtjQO-CDtl6ELebPSn5jWlpiclFup-ISlSVjPOB2dtU`
- ⏰ **Срок действия:** до 12 октября 2025

## 🐛 Отладочные команды:

### Kubernetes:
```bash
# Проверка JWT секрета
kubectl get secret cloudbridge-relay-jwt -n cloudbridge -o jsonpath='{.data.secret}' | base64 -d

# Логи relay pods  
kubectl logs -n cloudbridge -l app=cloudbridge-relay

# Порты и сервисы
kubectl get svc -n cloudbridge | grep cloudbridge
```

### Сеть:
```bash
# Minikube IP
minikube ip

# Проверка портов
nmap -p 32500 192.168.49.2
```

### Генерация новых токенов:
```bash
cd /home/ubuntu/cloudbridge-relay-installer
go run scripts/token-generator.go server-test-a mesh-network-test 168h
go run scripts/token-generator.go server-test-b mesh-network-test 168h
```

## 📊 Ожидаемые результаты:

### ✅ Работает:
- Health endpoints возвращают 200 OK
- API endpoints возвращают 400/401 (не 404)
- Токены имеют правильную структуру
- HTTP соединения устанавливаются

### ❌ Не работает:
- JWT подпись не проходит валидацию
- P2P клиент не может зарегистрироваться
- Peer discovery не работает

## 🎯 Готово к следующему этапу:

После решения проблемы с JWT signature можно будет протестировать:
1. Регистрацию двух peer'ов
2. P2P mesh соединение между ними
3. Передачу данных через relay
4. Автоматический failover на STUN/TURN

**Прогресс: 85% → осталось решить JWT валидацию**
