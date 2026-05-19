# Configuration Guide - Trend Micro Vision One API

**Last Updated:** January 20, 2026  
**Version:** 2.0.0 (Multi-Environment Support)  
**Environments:** Quality & Test (QTE), Production (PROD)  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## Overview

This guide covers all configuration aspects for the Trend Micro Vision One API integration, including multi-environment credentials, API endpoints, and deployment information.

**Multi-Environment Support:** As of v2.0.0, the configuration system supports multiple environments (QTE, Production, Staging, Development) with separate credentials and settings for each.

---

## 📸 Visual Setup Guide

For credential storage (pass), see [Pass & credentials](#pass--credentials) below and [INDEX.md](INDEX.md).

---

## Quick Setup

### 1. Create Credentials File

```bash
mkdir -p config
cat > config/deployment_config.json << 'EOF'
{
  "api_token": "YOUR_API_TOKEN_HERE",
  "region": "au",
  "business_id": "c732de94-ce77-4540-89d4-7f5c2c2032f6",
  "business_name": "Adobe Managed Services QTE"
}
EOF

chmod 600 config/deployment_config.json
```

### 2. Get Your API Token

1. Log in to https://portal.au.xdr.trendmicro.com/
2. Navigate to: **Administration → API Keys**
3. Click **"Generate API Key"** or copy existing key
4. Paste into `config/deployment_config.json`

### 3. Verify Configuration

```bash
python3 -c "from lib.config_loader import TrendMicroConfig; c = TrendMicroConfig(); print('✅ Configuration loaded')"
```

---

## Configuration Files

### Directory Structure

```
config/
├── deployment_config.json        # API credentials (REQUIRED, gitignored)
├── api_endpoints.json      # API endpoint definitions
├── environments.json       # Environment configurations
└── .gitignore             # Protects credentials
```

### deployment_config.json (REQUIRED) - v2.0.0 Multi-Environment

**Location:** `config/deployment_config.json`  
**Permissions:** `600` (read/write for owner only)  
**Git Status:** ❌ Ignored (never commit)  
**Version:** 2.0.0 (Multi-Environment Support)

**Format:**
```json
{
  "version": "2.0.0",
  "last_updated": "2026-01-20",
  "description": "Trend Micro Vision One API credentials - KEEP SECURE",
  "current_environment": "quality_test",
  "environments": {
    "quality_test": {
      "deployment": {
        "business_name": "Adobe Managed Services QTE",
        "business_id": "c732de94-ce77-4540-89d4-7f5c2c2032f6",
        "region": "au",
        "region_name": "Australia",
        "portal_url": "https://portal.au.xdr.trendmicro.com/",
        "api_base_url": "https://api.au.xdr.trendmicro.com"
      },
      "api_credentials": {
        "api_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...",
        "token_type": "Bearer",
        "issued_at": 1768861318,
        "expires_at": 1800397318,
        "token_use": "customer"
      },
      "token_info": {
        "issued_date": "2026-01-19",
        "expiry_date": "2027-01-19",
        "valid_for_days": 365,
        "status": "active"
      }
    },
    "production": {
      "deployment": {
        "business_name": "Adobe-AMS-Global",
        "business_id": "ec367c49-2f23-49a3-a55c-a062f7d6583a",
        "region": "us",
        "region_name": "United States (Global)",
        "portal_url": "https://portal.xdr.trendmicro.com/",
        "api_base_url": "https://api.xdr.trendmicro.com"
      },
      "api_credentials": {
        "api_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...",
        "token_type": "Bearer",
        "issued_at": 1768882796,
        "expires_at": 1800418796,
        "token_use": "customer"
      },
      "token_info": {
        "issued_date": "2026-01-19",
        "expiry_date": "2027-01-19",
        "valid_for_days": 365,
        "status": "active"
      }
    }
  },
  "security": {
    "permissions": "0600",
    "owner_only": true,
    "git_ignored": true,
    "rotation_policy": "Rotate every 90 days or before expiry"
  }
}
```

**Top-Level Fields:**
- `version` - Configuration file version (2.0.0)
- `current_environment` - Active environment name (REQUIRED)
- `environments` - Dictionary of environment configurations

**Per-Environment Fields:**
- `deployment.business_name` - Business name (REQUIRED)
- `deployment.business_id` - Business/tenant ID (REQUIRED)
- `deployment.region` - Region code: `au`, `us`, `eu`, etc. (REQUIRED)
- `deployment.api_base_url` - API endpoint URL (REQUIRED)
- `api_credentials.api_token` - API authentication token (REQUIRED)
- `api_credentials.expires_at` - Token expiry timestamp
- `token_info.status` - Token status (active/expired)

### api_endpoints.json

**Location:** `config/api_endpoints.json`  
**Purpose:** Defines all available API endpoints  
**Status:** Pre-configured, no changes needed

**Categories:**
1. **Kubernetes** - Cluster management and bootstrap tokens
2. **Devices** - Endpoint inventory and management
3. **Alerts** - Security alerts and notifications
4. **Threats** - Threat intelligence and detections
5. **Cloud Posture** - Cloud security posture management
6. **Vulnerabilities** - Container and system vulnerabilities

**Example Entry:**
```json
{
  "kubernetes": {
    "generate_token": {
      "path": "/beta/containerSecurity/kubernetesClusters/{id}/token/device",
      "method": "POST",
      "description": "Generate bootstrap token",
      "required_params": ["id"],
      "auth_required": true,
      "rate_limit": "50/hour"
    }
  }
}
```

### environments.json

**Location:** `config/environments.json`  
**Purpose:** Environment-specific settings  
**Status:** Pre-configured for quality_test, production, staging, development

**Environments:**
- **quality_test** - Adobe Managed Services QTE (Australia region)
- **production** - Adobe-AMS-Global (US/Global region)  
- **staging** - Testing environment
- **development** - Development environment

**Active Environment:** Controlled by `current_environment` field

**Example:**
```json
{
  "production": {
    "api_base_urls": {
      "au": "https://api.au.xdr.trendmicro.com",
      "us": "https://api.xdr.trendmicro.com",
      "eu": "https://api.eu.xdr.trendmicro.com"
    },
    "timeout": 60,
    "retry_attempts": 3,
    "log_level": "INFO"
  }
}
```

---

## Multi-Environment Configuration

### Overview

As of v2.0.0, the configuration system supports multiple environments with separate credentials and settings for each. This allows you to manage QTE (Quality & Test) and Production environments independently.

### Available Environments

| Environment | Business Name | Region | API Endpoint | Status |
|-------------|---------------|--------|--------------|--------|
| **quality_test** | Adobe Managed Services QTE | Australia (au) | https://api.au.xdr.trendmicro.com | ✅ Active |
| **production** | Adobe-AMS-Global | US (Global) | https://api.xdr.trendmicro.com | Configured |
| **staging** | Testing | Australia (au) | https://api.au.xdr.trendmicro.com | Available |
| **development** | Local Testing | Australia (au) | https://api.au.xdr.trendmicro.com | Available |

### Switching Between Environments

**Method 1: Change Active Environment (Recommended)**

Edit both configuration files to switch the active environment:

1. **Edit `config/deployment_config.json`:**
```json
{
  "current_environment": "production",  ← Change this
  ...
}
```

2. **Edit `config/environments.json`:**
```json
{
  "current_environment": "production",  ← Change this
  ...
}
```

3. **Verify the change:**
```bash
python3 lib/config_loader.py
```

All scripts will now automatically use the production environment.

**Method 2: Override Per Script (Programmatic)**

You can also specify the environment in your Python code:

```python
from lib.config_loader import TrendMicroConfig

config = TrendMicroConfig()

# Get production API token
prod_token = config.get_api_token(environment='production')

# Get production deployment info
prod_info = config.get_deployment_info(environment='production')

# Get production headers
prod_headers = config.get_common_headers(environment='production')

# Check production token expiry
prod_expiry = config.check_token_expiry(environment='production')
```

### List All Environments

To see all configured environments:

```python
from lib.config_loader import TrendMicroConfig

config = TrendMicroConfig()

# Get current active environment
current = config.get_credentials_environment()
print(f"Current environment: {current}")

# List all available environments
envs = config.list_available_environments()
for env_name, env_info in envs.items():
    print(f"\n{env_name}:")
    print(f"  Business: {env_info.get('business_name', 'N/A')}")
    print(f"  Region: {env_info['region']}")
    print(f"  API: {env_info['api_base_url']}")
    print(f"  Credentials: {'✅' if env_info.get('has_credentials') else '❌'}")
```

### Environment-Specific Behavior

When you switch environments, the following changes automatically:

1. **API Endpoint** - Points to the correct regional API
2. **API Token** - Uses the environment-specific token
3. **Business Context** - Deployment info reflects the environment
4. **Environment Label** - OTel logs labeled correctly (e.g., "Production" vs "Quality & Test")
5. **Log Files** - Separate log files per environment

Example:
- **QTE:** `~/.trend_micro_api.jsonl` → labeled as "Quality & Test"
- **Production:** `~/.trend_micro_api_prod.jsonl` → labeled as "Production"

---

## Deployment Information

### Quality & Test (QTE) Environment

**Business Details:**
- Name: Adobe Managed Services QTE
- ID: c732de94-ce77-4540-89d4-7f5c2c2032f6
- Region: Australia (au)
- Environment Label: "Quality & Test"

**Portal Access:**
- URL: https://portal.au.xdr.trendmicro.com/
- API Base: https://api.au.xdr.trendmicro.com

**API Token:**
- Status: ✅ Active
- Issued: January 19, 2026
- Expires: January 19, 2027
- Valid For: 365 days
- Recommended Rotation: Every 90 days (April 19, 2026)

### Production Environment

**Business Details:**
- Name: Adobe-AMS-Global
- ID: ec367c49-2f23-49a3-a55c-a062f7d6583a
- Region: United States (Global)
- Environment Label: "Production"

**Portal Access:**
- URL: https://portal.xdr.trendmicro.com/
- API Base: https://api.xdr.trendmicro.com

**API Token:**
- Status: ✅ Active
- Issued: January 19, 2026
- Expires: January 19, 2027
- Valid For: 365 days
- Recommended Rotation: Every 90 days (April 19, 2026)

### Supported Regions

| Region | Code | API Base URL |
|--------|------|--------------|
| Australia | `au` | https://api.au.xdr.trendmicro.com |
| United States | `us` | https://api.xdr.trendmicro.com |
| Europe | `eu` | https://api.eu.xdr.trendmicro.com |
| India | `in` | https://api.in.xdr.trendmicro.com |
| Singapore | `sg` | https://api.sg.xdr.trendmicro.com |
| Japan | `jp` | https://api.xdr.trendmicro.co.jp |

---

## Using Configuration in Scripts

### Python

```python
from lib.config_loader import TrendMicroConfig

# Initialize configuration
config = TrendMicroConfig()

# Get API base URL
base_url = config.get_api_base_url()
# Returns: https://api.au.xdr.trendmicro.com

# Get headers for API requests
headers = config.get_common_headers()
# Returns: {'Authorization': 'Bearer ...', 'Content-Type': 'application/json'}

# Get deployment info
info = config.get_deployment_info()
print(f"Business: {info['business_name']}")
print(f"Region: {info['region_name']}")

# Check token expiry
expiry = config.check_token_expiry()
if expiry['is_expired']:
    print("Token has expired!")
elif expiry['is_expiring_soon']:
    print(f"Token expires in {expiry['days_remaining']} days")
```

### Making API Requests

```python
import requests
from lib.config_loader import TrendMicroConfig

config = TrendMicroConfig()
base_url = config.get_api_base_url()
headers = config.get_common_headers()

# List Kubernetes clusters
response = requests.get(
    f"{base_url}/beta/containerSecurity/kubernetesClusters",
    headers=headers,
    timeout=60
)

if response.status_code == 200:
    clusters = response.json()
    print(f"Found {len(clusters['items'])} clusters")
```

---

## Security Best Practices

### Credential Protection

✅ **DO:**
- Store credentials in `config/deployment_config.json`
- Set file permissions to `600` (owner read/write only)
- Add `deployment_config.json` to `.gitignore`
- Rotate API tokens every 90 days
- Use separate tokens for production vs development
- Monitor token expiry dates

❌ **DON'T:**
- Commit credentials to git
- Share credentials via email or chat
- Use production tokens in development
- Hardcode credentials in scripts
- Store credentials in environment variables (for this project)

### Token Rotation

**Recommended Schedule:**
- Production: Every 90 days
- Development: Every 180 days
- After security incidents: Immediately

**Rotation Process:**
1. Generate new token in portal
2. Update `config/deployment_config.json`
3. Test with non-critical API call
4. Revoke old token in portal
5. Update documentation with new expiry date

### Monitoring

```bash
# Check token expiry
python3 -c "from lib.config_loader import TrendMicroConfig; \
  c = TrendMicroConfig(); \
  e = c.check_token_expiry(); \
  print(f'Expires in {e[\"days_remaining\"]} days')"
```

---

## Troubleshooting

### Issue: "Configuration file not found"

**Error:**
```
FileNotFoundError: config/deployment_config.json not found
```

**Solution:**
```bash
# Create config directory
mkdir -p config

# Create credentials file
cat > config/deployment_config.json << 'EOF'
{
  "api_token": "YOUR_TOKEN",
  "region": "au"
}
EOF

# Set permissions
chmod 600 config/deployment_config.json
```

### Issue: "API token has expired"

**Error:**
```
❌ Error: API token has expired
```

**Solution:**
1. Log in to https://portal.au.xdr.trendmicro.com/
2. Administration → API Keys
3. Generate new token
4. Update `config/deployment_config.json`
5. Test: `python3 get_container_vulnerabilities.py --quiet`

### Issue: "Invalid region"

**Error:**
```
KeyError: 'invalid_region'
```

**Solution:**
Use valid region code: `au`, `us`, `eu`, `in`, `sg`, or `jp`

```json
{
  "region": "au"
}
```

### Issue: "Permission denied"

**Error:**
```
PermissionError: config/deployment_config.json
```

**Solution:**
```bash
# Fix permissions
chmod 600 config/deployment_config.json

# Verify
ls -la config/deployment_config.json
# Should show: -rw------- (600)
```

---

## Environment Variables (Optional)

While this project uses `config/deployment_config.json`, you can optionally override settings with environment variables:

```bash
# Override API token
export TREND_MICRO_API_TOKEN="your-token"

# Override region
export TREND_MICRO_REGION="au"

# Override environment
export TREND_MICRO_ENV="production"
```

**Note:** File-based configuration is preferred for this project.

---

## Configuration Validation

### Validate Configuration

```python
#!/usr/bin/env python3
from lib.config_loader import TrendMicroConfig
import sys

try:
    config = TrendMicroConfig()
    info = config.get_deployment_info()
    expiry = config.check_token_expiry()
    
    print("✅ Configuration Valid")
    print(f"Business: {info['business_name']}")
    print(f"Region: {info['region_name']}")
    print(f"API Base: {info['api_base_url']}")
    print(f"Token Status: {'Expired' if expiry['is_expired'] else 'Valid'}")
    print(f"Days Remaining: {expiry['days_remaining']}")
    
    sys.exit(0)
except Exception as e:
    print(f"❌ Configuration Invalid: {e}")
    sys.exit(1)
```

Save as `validate_config.py` and run:
```bash
python3 validate_config.py
```

---

## Pass & credentials

**Pass** (password-store) holds GPG-encrypted API tokens. Set `USE_PASS=true` or rely on auto-detect. Helpers: `scripts/debug/update_pass_credential.sh`, `scripts/debug/verify_pass_tokens.sh`.

```bash
brew install pass gnupg
pass init "your-email@example.com"
echo "TOKEN" | pass insert -e TrendMicro/production/api_token
pass insert TrendMicro/production/api_base_url
```

**Critical:** Tokens must be a **single line** (`pass show PATH | wc -l` → `1`). Multi-line entries cause HTTP 401.

**AWS production:** Tokens live in Secrets Manager — `./scripts/migrate_secrets_to_aws.sh` ([AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md)).

---

## API reference

| Feature | API | Purpose |
|--------|-----|---------|
| Container vulnerabilities | `GET /beta/containerSecurity/vulnerabilities` | Cluster vuln counts |
| Endpoint inventory | OAT detections API | Endpoints with recent detections |
| Device vulnerabilities | ASRM Device Vulnerabilities | Per-device CVE data |

**Base URLs:** US `https://api.xdr.trendmicro.com` · AU `https://api.au.xdr.trendmicro.com` (see `config/environments.json` and pass).

Portal and API counts can differ by filters and timing; use API as source of record for automation.

---

## Monitoring & Grafana

**API server (optional local test):**

```bash
cd go && make build
./go/bin/api-server --port 8080 --data-dir ..
curl http://localhost:8080/health
```

- Structured JSON logs (`service.name`, `operation`, …) — OpenTelemetry-style.
- **Promtail:** `config/promtail-config.yaml`
- **Grafana starter:** `config/grafana-dashboard-container-security.json`
- **Streamlit dashboard** (`app.py`) displays JSONL + legacy weekly data — not a Grafana replacement.

---

## Go implementation

Production collectors and optional API server are **Go** (`go/Makefile`, `go/bin/`). Config is shared via `config/` and pass.

```bash
cd go && make collector
./bin/get_container_vulnerabilities --environment production
```

See [USER_GUIDE.md](USER_GUIDE.md) and [go/README.md](../go/README.md).

---

## Support

**Portal:** https://portal.au.xdr.trendmicro.com/  
**API Documentation:** https://automation.trendmicro.com/xdr/api-beta/  
**Support:** https://success.trendmicro.com/

**Business:**
- Name: Adobe Managed Services QTE
- ID: c732de94-ce77-4540-89d4-7f5c2c2032f6
- Region: Australia (au)
