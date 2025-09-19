#!/usr/bin/env python3
"""
Speed Test for Relay Server
Тест скорости передачи данных через relay сервер
"""

import socket
import time
import statistics
import threading
import random
import string

class SpeedTest:
    def __init__(self, host="edge.2gc.ru", port=9090):
        self.host = host
        self.port = port
        self.results = {}
    
    def generate_data(self, size):
        """Генерация тестовых данных заданного размера"""
        return ''.join(random.choices(string.ascii_letters + string.digits, k=size)).encode()
    
    def test_latency(self, iterations=10):
        """Тест задержки (latency)"""
        print("🧪 Testing Latency")
        print("=" * 30)
        
        latencies = []
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(5.0)
            
            for i in range(iterations):
                # Отправляем небольшое сообщение
                message = f"latency_test_{i}"
                start_time = time.time()
                
                sock.sendto(message.encode(), (self.host, self.port))
                response, addr = sock.recvfrom(1024)
                
                end_time = time.time()
                latency = (end_time - start_time) * 1000  # в миллисекундах
                latencies.append(latency)
                
                print(f"Test {i+1:2d}: {latency:6.2f}ms")
                time.sleep(0.1)  # Небольшая задержка между тестами
            
            # Статистика
            avg_latency = statistics.mean(latencies)
            min_latency = min(latencies)
            max_latency = max(latencies)
            std_latency = statistics.stdev(latencies) if len(latencies) > 1 else 0
            
            print(f"\n📊 Latency Statistics:")
            print(f"Average: {avg_latency:6.2f}ms")
            print(f"Minimum: {min_latency:6.2f}ms")
            print(f"Maximum: {max_latency:6.2f}ms")
            print(f"Std Dev: {std_latency:6.2f}ms")
            
            self.results['latency'] = {
                'average': avg_latency,
                'minimum': min_latency,
                'maximum': max_latency,
                'std_dev': std_latency,
                'samples': latencies
            }
            
            return True
            
        except Exception as e:
            print(f"❌ Latency test failed: {e}")
            return False
        finally:
            sock.close()
    
    def test_throughput(self, data_sizes=[64, 256, 1024, 4096, 16384]):
        """Тест пропускной способности для разных размеров данных"""
        print("\n🧪 Testing Throughput")
        print("=" * 30)
        
        throughput_results = {}
        
        for size in data_sizes:
            print(f"\nTesting {size} bytes...")
            
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.settimeout(10.0)
                
                # Генерируем тестовые данные
                test_data = self.generate_data(size)
                
                # Измеряем время передачи
                start_time = time.time()
                sock.sendto(test_data, (self.host, self.port))
                response, addr = sock.recvfrom(size + 100)  # +100 для буфера
                end_time = time.time()
                
                # Проверяем, что данные совпадают
                if response == test_data:
                    duration = end_time - start_time
                    throughput_mbps = (size * 8) / (duration * 1000000)  # Mbps
                    throughput_mbps_roundtrip = (size * 8 * 2) / (duration * 1000000)  # Roundtrip
                    
                    print(f"  Duration: {duration*1000:6.2f}ms")
                    print(f"  Throughput (one-way): {throughput_mbps:6.2f} Mbps")
                    print(f"  Throughput (roundtrip): {throughput_mbps_roundtrip:6.2f} Mbps")
                    
                    throughput_results[size] = {
                        'duration_ms': duration * 1000,
                        'throughput_mbps': throughput_mbps,
                        'throughput_roundtrip_mbps': throughput_mbps_roundtrip,
                        'success': True
                    }
                else:
                    print(f"  ❌ Data mismatch!")
                    throughput_results[size] = {'success': False}
                
                sock.close()
                time.sleep(0.5)  # Пауза между тестами
                
            except Exception as e:
                print(f"  ❌ Failed: {e}")
                throughput_results[size] = {'success': False}
        
        self.results['throughput'] = throughput_results
        return any(result.get('success', False) for result in throughput_results.values())
    
    def test_concurrent_throughput(self, num_clients=5, message_size=1024, duration=10):
        """Тест concurrent пропускной способности"""
        print(f"\n🧪 Testing Concurrent Throughput ({num_clients} clients)")
        print("=" * 50)
        
        results = []
        threads = []
        
        def client_thread(client_id):
            """Поток клиента"""
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.settimeout(2.0)
                
                messages_sent = 0
                messages_received = 0
                start_time = time.time()
                
                while time.time() - start_time < duration:
                    # Генерируем сообщение
                    message = f"client_{client_id}_msg_{messages_sent}".ljust(message_size)
                    message = message[:message_size].encode()
                    
                    try:
                        sock.sendto(message, (self.host, self.port))
                        messages_sent += 1
                        
                        response, addr = sock.recvfrom(message_size + 100)
                        if response == message:
                            messages_received += 1
                        
                        time.sleep(0.01)  # Небольшая задержка
                        
                    except socket.timeout:
                        continue
                
                end_time = time.time()
                actual_duration = end_time - start_time
                
                result = {
                    'client_id': client_id,
                    'messages_sent': messages_sent,
                    'messages_received': messages_received,
                    'duration': actual_duration,
                    'success_rate': (messages_received / messages_sent * 100) if messages_sent > 0 else 0
                }
                
                results.append(result)
                print(f"Client {client_id}: {messages_sent} sent, {messages_received} received, {result['success_rate']:.1f}% success")
                
            except Exception as e:
                print(f"Client {client_id} failed: {e}")
                results.append({'client_id': client_id, 'error': str(e)})
            finally:
                sock.close()
        
        # Запускаем клиентов
        for i in range(num_clients):
            thread = threading.Thread(target=client_thread, args=(i,))
            threads.append(thread)
            thread.start()
        
        # Ждем завершения
        for thread in threads:
            thread.join()
        
        # Анализируем результаты
        successful_results = [r for r in results if 'error' not in r]
        if successful_results:
            total_sent = sum(r['messages_sent'] for r in successful_results)
            total_received = sum(r['messages_received'] for r in successful_results)
            avg_success_rate = statistics.mean(r['success_rate'] for r in successful_results)
            
            print(f"\n📊 Concurrent Results:")
            print(f"Total messages sent: {total_sent}")
            print(f"Total messages received: {total_received}")
            print(f"Overall success rate: {(total_received/total_sent*100):.1f}%")
            print(f"Average client success rate: {avg_success_rate:.1f}%")
            
            self.results['concurrent'] = {
                'total_sent': total_sent,
                'total_received': total_received,
                'overall_success_rate': total_received/total_sent*100,
                'avg_client_success_rate': avg_success_rate,
                'clients': successful_results
            }
            
            return True
        else:
            print("❌ All clients failed")
            return False
    
    def test_stress(self, duration=30, message_size=512):
        """Стресс-тест"""
        print(f"\n🧪 Stress Test ({duration}s)")
        print("=" * 30)
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(1.0)
            
            messages_sent = 0
            messages_received = 0
            errors = 0
            start_time = time.time()
            
            while time.time() - start_time < duration:
                try:
                    # Генерируем сообщение
                    message = f"stress_test_{messages_sent}".ljust(message_size)
                    message = message[:message_size].encode()
                    
                    sock.sendto(message, (self.host, self.port))
                    messages_sent += 1
                    
                    response, addr = sock.recvfrom(message_size + 100)
                    if response == message:
                        messages_received += 1
                    
                    # Небольшая задержка для предотвращения перегрузки
                    time.sleep(0.001)
                    
                except socket.timeout:
                    errors += 1
                    continue
                except Exception as e:
                    errors += 1
                    continue
            
            end_time = time.time()
            actual_duration = end_time - start_time
            
            success_rate = (messages_received / messages_sent * 100) if messages_sent > 0 else 0
            messages_per_second = messages_sent / actual_duration
            
            print(f"Duration: {actual_duration:.2f}s")
            print(f"Messages sent: {messages_sent}")
            print(f"Messages received: {messages_received}")
            print(f"Errors: {errors}")
            print(f"Success rate: {success_rate:.1f}%")
            print(f"Messages per second: {messages_per_second:.1f}")
            
            self.results['stress'] = {
                'duration': actual_duration,
                'messages_sent': messages_sent,
                'messages_received': messages_received,
                'errors': errors,
                'success_rate': success_rate,
                'messages_per_second': messages_per_second
            }
            
            return success_rate > 80  # Считаем успешным если >80% сообщений доставлено
            
        except Exception as e:
            print(f"❌ Stress test failed: {e}")
            return False
        finally:
            sock.close()
    
    def run_all_tests(self):
        """Запуск всех тестов"""
        print("🚀 Relay Server Speed Test")
        print("=" * 50)
        print(f"Target: {self.host}:{self.port}")
        print()
        
        tests = [
            ("Latency Test", self.test_latency),
            ("Throughput Test", self.test_throughput),
            ("Concurrent Test", lambda: self.test_concurrent_throughput(3, 1024, 10)),
            ("Stress Test", lambda: self.test_stress(20, 512))
        ]
        
        results = {}
        
        for test_name, test_func in tests:
            print(f"\n{'='*20} {test_name} {'='*20}")
            try:
                success = test_func()
                results[test_name] = success
                print(f"✅ {test_name}: {'PASS' if success else 'FAIL'}")
            except Exception as e:
                print(f"❌ {test_name}: ERROR - {e}")
                results[test_name] = False
        
        # Итоговый отчет
        print(f"\n{'='*50}")
        print("📊 FINAL RESULTS")
        print(f"{'='*50}")
        
        for test_name, success in results.items():
            status = "✅ PASS" if success else "❌ FAIL"
            print(f"{test_name:20s}: {status}")
        
        passed = sum(results.values())
        total = len(results)
        print(f"\nOverall: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All tests passed!")
        else:
            print("⚠️  Some tests failed")
        
        return results

if __name__ == "__main__":
    # Запуск тестов
    speed_test = SpeedTest()
    speed_test.run_all_tests()


