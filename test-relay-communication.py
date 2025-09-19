#!/usr/bin/env python3
"""
Test Relay Communication
Тестирует связь между клиентами через relay сервер
Client A ←→ QUIC:9090 ←→ Relay ←→ QUIC:9090 ←→ Client B
"""

import socket
import time
import threading
import json
import uuid

class RelayClient:
    def __init__(self, client_id, relay_host="edge.2gc.ru", relay_port=9090):
        self.client_id = client_id
        self.relay_host = relay_host
        self.relay_port = relay_port
        self.sock = None
        self.connected = False
        self.messages_received = []
        
    def connect(self):
        """Подключение к relay серверу"""
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.settimeout(5.0)
            
            # Отправляем сообщение о подключении
            connect_msg = {
                "type": "connect",
                "client_id": self.client_id,
                "timestamp": time.time()
            }
            
            message = json.dumps(connect_msg).encode()
            self.sock.sendto(message, (self.relay_host, self.relay_port))
            
            # Ждем подтверждение
            try:
                response, addr = self.sock.recvfrom(1024)
                response_data = json.loads(response.decode())
                if response_data.get("type") == "connected":
                    self.connected = True
                    print(f"✅ Client {self.client_id} connected to relay")
                    return True
            except socket.timeout:
                print(f"⚠️  Client {self.client_id} connected (no confirmation received)")
                self.connected = True
                return True
                
        except Exception as e:
            print(f"❌ Client {self.client_id} connection failed: {e}")
            return False
    
    def send_message(self, target_client_id, message):
        """Отправка сообщения через relay"""
        if not self.connected:
            print(f"❌ Client {self.client_id} not connected")
            return False
            
        try:
            relay_msg = {
                "type": "relay",
                "from": self.client_id,
                "to": target_client_id,
                "message": message,
                "timestamp": time.time()
            }
            
            data = json.dumps(relay_msg).encode()
            self.sock.sendto(data, (self.relay_host, self.relay_port))
            print(f"📤 Client {self.client_id} sent to {target_client_id}: {message}")
            return True
            
        except Exception as e:
            print(f"❌ Client {self.client_id} send failed: {e}")
            return False
    
    def listen(self, duration=10):
        """Прослушивание сообщений"""
        if not self.connected:
            return
            
        start_time = time.time()
        while time.time() - start_time < duration:
            try:
                data, addr = self.sock.recvfrom(1024)
                message = json.loads(data.decode())
                
                if message.get("type") == "relay":
                    from_client = message.get("from")
                    msg_content = message.get("message")
                    print(f"📥 Client {self.client_id} received from {from_client}: {msg_content}")
                    self.messages_received.append(message)
                    
            except socket.timeout:
                continue
            except Exception as e:
                print(f"❌ Client {self.client_id} listen error: {e}")
                break
    
    def disconnect(self):
        """Отключение от relay"""
        if self.sock:
            disconnect_msg = {
                "type": "disconnect",
                "client_id": self.client_id,
                "timestamp": time.time()
            }
            try:
                self.sock.sendto(json.dumps(disconnect_msg).encode(), 
                               (self.relay_host, self.relay_port))
            except:
                pass
            self.sock.close()
            self.connected = False
            print(f"🔌 Client {self.client_id} disconnected")

def test_relay_communication():
    """Тест связи через relay"""
    print("🧪 Testing Relay Communication")
    print("=" * 50)
    print("Client A ←→ QUIC:9090 ←→ Relay ←→ QUIC:9090 ←→ Client B")
    print()
    
    # Создаем двух клиентов
    client_a = RelayClient("client_a")
    client_b = RelayClient("client_b")
    
    try:
        # Подключаем клиентов
        print("1. Connecting clients...")
        if not client_a.connect():
            print("❌ Client A connection failed")
            return False
        time.sleep(1)
        
        if not client_b.connect():
            print("❌ Client B connection failed")
            return False
        time.sleep(1)
        
        # Запускаем прослушивание в отдельных потоках
        print("2. Starting message listeners...")
        listener_a = threading.Thread(target=client_a.listen, args=(15,))
        listener_b = threading.Thread(target=client_b.listen, args=(15,))
        
        listener_a.start()
        listener_b.start()
        
        time.sleep(2)
        
        # Отправляем сообщения
        print("3. Sending test messages...")
        
        # A → B
        client_a.send_message("client_b", "Hello from Client A!")
        time.sleep(1)
        
        # B → A
        client_b.send_message("client_a", "Hello from Client B!")
        time.sleep(1)
        
        # A → B (еще одно сообщение)
        client_a.send_message("client_b", "How are you?")
        time.sleep(1)
        
        # B → A (ответ)
        client_b.send_message("client_a", "I'm fine, thanks!")
        time.sleep(2)
        
        # Ждем завершения прослушивания
        listener_a.join()
        listener_b.join()
        
        # Проверяем результаты
        print("\n4. Checking results...")
        print(f"Client A received {len(client_a.messages_received)} messages")
        print(f"Client B received {len(client_b.messages_received)} messages")
        
        if len(client_a.messages_received) > 0 and len(client_b.messages_received) > 0:
            print("✅ Relay communication successful!")
            return True
        else:
            print("❌ Relay communication failed - no messages received")
            return False
            
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False
    finally:
        # Отключаем клиентов
        client_a.disconnect()
        client_b.disconnect()

def test_simple_relay():
    """Простой тест relay - отправка и получение echo"""
    print("🧪 Simple Relay Test")
    print("=" * 30)
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(5.0)
        
        # Отправляем тестовое сообщение
        test_message = f"Relay test message {uuid.uuid4().hex[:8]}"
        print(f"Sending: {test_message}")
        
        sock.sendto(test_message.encode(), ("edge.2gc.ru", 9090))
        
        # Ждем ответ
        try:
            response, addr = sock.recvfrom(1024)
            print(f"Received: {response.decode()}")
            
            if response.decode() == test_message:
                print("✅ Relay echo test successful!")
                return True
            else:
                print("⚠️  Relay echo test - different response")
                return False
                
        except socket.timeout:
            print("❌ Relay echo test - no response")
            return False
            
    except Exception as e:
        print(f"❌ Relay test failed: {e}")
        return False
    finally:
        sock.close()

if __name__ == "__main__":
    print("🚀 Relay Communication Tests")
    print("=" * 50)
    
    # Простой тест
    print("\n--- Simple Relay Test ---")
    simple_success = test_simple_relay()
    
    print("\n--- Full Relay Communication Test ---")
    full_success = test_relay_communication()
    
    print("\n" + "=" * 50)
    print("📊 Test Results:")
    print(f"Simple Relay Test: {'✅ PASS' if simple_success else '❌ FAIL'}")
    print(f"Full Communication Test: {'✅ PASS' if full_success else '❌ FAIL'}")
    
    if simple_success and full_success:
        print("\n🎉 All relay tests passed!")
    else:
        print("\n⚠️  Some relay tests failed")


