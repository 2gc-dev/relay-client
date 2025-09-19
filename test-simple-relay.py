#!/usr/bin/env python3
"""
Simple Relay Test
Простой тест для проверки relay функциональности
"""

import socket
import time
import threading

def test_relay_echo():
    """Тест echo функции relay"""
    print("🧪 Testing Relay Echo Function")
    print("=" * 40)
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(3.0)
        
        # Тест 1: Простое сообщение
        message1 = "Hello Relay Server!"
        print(f"Test 1 - Sending: {message1}")
        sock.sendto(message1.encode(), ("edge.2gc.ru", 9090))
        
        response1, addr = sock.recvfrom(1024)
        print(f"Test 1 - Received: {response1.decode()}")
        
        time.sleep(1)
        
        # Тест 2: Другое сообщение
        message2 = "Relay Test Message 2"
        print(f"Test 2 - Sending: {message2}")
        sock.sendto(message2.encode(), ("edge.2gc.ru", 9090))
        
        response2, addr = sock.recvfrom(1024)
        print(f"Test 2 - Received: {response2.decode()}")
        
        time.sleep(1)
        
        # Тест 3: Длинное сообщение
        message3 = "This is a longer test message to check if the relay server can handle different message sizes properly."
        print(f"Test 3 - Sending: {message3}")
        sock.sendto(message3.encode(), ("edge.2gc.ru", 9090))
        
        response3, addr = sock.recvfrom(1024)
        print(f"Test 3 - Received: {response3.decode()}")
        
        # Проверяем результаты
        if (response1.decode() == message1 and 
            response2.decode() == message2 and 
            response3.decode() == message3):
            print("✅ All echo tests passed!")
            return True
        else:
            print("❌ Echo tests failed - responses don't match")
            return False
            
    except Exception as e:
        print(f"❌ Echo test failed: {e}")
        return False
    finally:
        sock.close()

def test_relay_performance():
    """Тест производительности relay"""
    print("\n🧪 Testing Relay Performance")
    print("=" * 40)
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(5.0)
        
        messages_sent = 0
        messages_received = 0
        start_time = time.time()
        
        # Отправляем 10 сообщений подряд
        for i in range(10):
            message = f"Performance test message {i+1}"
            sock.sendto(message.encode(), ("edge.2gc.ru", 9090))
            messages_sent += 1
            
            try:
                response, addr = sock.recvfrom(1024)
                if response.decode() == message:
                    messages_received += 1
                time.sleep(0.1)  # Небольшая задержка между сообщениями
            except socket.timeout:
                print(f"⚠️  Timeout on message {i+1}")
        
        end_time = time.time()
        duration = end_time - start_time
        
        print(f"Messages sent: {messages_sent}")
        print(f"Messages received: {messages_received}")
        print(f"Duration: {duration:.2f} seconds")
        print(f"Success rate: {(messages_received/messages_sent)*100:.1f}%")
        
        if messages_received == messages_sent:
            print("✅ Performance test passed!")
            return True
        else:
            print("⚠️  Performance test - some messages lost")
            return False
            
    except Exception as e:
        print(f"❌ Performance test failed: {e}")
        return False
    finally:
        sock.close()

def test_relay_concurrent():
    """Тест concurrent подключений к relay"""
    print("\n🧪 Testing Concurrent Relay Connections")
    print("=" * 50)
    
    def client_thread(client_id, results):
        """Поток клиента"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(3.0)
            
            # Отправляем сообщение
            message = f"Message from client {client_id}"
            sock.sendto(message.encode(), ("edge.2gc.ru", 9090))
            
            # Ждем ответ
            response, addr = sock.recvfrom(1024)
            if response.decode() == message:
                results[client_id] = True
                print(f"✅ Client {client_id} successful")
            else:
                results[client_id] = False
                print(f"❌ Client {client_id} failed - wrong response")
                
        except Exception as e:
            results[client_id] = False
            print(f"❌ Client {client_id} failed: {e}")
        finally:
            sock.close()
    
    # Запускаем 5 concurrent клиентов
    threads = []
    results = {}
    
    for i in range(5):
        thread = threading.Thread(target=client_thread, args=(i, results))
        threads.append(thread)
        thread.start()
    
    # Ждем завершения всех потоков
    for thread in threads:
        thread.join()
    
    # Проверяем результаты
    successful = sum(1 for success in results.values() if success)
    total = len(results)
    
    print(f"Successful connections: {successful}/{total}")
    
    if successful == total:
        print("✅ Concurrent test passed!")
        return True
    else:
        print("⚠️  Concurrent test - some connections failed")
        return False

if __name__ == "__main__":
    print("🚀 Simple Relay Tests")
    print("=" * 50)
    
    # Запускаем все тесты
    echo_success = test_relay_echo()
    performance_success = test_relay_performance()
    concurrent_success = test_relay_concurrent()
    
    print("\n" + "=" * 50)
    print("📊 Test Results:")
    print(f"Echo Test: {'✅ PASS' if echo_success else '❌ FAIL'}")
    print(f"Performance Test: {'✅ PASS' if performance_success else '❌ FAIL'}")
    print(f"Concurrent Test: {'✅ PASS' if concurrent_success else '❌ FAIL'}")
    
    if echo_success and performance_success and concurrent_success:
        print("\n🎉 All relay tests passed!")
    else:
        print("\n⚠️  Some relay tests failed")


