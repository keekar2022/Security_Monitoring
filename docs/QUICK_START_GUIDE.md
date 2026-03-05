# Quick Start Guide - Trend Micro Vision One API Tools

Get started with the multi-language implementations of Trend Micro Vision One API integration tools in minutes.

## Choose Your Language

- **Python** - Original implementation, easiest to modify
- **Node.js** - Fast development, rich ecosystem
- **Go** - Best balance of performance and simplicity
- **Rust** - Maximum performance and memory safety

## Prerequisites

### All Languages

1. **Configuration Files**
   ```bash
   cd Integration-API-Dev
   ls config/  # Should see deployment_config.json, environments.json
   ```

2. **Trend Micro API Access**
   - API token for your environment
   - Base URL (e.g., https://api.au.xdr.trendmicro.com)

3. **(Optional) Password Store**
   ```bash
   # Install pass for secure credential storage
   # macOS:
   brew install pass
   
   # Ubuntu:
   apt install pass
   ```

### Language-Specific

```bash
# Python
python3 --version  # 3.9+

# Node.js
node --version     # 18+

# Go
go version         # 1.21+

# Rust
rustc --version    # 1.70+
```

## 5-Minute Setup

### Python (Original)

```bash
# 1. Install dependencies
pip3 install -r requirements.txt

# 2. Run API checker
python3 check_api_availability.py --environment quality_test

# Done! ✅
```

### Node.js

```bash
# 1. Go to nodejs directory
cd nodejs

# 2. Install dependencies
npm install

# 3. Run API checker
npm run check-api -- --environment quality_test

# Done! ✅
```

### Go

```bash
# 1. Go to go directory
cd go

# 2. Download dependencies
go mod download

# 3. Build and run
go build -o bin/check_api_availability src/check_api_availability.go
./bin/check_api_availability --environment quality_test

# Done! ✅
```

### Rust

```bash
# 1. Go to rust directory
cd rust

# 2. Build (first build takes a few minutes)
cargo build --release

# 3. Run
./target/release/check_api_availability --environment quality_test

# Done! ✅
```

### Docker (Mac & Windows)

Run the API server in Docker Desktop without installing Go. The image has its own pass store (no host pass or re-entering tokens on Windows).

1. **Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. **Optional – put tokens in the image (once, on a Mac/Linux with pass):** Run `./export-pass-for-docker.sh`, then build. This copies your `TrendMicro/*` entries into the image so anyone (including Windows) can run the image without re-entering tokens. Without this, the image has an empty store (use `config/deployment_config.json`); or run `./export-pass-for-docker.sh --empty` then build to create an empty store.
3. **First run:** From the project root, run `docker compose up -d --build`, or use `./sync.sh` (Mac/Linux) / `.\sync.ps1` (Windows).
4. **After updates:** Run `./sync.sh` or `.\sync.ps1` to rebuild and restart the container with the latest source.
5. API is at **http://localhost:8080**. Config and data are in `./config` and `./data` on the host (mounted into the container).

## Secure Credential Storage with pass

### Setup pass (One-Time)

```bash
# 1. Initialize pass
gpg --gen-key  # If you don't have a GPG key
pass init "your-gpg-email@example.com"

# 2. Store Trend Micro credentials
pass insert TrendMicro/quality_test/api_token
# Paste your API token when prompted

pass insert TrendMicro/quality_test/api_base_url
# Enter: https://api.au.xdr.trendmicro.com

pass insert TrendMicro/production/api_token
pass insert TrendMicro/production/api_base_url

# 3. Verify storage
pass show TrendMicro/quality_test/api_token
```

### Use with Tools

```bash
# Enable pass
export USE_PASS=true

# Run any tool - it will automatically use pass
./check_api_availability --environment production

# All languages support pass automatically!
```

## Common Tasks

### Check API Availability

Tests all API endpoints to see what data is available:

```bash
# Python
python3 check_api_availability.py --environment production --output results.json

# Node.js
npm run check-api -- --environment production --output results.json

# Go
./bin/check_api_availability --environment production --output results.json

# Rust
./target/release/check_api_availability --environment production --output results.json
```

**Output**: JSON file with status of each endpoint and record counts

### Scan Container Vulnerabilities

Get vulnerability counts for Kubernetes clusters:

```bash
# Python
python3 get_container_vulnerabilities.py --environment production --group-name "My-K8s-Group"

# Node.js
npm run container-vulns -- --environment production --group-name "My-K8s-Group"

# Go
./bin/get_container_vulnerabilities --environment production --group-name "My-K8s-Group"

# Rust
./target/release/get_container_vulnerabilities --environment production --group-name "My-K8s-Group"
```

**Output**: CSV, JSONL (OpenTelemetry format), and text report

### Get Endpoint Statistics

Extract endpoint inventory from OAT detections:

```bash
# Python
python3 get_endpoint_stats.py --environment production

# Node.js
npm run endpoint-stats -- --environment production

# Go
./bin/get_endpoint_stats --environment production

# Rust
./target/release/get_endpoint_stats --environment production
```

**Output**: CSV summary, text report, OpenTelemetry logs

## Configuration

### deployment_config.json

```json
{
  "current_environment": "quality_test",
  "environments": {
    "quality_test": {
      "deployment": {
        "business_name": "Your Company",
        "business_id": "your-business-id",
        "region": "au",
        "region_name": "Australia",
        "api_base_url": "https://api.au.xdr.trendmicro.com",
        "portal_url": "https://portal.au.xdr.trendmicro.com"
      },
      "api_credentials": {
        "api_token": "your-api-token-here",
        "expires_at": 1735689600
      }
    },
    "production": {
      ...
    }
  }
}
```

### environments.json

```json
{
  "current_environment": "quality_test",
  "environments": {
    "quality_test": {
      "name": "Quality & Test Environment",
      "region": "au",
      "api_base_url": "https://api.au.xdr.trendmicro.com",
      "portal_url": "https://portal.au.xdr.trendmicro.com",
      "environment_label": "Quality & Test (AU)"
    },
    "production": {
      ...
    }
  }
}
```

## Environment Variables

```bash
# Use pass for credentials (recommended)
export USE_PASS=true

# Or disable pass to use JSON files
export USE_PASS=false

# Set config directory (if non-standard)
export CONFIG_DIR=/path/to/config

# Set log level
export LOG_LEVEL=info        # Node.js
export RUST_LOG=info         # Rust
```

## Cursor Rules

The project includes Cursor rules that automatically enforce standards:

### 1. OpenTelemetry Observability

**File**: `.cursor/rules/observability-standards.mdc`

- Enforces structured logging
- Requires OpenTelemetry attributes
- Standardizes log levels
- Ensures service identification

**Applied**: Automatically to all code

### 2. Markdown File Location

**File**: `.cursor/rules/markdown-file-location.mdc`

- All `.md` files go in `docs/` directory
- Exception: `README.md` in project root
- Maintains documentation organization

**Applied**: When creating markdown files

## Performance Comparison

Quick benchmark (checking 10 API endpoints):

| Language | Startup | Memory | Speed    | Binary Size |
|----------|---------|--------|----------|-------------|
| Python   | ~500ms  | ~50MB  | Baseline | N/A         |
| Node.js  | ~200ms  | ~40MB  | 1.5x     | N/A         |
| Go       | ~10ms   | ~20MB  | 3-5x     | ~10MB       |
| Rust     | ~5ms    | ~10MB  | 4-6x     | ~5MB        |

**Recommendation**:
- **Development**: Python or Node.js
- **Production**: Go or Rust
- **Containers**: Rust (smallest images)
- **Serverless**: Go or Rust (fast cold starts)

## Troubleshooting

### "config file not found"

```bash
# Check config directory exists
ls -la config/

# If in subdirectory (go/nodejs/rust/), config is at ../config/
ls -la ../config/
```

### "pass not found"

```bash
# Option 1: Install pass
brew install pass    # macOS
apt install pass     # Ubuntu

# Option 2: Disable pass
export USE_PASS=false
```

### "API token expired"

```bash
# Check token expiry
python3 -c "from lib.config_loader import TrendMicroConfig; c = TrendMicroConfig(); print(c.check_token_expiry('production'))"

# Update in pass
pass edit TrendMicro/production/api_token

# Or update in deployment_config.json
```

### "permission denied"

```bash
# Make scripts executable
chmod +x *.py
chmod +x nodejs/src/*.js

# Or run with interpreter
python3 script.py
node script.js
```

## Next Steps

1. **Read Language-Specific READMEs**
   - [Go README](../go/README.md)
   - [Node.js README](../nodejs/README.md)
   - [Rust README](../rust/README.md)

2. **Review Migration Guide**
   - [Language Migration Guide](./LANGUAGE_MIGRATION_GUIDE.md)

3. **Check Documentation**
   - [Configuration](CONFIGURATION.md) | [Pass & Credentials](PASS_AND_CREDENTIALS.md)
   - [Configuration](./CONFIGURATION.md)
   - [Best Practices](./BEST_PRACTICES.md)

4. **Deploy to Production**
   - Choose language based on requirements
   - Build production binaries
   - Set up monitoring
   - Configure log aggregation

## Getting Help

1. **Check Logs**
   ```bash
   # Enable verbose logging
   export RUST_LOG=debug     # Rust
   export LOG_LEVEL=debug    # Node.js
   # Python: use --verbose flag
   ```

2. **Read Documentation**
   - Language-specific READMEs
   - API documentation
   - Trend Micro docs

3. **Common Issues**
   - Configuration problems → Check `config/` directory
   - Authentication errors → Verify API token
   - Network issues → Check firewall/proxy

## Resources

- **Trend Micro**
  - [API Documentation](https://automation.trendmicro.com/xdr/api-v3/)
  - [Vision One Portal](https://portal.xdr.trendmicro.com/)
  
- **OpenTelemetry**
  - [Specification](https://opentelemetry.io/docs/specs/)
  - [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)

- **Language Resources**
  - [Python Docs](https://docs.python.org/)
  - [Node.js Docs](https://nodejs.org/docs/)
  - [Go Documentation](https://golang.org/doc/)
  - [Rust Book](https://doc.rust-lang.org/book/)

## Support

For questions or issues:

- Email: mkesharw@adobe.com
- Internal Wiki: [Link to wiki]
- Slack: #trend-micro-integration

---

**Last Updated**: 2026-02-02  
**Version**: 1.0.0
