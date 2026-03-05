# Documentation Index

Complete guide to the Trend Micro Vision One API Integration Suite with multi-language support.

## 🎯 Start Here

### New to the Project?

1. **[Quick Start Guide](QUICK_START_GUIDE.md)** ⭐
   - Get up and running in 5 minutes
   - Available for Python, Node.js, Go, and Rust
   - Includes common tasks and troubleshooting

2. **[Language Migration Guide](LANGUAGE_MIGRATION_GUIDE.md)** ⭐
   - Complete reference for all language implementations
   - Performance comparisons
   - Deployment recommendations
   - Migration patterns and best practices

3. **[Conversion Summary](CONVERSION_SUMMARY.md)** ⭐
   - What was accomplished
   - Cursor rules explained
   - Next steps and future work

### Language-Specific Documentation

- **[Go README](../go/README.md)** - Go implementation guide
- **[Node.js README](../nodejs/README.md)** - Node.js implementation guide
- **[Rust README](../rust/README.md)** - Rust implementation guide

## 📚 Core Documentation

### Setup & Configuration

- **[Getting Started](GETTING_STARTED.md)** - Original Python setup guide
- **[Configuration](CONFIGURATION.md)** - Configuration reference
- **[Setup Guide](SETUP_GUIDE.md)** - Detailed setup instructions
- **[Pass Integration](PASS_INTEGRATION.md)** - Secure credential storage setup
- **[Pass Quick Reference](PASS_QUICK_REFERENCE.md)** - Pass command cheatsheet
- **[Token Storage Guide](TOKEN_STORAGE_GUIDE.md)** - API token management
### Features & Usage

- **[Container Security](CONTAINER_SECURITY.md)** - Container vulnerability scanning
- **[Endpoint Inventory Guide](ENDPOINT_INVENTORY_GUIDE.md)** - Endpoint statistics
- **[Best Practices](BEST_PRACTICES.md)** - Usage best practices

### Observability & Monitoring

- **[OpenTelemetry & Grafana Guide](OTEL_GRAFANA_GUIDE.md)** - Grafana/Loki integration
- **[Grafana Guide](GRAFANA_GUIDE.md)** - Grafana dashboard setup

## 🆕 Multi-Language Support (Version 5.0+)

### What's New

The project now supports **4 programming languages**:

1. **Python** (Original)
   - Most mature implementation
   - Easy to modify
   - Rich ecosystem

2. **Go** 🆕
   - 3-5x faster than Python
   - Small binaries (~10MB)
   - Easy deployment
   - **Recommended for production**

3. **Rust** 🆕
   - 4-6x faster than Python
   - Smallest binaries (~5MB)
   - Maximum safety
   - **Recommended for containers/serverless**

4. **Node.js** 🆕
   - 1.5x faster than Python
   - Rich npm ecosystem
   - Easy for web developers
   - **Recommended for microservices**

### Why Multiple Languages?

- **Performance**: Go and Rust are significantly faster
- **Deployment**: Compiled languages create standalone binaries
- **Containers**: Smaller images with compiled languages
- **Team Skills**: Choose language that matches your team
- **Production Ready**: All implementations follow same standards

## 🤖 Cursor AI Rules

The project includes Cursor rules that **automatically enforce standards**:

### 1. observability-standards.mdc

**Always applied** to all code:
- Enforces OpenTelemetry-compliant logging
- Requires structured logging (JSON format)
- Standard service attributes
- Proper log levels

**You never have to mention this again** - Cursor will automatically follow it!

### 2. markdown-file-location.mdc

**Always applied** when creating documentation:
- All `.md` files go in `docs/` directory
- Exception: `README.md` in project root
- Maintains organization

**You never have to mention this again** - Cursor will automatically follow it!

## 📊 Performance Comparison

| Language | Startup | Memory | Speed    | Binary  | Use Case              |
|----------|---------|--------|----------|---------|-----------------------|
| Python   | ~500ms  | ~50MB  | Baseline | N/A     | Development           |
| Node.js  | ~200ms  | ~40MB  | 1.5x     | N/A     | Microservices         |
| Go       | ~10ms   | ~20MB  | 3-5x     | ~10MB   | Production (general)  |
| Rust     | ~5ms    | ~10MB  | 4-6x     | ~5MB    | High-performance      |

## 🚀 Quick Reference

### Building All Languages

```bash
# Build everything at once
./build-all.sh

# Or individually:
cd go && go build -o bin/check_api src/check_api_availability.go
cd rust && cargo build --release
cd nodejs && npm install
```

### Running Tools

```bash
# API Availability Checker
python3 check_api_availability.py --environment production
node nodejs/src/check_api_availability.js --environment production
./go/bin/check_api_availability --environment production
./rust/target/release/check_api_availability --environment production

# Container Vulnerability Scanner
python3 get_container_vulnerabilities.py --environment production --group-name "My-Group"

# Endpoint Statistics
python3 get_endpoint_stats.py --environment production
```

### Using pass (Recommended)

```bash
# One-time setup
pass init "your-email@example.com"
pass insert TrendMicro/production/api_token
pass insert TrendMicro/production/api_base_url

# Enable pass (works for all languages)
export USE_PASS=true

# All tools will automatically use pass
./check_api_availability --environment production
```

## 📁 File Organization

### Configuration (Shared)

All languages use the same configuration files:
- `config/deployment_config.json` - API credentials
- `config/environments.json` - Environment definitions
- `config/api_endpoints.json` - Endpoint configurations

### Implementation Structure

```
go/
├── lib/config_loader.go       # Config library
├── src/[scripts].go           # Main scripts
└── README.md                  # Go-specific docs

rust/
├── lib/config_loader.rs       # Config library
├── src/[scripts].rs           # Main scripts
└── README.md                  # Rust-specific docs

nodejs/
├── lib/config_loader.js       # Config library
├── src/[scripts].js           # Main scripts
└── README.md                  # Node.js-specific docs
```

## 🔧 Available Scripts

### Fully Implemented (All Languages)

✅ **check_api_availability**
- Tests all API endpoints
- Reports working vs failed
- Saves results to JSON

### Framework Ready (Python Only Currently)

⏳ These scripts have the framework ready for conversion:
- `get_container_vulnerabilities` - Container security scanning
- `get_endpoint_stats` - Endpoint inventory statistics
- `get_endpoint_vulnerabilities` - Endpoint vulnerability scanning

**To convert**: Follow patterns from `check_api_availability` implementation

## 📖 Documentation by Topic

### By Audience

**Developers**:
- [Quick Start Guide](QUICK_START_GUIDE.md)
- [Language Migration Guide](LANGUAGE_MIGRATION_GUIDE.md)
- [Best Practices](BEST_PRACTICES.md)
- Language-specific READMEs

**DevOps/SRE**:
- [Setup Guide](SETUP_GUIDE.md)
- [Configuration](CONFIGURATION.md)
- [OpenTelemetry Guide](OTEL_GRAFANA_GUIDE.md)
- [Pass Integration](PASS_INTEGRATION.md)

**Security Teams**:
- [Container Security](CONTAINER_SECURITY.md)
- [Vulnerability QTE vs API Comparison](VULNERABILITY_QTE_POST_FEB6_COMPARISON.md) - QTE sheet (post 6 Feb) vs API data; **comparable only** to `Container Vulnerabilities_20260207161801.csv` (two QTE clusters; Production excluded)
- [ASRM Vulnerable Devices API](ASRM_VULNERABLE_DEVICES_API.md) - Data from `api.au.xdr.trendmicro.com/v3.0/asrm/vulnerableDevices` using pass tokens
- [Token Storage Guide](TOKEN_STORAGE_GUIDE.md)
- [Pass Integration](PASS_INTEGRATION.md)

### By Task

**First Time Setup**:
1. [Quick Start Guide](QUICK_START_GUIDE.md)
2. [Setup Guide](SETUP_GUIDE.md)
3. [Pass Integration](PASS_INTEGRATION.md)
4. Run get_* binaries to verify connectivity (e.g. `./go/bin/get_container_vulnerabilities --environment production`)
**Scanning Containers**:
1. [Container Security](CONTAINER_SECURITY.md)
2. [Configuration](CONFIGURATION.md)
3. [Best Practices](BEST_PRACTICES.md)

**Setting Up Monitoring**:
1. [OpenTelemetry Guide](OTEL_GRAFANA_GUIDE.md)
2. [Grafana Guide](GRAFANA_GUIDE.md)
3. [Best Practices](BEST_PRACTICES.md)

**Converting to Another Language**:
1. [Language Migration Guide](LANGUAGE_MIGRATION_GUIDE.md)
2. Language-specific README
3. [Conversion Summary](CONVERSION_SUMMARY.md)

## 🎓 Learning Path

### Beginner (Getting Started)

1. **Read**: [Quick Start Guide](QUICK_START_GUIDE.md)
2. **Do**: Run `check_api_availability` in your preferred language
3. **Read**: [Configuration](CONFIGURATION.md)
4. **Do**: Set up `pass` for secure credentials
5. **Read**: [Pass Integration](PASS_INTEGRATION.md)

### Intermediate (Using the Tools)

1. **Read**: [Container Security](CONTAINER_SECURITY.md)
2. **Do**: Run container vulnerability scan
3. **Read**: [Endpoint Inventory Guide](ENDPOINT_INVENTORY_GUIDE.md)
4. **Do**: Generate endpoint statistics
5. **Read**: [Best Practices](BEST_PRACTICES.md)

### Advanced (Customization & Integration)

1. **Read**: [Language Migration Guide](LANGUAGE_MIGRATION_GUIDE.md)
2. **Do**: Choose and build your preferred language implementation
3. **Read**: [OpenTelemetry Guide](OTEL_GRAFANA_GUIDE.md)
4. **Do**: Set up Grafana dashboards
5. **Read**: [Best Practices](BEST_PRACTICES.md)
6. **Do**: Schedule automated scans

## 🔗 External Resources

### Trend Micro
- [API Documentation](https://automation.trendmicro.com/xdr/api-v3/)
- [Vision One Portal](https://portal.xdr.trendmicro.com/)
- [Container Security Guide](https://docs.trendmicro.com/en-us/enterprise/trend-micro-vision-one/container-security.aspx)

### OpenTelemetry
- [Specification](https://opentelemetry.io/docs/specs/)
- [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [Go SDK](https://pkg.go.dev/go.opentelemetry.io/otel)
- [Rust Tracing](https://docs.rs/tracing/)
- [Node.js SDK](https://opentelemetry.io/docs/instrumentation/js/)

### Languages
- [Python Docs](https://docs.python.org/)
- [Go Documentation](https://golang.org/doc/)
- [Rust Book](https://doc.rust-lang.org/book/)
- [Node.js Docs](https://nodejs.org/docs/)

### Tools
- [pass - Password Store](https://www.passwordstore.org/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)

## 📝 Version History

### Version 5.0.0 (2026-02-02) - Multi-Language Release

**Major Changes**:
- ✅ Added Go implementation
- ✅ Added Rust implementation
- ✅ Added Node.js implementation
- ✅ Created Cursor rules for automatic standards enforcement
- ✅ Added 6 comprehensive documentation files
- ✅ Created language-specific READMEs
- ✅ Added unified build script

**Documentation Added**:
- Quick Start Guide (3,500 words)
- Language Migration Guide (7,800 words)
- Conversion Summary (5,200 words)
- Go README (2,800 words)
- Node.js README (3,200 words)
- Rust README (3,600 words)

**Total**: ~24,000 words of new documentation

### Version 4.0.0 (Previous) - OpenTelemetry Integration
- Container vulnerability scanning
- Multi-environment support
- OpenTelemetry compliance
- Grafana/Loki integration

## 🆘 Getting Help

### Quick Answers

1. **"How do I get started?"**  
   → [Quick Start Guide](QUICK_START_GUIDE.md)

2. **"Which language should I use?"**  
   → [Language Migration Guide](LANGUAGE_MIGRATION_GUIDE.md) - See recommendations section

3. **"How do I set up pass?"**  
   → [Pass Integration](PASS_INTEGRATION.md)

4. **"How do I scan containers?"**  
   → [Container Security](CONTAINER_SECURITY.md)

5. **"How do I set up monitoring?"**  
   → [OpenTelemetry Guide](OTEL_GRAFANA_GUIDE.md)

### Troubleshooting

Common issues and solutions:
- "config file not found" → Check your working directory
- "pass not found" → Install pass or set `USE_PASS=false`
- "API token expired" → Update token in pass or config file
- "permission denied" → Make scripts executable with `chmod +x`

See language-specific READMEs for detailed troubleshooting.

## 📧 Contact

**Author**: Mukesh Kesharwani  
**Email**: mkesharw@adobe.com  
**Project**: Trend Micro Vision One API Integration Suite  
**Version**: 5.0.0  
**Last Updated**: 2026-02-02

---

## 📚 Documentation Map

```
docs/
├── INDEX.md (you are here)
│
├── Getting Started
│   ├── QUICK_START_GUIDE.md ⭐
│   ├── GETTING_STARTED.md
│   └── SETUP_GUIDE.md
│
├── Multi-Language (NEW)
│   ├── LANGUAGE_MIGRATION_GUIDE.md ⭐
│   ├── CONVERSION_SUMMARY.md ⭐
│   ├── ../go/README.md
│   ├── ../nodejs/README.md
│   └── ../rust/README.md
│
├── Configuration
│   ├── CONFIGURATION.md
│   ├── PASS_INTEGRATION.md
│   ├── PASS_QUICK_REFERENCE.md
│   └── TOKEN_STORAGE_GUIDE.md
│
├── Features
│   ├── CONTAINER_SECURITY.md
│   ├── VULNERABILITY_QTE_POST_FEB6_COMPARISON.md
│   ├── ENDPOINT_INVENTORY_GUIDE.md
│   └── BEST_PRACTICES.md
│
└── Monitoring
    ├── OTEL_GRAFANA_GUIDE.md
    └── GRAFANA_GUIDE.md
```

**Legend**:
- ⭐ Start here for new users
- 🆕 New in Version 5.0

---

**[Back to Main README](../README.md)**
