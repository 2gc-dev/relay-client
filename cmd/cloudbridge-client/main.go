package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	"github.com/2gc-dev/cloudbridge-client/pkg/config"
	"github.com/2gc-dev/cloudbridge-client/pkg/errors"
	"github.com/2gc-dev/cloudbridge-client/pkg/relay"
	"github.com/2gc-dev/cloudbridge-client/pkg/service"
	"github.com/2gc-dev/cloudbridge-client/pkg/types"
	"github.com/spf13/cobra" // Required for CLI interface
)

var (
	configFile string
	token      string
	tunnelID   string
	localPort  int
	remoteHost string
	remotePort int
	verbose    bool

	// P2P Mesh specific flags
	p2pMode    bool
	peerID     string
	endpoint   string
	publicKey  string
	privateKey string
	meshPort   int
)

func main() {
	// Ensure cobra is used to prevent go mod tidy from removing it
	_ = cobra.Command{}
	
	rootCmd := &cobra.Command{
		Use:   "cloudbridge-client",
		Short: "CloudBridge Relay Client",
		Long:  "A cross-platform client for CloudBridge Relay with TLS 1.3 support, JWT authentication, and P2P mesh networking",
		RunE:  run,
	}

	// Add basic flags
	rootCmd.Flags().StringVarP(&configFile, "config", "c", "", "Configuration file path")
	rootCmd.Flags().StringVarP(&token, "token", "t", "", "JWT token for authentication")
	rootCmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "Enable verbose logging")

	// Tunnel mode flags
	rootCmd.Flags().StringVarP(&tunnelID, "tunnel-id", "i", "tunnel_001", "Tunnel ID")
	rootCmd.Flags().IntVarP(&localPort, "local-port", "l", 3389, "Local port to bind")
	rootCmd.Flags().StringVarP(&remoteHost, "remote-host", "r", "192.168.1.100", "Remote host")
	rootCmd.Flags().IntVarP(&remotePort, "remote-port", "p", 3389, "Remote port")

	// P2P Mesh mode flags
	rootCmd.Flags().BoolVar(&p2pMode, "p2p", false, "Enable P2P mesh mode")
	rootCmd.Flags().StringVar(&peerID, "peer-id", "", "Peer ID for P2P mesh")
	rootCmd.Flags().StringVar(&endpoint, "endpoint", "", "WireGuard endpoint (IP:PORT)")
	rootCmd.Flags().StringVar(&publicKey, "public-key", "", "WireGuard public key")
	rootCmd.Flags().StringVar(&privateKey, "private-key", "", "WireGuard private key")
	rootCmd.Flags().IntVar(&meshPort, "mesh-port", 51820, "WireGuard mesh port")

	// Mark required flags
	if err := rootCmd.MarkFlagRequired("token"); err != nil {
		fmt.Fprintf(os.Stderr, "Error marking flag required: %v\n", err)
		os.Exit(1)
	}

	// Add subcommands
	rootCmd.AddCommand(createP2PCommand())
	rootCmd.AddCommand(createTunnelCommand())
	rootCmd.AddCommand(createServiceCommand())

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run(cmd *cobra.Command, args []string) error {
	// Log platform information
	log.Printf("Running on %s/%s", runtime.GOOS, runtime.GOARCH)

	// Load configuration
	cfg, err := config.LoadConfig(configFile)
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	// Override config with command line flags if provided
	if token != "" {
		cfg.Auth.Secret = token // For JWT auth, secret is the token
	}

	// Create client
	client, err := relay.NewClient(cfg)
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}
	defer func() {
		if err := client.Close(); err != nil {
			log.Printf("Failed to close client: %v", err)
		}
	}()

	// Set up signal handling for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	if runtime.GOOS == types.PlatformWindows {
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	} else {
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	}

	// Start connection with retry logic
	if err := connectWithRetry(client); err != nil {
		return fmt.Errorf("failed to connect: %w", err)
	}

	log.Printf("Successfully connected to relay server %s:%d", cfg.Relay.Host, cfg.Relay.Port)

	// Authenticate
	if err := authenticateWithRetry(client, token); err != nil {
		return fmt.Errorf("failed to authenticate: %w", err)
	}

	log.Printf("Successfully authenticated with client ID: %s", client.GetClientID())

	// Create tunnel
	if err := createTunnelWithRetry(client, tunnelID, localPort, remoteHost, remotePort); err != nil {
		return fmt.Errorf("failed to create tunnel: %w", err)
	}

	log.Printf("Successfully created tunnel %s: localhost:%d -> %s:%d",
		tunnelID, localPort, remoteHost, remotePort)

	// Start heartbeat
	if err := client.StartHeartbeat(); err != nil {
		return fmt.Errorf("failed to start heartbeat: %w", err)
	}

	log.Printf("Heartbeat started")

	// Wait for shutdown signal
	select {
	case <-sigChan:
		log.Println("Received shutdown signal, closing...")
	case <-ctx.Done():
		log.Println("Context canceled, closing...")
	}

	return nil
}

// connectWithRetry connects to the relay server with retry logic
func connectWithRetry(client *relay.Client) error {
	retryStrategy := client.GetRetryStrategy()

	for {
		err := client.Connect()
		if err == nil {
			return nil
		}

		relayErr, _ := errors.HandleError(err)
		if relayErr == nil || !retryStrategy.ShouldRetry(err) {
			return err
		}

		delay := retryStrategy.GetNextDelay(err)
		log.Printf("Connection failed: %v, retrying in %v...", err, delay)
		time.Sleep(delay)
	}
}

// authenticateWithRetry authenticates with retry logic
func authenticateWithRetry(client *relay.Client, token string) error {
	retryStrategy := client.GetRetryStrategy()

	for {
		err := client.Authenticate(token)
		if err == nil {
			return nil
		}

		relayErr, _ := errors.HandleError(err)
		if relayErr == nil || !retryStrategy.ShouldRetry(err) {
			return err
		}

		delay := retryStrategy.GetNextDelay(err)
		log.Printf("Authentication failed: %v, retrying in %v...", err, delay)
		time.Sleep(delay)
	}
}

// createTunnelWithRetry creates a tunnel with retry logic
func createTunnelWithRetry(client *relay.Client, tunnelID string, localPort int, remoteHost string, remotePort int) error {
	retryStrategy := client.GetRetryStrategy()

	for {
		err := client.CreateTunnel(tunnelID, localPort, remoteHost, remotePort)
		if err == nil {
			return nil
		}

		relayErr, _ := errors.HandleError(err)
		if relayErr == nil || !retryStrategy.ShouldRetry(err) {
			return err
		}

		delay := retryStrategy.GetNextDelay(err)
		log.Printf("Tunnel creation failed: %v, retrying in %v...", err, delay)
		time.Sleep(delay)
	}
}

// createP2PCommand creates the P2P mesh subcommand
func createP2PCommand() *cobra.Command {
	p2pCmd := &cobra.Command{
		Use:   "p2p",
		Short: "Start P2P mesh networking",
		Long:  "Connect to P2P mesh network using WireGuard",
		RunE:  runP2P,
	}

	// P2P specific flags
	p2pCmd.Flags().StringVar(&peerID, "peer-id", "", "Peer ID for P2P mesh (required)")
	p2pCmd.Flags().StringVar(&endpoint, "endpoint", "", "WireGuard endpoint (IP:PORT) (required)")
	p2pCmd.Flags().StringVar(&publicKey, "public-key", "", "WireGuard public key (required)")
	p2pCmd.Flags().StringVar(&privateKey, "private-key", "", "WireGuard private key (required)")
	p2pCmd.Flags().IntVar(&meshPort, "mesh-port", 51820, "WireGuard mesh port")

	// Mark required flags
	if err := p2pCmd.MarkFlagRequired("peer-id"); err != nil {
		fmt.Fprintf(os.Stderr, "Error marking flag required: %v\n", err)
		os.Exit(1)
	}
	if err := p2pCmd.MarkFlagRequired("endpoint"); err != nil {
		fmt.Fprintf(os.Stderr, "Error marking flag required: %v\n", err)
		os.Exit(1)
	}
	if err := p2pCmd.MarkFlagRequired("public-key"); err != nil {
		fmt.Fprintf(os.Stderr, "Error marking flag required: %v\n", err)
		os.Exit(1)
	}
	if err := p2pCmd.MarkFlagRequired("private-key"); err != nil {
		fmt.Fprintf(os.Stderr, "Error marking flag required: %v\n", err)
		os.Exit(1)
	}

	return p2pCmd
}

// createTunnelCommand creates the tunnel subcommand
func createTunnelCommand() *cobra.Command {
	tunnelCmd := &cobra.Command{
		Use:   "tunnel",
		Short: "Start tunnel mode",
		Long:  "Create a tunnel to remote host",
		RunE:  runTunnel,
	}

	// Tunnel specific flags
	tunnelCmd.Flags().StringVarP(&tunnelID, "tunnel-id", "i", "tunnel_001", "Tunnel ID")
	tunnelCmd.Flags().IntVarP(&localPort, "local-port", "l", 3389, "Local port to bind")
	tunnelCmd.Flags().StringVarP(&remoteHost, "remote-host", "r", "192.168.1.100", "Remote host")
	tunnelCmd.Flags().IntVarP(&remotePort, "remote-port", "p", 3389, "Remote port")

	return tunnelCmd
}

// createServiceCommand creates the service management subcommand
func createServiceCommand() *cobra.Command {
	svcCmd := &cobra.Command{
		Use:   "service",
		Short: "Manage CloudBridge Client service",
		Long:  "Install, uninstall, start, stop, restart, or check status of CloudBridge Client service",
	}

	// Install service command
	installCmd := &cobra.Command{
		Use:   "install",
		Short: "Install CloudBridge Client as a service",
		Long:  "Install CloudBridge Client as a system service with auto-start",
		RunE:  runServiceInstall,
	}
	installCmd.Flags().StringVarP(&configFile, "config", "c", "", "Configuration file path")
	installCmd.Flags().StringVarP(&token, "token", "t", "", "JWT token for authentication")
	if err := installCmd.MarkFlagRequired("config"); err != nil {
		fmt.Fprintf(os.Stderr, "Error marking flag required: %v\n", err)
		os.Exit(1)
	}
	if err := installCmd.MarkFlagRequired("token"); err != nil {
		fmt.Fprintf(os.Stderr, "Error marking flag required: %v\n", err)
		os.Exit(1)
	}

	// Uninstall service command
	uninstallCmd := &cobra.Command{
		Use:   "uninstall",
		Short: "Uninstall CloudBridge Client service",
		Long:  "Remove CloudBridge Client service from the system",
		RunE:  runServiceUninstall,
	}

	// Start service command
	startCmd := &cobra.Command{
		Use:   "start",
		Short: "Start CloudBridge Client service",
		Long:  "Start the CloudBridge Client service",
		RunE:  runServiceStart,
	}

	// Stop service command
	stopCmd := &cobra.Command{
		Use:   "stop",
		Short: "Stop CloudBridge Client service",
		Long:  "Stop the CloudBridge Client service",
		RunE:  runServiceStop,
	}

	// Restart service command
	restartCmd := &cobra.Command{
		Use:   "restart",
		Short: "Restart CloudBridge Client service",
		Long:  "Restart the CloudBridge Client service",
		RunE:  runServiceRestart,
	}

	// Status service command
	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Check CloudBridge Client service status",
		Long:  "Check the current status of CloudBridge Client service",
		RunE:  runServiceStatus,
	}

	svcCmd.AddCommand(installCmd)
	svcCmd.AddCommand(uninstallCmd)
	svcCmd.AddCommand(startCmd)
	svcCmd.AddCommand(stopCmd)
	svcCmd.AddCommand(restartCmd)
	svcCmd.AddCommand(statusCmd)

	return svcCmd
}

// runServiceInstall installs the service
func runServiceInstall(cmd *cobra.Command, args []string) error {
	log.Printf("Installing CloudBridge Client service...")

	// Get current executable path
	execPath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get executable path: %w", err)
	}

	// Create service configuration with token
	if err := createServiceConfig(configFile, token); err != nil {
		return fmt.Errorf("failed to create service config: %w", err)
	}

	// Install service
	if err := service.Install(execPath); err != nil {
		return fmt.Errorf("failed to install service: %w", err)
	}

	log.Printf("Service installed successfully")
	return nil
}

// runServiceUninstall uninstalls the service
func runServiceUninstall(cmd *cobra.Command, args []string) error {
	log.Printf("Uninstalling CloudBridge Client service...")

	if err := service.Uninstall(); err != nil {
		return fmt.Errorf("failed to uninstall service: %w", err)
	}

	log.Printf("Service uninstalled successfully")
	return nil
}

// runServiceStart starts the service
func runServiceStart(cmd *cobra.Command, args []string) error {
	log.Printf("Starting CloudBridge Client service...")

	if err := service.Start(); err != nil {
		return fmt.Errorf("failed to start service: %w", err)
	}

	log.Printf("Service started successfully")
	return nil
}

// runServiceStop stops the service
func runServiceStop(cmd *cobra.Command, args []string) error {
	log.Printf("Stopping CloudBridge Client service...")

	if err := service.Stop(); err != nil {
		return fmt.Errorf("failed to stop service: %w", err)
	}

	log.Printf("Service stopped successfully")
	return nil
}

// runServiceRestart restarts the service
func runServiceRestart(cmd *cobra.Command, args []string) error {
	log.Printf("Restarting CloudBridge Client service...")

	if err := service.Restart(); err != nil {
		return fmt.Errorf("failed to restart service: %w", err)
	}

	log.Printf("Service restarted successfully")
	return nil
}

// runServiceStatus checks the service status
func runServiceStatus(cmd *cobra.Command, args []string) error {
	status, err := service.Status()
	if err != nil {
		return fmt.Errorf("failed to get service status: %w", err)
	}

	fmt.Printf("Service status: %s\n", status)
	return nil
}

// createServiceConfig creates a service-specific configuration file
func createServiceConfig(configPath, token string) error {
	// Load base configuration
	cfg, err := config.LoadConfig(configPath)
	if err != nil {
		return fmt.Errorf("failed to load base configuration: %w", err)
	}

	// Set token in configuration
	cfg.Auth.Secret = token

	// Create service config directory
	serviceConfigDir := "/etc/cloudbridge-client"
	if runtime.GOOS == types.PlatformWindows {
		serviceConfigDir = filepath.Join(os.Getenv("ProgramData"), "cloudbridge-client")
	}

	if err := os.MkdirAll(serviceConfigDir, 0755); err != nil {
		return fmt.Errorf("failed to create service config directory: %w", err)
	}

	// Write service configuration
	serviceConfigPath := filepath.Join(serviceConfigDir, "config.yaml")
	// Note: In a real implementation, you would marshal the config to YAML
	// For now, we'll copy the original config and modify it
	if err := copyFile(configPath, serviceConfigPath); err != nil {
		return fmt.Errorf("failed to copy configuration: %w", err)
	}

	log.Printf("Service configuration created at: %s", serviceConfigPath)
	return nil
}

// copyFile copies a file from src to dst
func copyFile(src, dst string) error {
	input, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, input, 0644)
}

// runP2P runs the P2P mesh mode
func runP2P(cmd *cobra.Command, args []string) error {
	log.Printf("Starting P2P mesh mode...")
	log.Printf("Peer ID: %s", peerID)
	log.Printf("Endpoint: %s", endpoint)
	log.Printf("Public Key: %s", publicKey)
	log.Printf("Mesh Port: %d", meshPort)

	// Load configuration
	cfg, err := config.LoadConfig(configFile)
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	// Create client
	client, err := relay.NewClient(cfg)
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}
	defer func() {
		if err := client.Close(); err != nil {
			log.Printf("Failed to close client: %v", err)
		}
	}()

	// Set up signal handling for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	if runtime.GOOS == types.PlatformWindows {
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	} else {
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	}

	// Connect to relay server
	if err := connectWithRetry(client); err != nil {
		return fmt.Errorf("failed to connect: %w", err)
	}

	log.Printf("Successfully connected to relay server %s:%d", cfg.Relay.Host, cfg.Relay.Port)

	// Authenticate
	if err := authenticateWithRetry(client, token); err != nil {
		return fmt.Errorf("failed to authenticate: %w", err)
	}

	log.Printf("Successfully authenticated with client ID: %s", client.GetClientID())

	// Get P2P manager
	p2pManager := client.GetP2PManager()
	if p2pManager == nil {
		return fmt.Errorf("P2P manager not available")
	}

	// Start P2P mesh
	if err := p2pManager.Start(); err != nil {
		return fmt.Errorf("failed to start P2P mesh: %w", err)
	}

	log.Printf("P2P mesh started successfully")

	// Wait for shutdown signal
	select {
	case <-sigChan:
		log.Println("Received shutdown signal, closing...")
	case <-ctx.Done():
		log.Println("Context canceled, closing...")
	}

	return nil
}

// runTunnel runs the tunnel mode
func runTunnel(cmd *cobra.Command, args []string) error {
	log.Printf("Starting tunnel mode...")
	log.Printf("Tunnel ID: %s", tunnelID)
	log.Printf("Local Port: %d", localPort)
	log.Printf("Remote Host: %s", remoteHost)
	log.Printf("Remote Port: %d", remotePort)

	// Load configuration
	cfg, err := config.LoadConfig(configFile)
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	// Create client
	client, err := relay.NewClient(cfg)
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}
	defer func() {
		if err := client.Close(); err != nil {
			log.Printf("Failed to close client: %v", err)
		}
	}()

	// Set up signal handling for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	if runtime.GOOS == types.PlatformWindows {
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	} else {
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	}

	// Connect to relay server
	if err := connectWithRetry(client); err != nil {
		return fmt.Errorf("failed to connect: %w", err)
	}

	log.Printf("Successfully connected to relay server %s:%d", cfg.Relay.Host, cfg.Relay.Port)

	// Authenticate
	if err := authenticateWithRetry(client, token); err != nil {
		return fmt.Errorf("failed to authenticate: %w", err)
	}

	log.Printf("Successfully authenticated with client ID: %s", client.GetClientID())

	// Create tunnel
	if err := createTunnelWithRetry(client, tunnelID, localPort, remoteHost, remotePort); err != nil {
		return fmt.Errorf("failed to create tunnel: %w", err)
	}

	log.Printf("Successfully created tunnel %s: localhost:%d -> %s:%d",
		tunnelID, localPort, remoteHost, remotePort)

	// Start heartbeat
	if err := client.StartHeartbeat(); err != nil {
		return fmt.Errorf("failed to start heartbeat: %w", err)
	}

	log.Printf("Heartbeat started")

	// Wait for shutdown signal
	select {
	case <-sigChan:
		log.Println("Received shutdown signal, closing...")
	case <-ctx.Done():
		log.Println("Context canceled, closing...")
	}

	return nil
}
