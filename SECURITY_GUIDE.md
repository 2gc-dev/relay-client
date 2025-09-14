# 🔐 Руководство по безопасности CloudBridge Client

## ⚠️ **ВАЖНО: Безопасность секретов**

### **❌ НЕ ДЕЛАЙТЕ:**
- Не храните секреты в открытом виде в конфигурационных файлах
- Не коммитьте секреты в Git репозиторий
- Не передавайте секреты через незащищенные каналы

### **✅ ДЕЛАЙТЕ:**
- Используйте переменные окружения для секретов
- Используйте системы управления секретами (HashiCorp Vault, AWS Secrets Manager, etc.)
- Регулярно ротируйте секреты
- Используйте принцип минимальных привилегий

---

## 🔧 **Настройка переменных окружения**

### **1. Создайте файл .env:**
```bash
# Скопируйте env.example в .env
cp env.example .env

# Отредактируйте .env с реальными значениями
nano .env
```

### **2. Установите переменные окружения:**
```bash
# Для разработки
export FALLBACK_SECRET="eozy96a8+j125pOpIhCyytge1rR0MTiG4wBi/J9zpew="
export JWT_SECRET="your-jwt-secret-here"

# Для production
export FALLBACK_SECRET="eozy96a8+j125pOpIhCyytge1rR0MTiG4wBi/J9zpew="
export JWT_SECRET="production-jwt-secret"
```

### **3. Запустите CloudBridge Client:**
```bash
# CloudBridge Client автоматически загрузит переменные окружения
./cloudbridge-client --config config-production.yaml
```

---

## 🐳 **Docker и Kubernetes**

### **Docker:**
```dockerfile
# В Dockerfile
ENV FALLBACK_SECRET=""
ENV JWT_SECRET=""

# При запуске контейнера
docker run -e FALLBACK_SECRET="eozy96a8+j125pOpIhCyytge1rR0MTiG4wBi/J9zpew=" cloudbridge-client
```

### **Kubernetes Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudbridge-secrets
type: Opaque
data:
  fallback-secret: ZW96eTk2YTgrajEyNXBPcElIQ3l5dGdlMXJSMU1UaUc0d0JpL0o5enBldz0=  # base64 encoded
  jwt-secret: eW91ci1qd3Qtc2VjcmV0LWhlcmU=  # base64 encoded
```

### **Kubernetes Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudbridge-client
spec:
  template:
    spec:
      containers:
      - name: cloudbridge-client
        image: cloudbridge-client:latest
        env:
        - name: FALLBACK_SECRET
          valueFrom:
            secretKeyRef:
              name: cloudbridge-secrets
              key: fallback-secret
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: cloudbridge-secrets
              key: jwt-secret
```

---

## 🔄 **Ротация секретов**

### **1. Обновите секрет в системе управления секретами**
### **2. Обновите переменные окружения**
### **3. Перезапустите CloudBridge Client**
### **4. Проверьте логи на ошибки аутентификации**

---

## 📋 **Проверка безопасности**

### **Проверьте, что секреты не в Git:**
```bash
# Проверьте, что секреты не в истории Git
git log --all --full-history -- "*.yaml" | grep -i secret

# Проверьте, что секреты не в текущих файлах
grep -r "eozy96a8" . --exclude-dir=.git
```

### **Проверьте права доступа к файлам:**
```bash
# Убедитесь, что .env файл имеет ограниченные права
chmod 600 .env
ls -la .env
```

---

## 🚨 **В случае компрометации секрета**

### **1. Немедленно ротируйте секрет**
### **2. Обновите все системы**
### **3. Проверьте логи на подозрительную активность**
### **4. Уведомите команду безопасности**

---

## 📚 **Дополнительные ресурсы**

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

---

**Помните: Безопасность - это ответственность каждого разработчика!** 🔐


