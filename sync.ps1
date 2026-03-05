# Rebuild the Docker image from current source and restart the container.
# Use after pulling updates or making local changes.
# Windows: .\sync.ps1

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "docker is not installed or not in PATH. Install Docker Desktop and try again."
    exit 1
}

# Prefer "docker compose" (Docker Desktop); fallback to "docker-compose"
$UseComposePlugin = $false
try {
    docker compose version 2>$null | Out-Null
    $UseComposePlugin = $true
} catch { }

if (-not $UseComposePlugin -and -not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Error "docker compose is not available. Install Docker Desktop and try again."
    exit 1
}

Write-Host "Building image from current source..."
if ($UseComposePlugin) {
    docker compose build
} else {
    docker-compose build
}
if ($LASTEXITCODE -ne 0) {
    Write-Error "docker compose build failed."
    exit 1
}

Write-Host "Recreating and starting container..."
if ($UseComposePlugin) {
    docker compose up -d --force-recreate
} else {
    docker-compose up -d --force-recreate
}
if ($LASTEXITCODE -ne 0) {
    Write-Error "docker compose up failed."
    exit 1
}

Write-Host "Done. API is available at http://localhost:8080"
