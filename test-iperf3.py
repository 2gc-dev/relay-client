#!/usr/bin/env python3
"""
iperf3 Speed Test for Relay Server
Тест скорости с помощью iperf3 через relay сервер
"""

import subprocess
import time
import threading
import socket
import json

class Iperf3Test:
    def __init__(self, relay_host="edge.2gc.ru", relay_port=9090):
        self.relay_host = relay_host
        self.relay_port = relay_port
        self.results = {}
    
    def test_udp_throughput(self, duration=10, bandwidth="1M", packet_size=1470):
        """Тест UDP пропускной способности через relay"""
        print(f"🧪 Testing UDP Throughput via Relay")
        print(f"Duration: {duration}s, Bandwidth: {bandwidth}, Packet size: {packet_size} bytes")
        print("=" * 60)
        
        try:
            # Запускаем iperf3 клиент
            cmd = [
                "iperf3",
                "-c", self.relay_host,
                "-p", str(self.relay_port),
                "-u",  # UDP
                "-t", str(duration),
                "-b", bandwidth,
                "-l", str(packet_size),
                "-J"  # JSON output
            ]
            
            print(f"Running: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=duration+10)
            
            if result.returncode == 0:
                try:
                    data = json.loads(result.stdout)
                    if 'end' in data and 'sum' in data['end']:
                        sum_data = data['end']['sum']
                        
                        print(f"✅ UDP Test Results:")
                        print(f"  Duration: {sum_data.get('seconds', 0):.2f}s")
                        print(f"  Bytes sent: {sum_data.get('bytes', 0):,}")
                        print(f"  Bytes received: {sum_data.get('bytes', 0):,}")
                        print(f"  Bandwidth: {sum_data.get('bits_per_second', 0)/1000000:.2f} Mbps")
                        print(f"  Jitter: {sum_data.get('jitter_ms', 0):.2f} ms")
                        print(f"  Lost packets: {sum_data.get('lost_packets', 0)}")
                        print(f"  Lost percent: {sum_data.get('lost_percent', 0):.2f}%")
                        
                        self.results['udp_throughput'] = {
                            'duration': sum_data.get('seconds', 0),
                            'bytes_sent': sum_data.get('bytes', 0),
                            'bandwidth_mbps': sum_data.get('bits_per_second', 0)/1000000,
                            'jitter_ms': sum_data.get('jitter_ms', 0),
                            'lost_packets': sum_data.get('lost_packets', 0),
                            'lost_percent': sum_data.get('lost_percent', 0),
                            'success': True
                        }
                        
                        return True
                    else:
                        print("❌ Invalid iperf3 output format")
                        return False
                        
                except json.JSONDecodeError:
                    print("❌ Failed to parse iperf3 JSON output")
                    print(f"Output: {result.stdout}")
                    return False
            else:
                print(f"❌ iperf3 failed with return code {result.returncode}")
                print(f"Error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ iperf3 test timed out")
            return False
        except Exception as e:
            print(f"❌ iperf3 test failed: {e}")
            return False
    
    def test_tcp_throughput(self, duration=10):
        """Тест TCP пропускной способности через relay"""
        print(f"\n🧪 Testing TCP Throughput via Relay")
        print(f"Duration: {duration}s")
        print("=" * 40)
        
        try:
            # Запускаем iperf3 клиент для TCP
            cmd = [
                "iperf3",
                "-c", self.relay_host,
                "-p", str(self.relay_port),
                "-t", str(duration),
                "-J"  # JSON output
            ]
            
            print(f"Running: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=duration+10)
            
            if result.returncode == 0:
                try:
                    data = json.loads(result.stdout)
                    if 'end' in data and 'sum_sent' in data['end']:
                        sent_data = data['end']['sum_sent']
                        received_data = data['end']['sum_received']
                        
                        print(f"✅ TCP Test Results:")
                        print(f"  Duration: {sent_data.get('seconds', 0):.2f}s")
                        print(f"  Bytes sent: {sent_data.get('bytes', 0):,}")
                        print(f"  Bytes received: {received_data.get('bytes', 0):,}")
                        print(f"  Send bandwidth: {sent_data.get('bits_per_second', 0)/1000000:.2f} Mbps")
                        print(f"  Receive bandwidth: {received_data.get('bits_per_second', 0)/1000000:.2f} Mbps")
                        
                        self.results['tcp_throughput'] = {
                            'duration': sent_data.get('seconds', 0),
                            'bytes_sent': sent_data.get('bytes', 0),
                            'bytes_received': received_data.get('bytes', 0),
                            'send_bandwidth_mbps': sent_data.get('bits_per_second', 0)/1000000,
                            'receive_bandwidth_mbps': received_data.get('bits_per_second', 0)/1000000,
                            'success': True
                        }
                        
                        return True
                    else:
                        print("❌ Invalid iperf3 TCP output format")
                        return False
                        
                except json.JSONDecodeError:
                    print("❌ Failed to parse iperf3 JSON output")
                    print(f"Output: {result.stdout}")
                    return False
            else:
                print(f"❌ iperf3 TCP failed with return code {result.returncode}")
                print(f"Error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ iperf3 TCP test timed out")
            return False
        except Exception as e:
            print(f"❌ iperf3 TCP test failed: {e}")
            return False
    
    def test_parallel_streams(self, duration=10, num_streams=4):
        """Тест параллельных потоков"""
        print(f"\n🧪 Testing Parallel Streams ({num_streams} streams)")
        print(f"Duration: {duration}s")
        print("=" * 40)
        
        try:
            # Запускаем iperf3 с несколькими потоками
            cmd = [
                "iperf3",
                "-c", self.relay_host,
                "-p", str(self.relay_port),
                "-t", str(duration),
                "-P", str(num_streams),  # Parallel streams
                "-J"  # JSON output
            ]
            
            print(f"Running: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=duration+10)
            
            if result.returncode == 0:
                try:
                    data = json.loads(result.stdout)
                    if 'end' in data and 'sum_sent' in data['end']:
                        sent_data = data['end']['sum_sent']
                        received_data = data['end']['sum_received']
                        
                        print(f"✅ Parallel Streams Results:")
                        print(f"  Duration: {sent_data.get('seconds', 0):.2f}s")
                        print(f"  Streams: {num_streams}")
                        print(f"  Total bytes sent: {sent_data.get('bytes', 0):,}")
                        print(f"  Total bytes received: {received_data.get('bytes', 0):,}")
                        print(f"  Total bandwidth: {sent_data.get('bits_per_second', 0)/1000000:.2f} Mbps")
                        
                        # Информация по каждому потоку
                        if 'streams' in data['end']:
                            print(f"  Individual streams:")
                            for i, stream in enumerate(data['end']['streams']):
                                print(f"    Stream {i+1}: {stream.get('bits_per_second', 0)/1000000:.2f} Mbps")
                        
                        self.results['parallel_streams'] = {
                            'duration': sent_data.get('seconds', 0),
                            'num_streams': num_streams,
                            'total_bytes_sent': sent_data.get('bytes', 0),
                            'total_bytes_received': received_data.get('bytes', 0),
                            'total_bandwidth_mbps': sent_data.get('bits_per_second', 0)/1000000,
                            'success': True
                        }
                        
                        return True
                    else:
                        print("❌ Invalid iperf3 parallel output format")
                        return False
                        
                except json.JSONDecodeError:
                    print("❌ Failed to parse iperf3 JSON output")
                    return False
            else:
                print(f"❌ iperf3 parallel failed with return code {result.returncode}")
                print(f"Error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ iperf3 parallel test timed out")
            return False
        except Exception as e:
            print(f"❌ iperf3 parallel test failed: {e}")
            return False
    
    def test_bidirectional(self, duration=10):
        """Тест двунаправленной передачи"""
        print(f"\n🧪 Testing Bidirectional Transfer")
        print(f"Duration: {duration}s")
        print("=" * 40)
        
        try:
            # Запускаем iperf3 с двунаправленной передачей
            cmd = [
                "iperf3",
                "-c", self.relay_host,
                "-p", str(self.relay_port),
                "-t", str(duration),
                "--bidir",  # Bidirectional
                "-J"  # JSON output
            ]
            
            print(f"Running: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=duration+10)
            
            if result.returncode == 0:
                try:
                    data = json.loads(result.stdout)
                    if 'end' in data and 'sum_sent' in data['end']:
                        sent_data = data['end']['sum_sent']
                        received_data = data['end']['sum_received']
                        
                        print(f"✅ Bidirectional Results:")
                        print(f"  Duration: {sent_data.get('seconds', 0):.2f}s")
                        print(f"  Bytes sent: {sent_data.get('bytes', 0):,}")
                        print(f"  Bytes received: {received_data.get('bytes', 0):,}")
                        print(f"  Send bandwidth: {sent_data.get('bits_per_second', 0)/1000000:.2f} Mbps")
                        print(f"  Receive bandwidth: {received_data.get('bits_per_second', 0)/1000000:.2f} Mbps")
                        print(f"  Total bandwidth: {(sent_data.get('bits_per_second', 0) + received_data.get('bits_per_second', 0))/1000000:.2f} Mbps")
                        
                        self.results['bidirectional'] = {
                            'duration': sent_data.get('seconds', 0),
                            'bytes_sent': sent_data.get('bytes', 0),
                            'bytes_received': received_data.get('bytes', 0),
                            'send_bandwidth_mbps': sent_data.get('bits_per_second', 0)/1000000,
                            'receive_bandwidth_mbps': received_data.get('bits_per_second', 0)/1000000,
                            'total_bandwidth_mbps': (sent_data.get('bits_per_second', 0) + received_data.get('bits_per_second', 0))/1000000,
                            'success': True
                        }
                        
                        return True
                    else:
                        print("❌ Invalid iperf3 bidirectional output format")
                        return False
                        
                except json.JSONDecodeError:
                    print("❌ Failed to parse iperf3 JSON output")
                    return False
            else:
                print(f"❌ iperf3 bidirectional failed with return code {result.returncode}")
                print(f"Error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ iperf3 bidirectional test timed out")
            return False
        except Exception as e:
            print(f"❌ iperf3 bidirectional test failed: {e}")
            return False
    
    def run_all_tests(self):
        """Запуск всех iperf3 тестов"""
        print("🚀 iperf3 Speed Test for Relay Server")
        print("=" * 50)
        print(f"Target: {self.relay_host}:{self.relay_port}")
        print()
        
        tests = [
            ("UDP Throughput", lambda: self.test_udp_throughput(10, "1M", 1470)),
            ("TCP Throughput", lambda: self.test_tcp_throughput(10)),
            ("Parallel Streams", lambda: self.test_parallel_streams(10, 4)),
            ("Bidirectional", lambda: self.test_bidirectional(10))
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
            print("🎉 All iperf3 tests passed!")
        else:
            print("⚠️  Some iperf3 tests failed")
        
        return results

if __name__ == "__main__":
    # Запуск тестов
    iperf_test = Iperf3Test()
    iperf_test.run_all_tests()


