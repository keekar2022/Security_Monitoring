# Pass (Password Store) - Complete Guide

**Version:** 4.0 | **Last Updated:** January 21, 2026  
**Author:** Mukesh Kesharwani (mkesharw@adobe.com)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Why Use Pass](#why-use-pass)
3. [Installation](#installation)
4. [Initial Setup](#initial-setup)
5. [Storing Credentials](#storing-credentials) (includes [update-pass-credential.sh](#update-credentials-with-the-helper-script))
6. [Retrieving Credentials](#retrieving-credentials)
7. [Managing Credentials](#managing-credentials)
8. [Integration with Scripts](#integration-with-scripts)
9. [Command Reference](#command-reference)
10. [Backup & Recovery](#backup--recovery)
11. [Troubleshooting](#troubleshooting)
12. [Security Best Practices](#security-best-practices)

---

## Overview

**Pass** (password-store) is a simple, secure, GPG-encrypted password manager. All scripts in this project use Pass by default for retrieving sensitive credentials instead of plain-text configuration files.

### Key Benefits

- ✅ **GPG-encrypted** - RSA 4096-bit encryption
- ✅ **Simple** - Command-line interface
- ✅ **Git-friendly** - Version control your password store
- ✅ **Cross-platform** - Works on macOS, Linux, Windows (WSL)
- ✅ **Scriptable** - Easy integration with automation
- ✅ **Standard** - Uses standard Unix tools (GPG, Git)

### Security Model

```
Plain Text API Token
     ↓
GPG Encryption (4096-bit RSA)
     ↓
~/.password-store/TrendMicro/production/api_token.gpg
     ↓
Pass CLI retrieves and decrypts on-the-fly
     ↓
Scripts use credentials (never written to disk unencrypted)
```

---

## Why Use Pass

### Before Pass (Security Risks)

```
config/deployment_config.json (600 permissions)
{
  "api_token": "eyJ0eXAiOiJKV1QiLCJhbGciOi..."  ← Plain text!
}
```

**Risks:**
- ❌ Plain-text credentials on disk
- ❌ Accidental commits to Git
- ❌ Visible in backups
- ❌ Accessible if file permissions change
- ❌ No audit trail for access

### After Pass (Secure)

```
~/.password-store/TrendMicro/production/api_token.gpg  ← Encrypted!
```

**Benefits:**
- ✅ GPG-encrypted (requires passphrase to decrypt)
- ✅ Cannot be accidentally committed (outside project directory)
- ✅ Git history for changes
- ✅ Access logged by GPG
- ✅ Works across all environments

---

## Installation

### macOS (Homebrew)

```bash
# Install Pass
brew install pass

# Install GPG (if not already installed)
brew install gnupg

# Verify installation
pass version
gpg --version
```

### Linux (Debian/Ubuntu)

```bash
# Update package list
sudo apt-get update

# Install Pass and GPG
sudo apt-get install pass gnupg

# Verify installation
pass version
gpg --version
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Install Pass and GPG
sudo yum install pass gnupg
# or
sudo dnf install pass gnupg

# Verify installation
pass version
gpg --version
```

### Windows (WSL)

```bash
# In WSL terminal
sudo apt-get update
sudo apt-get install pass gnupg

# Verify installation
pass version
```

---

## Initial Setup

### Step 1: Generate GPG Key

If you don't already have a GPG key:

```bash
# Generate new key
gpg --full-generate-key

# Follow interactive prompts:
```

**Prompts and Recommended Answers:**

1. **Please select what kind of key you want:**
   - Select: `(1) RSA and RSA` (default)
   - Press Enter

2. **What keysize do you want?**
   - Enter: `4096`
   - Press Enter

3. **Please specify how long the key should be valid:**
   - Enter: `0` (key does not expire) or `1y` (1 year)
   - Press Enter
   - Confirm: `y`

4. **Real name:**
   - Enter: `Your Name`

5. **Email address:**
   - Enter: `your.email@company.com`

6. **Comment:**
   - Enter: `Trend Micro API Credentials` (optional)

7. **Passphrase:**
   - Enter a strong passphrase (you'll need this every time)
   - **IMPORTANT:** Remember this passphrase!

**Output:**
```
pub   rsa4096 2026-01-21 [SC]
      ABCD1234EFGH5678IJKL9012MNOP3456QRST7890
uid                      Your Name <your.email@company.com>
sub   rsa4096 2026-01-21 [E]
```

### Step 2: Initialize Pass

```bash
# List your GPG keys to get the key ID
gpg --list-keys

# Output shows your key ID (long hex string)
# pub   rsa4096 2026-01-21 [SC]
#       ABCD1234EFGH5678IJKL9012MNOP3456QRST7890  ← This is your key ID

# Initialize pass with your key ID
pass init ABCD1234EFGH5678IJKL9012MNOP3456QRST7890

# Or use your email
pass init your.email@company.com
```

**Output:**
```
Password store initialized for ABCD1234EFGH5678IJKL9012MNOP3456QRST7890
```

### Step 3: Verify Initialization

```bash
# List password store (should be empty initially)
pass ls

# Output:
# Password Store
```

---

## Storing Credentials

### Directory Structure

Organize credentials hierarchically:

```
~/.password-store/
└── TrendMicro/
    ├── production/
    │   ├── api_token.gpg
    │   ├── business_id.gpg
    │   └── api_base_url.gpg
    ├── production_au/
    │   ├── api_token.gpg
    │   ├── business_id.gpg
    │   └── api_base_url.gpg
    └── quality_test/
        ├── api_token.gpg
        ├── business_id.gpg
        └── api_base_url.gpg
```

### Store a Credential

```bash
# Basic syntax
pass insert path/to/credential

# Example: Store production API token
pass insert TrendMicro/production/api_token

# You'll be prompted:
# Enter password for TrendMicro/production/api_token: [paste token here]
# Retype password for TrendMicro/production/api_token: [paste again]
```

**Tips:**
- Password is hidden while typing (security feature)
- Use Ctrl+V or Cmd+V to paste
- Press Enter after each paste
- Token must match exactly both times

### ⚠️ CRITICAL: Proper Token Storage

**ALWAYS use this command format for API tokens to avoid issues:**

```bash
# Correct method - Use echo with pipe (single line only)
echo "TOKEN_VALUE_HERE" | pass insert -e TrendMicro/ENVIRONMENT/api_token

# Example with actual token:
echo "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQ..." | pass insert -e TrendMicro/production/api_token
```

**Why this matters:**
- ✅ Ensures **ONLY** the token is stored (single line)
- ✅ Prevents multiline metadata from being added
- ✅ Avoids HTTP 401 "Invalid header" errors

**❌ NEVER store tokens with extra lines like:**
```
eyJ0eXAi...TOKEN...F_U
Issued: 2026-01-20      ← These extra lines cause API failures!
Expires: 2027-01-20
Status: active
```

**If you accidentally added metadata:**
```bash
# Fix it by keeping only the first line
pass show TrendMicro/production/api_token | head -1 | pass insert -e TrendMicro/production/api_token

# Verify it's clean (should output "1")
pass show TrendMicro/production/api_token | wc -l
```

### Store Multiple Credentials

```bash
# Store all production credentials
pass insert TrendMicro/production/api_token
pass insert TrendMicro/production/business_id
pass insert TrendMicro/production/api_base_url

# Store quality/test credentials
pass insert TrendMicro/quality_test/api_token
pass insert TrendMicro/quality_test/business_id
pass insert TrendMicro/quality_test/api_base_url

# Store production AU credentials
pass insert TrendMicro/production_au/api_token
pass insert TrendMicro/production_au/business_id
pass insert TrendMicro/production_au/api_base_url
```

### Store Multiline Credentials

```bash
# For multiline data (like certificates)
pass insert -m TrendMicro/production/certificate

# Paste multiple lines, then press Ctrl+D when done
```

### Update credentials with the helper script

The project provides **`update-pass-credential.sh`** in the repository root to update or add pass entries interactively without typing full `pass insert` commands. Credentials are read from stdin (paste, then Ctrl+D) and are not written to disk in plain text.

**Location:** `./update-pass-credential.sh` (run from the project root)

**Requirements:** `pass` and `gpg` (e.g. `brew install pass` on macOS).

**What it does:**

1. Lists all existing pass entries (from `$PASSWORD_STORE_DIR` or `~/.password-store`).
2. Lets you choose an entry by number to update, or option **0** to add a new entry (you type the full path, e.g. `TrendMicro/production/api_token`).
3. Prompts you to paste your secret; you can use:
   - **AWS-style:** `aws_access_key_id=...`, `aws_secret_access_key=...`, `aws_session_token=...`
   - **Generic key=value** lines (first `=` separates key and value).
   - **Plain lines** (stored as-is, e.g. a single API token).
4. Writes the result into pass with `pass insert -m <entry> --force` (multi-line, overwriting the existing entry).

**Usage:**

```bash
# From the project root
./update-pass-credential.sh
```

**Example flow:**

```text
Stored credentials (pass entries):

  1) TrendMicro/production/api_token
  2) TrendMicro/quality_test/api_token
  0) New entry
  q) Exit

Which entry do you want to update? (1-2, 0=new, q=exit): 1

Paste your secret/credentials below (key=value lines or freeform). When done, press Ctrl+D:

eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...
^D
Done. Pass entry updated: TrendMicro/production/api_token
Verify with: pass show "TrendMicro/production/api_token"
```

**Security notes:**

- Input is read only from stdin and passed directly to `pass insert`; the script does not write credentials to temporary files.
- Use option **0** to create a new entry if the path does not exist yet.
- To verify after an update: `pass show "TrendMicro/production/api_token"` (or the path you used).

---

## Retrieving Credentials

### Show a Credential

```bash
# Basic retrieval
pass show TrendMicro/production/api_token

# Shorter form (optional)
pass TrendMicro/production/api_token

# Output: Shows the decrypted credential
# eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...
```

### Copy to Clipboard

```bash
# Copy to clipboard (auto-clears after 45 seconds)
pass -c TrendMicro/production/api_token

# Output:
# Copied TrendMicro/production/api_token to clipboard. Will clear in 45 seconds.
```

**Note:** Clipboard is automatically cleared after 45 seconds for security.

### Show First N Characters

```bash
# Show only first 50 characters (useful for verification)
pass show TrendMicro/production/api_token | head -c 50

# Output:
# eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJjaWQiO
```

### Use in Scripts

```bash
# Assign to variable
API_TOKEN=$(pass show TrendMicro/production/api_token)

# Use in command
curl -H "Authorization: Bearer $(pass show TrendMicro/production/api_token)" \
     https://api.xdr.trendmicro.com/...

# Python example
python3 << EOF
import subprocess
token = subprocess.check_output(['pass', 'show', 'TrendMicro/production/api_token']).decode().strip()
print(f"Token length: {len(token)}")
EOF
```

---

## Managing Credentials

### List All Credentials

```bash
# List all passwords
pass ls

# Output (tree view):
# Password Store
# └── TrendMicro
#     ├── production
#     │   ├── api_base_url
#     │   ├── api_token
#     │   └── business_id
#     ├── production_au
#     │   ├── api_base_url
#     │   ├── api_token
#     │   └── business_id
#     └── quality_test
#         ├── api_base_url
#         ├── api_token
#         └── business_id
```

### Edit a Credential

```bash
# Edit existing credential
pass edit TrendMicro/production/api_token

# Opens in $EDITOR (usually vim or nano)
# Make changes, save, and quit
```

### Delete a Credential

```bash
# Delete single credential
pass rm TrendMicro/production/api_token

# You'll be prompted to confirm:
# Are you sure you would like to delete TrendMicro/production/api_token? [y/N] y
```

### Delete Folder

```bash
# Delete entire folder
pass rm -r TrendMicro/production

# Confirms before deleting
```

### Move/Rename a Credential

```bash
# Move credential to new location
pass mv TrendMicro/old_name/api_token TrendMicro/new_name/api_token

# Rename credential
pass mv TrendMicro/production/old_token TrendMicro/production/api_token
```

### Search for Credentials

```bash
# Search by name
pass find api_token

# Output:
# Search Terms: api_token
# ├── TrendMicro/production/api_token
# ├── TrendMicro/production_au/api_token
# └── TrendMicro/quality_test/api_token

# Search by pattern
pass grep "australia"
```

---

## Integration with Scripts

### Python Integration

The project's `config_loader.py` automatically uses Pass:

```python
from lib.config_loader import TrendMicroConfig

# Initialize config (automatically checks Pass)
config = TrendMicroConfig()

# Get API token (retrieves from Pass)
token = config.get_api_token('production')

# Get other credentials
base_url = config.get_api_base_url('production')
business_id = config.get_deployment_info('production')['business_id']
```

**Fallback Behavior:**
1. Try to retrieve from Pass
2. If Pass fails or not available, fall back to `config/deployment_config.json`
3. If neither works, raise error

### Manual Pass Integration

```python
import subprocess

def get_pass_credential(path):
    """Retrieve credential from Pass."""
    try:
        result = subprocess.run(
            ['pass', 'show', path],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None

# Usage
api_token = get_pass_credential('TrendMicro/production/api_token')
```

### Bash Integration

```bash
#!/bin/bash

# Get credential from Pass
API_TOKEN=$(pass show TrendMicro/production/api_token)

# Check if retrieval was successful
if [ -z "$API_TOKEN" ]; then
    echo "Error: Failed to retrieve API token from Pass"
    exit 1
fi

# Use the token
curl -H "Authorization: Bearer $API_TOKEN" \
     https://api.xdr.trendmicro.com/...
```

---

## Command Reference

### Essential Commands

| Command | Description | Example |
|---------|-------------|---------|
| `pass init <gpg-id>` | Initialize password store | `pass init user@example.com` |
| `pass insert <path>` | Insert new credential | `pass insert TrendMicro/production/api_token` |
| `pass show <path>` | Show credential | `pass show TrendMicro/production/api_token` |
| `pass ls` | List all credentials | `pass ls` |
| `pass edit <path>` | Edit credential | `pass edit TrendMicro/production/api_token` |
| `pass rm <path>` | Delete credential | `pass rm TrendMicro/production/api_token` |
| `pass -c <path>` | Copy to clipboard | `pass -c TrendMicro/production/api_token` |
| `pass find <term>` | Search credentials | `pass find api_token` |
| `pass mv <old> <new>` | Move/rename | `pass mv old/path new/path` |
| `pass git <command>` | Git operations | `pass git log` |

### Advanced Commands

```bash
# Insert multiline
pass insert -m TrendMicro/production/certificate

# Show specific line
pass show TrendMicro/production/api_token | sed -n '2p'

# Generate random password
pass generate TrendMicro/test/random_password 32

# Copy specific line to clipboard
pass show -c2 TrendMicro/production/multiline_cred

# Find and show
pass find api_token | xargs -I {} sh -c 'echo "{}:"; pass show {}'

# List with grep
pass ls | grep production

# Version info
pass version

# Help
pass help
```

---

## Backup & Recovery

### Backup Pass Store

```bash
# Method 1: Simple tar backup
tar -czf ~/pass-backup-$(date +%Y%m%d).tar.gz ~/.password-store/

# Method 2: GPG-encrypted backup
tar -czf - ~/.password-store/ | gpg -e -r your.email@company.com > ~/pass-backup-$(date +%Y%m%d).tar.gz.gpg

# Method 3: Git backup (if using pass git)
cd ~/.password-store
git remote add backup git@github.com:youruser/pass-backup-private.git
pass git push backup main
```

### Backup GPG Keys

```bash
# Backup private key (KEEP SECURE!)
gpg --export-secret-keys your.email@company.com > ~/gpg-private-key-backup.asc

# Backup public key
gpg --export your.email@company.com > ~/gpg-public-key-backup.asc

# Encrypt the private key backup
gpg -c ~/gpg-private-key-backup.asc
rm ~/gpg-private-key-backup.asc  # Remove unencrypted version
```

### Restore Pass Store

```bash
# From tar backup
tar -xzf ~/pass-backup-20260121.tar.gz -C ~/

# From GPG-encrypted backup
gpg -d ~/pass-backup-20260121.tar.gz.gpg | tar -xzf - -C ~/

# Verify restoration
pass ls
```

### Restore GPG Keys

```bash
# Import private key
gpg --import ~/gpg-private-key-backup.asc.gpg

# Import public key
gpg --import ~/gpg-public-key-backup.asc

# Trust the key
gpg --edit-key your.email@company.com
# In GPG prompt:
# gpg> trust
# Select: 5 (ultimate trust)
# gpg> quit
```

---

## Troubleshooting

### Issue 1: Pass Not Initialized

**Symptoms:**
```
Error: password store is empty. Try "pass init".
```

**Solution:**
```bash
gpg --list-keys
pass init your.email@company.com
```

### Issue 2: GPG Decryption Failed

**Symptoms:**
```
gpg: decryption failed: No secret key
```

**Solution:**
```bash
# Check if you have the correct GPG key
gpg --list-secret-keys

# If missing, restore from backup or generate new key
gpg --full-generate-key
pass init your.email@company.com
```

### Issue 3: Passphrase Prompt Every Time

**Symptoms:**
- GPG asks for passphrase on every `pass` command

**Solution:**
```bash
# Start GPG agent (macOS)
eval $(gpg-agent --daemon)

# Or add to ~/.zshrc or ~/.bashrc
echo 'export GPG_TTY=$(tty)' >> ~/.zshrc

# Increase cache time (optional)
# Edit ~/.gnupg/gpg-agent.conf
echo "default-cache-ttl 3600" >> ~/.gnupg/gpg-agent.conf
echo "max-cache-ttl 7200" >> ~/.gnupg/gpg-agent.conf

# Reload GPG agent
gpgconf --reload gpg-agent
```

### Issue 4: Permission Denied

**Symptoms:**
```
Error: Permission denied
```

**Solution:**
```bash
# Fix Pass store permissions
chmod 700 ~/.password-store
chmod 600 ~/.password-store/**/*.gpg

# Fix GPG directory permissions
chmod 700 ~/.gnupg
chmod 600 ~/.gnupg/*
```

### Issue 5: Cannot Find Pass Command

**Symptoms:**
```
command not found: pass
```

**Solution:**
```bash
# Install Pass
# macOS:
brew install pass

# Linux:
sudo apt-get install pass
```

### Issue 6: HTTP 401 Errors Despite Valid Token

**Symptoms:**
```
✗ Failed to fetch clusters (HTTP 401)
requests.exceptions.InvalidHeader: Invalid leading whitespace, reserved character(s)...
```

**Root Cause:**
Token stored in Pass has extra lines (metadata) causing invalid HTTP headers.

**Check if you have this issue:**
```bash
# Check number of lines (should be 1)
pass show TrendMicro/production/api_token | wc -l

# If output is > 1, you have extra lines!
```

**Solution:**
```bash
# Fix by keeping only the first line (the actual token)
pass show TrendMicro/production/api_token | head -1 | pass insert -e TrendMicro/production/api_token

# Verify fix (should now output "1")
pass show TrendMicro/production/api_token | wc -l

# Test API works now
python3 get_container_vulnerabilities.py --environment production --summary-only
```

**Prevent this in the future:**
Always use `echo "TOKEN" | pass insert -e` format when storing tokens.

---

## Security Best Practices

### ✅ Do's

- ✅ Use a strong GPG passphrase (16+ characters, mixed case, numbers, symbols)
- ✅ Back up your GPG keys securely
- ✅ Back up your Pass store regularly
- ✅ Use unique credentials per environment
- ✅ Set GPG key expiration (1-2 years)
- ✅ Use clipboard copy (`pass -c`) instead of displaying
- ✅ Clear terminal history after viewing credentials
- ✅ Use Git for Pass store (version control)
- ✅ Encrypt Pass backups with GPG
- ✅ Store GPG key backup offline (USB drive in safe)

### ❌ Don'ts

- ❌ Never share your GPG passphrase
- ❌ Never store GPG passphrase in plain text
- ❌ Never commit Pass store to public Git repos
- ❌ Never screenshot credentials
- ❌ Never email or chat credentials
- ❌ Never use weak GPG passphrases
- ❌ Never skip GPG key backups
- ❌ Never store Pass backup unencrypted in cloud storage
- ❌ Never share GPG private keys
- ❌ Never disable GPG passphrase caching entirely (security vs usability)

---

## Quick Reference Card

```bash
# INITIALIZATION
gpg --full-generate-key          # Create GPG key
pass init user@example.com       # Initialize Pass

# STORING
pass insert path/to/cred         # Add new credential
pass insert -m path/to/cert      # Add multiline
pass edit path/to/cred           # Edit existing

# RETRIEVING
pass show path/to/cred           # Display credential
pass -c path/to/cred             # Copy to clipboard
pass ls                          # List all

# MANAGING
pass rm path/to/cred             # Delete
pass mv old/path new/path        # Move/rename
pass find search-term            # Search

# BACKUP
tar -czf pass-backup.tar.gz ~/.password-store/
gpg --export-secret-keys > gpg-backup.asc

# INTEGRATION
API_TOKEN=$(pass show TrendMicro/production/api_token)
```

---

## Resources

- **Pass Website:** https://www.passwordstore.org/
- **Pass Man Page:** `man pass`
- **GPG Documentation:** https://gnupg.org/documentation/
- **Pass Git Repository:** https://git.zx2c4.com/password-store/

---

**Last Updated:** January 21, 2026 | **Version:** 4.0
