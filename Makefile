# CloudBridge Client Makefile

# Default values
VERSION ?= dev
BUILD_TYPE ?= test
OUTPUT_DIR ?= dist

# Build targets
.PHONY: all build test clean help version

# Default target
all: build

# Help target
help:
	@echo "CloudBridge Client Build System"
	@echo "==============================="
	@echo ""
	@echo "Available targets:"
	@echo "  build          - Build for current platform"
	@echo "  build-all      - Build for all platforms"
	@echo "  build-test     - Build test version for current platform"
	@echo "  build-demo     - Build demo version for current platform"
	@echo "  build-prod     - Build production version for current platform"
	@echo "  test           - Run tests"
	@echo "  clean          - Clean build artifacts"
	@echo "  version        - Show version information"
	@echo ""
	@echo "Variables:"
	@echo "  VERSION        - Version to build (default: dev)"
	@echo "  BUILD_TYPE     - Build type: test, demo, production (default: test)"
	@echo "  OUTPUT_DIR     - Output directory (default: dist)"
	@echo ""
	@echo "Examples:"
	@echo "  make build-test VERSION=1.0.0"
	@echo "  make build-prod VERSION=1.0.0"
	@echo "  make build-all BUILD_TYPE=demo"

# Build for current platform
build:
	@echo "Building for current platform..."
	@./scripts/build-with-config.sh \
		--os $(shell go env GOOS) \
		--arch $(shell go env GOARCH) \
		--type $(BUILD_TYPE) \
		--version $(VERSION) \
		--output-dir $(OUTPUT_DIR)

# Build test version
build-test:
	@echo "Building test version..."
	@./scripts/build-with-config.sh \
		--os $(shell go env GOOS) \
		--arch $(shell go env GOARCH) \
		--type test \
		--version $(VERSION) \
		--output-dir $(OUTPUT_DIR)

# Build demo version
build-demo:
	@echo "Building demo version..."
	@./scripts/build-with-config.sh \
		--os $(shell go env GOOS) \
		--arch $(shell go env GOARCH) \
		--type demo \
		--version $(VERSION) \
		--output-dir $(OUTPUT_DIR)

# Build production version
build-prod:
	@echo "Building production version..."
	@./scripts/build-with-config.sh \
		--os $(shell go env GOOS) \
		--arch $(shell go env GOARCH) \
		--type production \
		--version $(VERSION) \
		--output-dir $(OUTPUT_DIR)

# Build for all platforms
build-all:
	@echo "Building for all platforms..."
	@./scripts/build-with-config.sh --os linux --arch amd64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)
	@./scripts/build-with-config.sh --os linux --arch arm64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)
	@./scripts/build-with-config.sh --os windows --arch amd64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)
	@./scripts/build-with-config.sh --os darwin --arch amd64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)
	@./scripts/build-with-config.sh --os darwin --arch arm64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)

# Build specific platform
build-linux:
	@echo "Building for Linux..."
	@./scripts/build-with-config.sh --os linux --arch amd64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)

build-windows:
	@echo "Building for Windows..."
	@./scripts/build-with-config.sh --os windows --arch amd64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)

build-darwin:
	@echo "Building for macOS..."
	@./scripts/build-with-config.sh --os darwin --arch amd64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)

build-darwin-arm:
	@echo "Building for macOS ARM64..."
	@./scripts/build-with-config.sh --os darwin --arch arm64 --type $(BUILD_TYPE) --version $(VERSION) --output-dir $(OUTPUT_DIR)

# Run tests
test:
	@echo "Running tests..."
	go test -v ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Lint code
lint:
	@echo "Running linter..."
	golangci-lint run

# Format code
fmt:
	@echo "Formatting code..."
	go fmt ./...

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUTPUT_DIR)
	rm -f cloudbridge-client
	rm -f cloudbridge-client.exe
	rm -f coverage.out
	rm -f coverage.html
	rm -f *.log

# Show version information
version:
	@echo "Version: $(VERSION)"
	@echo "Build Type: $(BUILD_TYPE)"
	@echo "Output Dir: $(OUTPUT_DIR)"
	@echo "Go Version: $(shell go version)"
	@echo "Go OS/Arch: $(shell go env GOOS)/$(shell go env GOARCH)"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod download
	go mod tidy

# Install build tools
install-tools:
	@echo "Installing build tools..."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Development build (with debug info)
dev-build:
	@echo "Building development version..."
	go build -o cloudbridge-client ./cmd/cloudbridge-client

# Quick test build
quick-test:
	@echo "Quick test build..."
	go build -o cloudbridge-client ./cmd/cloudbridge-client
	@echo "Built: cloudbridge-client"

# Docker build (if needed)
docker-build:
	@echo "Building Docker image..."
	docker build -t cloudbridge-client:$(VERSION) .

# Release build (all platforms)
release: clean
	@echo "Building release for all platforms..."
	@$(MAKE) build-all BUILD_TYPE=production VERSION=$(VERSION)

# CI build
ci-build:
	@echo "CI build..."
	@$(MAKE) build-test VERSION=$(VERSION)
	@$(MAKE) test
	@$(MAKE) lint