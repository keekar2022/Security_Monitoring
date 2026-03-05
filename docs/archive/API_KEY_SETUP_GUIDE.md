# API Key Setup Guide - Visual Walkthrough

**Version:** 1.0  
**Last Updated:** January 21, 2026  
**Purpose:** Complete visual guide for creating and storing Trend Micro API keys

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Create Custom Role](#step-1-create-custom-role)
4. [Step 2: Generate API Key](#step-2-generate-api-key)
5. [Step 3: Store in Pass Vault](#step-3-store-in-pass-vault)
6. [Step 4: Verify Storage](#step-4-verify-storage)
7. [Using the API Key](#using-the-api-key)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides a complete visual walkthrough for:
- Creating a custom role with appropriate permissions
- Generating an API key in Trend Vision One console
- Securely storing the API key in GPG-encrypted Pass vault
- Verifying the storage and using the key

**Time Required:** 10-15 minutes  
**Skill Level:** Beginner-friendly

---

## Prerequisites

Before starting, ensure you have:

- ✅ Access to Trend Vision One portal (Administrator role)
- ✅ `pass` (Password Store) installed and initialized
- ✅ GPG key configured for Pass
- ✅ Terminal access

**Installation Check:**
```bash
# Verify Pass is installed
pass --version

# Verify GPG is configured
gpg --list-keys

# Verify Pass is initialized
pass ls
```

**If not installed, see:** [`docs/PASS_INTEGRATION.md`](PASS_INTEGRATION.md)

---

## Step 1: Create Custom Role

Before creating an API key, you need a custom role with appropriate permissions.

### 1.1 Navigate to User Roles

1. Log into Trend Vision One portal
2. Go to **Administration** → **User Roles**
3. Click **Create custom role**

### 1.2 Configure Role

![Create Custom Role](images/04-create-custom-role.png)
*Figure 1: Creating a custom role for API access*

**Fill in the details:**

| Field | Value | Notes |
|-------|-------|-------|
| **Role name** | `AMS_Stats_Metric_Collector` | Use descriptive name |
| **Can be assigned to API keys** | ✅ **Yes** | Required for API access |
| **Can be assigned to user accounts** | ❌ No | Optional, typically not needed |
| **Role description** | `AMS's Metric and Statistics Collector` | Clear description of purpose |

**Important Settings:**
- ✅ **Must enable "Can be assigned to API keys"** - This is critical!
- The role name should follow naming convention: `{Team}_{Purpose}_{Type}`

### 1.3 Set Permissions

Click on **Permissions** tab and configure:

**Required Permissions for Container Security:**
- ✅ Container Security → View
- ✅ Container Security → Kubernetes Clusters → View
- ✅ Container Security → Vulnerabilities → View
- ✅ Container Security → Vulnerabilities → Export

**Required Permissions for Endpoint Security (if needed):**
- ✅ Endpoint Security → View
- ✅ Endpoint Security → Endpoints → View

Click **Save** to create the role.

---

## Step 2: Generate API Key

Now create an API key with the custom role.

### 2.1 Navigate to API Keys

1. Go to **Administration** → **API Keys**
2. Click **Add API Key**

### 2.2 Fill API Key Details

![Add API Key - Form](images/02-add-api-key-form.png)
*Figure 2: API Key creation form with all required fields*

**Fill in the form:**

| Field | Value | Example |
|-------|-------|---------|
| **Name** | Descriptive identifier | `AMS_Common_Monitoring` |
| **Role** | Select custom role | `AMS_Stats_Metric_Collector` |
| **Expiration Time** | Token validity period | `1 year` |
| **Description** | Purpose of this key | `AMS Stats Metric Collector` |
| **Status** | Enable/Disable | ✅ Enabled |

**Best Practices:**
- ✅ Use descriptive names that indicate purpose and environment
- ✅ Choose appropriate expiration (1 year for production, shorter for testing)
- ✅ Document the description clearly
- ✅ Keep status enabled only when actively used

### 2.3 Role Selection

![Add API Key - Role Selection](images/03-add-api-key-role-selection.png)
*Figure 3: Selecting the custom role for API key*

**Important:**
- The role dropdown will only show roles with "Can be assigned to API keys" enabled
- If your role doesn't appear, go back to Step 1 and verify the setting

### 2.4 Complete Creation

1. Click **Add** to create the API key
2. **IMPORTANT:** Copy the API token immediately - it will only be shown once!
3. The token will look like:
   ```
   eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQiOiJjYzMwNWMwYy1hNTYwLTRm...
   ```

**⚠️ WARNING:** The API token is only displayed once. If you lose it, you'll need to generate a new key.

---

## Step 3: Store in Pass Vault

Securely store the API key and related information in Pass.

### 3.1 Determine Environment

Choose the appropriate environment path:

| Environment | Path | Region |
|------------|------|--------|
| Quality & Test | `TrendMicro/quality_test/` | Australia |
| Production | `TrendMicro/production/` | United States |
| Production AU | `TrendMicro/production_au/` | Australia |

### 3.2 Store API Token

```bash
# Store the API token (will prompt for the token value)
pass insert TrendMicro/production_au/api_token

# Enter the token when prompted (it will be hidden)
# Paste: eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...
```

**Interactive Process:**
```
Enter password for TrendMicro/production_au/api_token: [paste token here]
Retype password for TrendMicro/production_au/api_token: [paste token again]
```

### 3.3 Store Business ID

```bash
# Store the Business ID
pass insert TrendMicro/production_au/business_id

# Enter the Business ID when prompted
# Example: cc305c0c-a560-4fa9-9481-46a77278122e
```

### 3.4 Store API Base URL

```bash
# Store the API base URL
pass insert TrendMicro/production_au/api_base_url

# Enter the API base URL
# For AU: https://api.au.xdr.trendmicro.com
# For US: https://api.xdr.trendmicro.com
```

### 3.5 Store Portal URL (Optional but Recommended)

```bash
# Store the portal URL for easy reference
pass insert TrendMicro/production_au/portal_url

# Enter the portal URL
# For AU: https://portal.au.xdr.trendmicro.com/
# For US: https://portal.xdr.trendmicro.com/
```

---

## Step 4: Verify Storage

Confirm everything is stored correctly.

### 4.1 List Pass Structure

```bash
pass ls
```

![Pass Vault Structure](images/01-pass-vault-structure.png)
*Figure 4: Pass vault showing organized TrendMicro credentials*

**Expected Output:**
```
Password Store
└── TrendMicro
    ├── production
    │   ├── api_base_url
    │   ├── api_token
    │   └── business_id
    ├── production_au
    │   ├── api_base_url
    │   ├── api_token
    │   ├── business_id
    │   └── portal_url
    └── quality_test
        ├── api_base_url
        ├── api_token
        └── business_id
```

### 4.2 Verify Each Entry

```bash
# Verify API token exists (won't show actual value)
pass show TrendMicro/production_au/api_token | head -c 50
# Should show: eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...

# Verify Business ID
pass show TrendMicro/production_au/business_id
# Should show: cc305c0c-a560-4fa9-9481-46a77278122e

# Verify API Base URL
pass show TrendMicro/production_au/api_base_url
# Should show: https://api.au.xdr.trendmicro.com

# Verify Portal URL
pass show TrendMicro/production_au/portal_url
# Should show: https://portal.au.xdr.trendmicro.com/
```

### 4.3 Test Configuration Loading

```bash
cd /Users/mkesharw/Documents/Integration-API-Dev

# Test that the script can load credentials
python3 -c "
from lib.config_loader import TrendMicroConfig
config = TrendMicroConfig()

# Check if credentials are loaded
envs = config.list_available_environments()
for env, info in envs.items():
    has_creds = '✅' if info.get('has_credentials') else '❌'
    print(f'{has_creds} {env}: {info[\"label\"]}')
"
```

**Expected Output:**
```
✅ quality_test: Quality & Test
✅ production: Production
✅ production_au: Production (Australia)
```

---

## Using the API Key

### Test the API Key

```bash
cd /Users/mkesharw/Documents/Integration-API-Dev

# Run a test scan for the new environment
python3 get_container_vulnerabilities.py --environment production_au

# Should see output like:
# ╔══════════════════════════════════════════════════════╗
# ║  ENVIRONMENT: PRODUCTION_AU                          ║
# ╚══════════════════════════════════════════════════════╝
# 
# 📊 Environment: Production (Australia)
#    Business: Adobe-MS-Au
#    Region: Australia (au)
```

### Run Regular Scans

```bash
# Scan all environments
python3 get_container_vulnerabilities.py

# Scan specific environment only
python3 get_container_vulnerabilities.py --environment production_au

# Quiet mode (for automation)
python3 get_container_vulnerabilities.py --environment production_au --quiet
```

---

## Troubleshooting

### Issue 1: Role Not Appearing in Dropdown

**Symptoms:**
- Custom role doesn't appear when creating API key

**Solution:**
1. Go back to **Administration → User Roles**
2. Edit the custom role
3. Verify **"Can be assigned to API keys"** is set to **Yes**
4. Save the role
5. Refresh the API Key creation page

### Issue 2: Pass Insert Fails

**Symptoms:**
```
gpg: decryption failed: No secret key
```

**Solution:**
```bash
# Check GPG keys
gpg --list-secret-keys

# If no keys, initialize Pass with a new GPG key
gpg --full-generate-key
pass init YOUR_GPG_KEY_ID
```

### Issue 3: API Token Not Working

**Symptoms:**
```
❌ Error: API token for 'production_au' has expired or is invalid
```

**Solution:**
1. Check token expiration in Trend Vision One portal
2. Verify the token was copied completely (no truncation)
3. Re-store the token in Pass:
   ```bash
   pass edit TrendMicro/production_au/api_token
   ```
4. Test again

### Issue 4: Wrong API Base URL

**Symptoms:**
```
ConnectionError: Failed to connect to API
```

**Solution:**
Verify the correct API base URL for your region:

| Region | API Base URL |
|--------|--------------|
| Australia | `https://api.au.xdr.trendmicro.com` |
| United States | `https://api.xdr.trendmicro.com` |
| Europe | `https://api.eu.xdr.trendmicro.com` |
| Singapore | `https://api.sg.xdr.trendmicro.com` |
| Japan | `https://api.xdr.trendmicro.co.jp` |
| India | `https://api.in.xdr.trendmicro.com` |

Update if incorrect:
```bash
pass edit TrendMicro/production_au/api_base_url
```

### Issue 5: Permission Denied

**Symptoms:**
```
403 Forbidden: Insufficient permissions
```

**Solution:**
1. Go to **Administration → User Roles**
2. Edit the role assigned to the API key
3. Go to **Permissions** tab
4. Verify required permissions are enabled:
   - Container Security → View
   - Container Security → Kubernetes Clusters → View
   - Container Security → Vulnerabilities → View
5. Save the role
6. Wait 5 minutes for permissions to propagate
7. Test again

---

## Security Best Practices

### Do's ✅

- ✅ Store API tokens in GPG-encrypted Pass vault
- ✅ Use descriptive names for API keys and roles
- ✅ Set appropriate expiration times (max 1 year for production)
- ✅ Document the purpose of each API key
- ✅ Rotate API keys every 90 days
- ✅ Use separate API keys for different environments
- ✅ Keep Pass vault backed up
- ✅ Use minimum required permissions for each role
- ✅ Review API key usage in Audit Logs regularly

### Don'ts ❌

- ❌ Never commit API tokens to Git repositories
- ❌ Never share API keys between environments
- ❌ Never store API keys in plain text files
- ❌ Never use overly broad permissions
- ❌ Never share Pass vault password via email/chat
- ❌ Never screenshot or copy API tokens to unsecured locations
- ❌ Never create API keys without expiration
- ❌ Never reuse API keys across multiple applications

---

## Quick Reference

### Creating API Key - Checklist

- [ ] Create custom role with "Can be assigned to API keys" enabled
- [ ] Set appropriate permissions on the role
- [ ] Go to Administration → API Keys
- [ ] Click "Add API Key"
- [ ] Fill in: Name, Role, Expiration, Description
- [ ] Enable status
- [ ] Click "Add"
- [ ] **IMMEDIATELY copy the API token**
- [ ] Store in Pass vault
- [ ] Store Business ID, API Base URL
- [ ] Verify with `pass ls`
- [ ] Test with `python3 get_container_vulnerabilities.py`

### Pass Commands Quick Reference

```bash
# List all entries
pass ls

# Show specific entry
pass show TrendMicro/production_au/api_token

# Insert new entry
pass insert TrendMicro/production_au/api_token

# Edit existing entry
pass edit TrendMicro/production_au/api_token

# Delete entry
pass rm TrendMicro/production_au/api_token

# Search for entries
pass find api_token

# Copy to clipboard (30 second timeout)
pass -c TrendMicro/production_au/api_token
```

---

## Screenshots Reference

This guide includes the following screenshots:

1. **`images/01-pass-vault-structure.png`**  
   Pass vault showing organized TrendMicro folder structure with all environments

2. **`images/02-add-api-key-form.png`**  
   Trend Vision One "Add API Key" dialog with all fields filled in

3. **`images/03-add-api-key-role-selection.png`**  
   Role selection dropdown showing custom role

4. **`images/04-create-custom-role.png`**  
   Custom role creation page with permissions and settings

---

## Related Documentation

- **[Pass Integration Guide](PASS_INTEGRATION.md)** - Complete Pass setup and usage
- **[Pass Quick Reference](PASS_QUICK_REFERENCE.md)** - Common Pass commands
- **[Configuration Guide](CONFIGURATION.md)** - Environment configuration reference
- **[Container Security Guide](CONTAINER_SECURITY.md)** - Using the vulnerability scanner
- **[Multi-Environment Setup](MULTI_ENVIRONMENT_QUICK_GUIDE.md)** - Setting up multiple environments

---

## Support

### Getting Help

1. **Pass Issues:**
   - Check Pass documentation: https://www.passwordstore.org/
   - Verify GPG setup: `gpg --list-keys`

2. **API Key Issues:**
   - Check Trend Vision One documentation
   - Review Audit Logs in portal
   - Verify role permissions

3. **Script Issues:**
   - Review [`docs/CONTAINER_SECURITY.md`](CONTAINER_SECURITY.md)
   - Check logs: `python3 get_container_vulnerabilities.py 2>&1 | tee debug.log`

### Contact Points

- **Trend Micro Support:** https://success.trendmicro.com/
- **API Documentation:** https://automation.trendmicro.com/xdr/api-beta/
- **Portal:** https://portal.au.xdr.trendmicro.com/ (or your region)

---

**Last Updated:** January 21, 2026  
**Version:** 1.0  
**Maintainer:** Integration-API-Dev Team
