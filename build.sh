#!/bin/bash

# Create build directory
mkdir -p build

# Build for different platforms
echo "Building for Windows (amd64)..."
GOOS=windows GOARCH=amd64 go build -o build/cloudbridge-client-windows-amd64.exe ./cmd/cloudbridge-client

echo "Building for Windows (arm64)..."
GOOS=windows GOARCH=arm64 go build -o build/cloudbridge-client-windows-arm64.exe ./cmd/cloudbridge-client

echo "Building for Linux (amd64)..."
GOOS=linux GOARCH=amd64 go build -o build/cloudbridge-client-linux-amd64 ./cmd/cloudbridge-client

echo "Building for Linux (arm64)..."
GOOS=linux GOARCH=arm64 go build -o build/cloudbridge-client-linux-arm64 ./cmd/cloudbridge-client

echo "Building for macOS (amd64)..."
GOOS=darwin GOARCH=amd64 go build -o build/cloudbridge-client-darwin-amd64 ./cmd/cloudbridge-client

echo "Building for macOS (arm64)..."
GOOS=darwin GOARCH=arm64 go build -o build/cloudbridge-client-darwin-arm64 ./cmd/cloudbridge-client

# Create checksums
cd build
echo "Creating checksums..."
sha256sum * > checksums.txt

echo "Build complete! Binaries are in the build directory." 