#!/usr/bin/env python3
"""
Advanced STUN Server Test
Tests STUN server functionality for NAT traversal
"""

import socket
import struct
import time
import random
import sys

def create_stun_request():
    """Create a STUN Binding Request"""
    # STUN header
    msg_type = 0x0001  # Binding Request
    msg_length = 0x0000  # No attributes
    transaction_id = bytes([random.randint(0, 255) for _ in range(12)])
    
    # Create STUN message
    stun_msg = struct.pack('>HH', msg_type, msg_length) + transaction_id
    return stun_msg, transaction_id

def parse_stun_response(data):
    """Parse STUN response"""
    if len(data) < 20:
        return None, "Response too short"
    
    # Parse header
    msg_type = struct.unpack('>H', data[0:2])[0]
    msg_length = struct.unpack('>H', data[2:4])[0]
    transaction_id = data[4:16]
    
    result = {
        'msg_type': msg_type,
        'msg_length': msg_length,
        'transaction_id': transaction_id.hex()
    }
    
    # Parse attributes if present
    if msg_length > 0 and len(data) >= 20 + msg_length:
        attributes = []
        offset = 20
        while offset < 20 + msg_length:
            if offset + 4 > len(data):
                break
            attr_type = struct.unpack('>H', data[offset:offset+2])[0]
            attr_length = struct.unpack('>H', data[offset+2:offset+4])[0]
            attr_value = data[offset+4:offset+4+attr_length]
            attributes.append({
                'type': attr_type,
                'length': attr_length,
                'value': attr_value
            })
            offset += 4 + attr_length
        result['attributes'] = attributes
    
    return result, None

def test_stun_server(host, port, timeout=5):
    """Test STUN server"""
    print(f"=== Testing STUN Server: {host}:{port} ===")
    
    try:
        # Create UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        
        # Create STUN request
        stun_request, transaction_id = create_stun_request()
        print(f"STUN Request: {stun_request.hex()}")
        print(f"Transaction ID: {transaction_id.hex()}")
        
        # Send request
        print(f"Sending STUN request to {host}:{port}...")
        start_time = time.time()
        sock.sendto(stun_request, (host, port))
        
        # Receive response
        print("Waiting for STUN response...")
        response, addr = sock.recvfrom(1024)
        end_time = time.time()
        
        print(f"✅ Received response from {addr}")
        print(f"Response time: {(end_time - start_time)*1000:.2f}ms")
        print(f"Response length: {len(response)} bytes")
        print(f"Response data: {response.hex()}")
        
        # Parse response
        parsed, error = parse_stun_response(response)
        if error:
            print(f"❌ Failed to parse response: {error}")
            return False
        
        print(f"✅ STUN Response parsed successfully:")
        print(f"  Message Type: 0x{parsed['msg_type']:04x}")
        print(f"  Message Length: {parsed['msg_length']}")
        print(f"  Transaction ID: {parsed['transaction_id']}")
        
        # Check if it's a Binding Success Response
        if parsed['msg_type'] == 0x0101:
            print("✅ STUN Binding Success Response received!")
            
            # Check for MAPPED-ADDRESS attribute (0x0001)
            if 'attributes' in parsed:
                for attr in parsed['attributes']:
                    if attr['type'] == 0x0001:  # MAPPED-ADDRESS
                        print(f"✅ MAPPED-ADDRESS attribute found: {attr['value'].hex()}")
                        # Parse mapped address
                        if len(attr['value']) >= 8:
                            family = struct.unpack('>H', attr['value'][2:4])[0]
                            port = struct.unpack('>H', attr['value'][4:6])[0]
                            if family == 0x01:  # IPv4
                                ip = socket.inet_ntoa(attr['value'][6:10])
                                print(f"  Mapped IP: {ip}")
                                print(f"  Mapped Port: {port}")
                        break
            return True
        else:
            print(f"⚠️  Unexpected STUN response type: 0x{parsed['msg_type']:04x}")
            return False
            
    except socket.timeout:
        print(f"❌ STUN request timeout after {timeout}s")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        sock.close()

def test_multiple_requests(host, port, count=3):
    """Test multiple STUN requests"""
    print(f"\n=== Testing {count} STUN Requests ===")
    success_count = 0
    
    for i in range(count):
        print(f"\n--- Request {i+1}/{count} ---")
        if test_stun_server(host, port):
            success_count += 1
        time.sleep(1)
    
    print(f"\n=== Results: {success_count}/{count} successful ===")
    return success_count == count

def main():
    """Main test function"""
    host = "edge.2gc.ru"
    port = 19302
    
    print("🧪 STUN Server Advanced Test")
    print("=" * 50)
    
    # Test single request
    success = test_stun_server(host, port)
    
    if success:
        # Test multiple requests
        test_multiple_requests(host, port, 3)
    
    print("\n" + "=" * 50)
    if success:
        print("🎉 STUN Server test completed successfully!")
    else:
        print("❌ STUN Server test failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()


