# Makefile for Trend Micro Integration API - Go Implementation

.PHONY: all build clean test install api-server tools

# Default target
all: build

# Build all Go tools and API server
build: tools api-server

# Build all command-line tools (viewer data: container vuln, endpoint inventory, endpoint vuln)
tools:
	@echo "Building Go tools..."
	@mkdir -p bin
	@go build -o bin/get_container_vulnerabilities src/get_container_vulnerabilities.go
	@go build -o bin/get_endpoint_stats src/get_endpoint_stats.go
	@go build -o bin/get_endpoint_vulnerabilities src/get_endpoint_vulnerabilities.go
	@echo "✅ All tools built successfully"

# Build API server
api-server:
	@echo "Building API server..."
	@mkdir -p bin
	@go build -o bin/api-server cmd/api-server/main.go
	@echo "✅ API server built successfully"

# Install binaries to system PATH (requires sudo)
install: build
	@echo "Installing binaries to /usr/local/bin..."
	@sudo cp bin/* /usr/local/bin/
	@echo "✅ Binaries installed"

# Run tests
test:
	@echo "Running tests..."
	@go test ./...

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin/
	@go clean
	@echo "✅ Cleaned"

# Run API server (development)
run-api:
	@echo "Starting API server on port 8080..."
	@go run cmd/api-server/main.go --port 8080 --data-dir ..

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	@go mod download
	@go mod tidy
	@echo "✅ Dependencies ready"

# Format code
fmt:
	@echo "Formatting code..."
	@go fmt ./...
	@echo "✅ Code formatted"

# Vet code
vet:
	@echo "Vetting code..."
	@go vet ./...
	@echo "✅ Code vetted"

# Build for multiple platforms
build-all:
	@echo "Building for multiple platforms..."
	@mkdir -p bin/linux bin/darwin bin/windows
	@GOOS=linux GOARCH=amd64 go build -o bin/linux/api-server cmd/api-server/main.go
	@GOOS=darwin GOARCH=amd64 go build -o bin/darwin/api-server cmd/api-server/main.go
	@GOOS=windows GOARCH=amd64 go build -o bin/windows/api-server.exe cmd/api-server/main.go
	@echo "✅ Multi-platform builds complete"

# Help target
help:
	@echo "Available targets:"
	@echo "  make build        - Build all tools and API server"
	@echo "  make tools        - Build command-line tools only"
	@echo "  make api-server   - Build API server only"
	@echo "  make run-api      - Run API server in development mode"
	@echo "  make install      - Install binaries to /usr/local/bin"
	@echo "  make test         - Run tests"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make deps         - Download and tidy dependencies"
	@echo "  make fmt          - Format code"
	@echo "  make vet          - Vet code"
	@echo "  make build-all    - Build for Linux, macOS, and Windows"
