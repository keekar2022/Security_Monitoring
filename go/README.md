# Go Implementation - Trend Micro Vision One API Tools

This directory contains Go implementations of the Trend Micro Vision One API integration tools, following OpenTelemetry standards for observability.

## Prerequisites

- Go 1.21 or higher
- Access to Trend Micro Vision One API
- Configuration files in `../config/`
- (Optional) `pass` for secure credential storage

## Installation

```bash
# Install dependencies
go mod download

# Build all tools (or use: make tools)
go build -o bin/get_container_vulnerabilities src/get_container_vulnerabilities.go
go build -o bin/get_endpoint_stats src/get_endpoint_stats.go
go build -o bin/get_endpoint_vulnerabilities src/get_endpoint_vulnerabilities.go

# Or build for production (optimized)
CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/get_container_vulnerabilities src/get_container_vulnerabilities.go
```

## Project Structure

```
go/
├── go.mod                     # Go module definition
├── lib/
│   └── config_loader.go       # Shared configuration library
├── src/
│   ├── get_container_vulnerabilities.go
│   ├── get_endpoint_stats.go
│   └── get_endpoint_vulnerabilities.go
└── bin/                       # Compiled binaries (created during build)
```

## Configuration

The Go tools use configuration files from the parent `config/` directory:

- `deployment_config.json` - API credentials and deployment info
- `environments.json` - Environment definitions
- `api_endpoints.json` - API endpoint configurations

### Using pass (Recommended)

```bash
# Enable pass for secure credential storage
export USE_PASS=true

# Store credentials in pass
pass insert TrendMicro/production/api_token
pass insert TrendMicro/production/api_base_url
```

### Using JSON Config

```bash
# Disable pass to use deployment_config.json
export USE_PASS=false

# Or let it auto-detect (uses pass if available)
unset USE_PASS
```

## Available Tools

### 1. Container Vulnerability Scanner

Scan container vulnerabilities for Kubernetes clusters:

```bash
./bin/get_container_vulnerabilities \
  --environment production \
  --group-name "Production-Cluster-Group" \
  --output report.txt
```

### 2. Endpoint Statistics

Gather endpoint inventory and statistics:

```bash
./bin/get_endpoint_stats \
  --environment production \
  --output endpoint_report.txt
```

### 3. Endpoint Vulnerability Scanner

Scan endpoints for vulnerabilities:

```bash
./bin/get_endpoint_vulnerabilities \
  --environment production \
  --output vuln_report.txt
```

## OpenTelemetry Compliance

All Go tools follow OpenTelemetry logging standards:

```go
import "log/slog"

slog.Info("Processing request",
    slog.String("service.name", "api-checker"),
    slog.String("service.version", "1.0.0"),
    slog.String("deployment.environment", environment),
    slog.Int("record_count", count),
    slog.String("host.name", hostname),
)
```

### Log Levels

- `TRACE` - Very detailed debugging
- `DEBUG` - Detailed debugging information
- `INFO` - Informational messages
- `WARN` - Warning messages
- `ERROR` - Error messages
- `FATAL` - Fatal errors causing shutdown

### Standard Attributes

Always included:
- `service.name` - Service identifier
- `service.version` - Version number
- `deployment.environment` - Environment name
- `host.name` - Hostname

## Error Handling

The Go implementation uses idiomatic error handling:

```go
if err := checker.CheckAllEndpoints(); err != nil {
    slog.Error("Failed to check endpoints",
        slog.String("error", err.Error()),
    )
    return err
}
```

## Performance

Go offers excellent performance characteristics:

- **Startup**: ~10ms
- **Memory**: ~20MB
- **Speed**: 3-5x faster than Python
- **Binary**: ~10MB (can be reduced to ~5MB with UPX)

## Cross-Compilation

Build for different platforms:

```bash
# Linux
GOOS=linux GOARCH=amd64 go build -o bin/linux/get_container_vulnerabilities src/get_container_vulnerabilities.go

# Windows
GOOS=windows GOARCH=amd64 go build -o bin/windows/get_container_vulnerabilities.exe src/get_container_vulnerabilities.go

# macOS (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o bin/macos/get_container_vulnerabilities src/get_container_vulnerabilities.go
```

## Kubernetes / containers (optional)

Container images are **not** maintained in this repo. Build `go/bin/*` in your own Dockerfile if needed.

## Testing

```bash
# Run tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run tests with verbose output
go test -v ./...

# Benchmark tests
go test -bench=. ./...
```

## Troubleshooting

### "config file not found"

Ensure config directory exists relative to binary:

```bash
# Check from binary location
ls -la ../config/

# Or set absolute path
export CONFIG_DIR=/absolute/path/to/config
```

### "pass not found"

```bash
# Install pass
brew install pass  # macOS
apt install pass   # Ubuntu

# Or disable pass
export USE_PASS=false
```

### "module not found"

```bash
# Download dependencies
go mod download

# Verify module
go mod verify

# Tidy up
go mod tidy
```

## Best Practices

1. **Error Handling**: Always check and log errors
2. **Context**: Use context for cancellation and timeouts
3. **Logging**: Use structured logging with OpenTelemetry attributes
4. **Configuration**: Load config once, reuse throughout
5. **Cleanup**: Use defer for resource cleanup

## Contributing

When adding new Go tools:

1. Follow existing code structure
2. Use `config_loader.go` for configuration
3. Implement OpenTelemetry logging
4. Add comprehensive error handling
5. Include CLI help text
6. Add tests
7. Update this README

## Resources

- [Go Documentation](https://golang.org/doc/)
- [Go OpenTelemetry](https://pkg.go.dev/go.opentelemetry.io/otel)
- [Effective Go](https://golang.org/doc/effective_go)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)

## License

MIT License - See LICENSE file in project root

## Author

Mukesh Kesharwani (mkesharw@adobe.com)
