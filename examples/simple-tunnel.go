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

// Simple tunnel example demonstrating CloudBridge Client usage
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

	// Create client with config path for hot-reload
	client, err := relay.NewClient(cfg, configPath)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}
	defer client.Close()

	// Set transport mode to gRPC
	if err := client.SetTransportMode("grpc"); err != nil {
		log.Printf("Failed to set gRPC transport: %v", err)
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

	// Create tunnel
	tunnelID := "example-tunnel"
	localPort := 8080
	remoteHost := "httpbin.org"
	remotePort := 80

	if err := client.CreateTunnel(tunnelID, localPort, remoteHost, remotePort); err != nil {
		log.Fatalf("Failed to create tunnel: %v", err)
	}

	log.Printf("Tunnel created: localhost:%d -> %s:%d", localPort, remoteHost, remotePort)

	// Start heartbeat
	if err := client.StartHeartbeat(); err != nil {
		log.Fatalf("Failed to start heartbeat: %v", err)
	}

	// Start metrics update loop
	go func() {
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				client.UpdateMetrics()
				// Simulate some data transfer
				client.RecordDataTransfer(1024, 2048)
			}
		}
	}()

	log.Println("Tunnel is active. Press Ctrl+C to stop.")
	log.Printf("Current transport mode: %s", client.GetTransportMode())

	// Wait for interrupt signal
	sigChan := utils.SetupSignalHandler()
	<-sigChan

	fmt.Println("\nShutting down...")
}
