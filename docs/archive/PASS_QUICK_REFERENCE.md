# Pass Integration - Quick Reference Card

**Last Updated:** January 20, 2026

---

## 🔐 Credential Source

**All scripts now use `pass` (GPG-encrypted) by default!**

```bash
# Verify which source is being used
python3 lib/config_loader.py

# Check credential source programmatically
python3 -c "from lib.config_loader import TrendMicroConfig; print(TrendMicroConfig().get_credential_source())"
```

---

## 📋 Quick Commands

### View Credentials

```bash
# List all stored credentials
pass

# View QTE API token
pass TrendMicro/quality_test/api_token

# View production API token
pass TrendMicro/production/api_token

# Copy to clipboard (safer - auto-clears after 45 seconds)
pass -c TrendMicro/quality_test/api_token
```

### Run Scripts (Auto-uses pass)

```bash
# Container vulnerabilities
python3 get_container_vulnerabilities.py

# Endpoint statistics
python3 get_endpoint_stats.py

# Container vulnerabilities
python3 get_container_vulnerabilities.py --environment production

# All scripts automatically use pass - no changes needed!
```

### Force Credential Source

```bash
# Force use of pass
USE_PASS=true python3 get_container_vulnerabilities.py

# Force use of deployment_config.json
USE_PASS=false python3 get_container_vulnerabilities.py
```

---

## 🔄 Token Rotation

```bash
# 1. Get new token from Trend Micro portal
# 2. Update in pass
pass edit TrendMicro/quality_test/api_token

# 3. Verify it works
python3 -c "from lib.config_loader import TrendMicroConfig; print(TrendMicroConfig().get_api_token()[:50])"

# 4. Test with API call
python3 get_container_vulnerabilities.py --summary-only
```

---

## 🔒 Security Best Practices

```bash
# ALWAYS backup your GPG key (CRITICAL!)
gpg --export-secret-keys -a "mkesharw@local" > ~/gpg-backup-private.asc

# Use clipboard (safer than displaying on screen)
pass -c TrendMicro/production/api_token

# Check git history of password store
pass git log --oneline

# Push to private git repo (optional backup)
pass git remote add origin git@your-server.com:passwords.git
pass git push
```

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| `pass: command not found` | `brew install pass` |
| Entry not found | `pass TrendMicro/quality_test/api_token` to verify |
| GPG key missing | Restore from backup: `gpg --import ~/gpg-backup-private.asc` |
| Scripts using deployment_config.json | Verify: `python3 -c "from lib.config_loader import TrendMicroConfig; print(TrendMicroConfig().is_using_pass())"` |

---

## 📚 Full Documentation

- **Pass Integration:** `docs/PASS_INTEGRATION.md` - Complete integration guide
- **Pass Usage:** `docs/PASSWORD_STORE_GUIDE.md` - Complete pass commands
- **Configuration:** `docs/CONFIGURATION.md` - Multi-environment setup

---

## ✅ What Was Changed

- **lib/config_loader.py** - Enhanced with pass integration (automatic)
- **All scripts** - Now use pass by default (no code changes required)
- **Credentials** - Stored encrypted in `~/.password-store/`
- **Fallback** - Automatic fallback to `deployment_config.json` if pass unavailable

---

**Quick Test:**
```bash
python3 lib/config_loader.py
# Should show: "🔐 Credential Source: pass (GPG-encrypted)"
```

**Need Help?** Read `docs/PASS_INTEGRATION.md` for complete guide.
