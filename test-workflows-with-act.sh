#!/bin/bash

# Script to test GitHub Actions workflows using act
# Requires Docker to be running

set -e

echo "🚀 Testing GitHub Actions workflows with act..."

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

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker Desktop first."
    exit 1
fi

print_status "Docker is running"

# Check if act is installed
if ! command -v act >/dev/null 2>&1; then
    print_error "act is not installed. Please install it first:"
    echo "brew install act"
    exit 1
fi

print_status "act is installed"

# Create .secrets file for act (if it doesn't exist)
if [ ! -f ".secrets" ]; then
    echo "Creating .secrets file for act..."
    cat > .secrets << EOF
# GitHub Actions secrets for local testing
JWT_SECRET=test-jwt-secret-for-local-testing
FALLBACK_SECRET=test-fallback-secret-for-local-testing
GITHUB_TOKEN=test-github-token
EOF
    print_status ".secrets file created"
fi

# Create .env file for act (if it doesn't exist)
if [ ! -f ".env" ]; then
    echo "Creating .env file for act..."
    cat > .env << EOF
# Environment variables for local testing
GO_VERSION=1.25
CGO_ENABLED=0
EOF
    print_status ".env file created"
fi

# Test 1: Test Build Workflow
echo ""
echo "🧪 Testing Test Build Workflow..."
echo "================================="

if act -j test-build --secret-file .secrets --env-file .env; then
    print_status "Test Build workflow passed"
else
    print_error "Test Build workflow failed"
fi

# Test 2: Build and Test Workflow
echo ""
echo "🔨 Testing Build and Test Workflow..."
echo "====================================="

if act -j test --secret-file .secrets --env-file .env; then
    print_status "Test job passed"
else
    print_error "Test job failed"
fi

if act -j build --secret-file .secrets --env-file .env; then
    print_status "Build job passed"
else
    print_error "Build job failed"
fi

# Test 3: Deploy Workflow (manual trigger)
echo ""
echo "🚀 Testing Deploy Workflow..."
echo "============================="

if act -j deploy --secret-file .secrets --env-file .env -e <(echo '{"inputs":{"environment":"staging","version":"test"}}'); then
    print_status "Deploy workflow passed"
else
    print_error "Deploy workflow failed"
fi

# Test 4: Release Workflow (tag trigger)
echo ""
echo "🏷️  Testing Release Workflow..."
echo "==============================="

if act -j release --secret-file .secrets --env-file .env -e <(echo '{"ref":"refs/tags/v1.0.0"}'); then
    print_status "Release workflow passed"
else
    print_error "Release workflow failed"
fi

echo ""
echo "🎉 All workflow tests with act completed!"
echo ""
echo "💡 Tips:"
echo "- Use 'act -l' to list all available workflows"
echo "- Use 'act -j <job-name>' to run specific jobs"
echo "- Use 'act --dry-run' to see what would be executed"
echo "- Use 'act --verbose' for detailed output"
