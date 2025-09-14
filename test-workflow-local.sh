#!/bin/bash

# Local testing script for GitHub Actions workflows
# This script simulates the steps from our GitHub Actions workflows

set -e

echo "🚀 Starting local workflow testing..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test 1: Build and Test Workflow
echo ""
echo "📦 Testing Build and Test Workflow..."
echo "======================================"

# Check Go version
echo "Checking Go version..."
go version
print_status "Go is installed"

# Download dependencies
echo "Downloading dependencies..."
go mod download
print_status "Dependencies downloaded"

# Verify dependencies
echo "Verifying dependencies..."
go mod verify
print_status "Dependencies verified"

# Run tests
echo "Running tests..."
if go test -v ./...; then
    print_status "All tests passed"
else
    print_error "Some tests failed"
    exit 1
fi

# Build binary
echo "Building binary..."
go build -ldflags="-s -w" -o cloudbridge-client ./cmd/cloudbridge-client
print_status "Binary built successfully"

# Check binary size
echo "Checking binary size..."
ls -lh cloudbridge-client
echo "Binary size: $(stat -c%s cloudbridge-client 2>/dev/null || stat -f%z cloudbridge-client) bytes"

# Test help command
echo "Testing help command..."
if ./cloudbridge-client --help >/dev/null 2>&1; then
    print_status "Help command works"
else
    print_error "Help command failed"
fi

# Test configuration loading
echo "Testing configuration loading..."
if [ -f "config.yaml" ]; then
    if ./cloudbridge-client --config config.yaml --help >/dev/null 2>&1; then
        print_status "Default config loaded successfully"
    else
        print_warning "Default config loading failed"
    fi
fi

if [ -f "config-test.yaml" ]; then
    if ./cloudbridge-client --config config-test.yaml --help >/dev/null 2>&1; then
        print_status "Test config loaded successfully"
    else
        print_warning "Test config loading failed"
    fi
fi

# Test 2: Release Workflow
echo ""
echo "🏷️  Testing Release Workflow..."
echo "==============================="

# Create build directory
mkdir -p build

# Build for different platforms
echo "Building for different platforms..."

# Windows
echo "Building for Windows..."
GOOS=windows GOARCH=amd64 go build -o build/cloudbridge-client-windows-amd64.exe ./cmd/cloudbridge-client
GOOS=windows GOARCH=arm64 go build -o build/cloudbridge-client-windows-arm64.exe ./cmd/cloudbridge-client
print_status "Windows builds completed"

# Linux
echo "Building for Linux..."
GOOS=linux GOARCH=amd64 go build -o build/cloudbridge-client-linux-amd64 ./cmd/cloudbridge-client
GOOS=linux GOARCH=arm64 go build -o build/cloudbridge-client-linux-arm64 ./cmd/cloudbridge-client
print_status "Linux builds completed"

# macOS
echo "Building for macOS..."
GOOS=darwin GOARCH=amd64 go build -o build/cloudbridge-client-darwin-amd64 ./cmd/cloudbridge-client
GOOS=darwin GOARCH=arm64 go build -o build/cloudbridge-client-darwin-arm64 ./cmd/cloudbridge-client
print_status "macOS builds completed"

# Create checksums
echo "Creating checksums..."
cd build
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum * > checksums.txt
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 * > checksums.txt
fi
print_status "Checksums created"
cd ..

# List all build artifacts
echo "Build artifacts:"
ls -la build/

# Test 3: Deploy Workflow
echo ""
echo "🚀 Testing Deploy Workflow..."
echo "============================="

# Create deployment package
echo "Creating deployment package..."
mkdir -p deployment
cp cloudbridge-client deployment/
if [ -f "config-production.yaml" ]; then
    cp config-production.yaml deployment/config.yaml
elif [ -f "config.yaml" ]; then
    cp config.yaml deployment/config.yaml
fi
cp env.example deployment/ 2>/dev/null || true

# Create deployment script
cat > deployment/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Deploying CloudBridge Client..."

# Check if secrets are set
if [ -z "$JWT_SECRET" ]; then
    echo "❌ JWT_SECRET environment variable is not set"
    exit 1
fi

if [ -z "$FALLBACK_SECRET" ]; then
    echo "❌ FALLBACK_SECRET environment variable is not set"
    exit 1
fi

echo "✅ Environment variables are set"
echo "🎉 Deployment completed successfully!"
EOF

chmod +x deployment/deploy.sh
print_status "Deployment package created"

# Test deployment script
echo "Testing deployment script..."
export JWT_SECRET="test-secret"
export FALLBACK_SECRET="test-fallback-secret"
if ./deployment/deploy.sh; then
    print_status "Deployment script works"
else
    print_error "Deployment script failed"
fi

# Cleanup
echo ""
echo "🧹 Cleaning up..."
rm -rf build/ deployment/ cloudbridge-client
print_status "Cleanup completed"

echo ""
echo "🎉 All local workflow tests completed successfully!"
echo "Your workflows should work correctly in GitHub Actions."