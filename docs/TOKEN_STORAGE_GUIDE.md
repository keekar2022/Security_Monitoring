# API Token Storage - Critical Guidelines

**Version:** 4.0 | **Last Updated:** January 23, 2026  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## ⚠️ Critical Issue: Proper Token Storage

This guide documents a critical issue that can cause **HTTP 401 Unauthorized errors** when storing API tokens in Pass, and how to prevent it.

---

## The Problem

When API tokens are stored in Pass with **extra metadata lines**, they cause authentication failures:

### ❌ INCORRECT Storage (Causes HTTP 401)

```bash
# Token stored with metadata
pass show TrendMicro/production/api_token

# Output (WRONG):
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQ...
Issued: 2026-01-20
Expires: 2027-01-20
Status: active
```

**Problem:** Scripts read ALL lines from Pass, creating an invalid HTTP Authorization header:

```http
Authorization: Bearer eyJ0eXAi...
Issued: 2026-01-20
Expires: 2027-01-20
Status: active
```

This causes: `requests.exceptions.InvalidHeader: Invalid leading whitespace, reserved character(s)...`

### ✅ CORRECT Storage

```bash
# Token stored as single line
pass show TrendMicro/production/api_token

# Output (CORRECT):
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQ...
```

---

## The Solution

### Method 1: Use `echo` with Pipe (RECOMMENDED)

Always store tokens using this format:

```bash
# Correct command format
echo "TOKEN_VALUE_HERE" | pass insert -e TrendMicro/ENVIRONMENT/api_token

# Example:
echo "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQ..." | pass insert -e TrendMicro/production/api_token
```

**Why this works:**
- `echo` ensures single-line input
- `-e` flag (echo mode) doesn't prompt for confirmation
- No chance of accidental multi-line paste

### Method 2: Interactive Mode (Be Careful)

```bash
# Interactive method
pass insert TrendMicro/production/api_token

# When prompted:
# 1. Paste ONLY the token (nothing else!)
# 2. Press Enter
# 3. Paste again for confirmation
# 4. Press Enter
```

**Risks:**
- Easy to accidentally paste metadata
- No validation of single-line format

---

## Diagnosis

### Check If You Have This Problem

```bash
# Check number of lines in stored token
pass show TrendMicro/production/api_token | wc -l

# Expected output: 1
# If > 1: YOU HAVE THE PROBLEM!
```

### Verify All Environments

```bash
# Run automated verification
./verify_pass_tokens.sh

# Script checks all environments and reports issues
```

---

## Fixing Broken Tokens

### Fix Single Environment

```bash
# Extract first line only and re-store
pass show TrendMicro/production/api_token | head -1 | pass insert -e TrendMicro/production/api_token

# Verify fix
pass show TrendMicro/production/api_token | wc -l
# Should output: 1
```

### Fix All Environments

```bash
# Quality/Test
pass show TrendMicro/quality_test/api_token | head -1 | pass insert -e TrendMicro/quality_test/api_token

# Production US
pass show TrendMicro/production/api_token | head -1 | pass insert -e TrendMicro/production/api_token

# Production AU
pass show TrendMicro/production_au/api_token | head -1 | pass insert -e TrendMicro/production_au/api_token

# Verify all are fixed
./verify_pass_tokens.sh
```

---

## Prevention

### Best Practices

1. ✅ **Always use:** `echo "TOKEN" | pass insert -e path/to/token`
2. ✅ **Verify storage:** Run `pass show path | wc -l` (should be 1)
3. ✅ **Run verification:** Use `./verify_pass_tokens.sh` after storing tokens
4. ✅ **Document process:** Share this guide with your team

### What NOT to Do

1. ❌ **Never manually type/paste** metadata like "Issued:", "Expires:", "Status:"
2. ❌ **Never use multi-line insert** for tokens (single-line only)
3. ❌ **Never skip verification** after storing credentials
4. ❌ **Never assume** token is correct without checking line count

---

## Symptoms of the Problem

If you see any of these errors, you likely have multi-line tokens:

### HTTP 401 Errors
```
✗ Failed to fetch clusters (HTTP 401)
```

### Invalid Header Errors
```
requests.exceptions.InvalidHeader: Invalid leading whitespace, reserved character(s), or return character(s) in header value
```

### Authentication Failures
```
API returned 401 Unauthorized even with valid token
```

---

## Testing After Fix

### 1. Verify Token Format

```bash
# Check line count (should be 1)
pass show TrendMicro/production/api_token | wc -l

# Check token starts correctly
pass show TrendMicro/production/api_token | head -c 50
# Should output: eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQiO
```

### 2. Test API Call

```bash
# Quick API test
python3 << 'EOF'
import subprocess
import requests

token = subprocess.check_output(['pass', 'show', 'TrendMicro/production/api_token'], text=True).strip()
url = "https://api.xdr.trendmicro.com/beta/containerSecurity/kubernetesClusters"
headers = {"Authorization": f"Bearer {token}"}

response = requests.get(url, headers=headers)
print(f"Status: {response.status_code}")
print("✅ SUCCESS" if response.status_code == 200 else f"❌ FAILED: {response.text}")
EOF
```

### 3. Run Full Scan

```bash
# Test complete workflow
python3 get_container_vulnerabilities.py --environment production --summary-only

# Should show clusters and vulnerabilities without errors
```

---

## Reference

### Related Documentation
- [Setup Guide](SETUP_GUIDE.md) - Initial setup instructions
- [Pass Guide](PASS_GUIDE.md) - Complete Pass documentation
- [Troubleshooting](SETUP_GUIDE.md#troubleshooting) - Common issues

### Quick Commands

```bash
# Store token correctly
echo "TOKEN" | pass insert -e TrendMicro/ENV/api_token

# Verify token
pass show TrendMicro/ENV/api_token | wc -l

# Fix broken token
pass show TrendMicro/ENV/api_token | head -1 | pass insert -e TrendMicro/ENV/api_token

# Check all tokens
./verify_pass_tokens.sh
```

---

## Summary

**The Rule:**
> API tokens in Pass MUST be stored as a single line with NO extra metadata.

**The Command:**
> `echo "TOKEN_VALUE" | pass insert -e TrendMicro/ENVIRONMENT/api_token`

**The Verification:**
> `./verify_pass_tokens.sh`

Follow these three steps and you'll never have token authentication issues again!

---

**Last Updated:** January 23, 2026 | **Version:** 4.0
