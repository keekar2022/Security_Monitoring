# Getting Started - Trend Micro Vision One API Integration

**Version:** 2.1  
**Last Updated:** January 20, 2026  
**Region:** Australia (au)

---

## Overview

This project provides automated scripts for Trend Micro Vision One API integration, specifically for:
- **Kubernetes Bootstrap Token Generation** - Automate cluster provisioning
- **Container Security Vulnerability Scanning** - Track vulnerabilities across all groups
- **Endpoint Statistics** - Monitor endpoint inventory

---

## Prerequisites

### 1. System Requirements
- Python 3.7 or higher
- Bash shell (for shell scripts)
- Internet connectivity to Trend Micro API

### 2. API Access
- Trend Micro Vision One account
- API token with appropriate permissions
- Business ID: `c732de94-ce77-4540-89d4-7f5c2c2032f6`
- Portal: https://portal.au.xdr.trendmicro.com/

---

## Quick Setup (5 Minutes)

### Step 1: Install Dependencies

```bash
cd /path/to/Integration-API-Dev
pip3 install -r requirements.txt
```

**Required packages:**
- `requests` - HTTP library for API calls
- Python 3 standard library (json, datetime, argparse)

### Step 2: Configure API Credentials

Create the credentials file:

```bash
mkdir -p config
cat > config/deployment_config.json << 'EOF'
{
  "api_token": "YOUR_API_TOKEN_HERE",
  "region": "au"
}
EOF

chmod 600 config/deployment_config.json
```

**Get your API token:**
1. Log in to https://portal.au.xdr.trendmicro.com/
2. Navigate to: Administration → API Keys
3. Generate new token or copy existing token
4. Paste into `config/deployment_config.json`

### Step 3: Verify Configuration

```bash
python3 -c "from lib.config_loader import TrendMicroConfig; c = TrendMicroConfig(); print('✅ Configuration loaded successfully')"
```

---

## Available Scripts

### 1. Container Vulnerability Scanner

**Purpose:** Get vulnerability counts for all Container Security groups

```bash
# Show all groups
python3 get_container_vulnerabilities.py

# Specific group
python3 get_container_vulnerabilities.py --group-name "AMS_EKS_Stage_01"

# Quiet mode for automation
python3 get_container_vulnerabilities.py --quiet
```

**Output:** `container_vulnerability_report.txt` (appends historical data)

### 2. Kubernetes Bootstrap Automation

### 2. Endpoint Statistics

**Purpose:** Get endpoint inventory statistics

```bash
python3 get_endpoint_stats.py
```

**Note:** Currently under investigation due to API endpoint access issues.

---

## Configuration Files

### Directory Structure

```
config/
├── deployment_config.json        # API credentials (REQUIRED)
├── api_endpoints.json      # API endpoint definitions
└── environments.json       # Environment configurations
```

### API Endpoints Configuration

The `config/api_endpoints.json` file defines all available API endpoints:
- Kubernetes cluster management
- Container Security vulnerabilities
- Device/endpoint management
- Alerts and threats
- Cloud posture management

**No changes needed** - Pre-configured for Trend Micro Vision One API.

### Environment Configuration

The `config/environments.json` file defines environment settings:
- **production** - Live environment (default)
- **staging** - Testing environment
- **development** - Development environment

Each environment has:
- Region-specific API base URLs
- Logging configurations
- Rate limit settings

---

## Usage Examples

### Daily Vulnerability Monitoring

```bash
# Add to crontab for daily reports at 8 AM
0 8 * * * cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --quiet
```

### Weekly Fresh Report

```bash
# Start fresh report every Monday
0 8 * * 1 cd /path/to/Integration-API-Dev && python3 get_container_vulnerabilities.py --overwrite --quiet
```

---

## Troubleshooting

### Issue: "Configuration file not found"

**Solution:**
```bash
# Check if credentials file exists
ls -la config/deployment_config.json

# If missing, create it
mkdir -p config
cat > config/deployment_config.json << 'EOF'
{
  "api_token": "YOUR_TOKEN",
  "region": "au"
}
EOF
chmod 600 config/deployment_config.json
```

### Issue: "API token has expired"

**Solution:**
1. Go to https://portal.au.xdr.trendmicro.com/
2. Administration → API Keys
3. Generate new token
4. Update `config/deployment_config.json`

### Issue: "No Kubernetes clusters found"

**Solution:**
- Verify clusters are registered in Container Security
- Check API token has Container Security permissions
- Ensure clusters are in the correct region (Australia)

### Issue: "Permission denied" on log files

**Solution:**
```bash
# Scripts now log to user home directory by default
# No sudo required
```

---

## Best Practices

### Security
- ✅ Keep `config/deployment_config.json` with 600 permissions
- ✅ Never commit credentials to git
- ✅ Rotate API tokens regularly (every 90 days)
- ✅ Use separate tokens for production vs development

### Automation
- ✅ Use `--quiet` flag for cron jobs
- ✅ Redirect output to log files for audit trails
- ✅ Set up alerts for critical vulnerabilities
- ✅ Archive old reports monthly

### Monitoring
- ✅ Review vulnerability reports weekly
- ✅ Track trends over time (use append mode)
- ✅ Alert on increases in critical/high vulnerabilities
- ✅ Verify API token expiry dates

---

## Next Steps

1. **Configure Credentials** - Set up your API token
2. **Run First Scan** - Execute vulnerability scanner
3. **Review Output** - Check the generated report
4. **Set Up Automation** - Add cron jobs for regular scans
5. **Customize** - Adjust scripts for your specific needs

---

## Support Resources

**Portal:** https://portal.au.xdr.trendmicro.com/  
**API Documentation:** https://automation.trendmicro.com/xdr/api-beta/  
**Support:** https://success.trendmicro.com/

**Business Details:**
- Name: Adobe Managed Services QTE
- ID: c732de94-ce77-4540-89d4-7f5c2c2032f6
- Region: Australia (au)

---

## Related Documentation

- **[Container Security Guide](CONTAINER_SECURITY.md)** - Complete vulnerability scanning guide
- **[Configuration Guide](CONFIGURATION.md)** - Detailed configuration reference
- **[Best Practices](BEST_PRACTICES.md)** - Development and security best practices
- **[API Reference](API_REFERENCE.md)** - API endpoint documentation

---

**Ready to start?** Configure your credentials and run your first vulnerability scan!

```bash
python3 get_container_vulnerabilities.py
```
