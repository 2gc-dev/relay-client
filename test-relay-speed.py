#!/usr/bin/env python3
"""
Relay Speed Test
Тест скорости передачи данных через relay сервер
"""

import socket
import time
import statistics
import threading
import random
import string

class RelaySpeedTest:
    def __init__(self, relay_host="edge.2gc.ru", relay_port=9090):
        self.relay_host = relay_host
        self.relay_port = relay_port
        self.results = {}
    
    def generate_data(self, size):
        """Генерация тестовых данных"""
        return ''.join(random.choices(string.ascii_letters + string.digits, k=size)).encode()
    
    def test_single_throughput(self, data_size, iterations=10):
        """Тест пропускной способности для одного размера данных"""
        print(f"Testing {data_size} bytes ({iterations} iterations)...")
        
        durations = []
        successful_transfers = 0
        
        for i in range(iterations):
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.settimeout(5.0)
                
                # Генерируем тестовые данные
                test_data = self.generate_data(data_size)
                
                # Измеряем время передачи
                start_time = time.time()
                sock.sendto(test_data, (self.relay_host, self.relay_port))
                response, addr = sock.recvfrom(data_size + 100)
                end_time = time.time()
                
                # Проверяем, что данные совпадают
                if response == test_data:
                    duration = end_time - start_time
                    durations.append(duration)
                    successful_transfers += 1
                
                sock.close()
                time.sleep(0.1)  # Небольшая задержка
                
            except Exception as e:
                print(f"  Error in iteration {i+1}: {e}")
                continue
        
        if durations:
            avg_duration = statistics.mean(durations)
            min_duration = min(durations)
            max_duration = max(durations)
            std_duration = statistics.stdev(durations) if len(durations) > 1 else 0
            
            # Рассчитываем пропускную способность
            throughput_mbps = (data_size * 8) / (avg_duration * 1000000)
            throughput_roundtrip_mbps = (data_size * 8 * 2) / (avg_duration * 1000000)
            
            success_rate = (successful_transfers / iterations) * 100
            
            print(f"  Success rate: {success_rate:.1f}%")
            print(f"  Avg duration: {avg_duration*1000:.2f}ms")
            print(f"  Throughput (one-way): {throughput_mbps:.2f} Mbps")
            print(f"  Throughput (roundtrip): {throughput_roundtrip_mbps:.2f} Mbps")
            
            return {
                'data_size': data_size,
                'iterations': iterations,
                'successful_transfers': successful_transfers,
                'success_rate': success_rate,
                'avg_duration_ms': avg_duration * 1000,
                'min_duration_ms': min_duration * 1000,
                'max_duration_ms': max_duration * 1000,
                'std_duration_ms': std_duration * 1000,
                'throughput_mbps': throughput_mbps,
                'throughput_roundtrip_mbps': throughput_roundtrip_mbps
            }
        else:
            print(f"  ❌ No successful transfers")
            return None
    
    def test_throughput_range(self, sizes=[64, 256, 1024, 4096, 8192]):
        """Тест пропускной способности для разных размеров данных"""
        print("🧪 Testing Throughput for Different Data Sizes")
        print("=" * 50)
        
        results = {}
        
        for size in sizes:
            result = self.test_single_throughput(size, 5)
            if result:
                results[size] = result
            print()
        
        self.results['throughput_range'] = results
        return results
    
    def test_concurrent_throughput(self, num_clients=3, data_size=1024, duration=10):
        """Тест concurrent пропускной способности"""
        print(f"🧪 Testing Concurrent Throughput ({num_clients} clients)")
        print(f"Data size: {data_size} bytes, Duration: {duration}s")
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
                total_bytes_sent = 0
                total_bytes_received = 0
                start_time = time.time()
                
                while time.time() - start_time < duration:
                    try:
                        # Генерируем сообщение
                        message = f"client_{client_id}_msg_{messages_sent}".ljust(data_size)
                        message = message[:data_size].encode()
                        
                        sock.sendto(message, (self.relay_host, self.relay_port))
                        messages_sent += 1
                        total_bytes_sent += len(message)
                        
                        response, addr = sock.recvfrom(data_size + 100)
                        if response == message:
                            messages_received += 1
                            total_bytes_received += len(response)
                        
                        time.sleep(0.01)  # Небольшая задержка
                        
                    except socket.timeout:
                        continue
                    except Exception as e:
                        continue
                
                end_time = time.time()
                actual_duration = end_time - start_time
                
                # Рассчитываем пропускную способность
                throughput_mbps = (total_bytes_sent * 8) / (actual_duration * 1000000)
                throughput_roundtrip_mbps = (total_bytes_received * 8) / (actual_duration * 1000000)
                
                result = {
                    'client_id': client_id,
                    'messages_sent': messages_sent,
                    'messages_received': messages_received,
                    'total_bytes_sent': total_bytes_sent,
                    'total_bytes_received': total_bytes_received,
                    'duration': actual_duration,
                    'success_rate': (messages_received / messages_sent * 100) if messages_sent > 0 else 0,
                    'throughput_mbps': throughput_mbps,
                    'throughput_roundtrip_mbps': throughput_roundtrip_mbps
                }
                
                results.append(result)
                print(f"Client {client_id}: {messages_sent} sent, {messages_received} received, {result['success_rate']:.1f}% success, {throughput_mbps:.2f} Mbps")
                
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
            total_bytes_sent = sum(r['total_bytes_sent'] for r in successful_results)
            total_bytes_received = sum(r['total_bytes_received'] for r in successful_results)
            avg_success_rate = statistics.mean(r['success_rate'] for r in successful_results)
            avg_throughput = statistics.mean(r['throughput_mbps'] for r in successful_results)
            
            print(f"\n📊 Concurrent Results:")
            print(f"Total messages sent: {total_sent}")
            print(f"Total messages received: {total_received}")
            print(f"Total bytes sent: {total_bytes_sent:,}")
            print(f"Total bytes received: {total_bytes_received:,}")
            print(f"Overall success rate: {(total_received/total_sent*100):.1f}%")
            print(f"Average client success rate: {avg_success_rate:.1f}%")
            print(f"Average throughput: {avg_throughput:.2f} Mbps")
            
            self.results['concurrent'] = {
                'total_sent': total_sent,
                'total_received': total_received,
                'total_bytes_sent': total_bytes_sent,
                'total_bytes_received': total_bytes_received,
                'overall_success_rate': total_received/total_sent*100,
                'avg_client_success_rate': avg_success_rate,
                'avg_throughput_mbps': avg_throughput,
                'clients': successful_results
            }
            
            return True
        else:
            print("❌ All clients failed")
            return False
    
    def test_latency(self, iterations=20):
        """Тест задержки"""
        print("🧪 Testing Latency")
        print("=" * 30)
        
        latencies = []
        
        for i in range(iterations):
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.settimeout(3.0)
                
                # Отправляем небольшое сообщение
                message = f"latency_test_{i}"
                start_time = time.time()
                
                sock.sendto(message.encode(), (self.relay_host, self.relay_port))
                response, addr = sock.recvfrom(1024)
                
                end_time = time.time()
                latency = (end_time - start_time) * 1000  # в миллисекундах
                latencies.append(latency)
                
                print(f"Test {i+1:2d}: {latency:6.2f}ms")
                time.sleep(0.1)
                
                sock.close()
                
            except Exception as e:
                print(f"Test {i+1:2d}: ERROR - {e}")
                continue
        
        if latencies:
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
        else:
            print("❌ No successful latency measurements")
            return False
    
    def run_all_tests(self):
        """Запуск всех тестов"""
        print("🚀 Relay Speed Test")
        print("=" * 50)
        print(f"Target: {self.relay_host}:{self.relay_port}")
        print()
        
        tests = [
            ("Latency Test", self.test_latency),
            ("Throughput Range Test", self.test_throughput_range),
            ("Concurrent Test", lambda: self.test_concurrent_throughput(3, 1024, 10))
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
    speed_test = RelaySpeedTest()
    speed_test.run_all_tests()


