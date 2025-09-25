//go:build example
// +build example

package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/2gc-dev/cloudbridge-client/pkg/config"
	"github.com/2gc-dev/cloudbridge-client/pkg/relay"
	"github.com/2gc-dev/cloudbridge-client/pkg/utils"
)

// P2P mesh example demonstrating CloudBridge Client P2P capabilities
func main() {
	// Load configuration
	configPath := "examples/config-with-pushgateway.yaml"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}
	cfg, err := config.LoadConfig(configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Create client with hot-reload support
	client, err := relay.NewClient(cfg, configPath)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}
	defer client.Close()

	// Set transport mode to gRPC for modern protocol
	if err := client.SetTransportMode("grpc"); err != nil {
		log.Printf("Warning: Failed to set gRPC transport, using fallback: %v", err)
	}

	// Connect to relay server
	if err := client.Connect(); err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}

	log.Printf("Connected to relay server %s:%d", cfg.Relay.Host, cfg.Relay.Port)
	log.Printf("Transport mode: %s", client.GetCurrentTransportMode())

	// Authenticate (token should be in environment variable JWT_TOKEN)
	token := os.Getenv("JWT_TOKEN")
	if token == "" {
		log.Fatal("JWT_TOKEN environment variable is required")
	}

	if err := client.Authenticate(token); err != nil {
		log.Fatalf("Failed to authenticate: %v", err)
	}

	log.Printf("Authenticated with client ID: %s", client.GetClientID())
	log.Printf("Connection type: %s", client.GetConnectionType())

	// Start heartbeat
	if err := client.StartHeartbeat(); err != nil {
		log.Fatalf("Failed to start heartbeat: %v", err)
	}

	// Get P2P manager if available
	p2pManager := client.GetP2PManager()
	if p2pManager != nil {
		log.Println("P2P mesh networking is active")
	} else {
		log.Println("P2P mesh networking not available (requires P2P token)")
	}

	// Get AutoSwitchManager for transport monitoring
	autoSwitchMgr := client.GetAutoSwitchManager()
	if autoSwitchMgr != nil {
		log.Printf("AutoSwitchManager active, current mode: %s", autoSwitchMgr.GetCurrentMode())

		// Add callback to monitor transport switches
		autoSwitchMgr.AddSwitchCallback(func(from, to relay.TransportMode) {
			log.Printf("Transport switched: %s -> %s", from, to)
		})
	}

	// Start metrics update loop with P2P session tracking
	go func() {
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				client.UpdateMetrics()
				// Simulate P2P data transfer
				client.RecordDataTransfer(2048, 4096)

				// Log current status
				if autoSwitchMgr != nil {
					log.Printf("Status - Transport: %s, AutoSwitch: %s",
						client.GetCurrentTransportMode(),
						autoSwitchMgr.GetCurrentMode())
				} else {
					log.Printf("Status - Transport: %s",
						client.GetCurrentTransportMode())
				}
			}
		}
	}()

	log.Println("P2P mesh client is running. Press Ctrl+C to stop.")
	log.Printf("Try changing %s to test hot-reload!", configPath)

	// Wait for interrupt signal
	sigChan := utils.SetupSignalHandler()
	<-sigChan

	fmt.Println("\nShutting down P2P mesh client...")
}
