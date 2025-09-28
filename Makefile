# CloudBridge Client Makefile
# Cross-platform build system

# Build variables
VERSION ?= dev
BUILD_TYPE ?= development
BUILD_TIME := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
GO_VERSION := $(shell go version | cut -d' ' -f3)
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Linker flags
LDFLAGS := -s -w \
	-X main.version=$(VERSION) \
	-X main.buildType=$(BUILD_TYPE) \
	-X main.buildTime=$(BUILD_TIME) \
	-X main.gitCommit=$(GIT_COMMIT)

# Build targets
BINARY_NAME := cloudbridge-client
CMD_DIR := ./cmd/cloudbridge-client

# Default target
.PHONY: all
all: build

# Build for current platform
.PHONY: build
build:
	@echo "Building CloudBridge Client for current platform..."
	go build -ldflags="$(LDFLAGS)" -o $(BINARY_NAME) $(CMD_DIR)
	@echo "Build complete: $(BINARY_NAME)"

# Build for all platforms
.PHONY: build-all
build-all: build-linux build-windows build-darwin
	@echo "All platform builds complete"

# Linux builds
.PHONY: build-linux
build-linux: build-linux-amd64 build-linux-arm64

.PHONY: build-linux-amd64
build-linux-amd64:
	@echo "Building for Linux AMD64..."
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build \
		-ldflags="$(LDFLAGS) -X main.buildOS=linux -X main.buildArch=amd64" \
		-o $(BINARY_NAME)-linux-amd64 $(CMD_DIR)

.PHONY: build-linux-arm64
build-linux-arm64:
	@echo "Building for Linux ARM64..."
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build \
		-ldflags="$(LDFLAGS) -X main.buildOS=linux -X main.buildArch=arm64" \
		-o $(BINARY_NAME)-linux-arm64 $(CMD_DIR)

# Windows builds
.PHONY: build-windows
build-windows: build-windows-amd64 build-windows-arm64

.PHONY: build-windows-amd64
build-windows-amd64:
	@echo "Building for Windows AMD64..."
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build \
		-ldflags="$(LDFLAGS) -X main.buildOS=windows -X main.buildArch=amd64" \
		-o $(BINARY_NAME)-windows-amd64.exe $(CMD_DIR)

.PHONY: build-windows-arm64
build-windows-arm64:
	@echo "Building for Windows ARM64..."
	GOOS=windows GOARCH=arm64 CGO_ENABLED=0 go build \
		-ldflags="$(LDFLAGS) -X main.buildOS=windows -X main.buildArch=arm64" \
		-o $(BINARY_NAME)-windows-arm64.exe $(CMD_DIR)

# macOS builds
.PHONY: build-darwin
build-darwin: build-darwin-amd64 build-darwin-arm64

.PHONY: build-darwin-amd64
build-darwin-amd64:
	@echo "Building for macOS AMD64..."
	GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build \
		-ldflags="$(LDFLAGS) -X main.buildOS=darwin -X main.buildArch=amd64" \
		-o $(BINARY_NAME)-darwin-amd64 $(CMD_DIR)

.PHONY: build-darwin-arm64
build-darwin-arm64:
	@echo "Building for macOS ARM64 (Apple Silicon)..."
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build \
		-ldflags="$(LDFLAGS) -X main.buildOS=darwin -X main.buildArch=arm64" \
		-o $(BINARY_NAME)-darwin-arm64 $(CMD_DIR)

# Testing
.PHONY: test
test:
	@echo "Running tests..."
	go test -v ./pkg/... -tags=mock

.PHONY: test-coverage
test-coverage:
	@echo "Running tests with coverage..."
	go test -v -cover ./pkg/... -tags=mock

.PHONY: test-integration
test-integration:
	@echo "Running integration tests..."
	go test -v ./pkg/... -tags=integration

# Linting and formatting
.PHONY: lint
lint:
	@echo "Running linters..."
	go vet ./...
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not found, skipping advanced linting"; \
	fi

.PHONY: fmt
fmt:
	@echo "Formatting code..."
	go fmt ./...

.PHONY: fmt-check
fmt-check:
	@echo "Checking code formatting..."
	@test -z "$$(gofmt -s -l . | grep -v vendor/)" || (echo "Code not formatted, run 'make fmt'" && exit 1)

# Dependencies
.PHONY: deps
deps:
	@echo "Downloading dependencies..."
	go mod download
	go mod tidy

.PHONY: deps-update
deps-update:
	@echo "Updating dependencies..."
	go get -u ./...
	go mod tidy

# Setup scripts
.PHONY: setup-linux
setup-linux:
	@echo "Setting up WireGuard for Linux..."
	sudo ./scripts/setup-wg-linux.sh

.PHONY: setup-windows
setup-windows:
	@echo "Setting up WireGuard for Windows..."
	@echo "Run this in Administrator PowerShell:"
	@echo ".\scripts\setup-wg-windows.ps1"

# Clean up
.PHONY: clean
clean:
	@echo "Cleaning up build artifacts..."
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_NAME)-*
	go clean

# Install (current platform only)
.PHONY: install
install: build
	@echo "Installing CloudBridge Client..."
	@if [ "$(shell uname)" = "Linux" ] || [ "$(shell uname)" = "Darwin" ]; then \
		sudo cp $(BINARY_NAME) /usr/local/bin/; \
		echo "Installed to /usr/local/bin/$(BINARY_NAME)"; \
	else \
		echo "Manual installation required on this platform"; \
	fi

# Uninstall
.PHONY: uninstall
uninstall:
	@echo "Uninstalling CloudBridge Client..."
	@if [ "$(shell uname)" = "Linux" ] || [ "$(shell uname)" = "Darwin" ]; then \
		sudo rm -f /usr/local/bin/$(BINARY_NAME); \
		echo "Uninstalled from /usr/local/bin/$(BINARY_NAME)"; \
	else \
		echo "Manual uninstallation required on this platform"; \
	fi

# Examples
.PHONY: examples
examples:
	@echo "Building examples..."
	go build -tags example -o examples/simple-tunnel examples/simple-tunnel.go
	go build -tags example -o examples/p2p-mesh examples/p2p-mesh.go
	@echo "Examples built successfully"

# Development helpers
.PHONY: dev
dev: deps fmt lint test build examples
	@echo "Development build complete"

.PHONY: release
release: clean deps fmt lint test build-all
	@echo "Release build complete"

# Help
.PHONY: help
help:
	@echo "CloudBridge Client Build System"
	@echo "==============================="
	@echo ""
	@echo "Build targets:"
	@echo "  build              Build for current platform"
	@echo "  build-all          Build for all platforms"
	@echo "  build-linux        Build for Linux (amd64 + arm64)"
	@echo "  build-windows      Build for Windows (amd64 + arm64)"
	@echo "  build-darwin       Build for macOS (amd64 + arm64)"
	@echo ""
	@echo "Testing:"
	@echo "  test               Run unit tests"
	@echo "  test-coverage      Run tests with coverage"
	@echo "  test-integration   Run integration tests"
	@echo ""
	@echo "Code quality:"
	@echo "  lint               Run linters"
	@echo "  fmt                Format code"
	@echo "  fmt-check          Check code formatting"
	@echo ""
	@echo "Examples:"
	@echo "  examples           Build example applications"
	@echo ""
	@echo "Dependencies:"
	@echo "  deps               Download dependencies"
	@echo "  deps-update        Update dependencies"
	@echo ""
	@echo "Setup:"
	@echo "  setup-linux        Setup WireGuard on Linux"
	@echo "  setup-windows      Show Windows setup instructions"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean              Clean build artifacts"
	@echo "  install            Install binary (Linux/macOS)"
	@echo "  uninstall          Uninstall binary (Linux/macOS)"
	@echo ""
	@echo "Development:"
	@echo "  dev                Full development build"
	@echo "  release            Full release build"
	@echo ""
	@echo "Environment variables:"
	@echo "  VERSION            Version string (default: dev)"
	@echo "  BUILD_TYPE         Build type (default: development)"