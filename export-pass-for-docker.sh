#!/usr/bin/env bash
# Export your host pass store (TrendMicro/*) into pass-export/ so the Docker image
# can have its own password store. Run once on a Mac/Linux with pass and tokens.
# Then: docker compose build. The image will contain the store; no host mount needed.
#
# Usage:
#   ./export-pass-for-docker.sh        # Copy TrendMicro/* from host pass into pass-export/
#   ./export-pass-for-docker.sh --empty   # Create empty pass-export (for Windows or no pass yet)
#
# Requires: pass, gpg (on host, for non--empty run).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
EXPORT_DIR="$SCRIPT_DIR/pass-export"
EMPTY=false
[[ "${1:-}" == "--empty" ]] && EMPTY=true

PASS_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

# Create export dir and use it as the store for the rest of the script
mkdir -p "$EXPORT_DIR"
export PASSWORD_STORE_DIR="$EXPORT_DIR"
export GNUPGHOME="$EXPORT_DIR/.gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME" "$EXPORT_DIR"

# Generate a new GPG key for the Docker image (batch, no passphrase)
if [[ ! -f "$EXPORT_DIR/.gpg-id" ]]; then
  echo "Generating GPG key for Docker image store..."
  gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key "Docker Monitoring API <noreply@local>" default default 0
  KEY_ID=$(gpg --list-keys --with-colons "Docker Monitoring API" 2>/dev/null | awk -F: '$1=="pub" {print $5}')
  if [[ -z "$KEY_ID" ]]; then
    echo "Error: Could not get new key id" >&2
    exit 1
  fi
  pass init "$KEY_ID"
  echo "Initialized pass store in $EXPORT_DIR with key $KEY_ID"
fi

if [[ "$EMPTY" == true ]]; then
  echo "Empty store created at $EXPORT_DIR. Run: docker compose build"
  echo "Use config/deployment_config.json for credentials, or run this script without --empty on a machine with pass."
  exit 0
fi

# Copy all TrendMicro/* entries from host pass into pass-export
if [[ ! -d "$PASS_DIR" ]]; then
  echo "Error: Host password store not found at $PASS_DIR. Use --empty to create an empty store." >&2
  exit 1
fi

if ! command -v pass >/dev/null 2>&1; then
  echo "Error: pass is required. Install: brew install pass" >&2
  exit 1
fi

# List TrendMicro/* entries from the *host* store (temporarily use host store)
host_store_pass() {
  PASSWORD_STORE_DIR="$PASS_DIR" pass "$@"
}

count=0
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  if host_store_pass show "$entry" &>/dev/null; then
    value="$(host_store_pass show "$entry")"
    echo "$value" | PASSWORD_STORE_DIR="$EXPORT_DIR" pass insert -m "$entry" --force
    echo "  Copied: $entry"
    ((count++)) || true
  fi
done < <(find "$PASS_DIR" -type f -path "$PASS_DIR/TrendMicro/*" -name "*.gpg" 2>/dev/null | sed "s|^$PASS_DIR/||;s|\.gpg$||" | sort -u)

echo "Done. Copied $count TrendMicro entries into $EXPORT_DIR"
echo "Run: docker compose build"
echo "Then start with: docker compose up -d (USE_PASS=true is default when store has entries)"
