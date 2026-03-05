# Pass & Credentials

Single reference for credential storage: Pass (password-store), token rules, and helper scripts. Replaces PASS_GUIDE, TOKEN_STORAGE_GUIDE, and archive Pass docs.

---

## Overview

**Pass** is a GPG-encrypted password manager. This project uses it for API tokens and related secrets. Set `USE_PASS=true` (or rely on auto-detect) so tools read from Pass instead of plain config files.

### Benefits

- GPG-encrypted (no plain-text tokens on disk)
- Scriptable; works with all project tools
- Use `update-pass-credential.sh` and `verify_pass_tokens.sh` for updates and checks

---

## Installation

```bash
# macOS
brew install pass gnupg

# Debian/Ubuntu
sudo apt-get install pass gnupg

# Verify
pass version && gpg --version
```

---

## Initial Setup

```bash
# 1. Create GPG key (if needed)
gpg --gen-key

# 2. Init pass with your key
pass init "your-email@example.com"

# 3. Store Trend Micro tokens (see Token Storage Rules below)
echo "YOUR_TOKEN" | pass insert -e TrendMicro/production/api_token
pass insert TrendMicro/production/api_base_url   # paste URL when prompted
```

---

## Token Storage Rules (Critical)

API tokens **must** be stored as a **single line**. Extra lines cause HTTP 401 or invalid header errors.

### Correct

```bash
echo "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9..." | pass insert -e TrendMicro/production/api_token
```

### Wrong

Storing with metadata (Issued:, Expires:, etc.) causes scripts to send invalid `Authorization` headers. Always use `echo "TOKEN" | pass insert -e PATH`.

### Fix an existing entry

```bash
pass show TrendMicro/production/api_token | head -1 | pass insert -e TrendMicro/production/api_token
pass show TrendMicro/production/api_token | wc -l   # should output 1
```

---

## Storing Credentials

```bash
# API token (single line)
echo "TOKEN" | pass insert -e TrendMicro/ENVIRONMENT/api_token

# Base URL (interactive)
pass insert TrendMicro/production/api_base_url

# Multiple environments
pass insert TrendMicro/quality_test/api_token
pass insert TrendMicro/production_au/api_token
```

---

## Helper Scripts

### update-pass-credential.sh

Interactive update/add of pass entries. Run from project root. Reads from stdin (paste, then Ctrl+D).

```bash
./update-pass-credential.sh
```

### verify_pass_tokens.sh

Checks that tokens are single-line and correctly formatted.

```bash
./verify_pass_tokens.sh
```

### In Docker

Scripts are in `/app/`. Use:

```bash
docker compose exec api /app/verify_pass_tokens.sh
docker compose exec -it api /app/update-pass-credential.sh
```

---

## Retrieving Credentials

```bash
pass show TrendMicro/production/api_token
pass show TrendMicro/production/api_token | head -1   # script-safe single line
```

---

## Docker: Image-Owned Store

The Docker image has its own pass store (no host mount). To populate it once from your laptop:

1. On a Mac/Linux with pass: `./export-pass-for-docker.sh` then `docker compose build`.
2. Tokens are baked into the image; no re-entry on Windows or other machines.

See README Docker section and [QUICK_START_GUIDE.md](QUICK_START_GUIDE.md).

---

## Command Reference

| Command | Description |
|--------|-------------|
| `pass init <gpg-id>` | Initialize store |
| `pass insert -e PATH` | Insert (echo mode, single line) |
| `pass show PATH` | Show decrypted value |
| `pass ls` | List entries |
| `pass rm PATH` | Remove entry |

---

## Troubleshooting

- **pass not found** – Install pass and gpg; or set `USE_PASS=false` to use config files.
- **HTTP 401 / Invalid header** – Ensure token is single-line: `pass show PATH | wc -l` should be 1; fix with `head -1 \| pass insert -e PATH`.
- **Password store is empty** – Run `pass init` with your GPG key id.

---

[Back to INDEX](INDEX.md)
