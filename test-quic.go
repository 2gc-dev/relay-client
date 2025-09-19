package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"time"

	"github.com/quic-go/quic-go"
)

func main() {
	fmt.Println("🚀 Testing QUIC Connection")
	fmt.Println("==================================================")
	
	// Test QUIC server
	host := "edge.2gc.ru:9090"
	
	fmt.Printf("Testing QUIC server: %s\n", host)
	
	// Create TLS config
	tlsConfig := &tls.Config{
		InsecureSkipVerify: true, // For testing
	}
	
	// Create QUIC config
	quicConfig := &quic.Config{
		HandshakeIdleTimeout: 10 * time.Second,
		MaxIdleTimeout:       30 * time.Second,
		MaxIncomingStreams:   100,
		MaxIncomingUniStreams: 100,
		KeepAlivePeriod:      15 * time.Second,
	}
	
	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	
	fmt.Println("Attempting QUIC connection...")
	start := time.Now()
	
	// Connect to QUIC server
	conn, err := quic.DialAddr(ctx, host, tlsConfig, quicConfig)
	if err != nil {
		fmt.Printf("❌ Failed to connect to QUIC server: %v\n", err)
		return
	}
	defer conn.CloseWithError(0, "test completed")
	
	fmt.Printf("✅ QUIC connection established in %v\n", time.Since(start))
	
	// Get connection info
	fmt.Printf("✅ Connection State: %s\n", conn.ConnectionState().TLS.Version)
	fmt.Printf("✅ Remote Address: %s\n", conn.RemoteAddr())
	fmt.Printf("✅ Local Address: %s\n", conn.LocalAddr())
	
	// Test opening a stream
	fmt.Println("Testing stream creation...")
	stream, err := conn.OpenStreamSync(ctx)
	if err != nil {
		fmt.Printf("❌ Failed to open stream: %v\n", err)
		return
	}
	defer stream.Close()
	
	fmt.Println("✅ Stream opened successfully")
	
	// Send test data
	testData := []byte("Hello QUIC Server!")
	fmt.Printf("Sending test data: %s\n", string(testData))
	
	_, err = stream.Write(testData)
	if err != nil {
		fmt.Printf("❌ Failed to write to stream: %v\n", err)
		return
	}
	
	fmt.Println("✅ Data sent successfully")
	
	// Close write side
	stream.Close()
	
	// Try to read response (with timeout)
	stream.SetReadDeadline(time.Now().Add(5 * time.Second))
	
	buffer := make([]byte, 1024)
	n, err := stream.Read(buffer)
	if err != nil && err != io.EOF {
		if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
			fmt.Println("⚠️  No response received (timeout expected)")
		} else {
			fmt.Printf("❌ Failed to read from stream: %v\n", err)
			return
		}
	} else {
		fmt.Printf("✅ Response received: %s\n", string(buffer[:n]))
	}
	
	fmt.Println("✅ QUIC test completed successfully!")
}
