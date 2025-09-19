#!/usr/bin/env python3
"""
Simple STUN Test - проверяет базовую функциональность STUN сервера
"""

import socket
import struct
import time
import random

def test_simple_stun():
    """Простой тест STUN сервера"""
    print("🧪 Simple STUN Test")
    print("=" * 40)
    
    host = "edge.2gc.ru"
    port = 19302
    
    try:
        # Create UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(3.0)
        
        # Create simple STUN request
        transaction_id = bytes([random.randint(0, 255) for _ in range(12)])
        stun_request = struct.pack('>HH', 0x0001, 0x0000) + transaction_id
        
        print(f"STUN Request: {stun_request.hex()}")
        print(f"Transaction ID: {transaction_id.hex()}")
        
        # Send request
        print(f"Sending to {host}:{port}...")
        sock.sendto(stun_request, (host, port))
        
        # Try to receive response
        try:
            response, addr = sock.recvfrom(1024)
            print(f"✅ Response received from {addr}")
            print(f"Response: {response.hex()}")
            
            # Check if it looks like STUN response
            if len(response) >= 20:
                msg_type = struct.unpack('>H', response[0:2])[0]
                print(f"Message Type: 0x{msg_type:04x}")
                if msg_type == 0x0101:
                    print("✅ STUN Binding Success Response!")
                    return True
                else:
                    print(f"⚠️  Unexpected message type: 0x{msg_type:04x}")
                    return False
            else:
                print("⚠️  Response too short")
                return False
                
        except socket.timeout:
            print("❌ No response received (timeout)")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        sock.close()

if __name__ == "__main__":
    success = test_simple_stun()
    if success:
        print("\n🎉 STUN test successful!")
    else:
        print("\n❌ STUN test failed!")


