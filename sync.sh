#!/usr/bin/env bash
# Rebuild the Docker image from current source and restart the container.
# Use after pulling updates or making local changes.
# Mac/Linux: ./sync.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH. Install Docker Desktop (Mac/Windows) and try again." >&2
  exit 1
fi

COMPOSE_CMD="docker compose"
if ! $COMPOSE_CMD version >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
  if ! command -v docker-compose >/dev/null 2>&1; then
    echo "Error: docker compose is not available. Install Docker Desktop and try again." >&2
    exit 1
  fi
fi

echo "Building image from current source..."
if ! $COMPOSE_CMD build; then
  echo "Error: docker compose build failed." >&2
  exit 1
fi

echo "Recreating and starting container..."
if ! $COMPOSE_CMD up -d --force-recreate; then
  echo "Error: docker compose up failed." >&2
  exit 1
fi

echo "Done. API is available at http://localhost:8080"
