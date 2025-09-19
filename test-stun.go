package main

import (
	"fmt"
	"net"
	"time"

	"github.com/pion/stun"
)

func main() {
	fmt.Println("🧪 Testing STUN Server with Go")
	fmt.Println("==================================================")
	
	// Test STUN server
	host := "edge.2gc.ru:19302"
	
	fmt.Printf("Testing STUN server: %s\n", host)
	
	// Create connection
	conn, err := net.Dial("udp", host)
	if err != nil {
		fmt.Printf("❌ Failed to connect to STUN server: %v\n", err)
		return
	}
	defer conn.Close()
	
	// Create STUN client with connection
	c, err := stun.NewClient(conn)
	if err != nil {
		fmt.Printf("❌ Failed to create STUN client: %v\n", err)
		return
	}
	defer c.Close()
	
	// Create STUN request
	message := stun.MustBuild(stun.TransactionID, stun.BindingRequest)
	
	fmt.Println("Sending STUN Binding Request...")
	start := time.Now()
	
	// Send request and wait for response
	err = c.Do(message, func(event stun.Event) {
		if event.Error != nil {
			fmt.Printf("❌ STUN error: %v\n", event.Error)
			return
		}
		
		fmt.Printf("✅ STUN response received in %v\n", time.Since(start))
		
		// Parse response
		var xorAddr stun.XORMappedAddress
		if err := xorAddr.GetFrom(event.Message); err == nil {
			fmt.Printf("✅ XORMappedAddress: %s\n", xorAddr.String())
		}
		
		var mappedAddr stun.MappedAddress
		if err := mappedAddr.GetFrom(event.Message); err == nil {
			fmt.Printf("✅ MappedAddress: %s\n", mappedAddr.String())
		}
		
		// Print message details
		fmt.Printf("Message Type: %s\n", event.Message.Type)
		fmt.Printf("Message Length: %d\n", event.Message.Length)
		fmt.Printf("Transaction ID: %x\n", event.Message.TransactionID)
	})
	
	if err != nil {
		fmt.Printf("❌ STUN request failed: %v\n", err)
		return
	}
	
	fmt.Println("✅ STUN test completed successfully!")
}
