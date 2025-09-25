# Test and Example Files

This document explains the test and example files in the CloudBridge Client repository.

## Build Tags Usage

Several files use build tags to prevent conflicts during normal compilation:

### `//go:build ignore` Files
These files are excluded from normal builds and must be run manually:

- `test-quic.go` - QUIC protocol testing
- `test-quic-simple.go` - Simple QUIC connection test  
- `test-quic-5553.go` - QUIC test on port 5553
- `test-heartbeat-implementation.go` - Heartbeat mechanism testing
- `test-stun.go` - STUN server testing
- `scripts/generate-jwt.go` - JWT token generation utility

**Usage:**
```bash
# Run individual test files
go run test-quic.go
go run scripts/generate-jwt.go
```

### `//go:build example` Files
These files are built only when the `example` tag is specified:

- `examples/simple-tunnel.go` - Simple tunnel example
- `examples/p2p-mesh.go` - P2P mesh networking example

**Usage:**
```bash
# Build examples
make examples
# Or manually:
go build -tags example -o simple-tunnel examples/simple-tunnel.go
go build -tags example -o p2p-mesh examples/p2p-mesh.go
```

## Regular Packages

### `cmd/quic-tester/`
Separate package for QUIC testing utilities. Builds normally without conflicts.

```bash
go build -o quic-tester ./cmd/quic-tester
```

## Why Build Tags?

Build tags prevent "main redeclared" errors when running `go vet ./...` or building the entire project. Without build tags, Go would try to compile multiple `main()` functions in the same package, causing conflicts.

## Running Tests

```bash
# Unit tests (mock mode, no privileges required)
go test ./pkg/... -tags=mock

# Examples (requires build tag)
go build -tags example ./examples/...

# Manual test files (requires manual execution)
go run test-quic.go
```

## Development Workflow

1. **Normal development**: `go build ./cmd/cloudbridge-client` - works without issues
2. **Testing examples**: `make examples` - builds with proper tags
3. **Manual testing**: `go run test-*.go` - run individual test files
4. **Linting**: `go vet ./...` - passes without "main redeclared" errors
