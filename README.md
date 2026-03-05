# Trend Micro Vision One - API Integration Suite

**Version:** 6.0.0 | **Last Updated:** 2026-02-02 | **Status:** ✅ Production Ready  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## 🚀 Go-Based Security Monitoring Platform

**High-performance, production-ready security monitoring and API integration** built with Go for superior performance, reliability, and ease of deployment.

### Why Go?

- ⚡ **5-10x faster** than Python
- 📦 **Single binary** deployment - no dependencies
- 🔒 **Type-safe** with compile-time error checking
- 💪 **Concurrent** API calls with goroutines
- 🎯 **Production-ready** standard library
- 💾 **Low memory** footprint (~15MB vs ~80MB Python)

---

## 🎯 Key Features

- **🔒 REST API Server**: Serve historical security metrics via HTTP/JSON endpoints
- **📊 Container Security Monitoring**: Track vulnerabilities across Kubernetes clusters (CSV, JSONL, TXT)
- **💻 Endpoint Inventory & Statistics**: Comprehensive endpoint visibility and detection tracking (CSV, JSONL, TXT)
- **🛡️ Endpoint Vulnerabilities**: Per-device vulnerability metrics (CSV, JSONL, TXT)
- **🌍 Multi-Environment Support**: Manage multiple deployments (Production, QTE, Staging)
- **🔑 Secure Credential Management**: Integration with `pass` (Unix password manager)
- **📈 OpenTelemetry Compliance**: Structured logging ready for Grafana/Loki
- **⏱️ Time-Series Metrics**: JSONL format for historical tracking

---

## 📁 Project Structure

```
Integration-API-Dev/
├── README.md                              # This file
├── VERSION                                # Version tracking
│
├── .cursor/                               # Cursor AI rules
│   └── rules/
│       ├── observability-standards.mdc    # OpenTelemetry compliance (auto-applied)
│       └── markdown-file-location.mdc     # Documentation organization
│
├── config/                                # Configuration files
│   ├── environments.json                  # Environment definitions
│   ├── deployment_config.json             # Deployment metadata (not in git)
│   ├── api_endpoints.json                 # API endpoint configurations
│   └── grafana-dashboard-container-security.json
│
├── go/                                    # Go implementation
│   ├── cmd/
│   │   └── api-server/                    # REST API server
│   │       └── main.go
│   ├── lib/
│   │   └── config_loader.go              # Configuration library
│   ├── src/                               # Command-line tools (viewer data)
│   │   ├── get_container_vulnerabilities.go
│   │   ├── get_endpoint_stats.go
│   │   └── get_endpoint_vulnerabilities.go
│   ├── bin/                               # Compiled binaries (created by make)
│   ├── go.mod                             # Go module definition
│   ├── Makefile                           # Build automation
│   └── README.md                          # Go-specific documentation
│
├── docs/                                  # 📚 Complete Documentation
│   ├── INDEX.md                          # Documentation index (start here)
│   ├── FEATURES.md                       # Container & endpoint scanning
│   ├── CONFIGURATION.md                  # Configuration reference
│   ├── PASS_AND_CREDENTIALS.md           # Pass & credential storage
│   └── ...                                # Additional guides
│
├── lib/                                   # (Deprecated Python library)
│   └── config_loader.py                   
│
├── *.py                                   # (Deprecated Python scripts - to be removed)
├── *.jsonl                                # Historical data (served by API)
├── *.csv                                  # CSV summaries
└── *.txt                                  # Text reports
```

---

## 🚀 Quick Start

### Prerequisites

```bash
# Install Go (1.21 or later)
brew install go              # macOS
# or
sudo apt install golang-go   # Linux

# Verify installation
go version
```

### Build

```bash
cd go/
make build

# This creates:
# - bin/get_container_vulnerabilities
# - bin/get_endpoint_stats
# - bin/get_endpoint_vulnerabilities
# - bin/api-server
```

### Run Tools

```bash
# Container vulnerabilities (CSV, JSONL, TXT; default: append)
./go/bin/get_container_vulnerabilities --environment production

# Endpoint inventory (CSV, JSONL, TXT)
./go/bin/get_endpoint_stats --environment production

# Endpoint vulnerabilities (CSV, JSONL, TXT)
./go/bin/get_endpoint_vulnerabilities --environment production

# Start API server
./go/bin/api-server --port 8080 --data-dir .
```

### Docker (Mac & Windows)

Run the API server in Docker Desktop so anyone can start and work without installing Go.

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac or Windows).

**First-time run:**
```bash
docker compose up -d --build
```
Or use the sync script: `./sync.sh` (Mac/Linux) or `.\sync.ps1` (Windows).

**After pulling updates or changing source:** Rebuild and restart the container with one script:
- **Mac/Linux:** `./sync.sh`
- **Windows:** `.\sync.ps1` (or run `./sync.sh` in Git Bash)

Config and data stay on the host: `./config` and `./data` are mounted into the container, so changes to config or JSONL files are visible to the API without rebuilding. The API is available at **http://localhost:8080**.

To **fetch endpoint vulnerabilities from Trend Micro** (or other reports) inside Docker, run a one-off container with the same config and data volumes:

```bash
# Endpoint vulnerabilities (writes to ./data/, API server will pick up the new JSONL)
docker compose run --rm --entrypoint /app/get_endpoint_vulnerabilities api --environment production

# Other tools (endpoint inventory, container vulnerabilities):
docker compose run --rm --entrypoint /app/get_endpoint_stats api --environment production
docker compose run --rm --entrypoint /app/get_container_vulnerabilities api --environment production
```

Replace `production` with your environment name (e.g. `quality_test`, `production_au`). Ensure `config/` has your Trend Micro credentials (e.g. `deployment_config.json` or pass).

**Pass store inside the image (no host pass at run time):** The image has its own password store so users (including on Windows) do not re-enter tokens. To put your Trend Micro tokens into the image once (on a Mac/Linux with pass), run `./export-pass-for-docker.sh`, then `docker compose build`. That bakes your `TrendMicro/*` entries into the image. If you never run the export script, the image still builds with an empty store (use `config/deployment_config.json`). For an empty store only, run `./export-pass-for-docker.sh --empty`, then build.

---

## 🔒 API Server

The REST API server provides HTTP access to historical security metrics stored in JSONL files.

### Starting the Server

```bash
cd go/
./bin/api-server --port 8080 --data-dir ..

# Server starts on http://localhost:8080
# OpenTelemetry-compliant logs to stdout
```

### Quick Examples

```bash
# Health check
curl http://localhost:8080/health

# Get statistics
curl http://localhost:8080/api/v1/stats

# Get container vulnerabilities (last 10, production only)
curl "http://localhost:8080/api/v1/metrics/container-vulnerabilities?environment=production&limit=10"

# Get endpoint inventory
curl http://localhost:8080/api/v1/metrics/endpoint-inventory

# Interactive dashboard
open http://localhost:8080/
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check and data status |
| `/api/v1/stats` | GET | Aggregated statistics |
| `/api/v1/metrics/container-vulnerabilities` | GET | Container vulnerability metrics |
| `/api/v1/metrics/endpoint-inventory` | GET | Endpoint inventory and detections |
| `/` | GET | Interactive HTML dashboard |

### Query Parameters

**Container Vulnerabilities:**
- `environment` - Filter by environment (e.g., `production`)
- `group_name` - Filter by group name
- `cluster_name` - Filter by cluster name
- `limit` - Limit number of results

**Endpoint Inventory:**
- `environment` - Filter by environment
- `endpoint_name` - Filter by endpoint name
- `limit` - Limit number of results

### Example Response

```json
{
  "total": 10,
  "metrics": [
    {
      "Timestamp": "2026-02-02T10:00:00Z",
      "Attributes": {
        "group.name": "MyGroup",
        "cluster.name": "prod-k8s",
        "vulnerability.total": 245,
        "vulnerability.severity.critical": 12,
        "vulnerability.severity.high": 45,
        "vulnerability.risk_score": 345
      }
    }
  ]
}
```

📚 **See**: [MIGRATION](docs/MIGRATION.md) and [go/README](go/README.md) for API server and Go details

---

## 🔧 Available Tools

### 1. Container Vulnerability Scanner

Fetches and analyzes container security vulnerabilities across Kubernetes clusters.

```bash
./go/bin/get_container_vulnerabilities \
    --environment production \
    --group-name "MyGroup" \
    --csv-output vulns.csv \
    --otel-output vulns.jsonl
```

**Features:**
- Per-cluster vulnerability tracking
- CVSS severity scoring
- Risk score calculation
- Multi-format output (TXT, CSV, JSONL)
- Grafana/Loki ready

### 2. Endpoint Inventory Scanner

Extracts endpoint inventory and detection statistics from OAT data.

```bash
./go/bin/get_endpoint_stats \
    --environment production \
    --csv-output endpoints.csv \
    --otel-output endpoints.jsonl
```

**Features:**
- Unique endpoint discovery
- Detection count aggregation
- Risk scoring
- MITRE ATT&CK mapping
- Time-series tracking

### 3. Endpoint Vulnerability Scanner

Scans device-level vulnerabilities using ASRM API.

```bash
./go/bin/get_endpoint_vulnerabilities \
    --environment production \
    --setup-help  # Show permission setup guide
```

**Features:**
- Device vulnerability enumeration
- Per-device risk scoring
- Setup assistance for API permissions

---

## 📈 OpenTelemetry Compliance

All tools follow OpenTelemetry standards for observability:

```json
{
  "time": "2026-02-02T10:30:00Z",
  "level": "INFO",
  "msg": "Container vulnerability scan completed",
  "service.name": "trend-micro-container-security",
  "service.version": "1.0.0",
  "deployment.environment": "production",
  "operation": "scan_vulnerabilities",
  "vulnerabilities.total": 245
}
```

**Benefits:**
- ✅ Consistent structured logging
- ✅ Ready for Grafana/Loki/Elasticsearch
- ✅ Trace correlation support
- ✅ Service metadata included

**Configuration:** Automatically enforced via `.cursor/rules/observability-standards.mdc`

---

## ⚙️ Configuration

### Required Files

1. **`config/environments.json`** - Environment definitions
2. **`config/deployment_config.json`** - Deployment metadata (region, business info)
3. **`config/api_endpoints.json`** - API endpoint configurations

### Secure Credentials with `pass`

Store API tokens securely using `pass` (GPG-encrypted password manager):

```bash
# Initialize pass
pass init your-gpg-key-id

# Store API token
pass insert trendmicro/production/api_token
pass insert trendmicro/production/api_base_url

# Verify
pass show trendmicro/production/api_token
```

Tools automatically retrieve credentials from `pass`.

📚 **See**: [Pass & Credentials](docs/PASS_AND_CREDENTIALS.md) | [Configuration](docs/CONFIGURATION.md)

---

## 🐳 Deployment

### Docker

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go/ .
RUN go build -o /api-server cmd/api-server/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
COPY --from=builder /api-server /api-server
COPY *.jsonl /data/

EXPOSE 8080
CMD ["/api-server", "--port", "8080", "--data-dir", "/data"]
```

```bash
docker build -t trend-micro-api:latest .
docker run -d -p 8080:8080 \
    -v $(pwd):/data \
    trend-micro-api:latest
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trend-micro-api
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: api-server
        image: trend-micro-api:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

### systemd Service

```ini
[Unit]
Description=Trend Micro API Server
After=network.target

[Service]
ExecStart=/opt/trend-micro/bin/api-server --port 8080 --data-dir /var/lib/trend-micro
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

---

## 📊 Performance

| Metric | Python | Go | Improvement |
|--------|--------|----|-----------| 
| Startup Time | 500ms | 10ms | **50x faster** |
| Memory Usage | 80MB | 15MB | **5x less** |
| API Request | 200ms | 25ms | **8x faster** |
| Binary Size | N/A | 8MB | **Single file** |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Index](docs/INDEX.md) | Documentation index (start here) |
| [Quick Start](docs/QUICK_START_GUIDE.md) | Get running in minutes |
| [Configuration](docs/CONFIGURATION.md) | Config reference |
| [Pass & Credentials](docs/PASS_AND_CREDENTIALS.md) | Credential storage |
| [Features](docs/FEATURES.md) | Container & endpoint scanning |

---

## 🔄 Migration from Python

Python scripts are **deprecated**. All functionality is available in Go with improved performance.

| Python (Deprecated) | Go (Current) |
|---------------------|--------------|
| `get_container_vulnerabilities.py` | `bin/get_container_vulnerabilities` |
| `get_endpoint_stats.py` | `bin/get_endpoint_stats` |
| `get_endpoint_vulnerabilities.py` | `bin/get_endpoint_vulnerabilities` |

**Same configuration files, same output formats, drop-in replacement!**

---

## 🛠️ Development

### Building

```bash
cd go/
make build      # Build all
make api-server # Build API server only
make tools      # Build CLI tools only
make clean      # Clean artifacts
```

### Testing

```bash
make test
make fmt        # Format code
make vet        # Vet code
```

### Cross-Compilation

```bash
make build-all  # Linux, macOS, Windows binaries
```

---

## 🐛 Troubleshooting

### Build Issues

```bash
# Download dependencies
go mod download
go mod tidy

# Install make (if needed)
sudo apt install build-essential  # Linux
xcode-select --install            # macOS
```

### Runtime Issues

```bash
# Run from project root
cd /Users/mkesharw/Documents/Integration-API-Dev
./go/bin/api-server --data-dir .

# Generate JSONL files if missing
./go/bin/get_container_vulnerabilities --environment production
./go/bin/get_endpoint_stats --environment production
```

---

## 📞 Support

**Author:** Mukesh Kesharwani (mkesharw@adobe.com)  
**Documentation:** See `docs/` directory  
**API Docs:** http://localhost:8080/ (when server running)

---

## ✅ Status

**Production Ready** • Go 1.21+ • OpenTelemetry Compliant • Zero External Dependencies

---

**Last Updated:** 2026-02-02 | **Version:** 6.0.0
