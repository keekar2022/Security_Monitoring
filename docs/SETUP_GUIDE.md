# Complete Setup Guide

**Version:** 4.0 | **Last Updated:** January 21, 2026 | **Time Required:** 15-20 minutes  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## 📋 Table of Contents

1. [Quick Start (5 Minutes)](#quick-start-5-minutes)
2. [Prerequisites](#prerequisites)
3. [Step 1: Install Dependencies](#step-1-install-dependencies)
4. [Step 2: Setup Pass (Password Store)](#step-2-setup-pass-password-store)
5. [Step 3: Create Trend Micro API Key](#step-3-create-trend-micro-api-key)
6. [Step 4: Store Credentials](#step-4-store-credentials)
7. [Step 5: Verify Setup](#step-5-verify-setup)
8. [Step 6: Run First Scan](#step-6-run-first-scan)
9. [Next Steps](#next-steps)
10. [Troubleshooting](#troubleshooting)

---

## Quick Start (5 Minutes)

**If you already have Pass configured and API credentials:**

```bash
# 1. Install Python dependencies
pip install -r requirements.txt

# 2. Verify credentials are loaded
python3 -c "from lib.config_loader import TrendMicroConfig; \
            config = TrendMicroConfig(); \
            print('✅ Configured environments:'); \
            for env, info in config.list_available_environments().items(): \
                print(f'  {env}: {info[\"label\"]}')"

# 3. Run first scan
python3 get_container_vulnerabilities.py

# Done! Check output files:
ls -lh container_vulnerability_*
```

**If this is your first time**, follow the complete setup below.

---

## Prerequisites

Before starting, ensure you have:

### System Requirements
- ✅ macOS, Linux, or Windows (WSL)
- ✅ Python 3.8 or higher
- ✅ Terminal/command line access
- ✅ Internet connectivity

### Accounts & Permissions
- ✅ Trend Micro Vision One account
- ✅ Administrator role (to create API keys and roles)
- ✅ Access to Container Security module

### Tools to Install
- ✅ GPG (GnuPG) for encryption
- ✅ Pass (password-store) for credential management
- ✅ Git (optional, but recommended)

**Check what's already installed:**
```bash
python3 --version    # Should be 3.8+
gpg --version       # Should be 2.x
pass --version      # Should be 1.7+
```

---

## Step 1: Install Dependencies

### Python Dependencies

```bash
cd /path/to/Integration-API-Dev

# Install required Python packages
pip install -r requirements.txt

# Verify installation
python3 -c "import requests; print('✅ requests installed')"
```

### Install Pass (if not already installed)

#### macOS (Homebrew)
```bash
brew install pass
```

#### Linux (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install pass
```

#### Linux (RHEL/CentOS/Fedora)
```bash
sudo yum install pass
# or
sudo dnf install pass
```

### Install GPG (if not already installed)

#### macOS
```bash
brew install gnupg
```

#### Linux
```bash
# Usually pre-installed, but if needed:
sudo apt-get install gnupg  # Debian/Ubuntu
sudo yum install gnupg      # RHEL/CentOS
```

---

## Step 2: Setup Pass (Password Store)

### 2.1 Create GPG Key (if you don't have one)

```bash
# Generate a new GPG key
gpg --full-generate-key

# Follow prompts:
# - Select: (1) RSA and RSA
# - Key size: 4096
# - Expiration: 0 (never expires) or 1y (1 year)
# - Real name: Your Name
# - Email: your.email@company.com
# - Comment: Trend Micro API Keys
# - Passphrase: Enter a strong passphrase
```

### 2.2 Initialize Pass

```bash
# List your GPG keys to get the key ID
gpg --list-keys

# Output will show:
# pub   rsa4096 2026-01-21 [SC]
#       ABCD1234EFGH5678IJKL9012MNOP3456QRST7890  ← This is your key ID
# uid   [ultimate] Your Name <your.email@company.com>

# Initialize pass with your GPG key ID
pass init ABCD1234EFGH5678IJKL9012MNOP3456QRST7890

# Or use email:
pass init your.email@company.com

# Verify initialization
pass ls
# Should show: Password Store (empty)
```

---

## Step 3: Create Trend Micro API Key

### 3.1 Create Custom Role

1. **Log into Trend Vision One portal:**
   - Australia: https://portal.au.xdr.trendmicro.com/
   - US/Global: https://portal.xdr.trendmicro.com/

2. **Navigate to User Roles:**
   - Click **Administration** (left sidebar)
   - Click **User Roles**

3. **Create custom role:**
   - Click **Create custom role**
   - Fill in the form:
     - **Role name:** `Container_Security_Reader` (or your preferred name)
     - **Can be assigned to API keys:** ✅ **Yes** (IMPORTANT!)
     - **Can be assigned to user accounts:** ❌ No
     - **Role description:** `Read-only access for container vulnerability scanning`

4. **Set Permissions (Permissions tab):**
   - ✅ Container Security → View
   - ✅ Container Security → Kubernetes Clusters → View
   - ✅ Container Security → Vulnerabilities → View
   - ✅ Container Security → Vulnerabilities → Export (optional)

5. **Save the role**

### 3.2 Generate API Key

1. **Navigate to API Keys:**
   - Click **Administration** → **API Keys**

2. **Create new API key:**
   - Click **Add API Key**
   - Fill in the form:
     - **Name:** `Container_Vulnerability_Scanner` (descriptive name)
     - **Role:** Select the custom role you just created
     - **Expiration Time:** `1 year`
     - **Description:** `Automated container vulnerability scanning`
     - **Status:** ✅ Enabled

3. **Copy the API token:**
   - **⚠️ IMPORTANT:** The token is only shown once!
   - Click **Add**
   - **Immediately copy the entire token** (starts with `eyJ0eXAi...`)
   - Save it temporarily in a secure location

### 3.3 Get Business Information

While in the portal:

1. **Get Business ID:**
   - Go to **Administration** → **License Information**
   - Copy the **Business ID** (UUID format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

2. **Note your API Base URL:**
   - Australia: `https://api.au.xdr.trendmicro.com`
   - US/Global: `https://api.xdr.trendmicro.com`
   - Europe: `https://api.eu.xdr.trendmicro.com`
   - Singapore: `https://api.sg.xdr.trendmicro.com`
   - Japan: `https://api.xdr.trendmicro.co.jp`
   - India: `https://api.in.xdr.trendmicro.com`

---

## Step 4: Store Credentials

### 4.1 Determine Environment Path

Choose the environment name based on your use case:

| Environment | Use Case | Example |
|------------|----------|---------|
| `production` | Production systems | Main US/Global production |
| `production_au` | Production (Australia) | Australia production |
| `quality_test` | QA/Testing | Staging/Test environments |
| `development` | Development | Dev environments |

### 4.2 Store API Token

**⚠️ CRITICAL: Use the correct command format to avoid authentication errors!**

```bash
# RECOMMENDED METHOD - Store token using echo pipe (ensures single line)
echo "PASTE_YOUR_TOKEN_HERE" | pass insert -e TrendMicro/production/api_token

# Example with actual token format:
echo "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQ..." | pass insert -e TrendMicro/production/api_token
```

**Alternative method (interactive):**
```bash
# Store the API token (replace 'production' with your environment)
pass insert TrendMicro/production/api_token

# Paste the token when prompted (it will be hidden):
# eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...

# Press Enter, then paste again to confirm
```

**Helper script:** You can also use the project script `./update-pass-credential.sh` (from the repo root) to pick an existing pass entry or add a new one, then paste credentials; see [PASS_GUIDE.md - Update credentials with the helper script](PASS_GUIDE.md#update-credentials-with-the-helper-script).

**⚠️ IMPORTANT - Token Storage Rules:**
- ✅ **ONLY** store the raw JWT token (the long string starting with `eyJ0...`)
- ✅ Store as a **single line** with NO extra metadata
- ❌ **NEVER** add metadata lines like "Issued:", "Expires:", "Status:" etc.
- ❌ **NEVER** store multi-line content for tokens

**Why this matters:**
Extra lines in the token cause **HTTP 401 Unauthorized errors** because the authentication header becomes invalid. The script reads ALL lines from `pass`, so only the token should be present.

**Verify your token is stored correctly:**
```bash
# Check that token is exactly 1 line (should output "1")
pass show TrendMicro/production/api_token | wc -l

# View first 50 characters to verify format
pass show TrendMicro/production/api_token | head -c 50
# Should output: eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQiO
```

### 4.3 Store Business ID

```bash
# Store the Business ID
pass insert TrendMicro/production/business_id

# Enter the Business ID when prompted:
# Example: ec367c49-2f23-49a3-a55c-a062f7d6583a
```

### 4.4 Store API Base URL

```bash
# Store the API base URL
pass insert TrendMicro/production/api_base_url

# Enter the API base URL:
# For US: https://api.xdr.trendmicro.com
# For AU: https://api.au.xdr.trendmicro.com
```

### 4.5 Verify Storage

```bash
# List all stored credentials
pass ls

# Should show:
# Password Store
# └── TrendMicro
#     └── production
#         ├── api_base_url
#         ├── api_token
#         └── business_id

# Test retrieval (shows first 50 characters of token)
pass show TrendMicro/production/api_token | head -c 50

# RECOMMENDED: Run automated verification
./verify_pass_tokens.sh
```

**The verification script checks:**
- ✅ Token is stored as a single line (no extra metadata)
- ✅ Token length is reasonable (JWT format)
- ✅ No issues that would cause HTTP 401 errors

**If verification fails**, follow the fix commands provided by the script.

---

## Step 5: Verify Setup

### 5.1 Test Configuration Loading

```bash
cd /path/to/Integration-API-Dev

# Test that credentials are loaded correctly
python3 << 'EOF'
from lib.config_loader import TrendMicroConfig

config = TrendMicroConfig()
envs = config.list_available_environments()

print("\n✅ Configured Environments:\n")
for env, info in envs.items():
    has_creds = '✅' if info.get('has_credentials') else '❌'
    print(f"{has_creds} {env:20s} - {info['label']}")

print("\n")

# Test specific environment
try:
    token = config.get_api_token('production')
    print(f"✅ API token loaded successfully (length: {len(token)} characters)")
    
    base_url = config.get_api_base_url('production')
    print(f"✅ API base URL: {base_url}")
    
    business_id = config.get_deployment_info('production')['business_id']
    print(f"✅ Business ID: {business_id}")
    
    print("\n🎉 Configuration is valid!")
except Exception as e:
    print(f"❌ Error: {e}")
EOF
```

**Expected output:**
```
✅ Configured Environments:

✅ production            - Production
❌ quality_test          - Quality & Test
❌ production_au         - Production (Australia)

✅ API token loaded successfully (length: 632 characters)
✅ API base URL: https://api.xdr.trendmicro.com
✅ Business ID: ec367c49-2f23-49a3-a55c-a062f7d6583a

🎉 Configuration is valid!
```

### 5.2 Test API Connectivity

```bash
# Run a quick test to verify API access
python3 get_container_vulnerabilities.py \
    --environment production \
    --summary-only

# Should show:
# ╔══════════════════════════════════════╗
# ║  ENVIRONMENT: PRODUCTION             ║
# ╚══════════════════════════════════════╝
#
# 📊 Environment: Production
#    Business: Your-Business-Name
#    Region: United States (us)
#
# Found X Kubernetes clusters...
```

---

## Step 6: Run First Scan

### 6.1 Run Complete Scan

```bash
cd /path/to/Integration-API-Dev

# Run scan for configured environment
python3 get_container_vulnerabilities.py --environment production
```

**The script will:**
1. ✅ Discover all Kubernetes clusters
2. ✅ Fetch vulnerability data for each cluster
3. ✅ Generate three output files:
   - `container_vulnerability_summary.csv` (Excel-ready)
   - `container_vulnerability_report.txt` (Human-readable)
   - `container_vulnerability_metrics.jsonl` (Grafana/Loki)

### 6.2 View Results

```bash
# View human-readable report
cat container_vulnerability_report.txt

# View CSV (formatted)
column -t -s',' < container_vulnerability_summary.csv | head -20

# View latest JSONL entry
tail -1 container_vulnerability_metrics.jsonl | python3 -m json.tool

# Count clusters scanned
grep -c '"aggregation.level": "cluster"' container_vulnerability_metrics.jsonl
```

---

## Next Steps

### 1. Setup Multiple Environments

Repeat Steps 3-4 for additional environments:

```bash
# Quality/Test environment
pass insert TrendMicro/quality_test/api_token
pass insert TrendMicro/quality_test/business_id
pass insert TrendMicro/quality_test/api_base_url

# Production AU environment
pass insert TrendMicro/production_au/api_token
pass insert TrendMicro/production_au/business_id
pass insert TrendMicro/production_au/api_base_url
```

### 2. Schedule Automated Scans

```bash
# Edit crontab
crontab -e

# Add for production (every 6 hours):
0 */6 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --environment production --quiet

# Add for all environments (daily at 2 AM):
0 2 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
```

### 3. Setup Grafana (Optional but Recommended)

See [`GRAFANA_GUIDE.md`](GRAFANA_GUIDE.md) for complete Grafana/Loki setup instructions.

### 4. Review Documentation

- [`CONTAINER_SECURITY.md`](CONTAINER_SECURITY.md) - Complete vulnerability management guide
- [`CONFIGURATION.md`](CONFIGURATION.md) - Advanced configuration options
- [`PASS_GUIDE.md`](PASS_GUIDE.md) - Complete Pass (password store) guide
- [`BEST_PRACTICES.md`](BEST_PRACTICES.md) - Security and operational best practices

---

## Troubleshooting

### Issue 1: Pass Not Initialized

**Symptoms:**
```
pass: password store is empty
```

**Solution:**
```bash
# List GPG keys
gpg --list-keys

# Initialize pass with your key
pass init your.email@company.com
```

### Issue 2: GPG Key Not Found

**Symptoms:**
```
gpg: decryption failed: No secret key
```

**Solution:**
```bash
# Generate new GPG key
gpg --full-generate-key

# Follow prompts, then initialize pass
pass init your.email@company.com
```

### Issue 3: API Token Expired

**Symptoms:**
```
❌ Error: API token for 'production' has expired
```

**Solution:**
1. Go to Trend Vision One portal
2. Administration → API Keys
3. Generate new API key
4. Update in Pass:
   ```bash
   pass edit TrendMicro/production/api_token
   ```

### Issue 4: Permission Denied (403)

**Symptoms:**
```
403 Forbidden: Insufficient permissions
```

**Solution:**
1. Verify custom role has required permissions
2. Go to Administration → User Roles
3. Edit the role
4. Verify Container Security permissions are enabled
5. Wait 5 minutes for changes to propagate

### Issue 5: No Clusters Found

**Symptoms:**
```
❌ No Kubernetes clusters found
```

**Solution:**
1. Verify clusters exist in portal: Container Security → Kubernetes Clusters
2. Verify API token has Container Security permissions
3. Check you're scanning the correct environment
4. Ensure token is not expired

### Issue 6: Configuration Not Loading

**Symptoms:**
```
❌ production - Credentials: No
```

**Solution:**
```bash
# Verify Pass structure
pass ls

# Should show TrendMicro/production/ with 3 entries
# If missing, re-run Step 4

# Test Pass retrieval
pass show TrendMicro/production/api_token
```

### Issue 7: HTTP 401 Unauthorized Despite Valid Token

**Symptoms:**
```
✗ Failed to fetch clusters (HTTP 401)
API returns 401 Unauthorized even though token is valid
```

**Root Cause:**
Token stored in Pass contains extra metadata lines (e.g., "Issued:", "Expires:", "Status:") which causes invalid HTTP headers.

**Diagnosis:**
```bash
# Check if token has extra lines (should output "1")
pass show TrendMicro/production/api_token | wc -l

# If output is > 1, you have this problem!
```

**Solution:**
```bash
# Fix by keeping only the token (first line)
pass show TrendMicro/production/api_token | head -1 | pass insert -e TrendMicro/production/api_token

# Verify it's fixed (should now be 1 line)
pass show TrendMicro/production/api_token | wc -l

# Test that API now works
python3 get_container_vulnerabilities.py --environment production
```

**Prevention:**
Always store tokens using: `echo "TOKEN" | pass insert -e TrendMicro/ENVIRONMENT/api_token`

---

## Security Best Practices

### ✅ Do's

- ✅ Use Pass (GPG-encrypted) for all credentials
- ✅ Set strong GPG passphrase
- ✅ Rotate API tokens every 90 days
- ✅ Use minimum required permissions
- ✅ Keep Pass vault backed up
- ✅ Use separate tokens per environment
- ✅ Review audit logs regularly

### ❌ Don'ts

- ❌ Never store API tokens in plain text
- ❌ Never commit credentials to Git
- ❌ Never share Pass GPG keys
- ❌ Never use the same token across environments
- ❌ Never screenshot API tokens
- ❌ Never email or chat credentials
- ❌ Never create tokens without expiration

---

## Quick Reference

### Common Commands

```bash
# List all Pass entries
pass ls

# Show specific credential
pass show TrendMicro/production/api_token

# Edit credential
pass edit TrendMicro/production/api_token

# Copy to clipboard (clears after 45s)
pass -c TrendMicro/production/api_token

# Run scan for environment
python3 get_container_vulnerabilities.py --environment production

# Run scan for all environments
python3 get_container_vulnerabilities.py

# Quiet mode (for cron)
python3 get_container_vulnerabilities.py --quiet

# Check configuration
python3 -c "from lib.config_loader import TrendMicroConfig; \
            config = TrendMicroConfig(); \
            print('Environments:', list(config.list_available_environments().keys()))"
```

---

## Support

### Resources

- **Pass Documentation:** https://www.passwordstore.org/
- **Trend Micro Portal:** https://portal.xdr.trendmicro.com/ (or your region)
- **API Documentation:** https://automation.trendmicro.com/xdr/api-beta/
- **GPG Documentation:** https://gnupg.org/documentation/

### Getting Help

1. Review this guide and troubleshooting section
2. Check [`PASS_GUIDE.md`](PASS_GUIDE.md) for Pass-specific help
3. Check [`CONTAINER_SECURITY.md`](CONTAINER_SECURITY.md) for scanning help
4. Review Trend Micro API documentation

---

**🎉 Congratulations! Your setup is complete.**

You can now:
- ✅ Scan container vulnerabilities across all environments
- ✅ Generate CSV, TXT, and JSONL reports
- ✅ Securely manage credentials with Pass
- ✅ Automate scans with cron
- ✅ Track vulnerability trends over time

**Next:** Set up Grafana dashboards to visualize trends → [`GRAFANA_GUIDE.md`](GRAFANA_GUIDE.md)

---

**Last Updated:** January 21, 2026 | **Version:** 4.0
