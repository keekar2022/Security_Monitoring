# Password Store (pass) Usage Guide

**Last Updated:** January 20, 2026  
**Password Manager:** `pass` v1.7.4  
**Encryption:** GPG 2.4.9  
**Documentation:** https://www.passwordstore.org/

---

## Overview

Your Trend Micro API credentials are now securely stored using `pass`, the standard Unix password manager. All credentials are encrypted with GPG and stored in `~/.password-store`.

### Why `pass`?

- ✅ **GPG Encrypted** - Military-grade encryption (RSA 4096-bit)
- ✅ **Git Versioned** - Track all changes to credentials
- ✅ **Simple & Unix-like** - Uses standard tools and file structure
- ✅ **No Cloud Dependency** - Everything stored locally
- ✅ **Cross-platform** - Works on macOS, Linux, BSD, Windows (WSL)
- ✅ **Extensible** - Many plugins and integrations available

---

## Quick Reference

### List All Passwords

```bash
pass
# or
pass ls
```

**Output:**
```
Password Store
└── TrendMicro/
    ├── production/
    │   ├── api_base_url
    │   ├── api_token
    │   └── business_id
    └── quality_test/
        ├── api_base_url
        ├── api_token
        └── business_id
```

### View a Password/Secret

```bash
# View QTE API token with all metadata
pass TrendMicro/quality_test/api_token

# View production API token
pass TrendMicro/production/api_token

# View just the business ID
pass TrendMicro/quality_test/business_id

# View API base URL
pass TrendMicro/production/api_base_url
```

### Copy to Clipboard (Safer!)

```bash
# Copy QTE API token to clipboard (clears after 45 seconds)
pass -c TrendMicro/quality_test/api_token

# Copy production API token
pass -c TrendMicro/production/api_token
```

**Note:** The `-c` flag copies only the first line (the actual token) to clipboard, which is perfect for our multi-line format.

### Search for Passwords

```bash
# Search for production entries
pass grep production

# Search for a specific business ID
pass grep "ec367c49"
```

---

## Stored Credentials Structure

Each API token entry contains:

```
<API_TOKEN>                          ← Line 1: The actual JWT token
URL: <API_BASE_URL>                  ← Line 2: API endpoint
Portal: <PORTAL_URL>                 ← Line 3: Portal URL
Business Name: <NAME>                ← Line 4: Business name
Business ID: <ID>                    ← Line 5: Business ID
Region: <REGION_NAME> (<CODE>)       ← Line 6: Region info
Token Type: Bearer                   ← Line 7: Token type
Issued: <DATE>                       ← Line 8: Issue date
Expires: <DATE>                      ← Line 9: Expiry date
Status: active                       ← Line 10: Status
```

### Quality & Test (QTE) Environment

```bash
pass TrendMicro/quality_test/api_token
# Full token: eyJ0eXAiOiJKV1QiLCJhbGc...
# URL: https://api.au.xdr.trendmicro.com
# Business: Adobe Managed Services QTE
# Region: Australia (au)
```

### Production Environment

```bash
pass TrendMicro/production/api_token
# Full token: eyJ0eXAiOiJKV1QiLCJhbGc...
# URL: https://api.xdr.trendmicro.com
# Business: Adobe-AMS-Global
# Region: United States (us)
```

---

## Common Operations

### Extract Just the Token (First Line)

```bash
# Get QTE token (first line only)
pass TrendMicro/quality_test/api_token | head -1

# Get production token (first line only)
pass TrendMicro/production/api_token | head -1
```

### Use in Scripts

```bash
#!/bin/bash

# Extract QTE API token for use in API calls
QTE_TOKEN=$(pass TrendMicro/quality_test/api_token | head -1)
QTE_API_URL=$(pass TrendMicro/quality_test/api_base_url)

# Make API call
curl -H "Authorization: Bearer $QTE_TOKEN" \
     "$QTE_API_URL/v3.0/containerSecurity/groups"
```

### Python Integration

```python
import subprocess

def get_api_token(environment='quality_test'):
    """Get API token from pass"""
    path = f"TrendMicro/{environment}/api_token"
    result = subprocess.run(
        ['pass', path],
        capture_output=True,
        text=True,
        check=True
    )
    # Return first line (the token)
    return result.stdout.split('\n')[0]

def get_api_base_url(environment='quality_test'):
    """Get API base URL from pass"""
    path = f"TrendMicro/{environment}/api_base_url"
    result = subprocess.run(
        ['pass', path],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout.strip()

# Usage
token = get_api_token('production')
api_url = get_api_base_url('production')
print(f"Token: {token[:30]}...")
print(f"API URL: {api_url}")
```

---

## Managing Credentials

### Add New Credentials

```bash
# Add a single-line secret
pass insert TrendMicro/staging/business_id

# Add multi-line secret (token with metadata)
pass insert -m TrendMicro/staging/api_token
# Then paste your token and metadata, press Ctrl+D when done
```

### Edit Existing Credentials

```bash
# Edit QTE token (opens in your default editor)
pass edit TrendMicro/quality_test/api_token

# Edit production token
pass edit TrendMicro/production/api_token
```

### Update/Rotate API Tokens

```bash
# When you get a new token from Trend Micro portal:

# Option 1: Edit existing entry
pass edit TrendMicro/production/api_token
# Replace the token on line 1, update Issued/Expires dates

# Option 2: Insert new token (overwrites)
pass insert -m -f TrendMicro/production/api_token
# Paste new token and metadata
```

### Delete Credentials

```bash
# Remove a single entry
pass rm TrendMicro/staging/api_token

# Remove entire environment
pass rm -r TrendMicro/staging
```

---

## Git Integration

Your password store is git-versioned. Every change creates a commit.

### View History

```bash
# See all password store changes
pass git log --oneline

# See detailed history of a specific entry
pass git log -p TrendMicro/production/api_token.gpg
```

### Undo Changes

```bash
# Revert to previous version
pass git revert HEAD

# View what changed in last commit
pass git show
```

### Backup to Remote Repository

```bash
# Add remote repository (e.g., private git server)
pass git remote add origin git@your-server.com:password-store.git

# Push changes
pass git push -u origin master

# Pull changes (if syncing across machines)
pass git pull
```

**⚠️ IMPORTANT:** Only push to a **private** git repository that you control. Never push to public repositories!

---

## Security Best Practices

### 1. **Never Share Your GPG Key**

Your password store is encrypted with your GPG key. Keep it safe!

```bash
# Backup your GPG key (store securely offline)
gpg --export-secret-keys -a "mkesharw@local" > ~/gpg-backup-private.asc
gpg --export -a "mkesharw@local" > ~/gpg-backup-public.asc

# Store these files on an encrypted USB drive, not in cloud storage!
```

### 2. **Use Clipboard for Sensitive Operations**

```bash
# GOOD: Copy to clipboard, clears after 45 seconds
pass -c TrendMicro/production/api_token

# AVOID: Displaying token on screen (can be shoulder-surfed)
pass TrendMicro/production/api_token
```

### 3. **Clear Your Shell History**

If you've displayed tokens in terminal:

```bash
# Clear current session history
history -c

# Or edit history file
vi ~/.zsh_history  # or ~/.bash_history
```

### 4. **Lock Your Computer**

Since the GPG key has no passphrase (for convenience), always lock your computer when away.

### 5. **Regular Backups**

```bash
# Backup entire password store
cp -r ~/.password-store ~/backups/password-store-$(date +%Y%m%d)

# Or use git to push to private remote
pass git push
```

---

## Token Rotation Schedule

Both tokens expire on **2027-01-19** (364 days remaining).

### Rotation Timeline

| Date | Action | Environment |
|------|--------|-------------|
| **April 19, 2026** | Rotate tokens (90-day policy) | QTE + Production |
| **July 18, 2026** | Rotate tokens | QTE + Production |
| **October 16, 2026** | Rotate tokens | QTE + Production |
| **January 14, 2027** | Rotate tokens (before expiry) | QTE + Production |

### Rotation Procedure

1. **Generate new token in Trend Micro Portal:**
   - QTE: https://portal.au.xdr.trendmicro.com/
   - Production: https://portal.xdr.trendmicro.com/

2. **Update password store:**
   ```bash
   pass edit TrendMicro/quality_test/api_token
   # Update line 1 (token), line 8 (issued), line 9 (expires)
   ```

3. **Verify new token works:**
   ```bash
   # Test API call with new token
   curl -H "Authorization: Bearer $(pass TrendMicro/quality_test/api_token | head -1)" \
        "https://api.au.xdr.trendmicro.com/v3.0/containerSecurity/groups" | jq
   ```

4. **Update config/deployment_config.json if still in use**

5. **Commit change:**
   ```bash
   pass git log -1  # Verify automatic commit
   ```

---

## Advanced Features

### Generate Random Passwords

```bash
# Generate 32-character password
pass generate TrendMicro/test/random_password 32

# Generate without symbols
pass generate -n TrendMicro/test/random_password 32
```

### QR Code Generation

```bash
# Generate QR code for a token (useful for mobile apps)
pass TrendMicro/quality_test/api_token | qrencode -t UTF8
```

### Extensions

Explore pass extensions at: https://www.passwordstore.org/#extensions

Popular extensions:
- `pass-otp` - One-time password (2FA) support
- `pass-update` - Easy password update flow
- `pass-import` - Import from other password managers

---

## Integration with Config Loader

You can optionally update `lib/config_loader.py` to read from `pass` instead of `deployment_config.json`:

```python
def get_api_token_from_pass(self, environment: Optional[str] = None) -> str:
    """Get API token from pass instead of deployment_config.json"""
    env = environment if environment else self.get_current_environment()
    result = subprocess.run(
        ['pass', f'TrendMicro/{env}/api_token'],
        capture_output=True,
        text=True,
        check=True
    )
    # Return first line (the token)
    return result.stdout.split('\n')[0]
```

---

## Troubleshooting

### "gpg: decryption failed: No secret key"

Your GPG key is missing. Restore from backup:

```bash
gpg --import ~/gpg-backup-private.asc
gpg --import ~/gpg-backup-public.asc
gpg --edit-key "mkesharw@local"
# Type: trust
# Select: 5 (ultimate)
# Type: quit
```

### "pass: TrendMicro/... is not in the password store"

Check if the entry exists:

```bash
pass ls
pass grep <search-term>
```

### Clipboard Not Working

macOS clipboard requires `pbcopy`/`pbpaste` (should be built-in). If issues:

```bash
# Verify clipboard works
echo "test" | pbcopy
pbpaste
```

### Git Sync Conflicts

```bash
# Pull latest changes
pass git pull

# If conflicts, resolve manually
cd ~/.password-store
git status
# Resolve conflicts, then:
git add .
git commit -m "Resolved merge conflict"
```

---

## Comparison: deployment_config.json vs pass

| Feature | deployment_config.json | pass |
|---------|------------------|------|
| **Encryption** | ❌ Plain text (even with 600 perms) | ✅ GPG encrypted |
| **Version Control** | ⚠️ Git-ignored (no history) | ✅ Full git history |
| **Portability** | ✅ JSON (easy to parse) | ⚠️ Requires pass + GPG |
| **Security** | ⚠️ File permissions only | ✅ Encryption + permissions |
| **Clipboard** | ❌ Manual copy | ✅ Auto-clear clipboard |
| **Audit Trail** | ❌ None | ✅ Git commits |
| **Backup** | ⚠️ Manual | ✅ Git push/pull |
| **Multi-user** | ❌ Difficult | ✅ Multiple GPG keys |
| **Cloud Sync** | ❌ Risky | ✅ Encrypted git repo |

---

## Migration Path

You have **three options**:

### Option 1: Dual System (Recommended Initially)

- Keep `config/deployment_config.json` for scripts (current)
- Use `pass` for manual access and rotation
- Gradually migrate scripts to use `pass`

### Option 2: Full Migration

- Update `lib/config_loader.py` to read from `pass`
- Remove `config/deployment_config.json`
- All scripts use encrypted storage

### Option 3: Keep Current System

- Use `pass` only for backup/reference
- Continue using `deployment_config.json`
- Manually sync when rotating tokens

---

## Commands Cheat Sheet

```bash
# List all passwords
pass

# View password (with metadata)
pass TrendMicro/quality_test/api_token

# Copy to clipboard (45s auto-clear)
pass -c TrendMicro/quality_test/api_token

# Get just the token (first line)
pass TrendMicro/quality_test/api_token | head -1

# Add new password (single line)
pass insert TrendMicro/new/secret

# Add new password (multi-line)
pass insert -m TrendMicro/new/secret

# Edit existing password
pass edit TrendMicro/quality_test/api_token

# Delete password
pass rm TrendMicro/old/secret

# Search passwords
pass grep "production"

# Show git history
pass git log --oneline

# Push to remote git
pass git push

# Pull from remote git
pass git pull

# Generate random password (32 chars)
pass generate TrendMicro/test/random 32
```

---

## Additional Resources

- **Official Documentation:** https://www.passwordstore.org/
- **Man Page:** `man pass`
- **Git Integration:** `man pass-git`
- **GPG Documentation:** https://gnupg.org/documentation/
- **Community Forum:** #pass on Libera.Chat IRC
- **GitHub Repository:** https://github.com/zx2c4/password-store

---

## Support

For issues with `pass`:
- Check the man page: `man pass`
- Visit: https://www.passwordstore.org/

For GPG issues:
- Check the man page: `man gpg`
- Visit: https://gnupg.org/

For Trend Micro API issues:
- See: `docs/CONFIGURATION.md`

---

**Last Updated:** January 20, 2026  
**Maintained By:** Mukesh Kesharwani  
**Password Store Version:** 1.7.4  
**GPG Version:** 2.4.9
