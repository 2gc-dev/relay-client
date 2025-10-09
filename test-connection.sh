#!/bin/bash

# Тест подключения CloudBridge Relay Client
echo "=== CloudBridge Relay Client Connection Test ==="
echo "Date: $(date)"
echo ""

# Проверяем доступность сервера
echo "1. Проверка доступности сервера..."
echo "   Health check:"
curl -s http://192.168.58.2:32100/health | jq . || echo "   ❌ Health check failed"
echo ""

echo "   API endpoints:"
curl -s http://192.168.58.2:32092/api/v1/ | jq . || echo "   ❌ API v1 failed"
echo ""

# Проверяем JWT токен
echo "2. Проверка JWT токена..."
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2VkZ2UuMmdjLnJ1L29hdXRoL3YyIiwic3ViIjoic2VydmVyLXNlcnZlci1hLTEyMzQ1IiwiYXVkIjpbImNsb3VkYnJpZGdlLXJlbGF5Il0sImlhdCI6MTc1OTg3NTk3MSwianRpIjoiand0XzE3NTk4NzU5NzE5NTRfMTBoZzY4eDBzIiwib3JnX2lkIjoib3JnLTEyMyIsInRlbmFudF9pZCI6InRlc3QtdGVuYW50LWRldiIsInJlbGF5X3NlcnZlcl9pZCI6InNlcnZlci1hLTEyMzQ1IiwicHJvdG9jb2xfdHlwZSI6InF1aWNrIiwidG9rZW5fdHlwZSI6InJlbGF5X3NlcnZlciIsInBlcm1pc3Npb25zIjpbInJlbGF5OmNvbm5lY3QiLCJyZWxheTptYW5hZ2UiXSwicm9sZXMiOlsicmVsYXktdXNlciIsInRlbmFudC1hZG1pbiJdLCJzY29wZSI6InJlbGF5OmNvbm5lY3QgcmVsYXk6bWFuYWdlIHRlbmFudDpyZWFkIHRlbmFudDp3cml0ZSJ9.mock-signature"

echo "   Testing with JWT token:"
curl -s -H "Authorization: Bearer $TOKEN" http://192.168.58.2:32092/api/v1/peers/list | jq . || echo "   ❌ JWT auth failed"
echo ""

# Тестируем простой HTTP клиент
echo "3. Тестирование простого HTTP клиента..."
echo "   GET request:"
curl -s -H "Authorization: Bearer $TOKEN" http://192.168.58.2:32092/api/v1/peers/discover?tenant_id=test-tenant-dev | jq . || echo "   ❌ GET request failed"
echo ""

echo "   POST request (peer registration):"
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"peer_id": "test-peer-001"}' \
  http://192.168.58.2:32092/api/v1/tenants/test-tenant-dev/peers/register | jq . || echo "   ❌ POST request failed"
echo ""

# Проверяем конфигурацию клиента
echo "4. Проверка конфигурации клиента..."
if [ -f "config.yaml" ]; then
    echo "   ✅ config.yaml найден"
    echo "   Содержимое конфигурации:"
    cat config.yaml | head -20
else
    echo "   ❌ config.yaml не найден"
fi
echo ""

# Тестируем клиент
echo "5. Тестирование CloudBridge Client..."
echo "   Запуск клиента на 10 секунд..."
timeout 10s ./cloudbridge-client p2p --config config.yaml --log-level debug --verbose 2>&1 | head -20 || echo "   ❌ Client test failed"
echo ""

echo "=== Тест завершен ==="
