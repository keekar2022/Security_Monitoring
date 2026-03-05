# 🎯 Kubernetes Bootstrap Automation - Best Practices Guide

**Project:** Kubernetes Bootstrap Token Automation via Trend Micro XDR Beta API  
**Version:** 1.0.0  
**Last Updated:** January 12, 2026  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## 📋 Document Purpose

This comprehensive guide defines best practices for the Kubernetes Bootstrap Automation project and serves as a reusable template for future integration automation projects. These practices are derived from proven patterns in the KACI Parental Control and OSCAL Report Generator V2 projects.

**Use this document to:**
- Ensure consistency across all automation scripts
- Avoid common pitfalls in API integration projects
- Maintain high-quality, production-ready code
- Quickly bootstrap new integration projects

---

## 📑 Table of Contents

1. [Version Management](#version-management)
2. [Logging & Debugging](#logging--debugging)
3. [Error Handling & Resilience](#error-handling--resilience)
4. [Security Best Practices](#security-best-practices)
5. [API Integration Patterns](#api-integration-patterns)
6. [Code Organization](#code-organization)
7. [Documentation Standards](#documentation-standards)
8. [Git Practices](#git-practices)
9. [Testing & Validation](#testing--validation)
10. [CI/CD Integration](#cicd-integration)
11. [Quick Reference Checklist](#quick-reference-checklist)
12. [Reusable Templates](#reusable-templates)

---

## Version Management

### ✅ **Single Source of Truth - VERSION File**

**Problem:** Hardcoded version numbers scattered across multiple files lead to inconsistencies.

**Solution:** Single VERSION file in INI format, automatically loaded by all scripts.

**Implementation:**

```ini
# VERSION
VERSION=1.0.0
BUILD_DATE=2026-01-12
PROJECT_NAME=K8s Bootstrap Automation
MAINTAINER=Mukesh Kesharwani
```

**Usage in Bash:**
```bash
#!/bin/bash
# Load version from VERSION file
VERSION_FILE="$(dirname "$0")/VERSION"
if [[ -f "$VERSION_FILE" ]]; then
    source <(grep = "$VERSION_FILE")
fi

echo "Running ${PROJECT_NAME} v${VERSION}"
```

**Usage in Python:**
```python
import configparser
from pathlib import Path

def load_version():
    version_file = Path(__file__).parent / 'VERSION'
    config = configparser.ConfigParser()
    config.read(version_file)
    return config['DEFAULT']

VERSION_INFO = load_version()
VERSION = VERSION_INFO['VERSION']
```

**Benefits:**
- ✅ Single file to update for version changes
- ✅ Consistent versioning across all scripts
- ✅ Easy to automate version bumps
- ✅ CI/CD can read and validate version

---

### ✅ **Automated Version Bumping Script**

**File:** `bump_version.sh`

**Features:**
- Semantic versioning (major.minor.patch)
- Auto-updates VERSION file and all references
- Appends to CHANGELOG.md
- Creates git commits and tags
- Pre-commit validation

**Usage:**
```bash
# Patch release (1.0.0 → 1.0.1)
./bump_version.sh patch "Fix token expiry handling"

# Minor release (1.0.0 → 1.1.0)
./bump_version.sh minor "Add multi-cluster support"

# Major release (1.0.0 → 2.0.0)
./bump_version.sh major "Breaking: New API endpoint structure"
```

---

### ✅ **Pre-Commit Hook for Version Enforcement**

**Prevents commits with code changes but no version bump.**

```bash
#!/bin/bash
# .git/hooks/pre-commit

CODE_CHANGED=$(git diff --cached --name-only | grep -E '\.(sh|py)$')
VERSION_CHANGED=$(git diff --cached --name-only | grep -E '^VERSION$')

if [ -n "$CODE_CHANGED" ] && [ -z "$VERSION_CHANGED" ]; then
    echo "⚠️  ERROR: Code changed but version not bumped!"
    echo "Run: ./bump_version.sh [major|minor|patch] 'description'"
    exit 1
fi
```

---

## Logging & Debugging

### ✅ **JSONL (JSON Lines) Format**

**Problem:** Traditional logs are hard to parse, search, and analyze programmatically.

**Solution:** Use JSONL - one JSON object per line, compatible with log aggregators.

**Implementation:**

```bash
#!/bin/bash
# Bash logging function

log_json() {
    local level="$1"
    local message="$2"
    local context="$3"
    
    local log_entry=$(jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg level "$level" \
        --arg message "$message" \
        --arg version "$VERSION" \
        --arg hostname "$(hostname)" \
        --argjson context "${context:-{}}" \
        '{
            "@timestamp": $timestamp,
            "log.level": $level,
            "message": $message,
            "service.name": "k8s-bootstrap-automation",
            "service.version": $version,
            "host.hostname": $hostname,
            "context": $context
        }')
    
    echo "$log_entry" | tee -a "/var/log/k8s_bootstrap.jsonl"
}

# Usage
log_json "info" "Token generated successfully" '{"cluster_id": "prod-001", "token_length": 64}'
log_json "error" "API request failed" '{"http_code": 401, "error": "Unauthorized"}'
```

**Python Implementation:**

```python
import json
import logging
from datetime import datetime

def log_json(level, message, **context):
    log_entry = {
        '@timestamp': datetime.utcnow().isoformat() + 'Z',
        'log.level': level,
        'message': message,
        'service.name': 'k8s-bootstrap-automation',
        'service.version': VERSION,
        'host.hostname': os.uname().nodename,
        **context
    }
    print(json.dumps(log_entry))
    
    # Also write to file
    with open('/var/log/k8s_bootstrap.jsonl', 'a') as f:
        f.write(json.dumps(log_entry) + '\n')

# Usage
log_json('info', 'Token generated successfully', 
         cluster_id='prod-001', token_length=64)
```

**Benefits:**
- ✅ Machine-readable for automation
- ✅ Easy to parse with `jq` or log aggregators
- ✅ Searchable by any field
- ✅ Compatible with ELK, Splunk, Datadog
- ✅ Supports complex nested data

**Query Examples:**
```bash
# Find all errors
cat /var/log/k8s_bootstrap.jsonl | jq 'select(.["log.level"] == "error")'

# Find API failures
cat /var/log/k8s_bootstrap.jsonl | jq 'select(.context.http_code >= 400)'

# Count by log level
cat /var/log/k8s_bootstrap.jsonl | jq -r '.["log.level"]' | sort | uniq -c
```

---

### ✅ **ECS (Elastic Common Schema) Compliance**

**Use standardized field names** for better interoperability:

```python
STANDARD_FIELDS = {
    '@timestamp': 'ISO 8601 timestamp',
    'log.level': 'debug, info, warning, error, critical',
    'message': 'Human-readable message',
    'event.action': 'What happened (generate_token, save_token, api_call)',
    'event.category': 'Category (api, authentication, configuration)',
    'event.outcome': 'success, failure, unknown',
    'http.request.method': 'GET, POST, PUT, DELETE',
    'http.response.status_code': '200, 401, 404, etc.',
    'error.type': 'Error class name',
    'error.message': 'Error details',
    'error.stack_trace': 'Full stack trace',
    'user.name': 'Username or API key identifier',
    'service.name': 'k8s-bootstrap-automation',
    'service.version': 'Current version'
}
```

**Reference:** https://www.elastic.co/guide/en/ecs/current/

---

### ✅ **Context-Rich Logging**

**Always include context** for effective debugging:

```python
# ✅ GOOD: Rich context
log_json('info', 'Bootstrap token generated', 
    event_action='generate_token',
    event_outcome='success',
    cluster_id='prod-k8s-001',
    api_endpoint='/beta/containerSecurity/kubernetesClusters/prod-k8s-001/token/device',
    http_status=200,
    response_time_ms=1250,
    token_length=256,
    token_expires_at='2026-01-13T12:00:00Z'
)

# ❌ BAD: Minimal context
log_json('info', 'Token generated')
```

---

## Error Handling & Resilience

### ✅ **Retry Logic with Exponential Backoff**

**Problem:** Transient network errors cause script failures.

**Solution:** Implement exponential backoff with configurable retries.

```python
import time
from typing import Callable, Any

def retry_with_backoff(
    func: Callable,
    max_retries: int = 3,
    initial_delay: float = 1.0,
    backoff_factor: float = 2.0,
    max_delay: float = 60.0
) -> Any:
    """
    Retry a function with exponential backoff.
    
    Args:
        func: Function to retry
        max_retries: Maximum number of retry attempts
        initial_delay: Initial delay in seconds
        backoff_factor: Multiplier for delay after each retry
        max_delay: Maximum delay between retries
    
    Returns:
        Result of successful function call
    
    Raises:
        Last exception if all retries fail
    """
    delay = initial_delay
    last_exception = None
    
    for attempt in range(max_retries + 1):
        try:
            return func()
        except Exception as e:
            last_exception = e
            
            if attempt == max_retries:
                log_json('error', f'All {max_retries} retry attempts failed',
                    error_type=type(e).__name__,
                    error_message=str(e),
                    attempts=attempt + 1
                )
                raise
            
            log_json('warning', f'Retry attempt {attempt + 1}/{max_retries}',
                error_type=type(e).__name__,
                error_message=str(e),
                retry_delay_seconds=delay
            )
            
            time.sleep(delay)
            delay = min(delay * backoff_factor, max_delay)
    
    raise last_exception

# Usage
def generate_token():
    return automation.generate_bootstrap_token(cluster_id)

token = retry_with_backoff(generate_token, max_retries=3)
```

**Bash Implementation:**

```bash
retry_with_backoff() {
    local max_retries=3
    local delay=1
    local attempt=1
    
    while [ $attempt -le $max_retries ]; do
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -eq $max_retries ]; then
            log_json "error" "All $max_retries retry attempts failed"
            return 1
        fi
        
        log_json "warning" "Retry attempt $attempt/$max_retries" \
            "{\"retry_delay_seconds\": $delay}"
        
        sleep $delay
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# Usage
retry_with_backoff generate_bootstrap_token "$CLUSTER_ID"
```

---

### ✅ **Graceful Degradation**

**Design systems to continue operating** even when non-critical components fail.

```python
def generate_and_save_token(cluster_id, output_file=None):
    """Generate token with graceful degradation."""
    
    try:
        # Critical: Generate token (must succeed)
        token = automation.generate_bootstrap_token(cluster_id)
        log_json('info', 'Token generated', event_outcome='success')
        
    except Exception as e:
        # Critical operation failed - propagate exception
        log_json('error', 'Token generation failed',
            event_outcome='failure',
            error_type=type(e).__name__,
            error_message=str(e)
        )
        raise
    
    # Non-critical: Save to file (can fail without aborting)
    if output_file:
        try:
            automation.save_token_to_file(output_file)
            log_json('info', 'Token saved to file', 
                event_outcome='success',
                file_path=output_file
            )
        except Exception as e:
            # Log but don't fail - token generation succeeded
            log_json('warning', 'Failed to save token to file',
                event_outcome='failure',
                error_type=type(e).__name__,
                error_message=str(e),
                file_path=output_file
            )
    
    return token
```

---

### ✅ **Timeout Configuration**

**Always set timeouts** to prevent hanging scripts.

```python
import requests

# ✅ GOOD: Configured timeouts
response = session.post(endpoint, 
    timeout=(5, 30)  # (connect timeout, read timeout)
)

# ❌ BAD: No timeout (can hang forever)
response = session.post(endpoint)
```

**Best Practices:**
- Connect timeout: 5-10 seconds
- Read timeout: 30-60 seconds for API calls
- Adjust based on expected response time

---

## Security Best Practices

### ✅ **Never Hardcode Secrets**

**Problem:** Hardcoded API tokens in code = security breach.

**Solution:** Environment variables, secret managers, or encrypted files.

```bash
# ✅ GOOD: Environment variable
export TRENDMICRO_API_TOKEN="your-token"
./go/bin/get_container_vulnerabilities --environment production

# ✅ GOOD: Secret file with restricted permissions
chmod 600 ~/.trend_micro_token
TRENDMICRO_API_TOKEN=$(cat ~/.trend_micro_token)

# ❌ BAD: Hardcoded in script
API_TOKEN="abcd1234secret5678"  # NEVER DO THIS!
```

**Token Storage Hierarchy (Best to Worst):**
1. ✅ Enterprise secret manager (HashiCorp Vault, AWS Secrets Manager)
2. ✅ Environment variable in secure CI/CD
3. ✅ Encrypted file with key management
4. ⚠️ Plain file with chmod 600
5. ❌ Hardcoded in scripts
6. ❌ Committed to version control

---

### ✅ **Secure Token File Permissions**

**Always restrict permissions** on files containing tokens.

```bash
# Create token file with secure permissions
touch /tmp/k8s_token.json
chmod 600 /tmp/k8s_token.json  # Owner read/write only
chown $USER:$USER /tmp/k8s_token.json

# Write token
echo "$TOKEN_DATA" > /tmp/k8s_token.json

# Verify permissions
ls -la /tmp/k8s_token.json
# Should show: -rw------- (600)
```

**Python Implementation:**

```python
import os
import stat

def save_token_securely(token, filepath):
    """Save token with secure permissions."""
    
    # Write to temp file first
    temp_file = filepath + '.tmp'
    
    with open(temp_file, 'w') as f:
        json.dump(token, f, indent=2)
    
    # Set restrictive permissions (owner read/write only)
    os.chmod(temp_file, stat.S_IRUSR | stat.S_IWUSR)  # 0o600
    
    # Atomic rename
    os.rename(temp_file, filepath)
    
    log_json('info', 'Token saved securely',
        file_path=filepath,
        permissions='600'
    )
```

---

### ✅ **Automatic Token Cleanup**

**Don't leave tokens lying around.**

```bash
#!/bin/bash
# Automatic cleanup on exit

TOKEN_FILE="/tmp/k8s_token_$$.json"

# Trap to ensure cleanup
cleanup() {
    if [[ -f "$TOKEN_FILE" ]]; then
        shred -u "$TOKEN_FILE" 2>/dev/null || rm -f "$TOKEN_FILE"
        log_json "info" "Token file cleaned up" "{\"file\": \"$TOKEN_FILE\"}"
    fi
}

trap cleanup EXIT INT TERM

# Your script logic here
generate_token "$TOKEN_FILE"

# cleanup() will be called automatically on exit
```

---

### ✅ **API Token Validation**

**Validate tokens before use** to fail fast.

```python
import re

def validate_api_token(token: str) -> bool:
    """
    Validate API token format.
    
    Args:
        token: API token to validate
    
    Returns:
        True if token appears valid, False otherwise
    """
    if not token or not isinstance(token, str):
        return False
    
    # Check minimum length
    if len(token) < 32:
        log_json('warning', 'API token too short', 
            token_length=len(token),
            expected_min_length=32
        )
        return False
    
    # Check for suspicious patterns
    if token in ['test', 'demo', 'example', 'YOUR_TOKEN_HERE']:
        log_json('error', 'Placeholder token detected')
        return False
    
    # Check for whitespace
    if token != token.strip():
        log_json('warning', 'API token contains whitespace')
        return False
    
    return True

# Usage
api_token = os.getenv('TRENDMICRO_API_TOKEN')
if not validate_api_token(api_token):
    sys.exit(1)
```

---

## API Integration Patterns

### ✅ **Consistent API Client Design**

**Encapsulate API logic** in a reusable class/module.

```python
class TrendMicroAPIClient:
    """Base API client with common patterns."""
    
    def __init__(self, api_token: str, base_url: str = None, timeout: int = 30):
        self.api_token = api_token
        self.base_url = base_url or 'https://automation.trendmicro.com'
        self.timeout = timeout
        self.session = self._create_session()
    
    def _create_session(self) -> requests.Session:
        """Create configured session."""
        session = requests.Session()
        session.headers.update({
            'Authorization': f'Bearer {self.api_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': f'K8sBootstrapAutomation/{VERSION}'
        })
        return session
    
    def _request(self, method: str, endpoint: str, **kwargs) -> dict:
        """Make API request with error handling."""
        url = f"{self.base_url}{endpoint}"
        
        log_json('debug', f'{method} {endpoint}',
            http_method=method,
            url=url
        )
        
        try:
            response = self.session.request(
                method, url,
                timeout=self.timeout,
                **kwargs
            )
            response.raise_for_status()
            
            log_json('info', 'API request successful',
                http_method=method,
                endpoint=endpoint,
                status_code=response.status_code
            )
            
            return response.json()
            
        except requests.exceptions.HTTPError as e:
            log_json('error', 'API request failed',
                http_method=method,
                endpoint=endpoint,
                status_code=e.response.status_code,
                error_message=str(e)
            )
            raise
```

---

### ✅ **Request/Response Logging**

**Log all API interactions** for debugging and auditing.

```python
def log_api_call(method, endpoint, status_code, duration_ms, error=None):
    """Log API call with full context."""
    
    log_data = {
        'event.action': 'api_call',
        'event.category': 'api',
        'http.request.method': method,
        'http.request.url': endpoint,
        'http.response.status_code': status_code,
        'event.duration': duration_ms,
    }
    
    if error:
        log_data['event.outcome'] = 'failure'
        log_data['error.message'] = str(error)
        level = 'error'
    elif status_code >= 400:
        log_data['event.outcome'] = 'failure'
        level = 'error'
    else:
        log_data['event.outcome'] = 'success'
        level = 'info'
    
    log_json(level, f'{method} {endpoint}', **log_data)
```

---

### ✅ **Rate Limiting & Throttling**

**Respect API rate limits** to avoid being blocked.

```python
import time
from collections import deque

class RateLimiter:
    """Simple rate limiter using sliding window."""
    
    def __init__(self, max_requests: int, time_window: int):
        """
        Args:
            max_requests: Maximum requests allowed
            time_window: Time window in seconds
        """
        self.max_requests = max_requests
        self.time_window = time_window
        self.requests = deque()
    
    def wait_if_needed(self):
        """Wait if rate limit would be exceeded."""
        now = time.time()
        
        # Remove old requests outside time window
        while self.requests and self.requests[0] < now - self.time_window:
            self.requests.popleft()
        
        # Check if we're at the limit
        if len(self.requests) >= self.max_requests:
            sleep_time = self.requests[0] + self.time_window - now
            if sleep_time > 0:
                log_json('info', 'Rate limit reached, waiting',
                    sleep_seconds=sleep_time
                )
                time.sleep(sleep_time)
        
        # Record this request
        self.requests.append(now)

# Usage
rate_limiter = RateLimiter(max_requests=100, time_window=60)  # 100 req/min

for cluster_id in cluster_ids:
    rate_limiter.wait_if_needed()
    generate_token(cluster_id)
```

---

## Code Organization

### ✅ **Consistent File Structure**

**Organize project files** for easy navigation.

```
k8s-bootstrap-automation/
├── VERSION                        # Single source of truth
├── README.md                      # Main documentation
├── QUICKSTART.md                  # Quick start guide
├── BEST_PRACTICES.md              # This file (reusable)
├── CHANGELOG.md                   # Version history
├── .gitignore                     # Ignore sensitive files
├── .env.example                   # Environment variable template
├── requirements.txt               # Python dependencies
├── bump_version.sh                # Version bump automation
├── example_usage.py               # Usage examples
├── tests/                         # Test files
│   ├── test_automation.py
│   └── test_integration.sh
├── .git/
│   └── hooks/
│       └── pre-commit             # Version enforcement hook
└── docs/                          # Additional documentation
    ├── API_INTEGRATION.md
    └── TROUBLESHOOTING.md
```

---

### ✅ **Function Naming Conventions**

**Use prefixes** to avoid naming conflicts and improve searchability.

```bash
# Bash: prefix with project abbreviation
k8s_generate_token() { ... }
k8s_validate_cluster_id() { ... }
k8s_cleanup() { ... }

# Python: use descriptive names with clear purpose
def generate_bootstrap_token(cluster_id): ...
def validate_api_response(response): ...
def save_token_securely(token, filepath): ...
```

**Benefits:**
- ✅ Easy to find all project functions: `grep "k8s_"`
- ✅ No conflicts with system functions
- ✅ Clear ownership and purpose

---

### ✅ **Configuration Management**

**Centralize configuration** for easy modification.

```python
# config.py
import os
from dataclasses import dataclass

@dataclass
class Config:
    """Application configuration."""
    
    # API Settings
    API_BASE_URL: str = os.getenv(
        'TRENDMICRO_API_BASE_URL',
        'https://automation.trendmicro.com'
    )
    API_TOKEN: str = os.getenv('TRENDMICRO_API_TOKEN', '')
    API_TIMEOUT: int = int(os.getenv('API_TIMEOUT', '30'))
    
    # Retry Settings
    MAX_RETRIES: int = int(os.getenv('MAX_RETRIES', '3'))
    INITIAL_RETRY_DELAY: float = float(os.getenv('INITIAL_RETRY_DELAY', '1.0'))
    MAX_RETRY_DELAY: float = float(os.getenv('MAX_RETRY_DELAY', '60.0'))
    
    # Logging Settings
    LOG_FILE: str = os.getenv('LOG_FILE', '/var/log/k8s_bootstrap.jsonl')
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    
    # Security Settings
    TOKEN_FILE_PERMISSIONS: int = 0o600
    AUTO_CLEANUP: bool = os.getenv('AUTO_CLEANUP', 'true').lower() == 'true'
    
    def validate(self) -> bool:
        """Validate configuration."""
        if not self.API_TOKEN:
            print("ERROR: TRENDMICRO_API_TOKEN not set")
            return False
        
        if self.API_TIMEOUT < 1:
            print("ERROR: API_TIMEOUT must be positive")
            return False
        
        return True

# Usage
config = Config()
if not config.validate():
    sys.exit(1)
```

---

## Documentation Standards

### ✅ **Maximum 4 Consolidated Files**

**Problem:** Many small docs = navigation hell.

**Solution:** Consolidate into 4 logical documents.

```
docs/
├── README.md              # Project overview, quick links, navigation hub
├── QUICKSTART.md          # Installation, setup, first use (5-minute guide)
├── BEST_PRACTICES.md      # This file - standards and patterns
└── CHANGELOG.md           # Version history and changes
```

**Additional specialized docs (only if needed):**
- API_INTEGRATION.md (complex API interactions)
- TROUBLESHOOTING.md (common issues and solutions)
- CONTRIBUTING.md (for open source projects)

---

### ✅ **Code References with Line Numbers**

**For existing code**, use format with line numbers:

```markdown
The config loading logic is implemented here:

```45:67:go/lib/config_loader.go
// Example: Load deployment config and resolve credentials
func NewTrendMicroConfig(env string, overrides map[string]string) (*TrendMicroConfig, error) {
    // ... load from deployment_config.json or pass
    return config, nil
}
```
```

**Benefits:**
- ✅ Creates clickable links in modern IDEs
- ✅ Easy to find exact code location
- ✅ Readers can verify claims
- ✅ Updates visible in diffs

---

### ✅ **Self-Documenting Scripts**

**Include comprehensive help text** in all scripts.

```bash
#!/bin/bash

usage() {
    cat << EOF
Container Vulnerability Scanner

USAGE:
    $(basename "$0") [OPTIONS]

DESCRIPTION:
    Generates bootstrap tokens for Kubernetes clusters using the 
    Trend Micro XDR Beta API. Supports automatic token storage,
    environment variable export, and secure file handling.

OPTIONS:
    -c, --cluster-id ID       Kubernetes cluster ID (required)
    -t, --api-token TOKEN     API token (or set TRENDMICRO_API_TOKEN)
    -o, --output-file FILE    Save token to file
    -u, --base-url URL        API base URL
    -v, --verbose             Enable verbose logging
    -h, --help                Show this help message

ENVIRONMENT VARIABLES:
    TRENDMICRO_API_TOKEN      API authentication token
    K8S_CLUSTER_ID            Default cluster ID
    API_BASE_URL              Override default API URL

EXAMPLES:
    # Basic usage
    $0 --cluster-id "prod-k8s-001"
    
    # Save to specific file
    $0 -c "prod-k8s-001" -o "/secure/tokens/prod.json"
    
    # Use custom API URL
    $0 -c "dev-001" -u "https://dev-api.trendmicro.com"

EXIT CODES:
    0    Success
    1    General error
    2    Invalid arguments
    3    API error
    4    Token generation failed

AUTHOR:
    Mukesh Kesharwani

VERSION:
    $VERSION (Built: $BUILD_DATE)

EOF
    exit 0
}
```

---

## Git Practices

### ✅ **Semantic Commit Messages**

**Format:** `type(scope): description`

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code restructure, no behavior change
- `perf`: Performance improvement
- `test`: Add/update tests
- `chore`: Maintenance tasks
- `security`: Security improvements

```bash
# ✅ GOOD: Clear, categorized, descriptive
git commit -m "feat(api): Add retry logic with exponential backoff"
git commit -m "fix(logging): Correct JSONL timestamp format to ISO 8601"
git commit -m "docs: Update QUICKSTART with environment variable examples"
git commit -m "security: Add token validation before API calls"

# ❌ BAD: Vague, non-descriptive
git commit -m "updates"
git commit -m "fix bug"
git commit -m "changes"
```

---

### ✅ **Version in Commit Messages**

**For version bumps**, include version in commit:

```bash
# ✅ GOOD: Version explicit
git commit -m "chore: v1.1.0 - Add multi-cluster batch processing"

# After using bump_version.sh, the commit is automatic:
./bump_version.sh minor "Add multi-cluster batch processing"
# Creates commit: "chore: v1.1.0 - Add multi-cluster batch processing"
```

---

### ✅ **Document with Code Changes**

**Always update docs in same commit** as code changes:

```bash
# ✅ GOOD: Code + docs together
git add go/src/get_container_vulnerabilities.go
git add README.md
git add CHANGELOG.md
git commit -m "feat: v1.2.0 - Add multi-cluster support

- Modified automation class to support batch operations
- Updated bash script with parallel processing
- Added complete feature documentation to README
- Updated CHANGELOG with breaking changes"

# ❌ BAD: Separate commits days apart
git commit -m "add multi-cluster"
# ... 3 days later ...
git commit -m "update docs"
```

---

## Testing & Validation

### ✅ **Comprehensive Test Coverage**

**Test all critical paths** with automated tests.

```python
# tests/test_automation.py
import pytest
from lib.config_loader import TrendMicroConfig

class TestConfigLoader:
    """Test suite for configuration and credential loading."""
    
    def test_token_validation(self):
        """Test API token validation."""
        # Valid token
        assert validate_api_token('a' * 64) == True
        
        # Invalid: too short
        assert validate_api_token('short') == False
        
        # Invalid: placeholder
        assert validate_api_token('YOUR_TOKEN_HERE') == False
    
    def test_retry_logic(self):
        """Test retry with exponential backoff."""
        call_count = 0
        
        def failing_func():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise Exception("Temporary failure")
            return "success"
        
        result = retry_with_backoff(failing_func, max_retries=5)
        assert result == "success"
        assert call_count == 3
    
    @pytest.mark.integration
    def test_api_integration(self, api_token, cluster_id):
        """Integration test with real API."""
        automation = TrendMicroK8sAutomation(api_token)
        result = automation.generate_bootstrap_token(cluster_id)
        
        assert 'token' in result
        assert len(result['token']) > 0
```

**Run tests:**

```bash
# Unit tests only
pytest tests/ -m "not integration"

# All tests including integration
pytest tests/ --api-token="$TRENDMICRO_API_TOKEN" --cluster-id="test-001"
```

---

### ✅ **Pre-Deployment Checklist**

**Verify before deploying** to production.

```markdown
## Pre-Deployment Checklist

### Code Quality
- [ ] All tests pass
- [ ] No hardcoded secrets
- [ ] Error handling for all API calls
- [ ] Logging configured and tested
- [ ] Version bumped in VERSION file

### Documentation
- [ ] README updated
- [ ] CHANGELOG updated
- [ ] Code comments added for complex logic
- [ ] Usage examples provided

### Security
- [ ] API tokens not in code
- [ ] File permissions set correctly (600)
- [ ] Token cleanup implemented
- [ ] Input validation added

### Testing
- [ ] Tested with valid cluster ID
- [ ] Tested with invalid cluster ID
- [ ] Tested with expired API token
- [ ] Tested network failure scenarios
- [ ] Tested on target environment

### Git
- [ ] Semantic commit message
- [ ] Code and docs in same commit
- [ ] Pre-commit hook passes
- [ ] Changes reviewed
```

---

## CI/CD Integration

### ✅ **GitHub Actions Example**

```yaml
name: K8s Bootstrap Automation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov
      
      - name: Run tests
        run: |
          pytest tests/ -v --cov=. --cov-report=xml
      
      - name: Validate version consistency
        run: |
          VERSION=$(grep "VERSION=" VERSION | cut -d'=' -f2)
          echo "Version: $VERSION"
          grep -q "$VERSION" README.md || exit 1
      
      - name: Check for hardcoded secrets
        run: |
          if grep -r "API_TOKEN\s*=\s*['\"]" --include="*.py" --include="*.sh" .; then
            echo "ERROR: Hardcoded secrets found!"
            exit 1
          fi
  
  integration:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Run integration test
        env:
          TRENDMICRO_API_TOKEN: ${{ secrets.TRENDMICRO_API_TOKEN }}
        run: |
          ./go/bin/get_container_vulnerabilities --environment production --no-txt --no-csv
          
          # Verify JSONL output
          test -f container_vulnerability_metrics.jsonl
          head -1 container_vulnerability_metrics.jsonl | jq . > /dev/null
```

---

## Quick Reference Checklist

**Use this checklist when creating new integration automation projects:**

### Version Management
- [ ] VERSION file created (INI format)
- [ ] All scripts load version from VERSION file
- [ ] bump_version.sh script created and tested
- [ ] Pre-commit hook installed
- [ ] Version displayed in help text and logs

### Logging
- [ ] JSONL format implemented
- [ ] ECS-compliant field names used
- [ ] Context-rich log entries
- [ ] Log file rotation configured
- [ ] Logs queryable with jq

### Error Handling
- [ ] Retry logic with exponential backoff
- [ ] Graceful degradation for non-critical failures
- [ ] Timeouts configured for all API calls
- [ ] Detailed error messages in logs
- [ ] Exit codes documented

### Security
- [ ] No hardcoded secrets
- [ ] Environment variables for API tokens
- [ ] Secure file permissions (600)
- [ ] Automatic token cleanup on exit
- [ ] Token validation before use

### Code Organization
- [ ] Consistent file structure
- [ ] Function naming conventions (prefixes)
- [ ] Configuration centralized
- [ ] Reusable components
- [ ] Clear separation of concerns

### Documentation
- [ ] README with quick start
- [ ] QUICKSTART.md (5-minute guide)
- [ ] BEST_PRACTICES.md (this template)
- [ ] CHANGELOG.md
- [ ] Inline comments explain WHY
- [ ] Self-documenting help text

### Git
- [ ] Semantic commit messages
- [ ] Code and docs in same commit
- [ ] .gitignore configured
- [ ] Pre-commit hook working
- [ ] Version in commit messages

### Testing
- [ ] Unit tests for core logic
- [ ] Integration tests for API
- [ ] Pre-deployment checklist completed
- [ ] Tested on target environment
- [ ] Edge cases covered

### API Integration
- [ ] API client class/module
- [ ] Request/response logging
- [ ] Rate limiting implemented
- [ ] Error handling for HTTP errors
- [ ] User-Agent header set

### CI/CD
- [ ] GitHub Actions workflow (or equivalent)
- [ ] Automated testing
- [ ] Version validation
- [ ] Secret detection
- [ ] Integration tests

---

## Reusable Templates

### 🔧 New Integration Project Template

**Use this template to start a new integration automation project:**

```bash
#!/bin/bash
# Initialize new integration automation project

PROJECT_NAME="$1"
API_NAME="$2"

if [[ -z "$PROJECT_NAME" ]] || [[ -z "$API_NAME" ]]; then
    echo "Usage: $0 <project-name> <api-name>"
    echo "Example: $0 cloud-provisioning AWS"
    exit 1
fi

# Create directory structure
mkdir -p "${PROJECT_NAME}"
cd "${PROJECT_NAME}"

mkdir -p tests docs .git/hooks

# Create VERSION file
cat > VERSION << EOF
VERSION=1.0.0
BUILD_DATE=$(date +%Y-%m-%d)
PROJECT_NAME=${PROJECT_NAME}
API_NAME=${API_NAME}
MAINTAINER=$(git config user.name)
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
.env
*.token
*token*.json
__pycache__/
*.pyc
.DS_Store
*.log
*.jsonl
/tmp/
EOF

# Create .env.example
cat > .env.example << EOF
# ${API_NAME} API Configuration
${API_NAME^^}_API_TOKEN=your-token-here
${API_NAME^^}_API_BASE_URL=https://api.example.com
LOG_LEVEL=INFO
EOF

# Create requirements.txt
cat > requirements.txt << 'EOF'
requests>=2.31.0
urllib3>=2.0.0
EOF

# Create README.md
cat > README.md << EOF
# ${PROJECT_NAME}

Integration automation for ${API_NAME} API.

## Quick Start

\`\`\`bash
export ${API_NAME^^}_API_TOKEN="your-token"
./automation.sh --help
\`\`\`

See [QUICKSTART.md](QUICKSTART.md) for detailed instructions.
EOF

# Copy BEST_PRACTICES.md
cp ../Integration-API-Dev/BEST_PRACTICES.md ./BEST_PRACTICES.md

# Copy bump_version.sh
cp ../Integration-API-Dev/bump_version.sh ./bump_version.sh
chmod +x bump_version.sh

# Create pre-commit hook
cp ../Integration-API-Dev/.git/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Initialize git
git init
git add .
git commit -m "chore: v1.0.0 - Initial project structure"

echo "✅ Project ${PROJECT_NAME} initialized!"
echo "Next steps:"
echo "1. cd ${PROJECT_NAME}"
echo "2. Edit .env.example and create .env"
echo "3. Implement automation logic"
echo "4. Update README.md with project-specific details"
```

---

## 📚 References

### Standards
- **ECS (Elastic Common Schema):** https://www.elastic.co/guide/en/ecs/current/
- **Semantic Versioning:** https://semver.org/
- **Conventional Commits:** https://www.conventionalcommits.org/
- **12-Factor App:** https://12factor.net/

### Security
- **OWASP Top 10:** https://owasp.org/Top10/
- **API Security Best Practices:** https://owasp.org/www-project-api-security/

### Source Projects
- **KACI Best Practices:** `docs/BEST_PRACTICES_1.md`
- **OSCAL Best Practices:** `docs/BEST_PRACTICES_2.md`

---

## 💡 Contributing to This Document

**This is a living document.** As you discover new patterns or encounter issues, add them here!

**Format for new practices:**

```markdown
### ✅ **Practice Title**

**Problem:** What problem does this solve?

**Solution:** What's the better approach?

**Implementation:**
```code example```

**Benefits:**
- Benefit 1
- Benefit 2
```

---

## 📝 Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-01-12 | Initial creation from KACI/OSCAL patterns | Mukesh Kesharwani |

---

## 🎯 Summary

**Core Principles:**

1. **Single Source of Truth** - VERSION file, centralized config
2. **Structured Logging** - JSONL format, ECS-compliant
3. **Robust Error Handling** - Retry logic, graceful degradation
4. **Security First** - No hardcoded secrets, secure permissions
5. **Test Everything** - Unit tests, integration tests, validation
6. **Document As You Go** - Code and docs in same commit
7. **Automate Repetition** - Version bumps, testing, deployment

**Apply these practices to every integration automation project for:**
- ✅ Production-ready code
- ✅ Easy debugging and troubleshooting
- ✅ Secure handling of credentials
- ✅ Consistent development experience
- ✅ Fast onboarding for new developers

---

**Last Updated:** January 12, 2026  
**Project:** Kubernetes Bootstrap Automation  
**Version:** 1.0.0  
**Maintainer:** Mukesh Kesharwani

**Use these practices. Build better automation. 🚀**

