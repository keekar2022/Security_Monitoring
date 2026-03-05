#!/bin/bash

# Build script for Trend Micro Integration API - Go Implementation
# Builds all Go tools and API server

set -e  # Exit on error

echo "=================================="
echo "Building Go Tools & API Server"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track success/failure
FAILURES=0

# Function to print colored status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        FAILURES=$((FAILURES + 1))
    fi
}

# Go Build - Use the Makefile
echo -e "${BLUE}Building Go implementation...${NC}"
cd go
if make deps && make build; then
    print_status 0 "Go build successful"
else
    print_status 1 "Go build failed"
    cd ..
    exit 1
fi
cd ..
echo ""

# Summary
echo "=================================="
echo "Build Summary"
echo "=================================="
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}All builds successful!${NC}"
    echo ""
    echo "Available tools:"
    echo "  API Availability:    ./go/bin/check_api_availability --help"
    echo "  Container Vulns:     ./go/bin/get_container_vulnerabilities --help"
    echo "  Endpoint Stats:      ./go/bin/get_endpoint_stats --help"
    echo "  Endpoint Vulns:      ./go/bin/get_endpoint_vulnerabilities --help"
    echo "  API Server:          ./go/bin/api-server --help"
else
    echo -e "${RED}$FAILURES build(s) failed${NC}"
    exit 1
fi
