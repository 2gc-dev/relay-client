# CloudBridge Client

Production-ready CloudBridge client for secure tunnel connections.

## Quick Start

### 1. Build

```bash
make build
```

### 2. Configure

Edit `config.yaml` and set:
- `relay.2gc.ru` - relay server hostname
- `YOUR_JWT_SECRET` - your JWT secret key
- `target.2gc.ru` - target remote host

### 3. Run

```bash
./cloudbridge-client --config config.yaml --token YOUR_JWT_TOKEN
```

## Configuration

The main configuration file is `config.yaml`. Key settings:

- **relay.host**: Relay server address
- **auth.secret**: JWT secret for authentication
- **tunnel.remote_host**: Target server for tunneling

## Docker

```bash
docker build -t cloudbridge-client .
docker run -v $(pwd)/config.yaml:/app/config.yaml cloudbridge-client
```

## License

MIT License - see LICENSE file for details.