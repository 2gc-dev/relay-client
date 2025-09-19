#!/usr/bin/env python3
"""
Тест P2P соединения между двумя клиентами через Relay QUIC
Симулирует архитектуру: Client A ←→ QUIC:9090 ←→ Relay ←→ QUIC:9090 ←→ Client B
"""

import socket
import time
import json
import threading
import sys
from datetime import datetime

# Конфигурация
RELAY_HOST = "edge.2gc.ru"
RELAY_PORT = 9090
BUFFER_SIZE = 65507
TIMEOUT = 10

class P2PClient:
    def __init__(self, client_id, relay_host, relay_port):
        self.client_id = client_id
        self.relay_host = relay_host
        self.relay_port = relay_port
        self.sock = None
        self.running = False
        self.received_messages = []
        
    def connect(self):
        """Подключение к relay серверу"""
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.settimeout(TIMEOUT)
            self.running = True
            print(f"✅ {self.client_id}: Подключен к relay {self.relay_host}:{self.relay_port}")
            return True
        except Exception as e:
            print(f"❌ {self.client_id}: Ошибка подключения: {e}")
            return False
    
    def send_message(self, message, target_client=None):
        """Отправка сообщения через relay"""
        try:
            # Формируем пакет с информацией о получателе
            packet = {
                "from": self.client_id,
                "to": target_client or "broadcast",
                "message": message,
                "timestamp": datetime.now().isoformat()
            }
            
            data = json.dumps(packet).encode('utf-8')
            self.sock.sendto(data, (self.relay_host, self.relay_port))
            print(f"📤 {self.client_id}: Отправлено сообщение '{message}' -> {target_client or 'broadcast'}")
            return True
        except Exception as e:
            print(f"❌ {self.client_id}: Ошибка отправки: {e}")
            return False
    
    def listen(self):
        """Прослушивание входящих сообщений"""
        print(f"👂 {self.client_id}: Начинаю прослушивание...")
        while self.running:
            try:
                data, addr = self.sock.recvfrom(BUFFER_SIZE)
                packet = json.loads(data.decode('utf-8'))
                
                # Проверяем, адресовано ли сообщение нам
                if packet.get("to") == self.client_id or packet.get("to") == "broadcast":
                    self.received_messages.append(packet)
                    print(f"📥 {self.client_id}: Получено от {packet.get('from')}: '{packet.get('message')}'")
                else:
                    print(f"📨 {self.client_id}: Пропущено сообщение для {packet.get('to')}")
                    
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"❌ {self.client_id}: Ошибка получения: {e}")
                break
    
    def disconnect(self):
        """Отключение от relay"""
        self.running = False
        if self.sock:
            self.sock.close()
        print(f"🔌 {self.client_id}: Отключен от relay")

def test_basic_communication():
    """Базовый тест коммуникации"""
    print("🧪 Тест 1: Базовая коммуникация")
    print("=" * 50)
    
    # Создаем двух клиентов
    client_a = P2PClient("Client-A", RELAY_HOST, RELAY_PORT)
    client_b = P2PClient("Client-B", RELAY_HOST, RELAY_PORT)
    
    # Подключаемся
    if not client_a.connect() or not client_b.connect():
        print("❌ Не удалось подключить клиентов")
        return False
    
    # Запускаем прослушивание в отдельных потоках
    thread_a = threading.Thread(target=client_a.listen, daemon=True)
    thread_b = threading.Thread(target=client_b.listen, daemon=True)
    
    thread_a.start()
    thread_b.start()
    
    time.sleep(1)  # Даем время на запуск потоков
    
    # Тест 1: Client A отправляет сообщение Client B
    print("\n📋 Тест 1.1: Client A -> Client B")
    client_a.send_message("Hello from Client A!", "Client-B")
    time.sleep(2)
    
    # Тест 2: Client B отправляет сообщение Client A
    print("\n📋 Тест 1.2: Client B -> Client A")
    client_b.send_message("Hello from Client B!", "Client-A")
    time.sleep(2)
    
    # Тест 3: Broadcast сообщение
    print("\n📋 Тест 1.3: Broadcast сообщение")
    client_a.send_message("Broadcast message from Client A")
    time.sleep(2)
    
    # Проверяем результаты
    print(f"\n📊 Результаты:")
    print(f"Client A получил {len(client_a.received_messages)} сообщений")
    print(f"Client B получил {len(client_b.received_messages)} сообщений")
    
    # Отключаемся
    client_a.disconnect()
    client_b.disconnect()
    
    return len(client_a.received_messages) > 0 and len(client_b.received_messages) > 0

def test_multiple_clients():
    """Тест с несколькими клиентами"""
    print("\n🧪 Тест 2: Множественные клиенты")
    print("=" * 50)
    
    clients = []
    threads = []
    
    # Создаем 3 клиентов
    for i in range(3):
        client = P2PClient(f"Client-{i+1}", RELAY_HOST, RELAY_PORT)
        if client.connect():
            clients.append(client)
            thread = threading.Thread(target=client.listen, daemon=True)
            threads.append(thread)
            thread.start()
    
    if len(clients) < 2:
        print("❌ Не удалось подключить достаточно клиентов")
        return False
    
    time.sleep(1)
    
    # Каждый клиент отправляет сообщение следующему
    for i, client in enumerate(clients):
        next_client = clients[(i + 1) % len(clients)]
        client.send_message(f"Message from {client.client_id}", next_client.client_id)
        time.sleep(1)
    
    time.sleep(3)
    
    # Проверяем результаты
    print(f"\n📊 Результаты:")
    for client in clients:
        print(f"{client.client_id} получил {len(client.received_messages)} сообщений")
    
    # Отключаемся
    for client in clients:
        client.disconnect()
    
    return all(len(client.received_messages) > 0 for client in clients)

def test_latency():
    """Тест задержки"""
    print("\n🧪 Тест 3: Измерение задержки")
    print("=" * 50)
    
    client_a = P2PClient("Latency-A", RELAY_HOST, RELAY_PORT)
    client_b = P2PClient("Latency-B", RELAY_HOST, RELAY_PORT)
    
    if not client_a.connect() or not client_b.connect():
        print("❌ Не удалось подключить клиентов")
        return False
    
    # Запускаем прослушивание
    thread_b = threading.Thread(target=client_b.listen, daemon=True)
    thread_b.start()
    time.sleep(1)
    
    latencies = []
    for i in range(10):
        start_time = time.perf_counter()
        client_a.send_message(f"Ping {i+1}", "Latency-B")
        
        # Ждем ответ
        timeout = time.time() + 5
        while time.time() < timeout:
            if len(client_b.received_messages) > i:
                end_time = time.perf_counter()
                latency = (end_time - start_time) * 1000  # в миллисекундах
                latencies.append(latency)
                print(f"Ping {i+1}: {latency:.2f}ms")
                break
            time.sleep(0.1)
        else:
            print(f"Ping {i+1}: Timeout")
    
    if latencies:
        avg_latency = sum(latencies) / len(latencies)
        min_latency = min(latencies)
        max_latency = max(latencies)
        print(f"\n📊 Статистика задержки:")
        print(f"Средняя: {avg_latency:.2f}ms")
        print(f"Минимальная: {min_latency:.2f}ms")
        print(f"Максимальная: {max_latency:.2f}ms")
    
    client_a.disconnect()
    client_b.disconnect()
    
    return len(latencies) > 0

def main():
    """Основная функция"""
    print("🚀 Тест P2P соединения через Relay QUIC")
    print("=" * 60)
    print(f"Relay сервер: {RELAY_HOST}:{RELAY_PORT}")
    print(f"Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    results = []
    
    # Запускаем тесты
    try:
        results.append(("Базовая коммуникация", test_basic_communication()))
        results.append(("Множественные клиенты", test_multiple_clients()))
        results.append(("Измерение задержки", test_latency()))
    except KeyboardInterrupt:
        print("\n⏹️  Тестирование прервано пользователем")
    except Exception as e:
        print(f"\n❌ Ошибка тестирования: {e}")
    
    # Выводим итоговые результаты
    print("\n" + "=" * 60)
    print("📊 ИТОГОВЫЕ РЕЗУЛЬТАТЫ")
    print("=" * 60)
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:<25}: {status}")
        if result:
            passed += 1
    
    print(f"\nРезультат: {passed}/{len(results)} тестов прошли успешно")
    
    if passed == len(results):
        print("🎉 Все тесты прошли успешно! P2P соединение работает!")
    else:
        print("⚠️  Некоторые тесты не прошли. Проверьте настройки relay сервера.")

if __name__ == "__main__":
    main()


