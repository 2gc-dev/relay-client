# ---- Flags & meta ----
BINARY_NAME := cloudbridge-client
VERSION     := $(shell cat VERSION 2>/dev/null || git describe --tags --always --dirty)
GIT_COMMIT  := $(shell git rev-parse --short HEAD)
BUILD_TIME  := $(shell date -u '+%Y-%m-%d_%H:%M:%S')

# Разделяем «ldflags» и «флаги go build», чтобы не дублировать -ldflags
LDFLAGS_BASE := -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)
LDFLAGS_SIZE := -s -w
# Для воспроизводимости: отключаем VCS-метаданные и чистим пути
BUILD_FLAGS  := -trimpath -buildvcs=false

# Платформы Go (без arm/v7 в виде «arch»)
PLATFORMS := linux/amd64 linux/arm64 windows/amd64 windows/arm64 darwin/amd64 darwin/arm64

# ARMv7 выносим отдельно (GOARM=7)
ARMV7_PLATFORMS := linux/arm

RUSSIAN_PLATFORMS := astra/amd64 alt/amd64 rosa/amd64 redos/amd64 vos/amd64
ENTERPRISE_PLATFORMS := linux/amd64 linux/arm64 windows/amd64 darwin/amd64 darwin/arm64

BUILD_DIR     := build
PACKAGE_DIR   := packages
CONTAINER_DIR := containers
VM_DIR        := vm-images

.PHONY: all build clean test install build-all build-russian build-enterprise build-packages build-containers build-vm help

all: clean build

build:
	@echo "Building $(BINARY_NAME)..."
	@go build $(BUILD_FLAGS) -ldflags '$(LDFLAGS_BASE)' -o bin/$(BINARY_NAME) ./cmd/cloudbridge-client

# Multi-platform
build-all:
	@echo "Building for all platforms..."
	@mkdir -p $(BUILD_DIR)
	@for platform in $(PLATFORMS); do \
		os=$${platform%/*}; arch=$${platform#*/}; \
		out="$(BUILD_DIR)/$(BINARY_NAME)-$${os}-$${arch}"; \
		[ "$${os}" = "windows" ] && out="$${out}.exe"; \
		echo "-> $${os}/$${arch}"; \
		GOOS=$${os} GOARCH=$${arch} CGO_ENABLED=0 \
		go build $(BUILD_FLAGS) -ldflags '$(LDFLAGS_BASE)' -o "$${out}" ./cmd/cloudbridge-client; \
	done
	@# ARMv7 (GOARM=7)
	@for platform in $(ARMV7_PLATFORMS); do \
		os=$${platform%/*}; arch=$${platform#*/}; \
		out="$(BUILD_DIR)/$(BINARY_NAME)-$${os}-armv7"; \
		echo "-> $${os}/arm (GOARM=7)"; \
		GOOS=$${os} GOARCH=arm GOARM=7 CGO_ENABLED=0 \
		go build $(BUILD_FLAGS) -ldflags '$(LDFLAGS_BASE)' -o "$${out}" ./cmd/cloudbridge-client; \
	done

# Russian distros (linux/amd64, разные репозитории)
build-russian:
	@echo "Building for Russian Linux distros (glibc) ..."
	@mkdir -p $(BUILD_DIR)
	@for platform in $(RUSSIAN_PLATFORMS); do \
		distro=$${platform%/*}; arch=$${platform#*/}; \
		out="$(BUILD_DIR)/$(BINARY_NAME)-$${distro}-$${arch}"; \
		echo "-> $$distro/$$arch (GOOS=linux)"; \
		GOOS=linux GOARCH=$${arch} CGO_ENABLED=0 \
		go build $(BUILD_FLAGS) -ldflags '$(LDFLAGS_BASE)' -o "$${out}" ./cmd/cloudbridge-client; \
	done

# Enterprise (минимальный размер + мета)
build-enterprise:
	@echo "Building Enterprise..."
	@mkdir -p $(BUILD_DIR)
	@for platform in $(ENTERPRISE_PLATFORMS); do \
		os=$${platform%/*}; arch=$${platform#*/}; \
		out="$(BUILD_DIR)/$(BINARY_NAME)-enterprise-$${os}-$${arch}"; \
		[ "$${os}" = "windows" ] && out="$${out}.exe"; \
		echo "-> enterprise $${os}/$${arch}"; \
		GOOS=$${os} GOARCH=$${arch} CGO_ENABLED=0 \
		go build $(BUILD_FLAGS) -ldflags '$(LDFLAGS_BASE) $(LDFLAGS_SIZE)' -o "$${out}" ./cmd/cloudbridge-client; \
	done

build-packages: build-all
	@echo "Creating packages..."
	@mkdir -p $(PACKAGE_DIR)
	@./scripts/build-packages.sh

build-containers:
	@echo "Building containers..."
	@mkdir -p $(CONTAINER_DIR)
	@./scripts/build-containers.sh

build-vm:
	@echo "Building VM images..."
	@mkdir -p $(VM_DIR)
	@./scripts/build-vm-images.sh

build-universal: build-all build-russian build-enterprise
	@echo "Building for all platforms..."
ifeq ($(SKIP_PACKAGES),1)
	@echo "Skipping packaging (SKIP_PACKAGES=1)"
else
	$(MAKE) build-packages
	$(MAKE) build-containers
	$(MAKE) build-vm
endif

clean:
	@echo "Cleaning..."
	@rm -rf bin/ $(BUILD_DIR)/ $(PACKAGE_DIR)/ $(CONTAINER_DIR)/ $(VM_DIR)/ coverage.out coverage.html

test:
	@echo "Running tests..."
	@go test -v ./...

test-race:
	@echo "Running tests (race)..."
	@go test -race -v ./...

test-coverage:
	@echo "Running tests (coverage)..."
	@go test -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html

install: build
	@echo "Installing (Linux systemd only)..."
	@which systemctl >/dev/null 2>&1 && { \
		sudo cp bin/$(BINARY_NAME) /usr/local/bin/; \
		sudo mkdir -p /etc/cloudbridge-client; \
		sudo cp config/config.yaml /etc/cloudbridge-client/; \
		sudo cp deploy/cloudbridge-client.service /etc/systemd/system/; \
		sudo systemctl daemon-reload; \
		sudo systemctl enable cloudbridge-client; \
		sudo systemctl start cloudbridge-client; \
	} || { echo "Skip: systemd not found"; }

uninstall:
	@echo "Uninstall (Linux systemd only)..."
	@which systemctl >/dev/null 2>&1 && { \
		sudo systemctl stop cloudbridge-client || true; \
		sudo systemctl disable cloudbridge-client || true; \
		sudo rm -f /usr/local/bin/$(BINARY_NAME); \
		sudo rm -f /etc/systemd/system/cloudbridge-client.service; \
		sudo systemctl daemon-reload; \
	} || { echo "Skip: systemd not found"; }

deps:
	@echo "Downloading modules..."
	@go mod download
	@go mod tidy

lint:
	@echo "Running golangci-lint..."
	@golangci-lint run

fmt:
	@echo "Formatting..."
	@go fmt ./...

vet:
	@echo "go vet..."
	@go vet ./...

security-scan:
	@echo "Security scan..."
	@./scripts/security-scan.sh

bench:
	@echo "Benchmarks..."
	@go test -bench=. ./...

docs:
	@echo "Generating docs (stdout)..."
	@go doc -all ./...

release: clean build-universal
	@echo "Preparing release..."
	@./scripts/prepare-release.sh

help:
	@echo "Targets: build build-all build-russian build-enterprise build-packages build-containers build-vm build-universal test test-race test-coverage install uninstall deps lint fmt vet security-scan bench docs release clean help" 