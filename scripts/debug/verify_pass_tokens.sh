#!/usr/bin/env bash
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Verify Trend Micro API tokens in pass are single-line (avoids HTTP 401).
# Usage: ./scripts/debug/verify_pass_tokens.sh

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Pass Token Storage Verification                                   ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

if ! command -v pass &> /dev/null; then
    echo "❌ Error: 'pass' command not found. Please install it first:"
    echo "   macOS: brew install pass"
    echo "   Linux: sudo apt-get install pass"
    exit 1
fi

if ! pass ls &> /dev/null; then
    echo "❌ Error: Pass is not initialized. Run:"
    echo "   pass init your.email@company.com"
    exit 1
fi

echo "Checking token storage for all environments..."
echo ""

ENVIRONMENTS=("production" "production_au" "quality_test" "AMS_QTE")
ISSUE_COUNT=0
SUCCESS_COUNT=0

for env in "${ENVIRONMENTS[@]}"; do
    TOKEN_PATH="TrendMicro/$env/api_token"
    
    if pass show "$TOKEN_PATH" &> /dev/null; then
        LINE_COUNT=$(pass show "$TOKEN_PATH" | wc -l | tr -d ' ')
        TOKEN_LENGTH=$(pass show "$TOKEN_PATH" | head -1 | wc -c | tr -d ' ')
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Environment: $env"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if [ "$LINE_COUNT" -eq 1 ]; then
            echo "  Status:       ✅ OK"
            echo "  Lines:        $LINE_COUNT (correct)"
            echo "  Token length: $((TOKEN_LENGTH - 1)) characters"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "  Status:       ❌ PROBLEM DETECTED"
            echo "  Lines:        $LINE_COUNT (should be 1)"
            echo "  Issue:        Extra metadata lines found!"
            echo ""
            echo "  ⚠️  This will cause HTTP 401 authentication errors!"
            echo ""
            echo "  Fix with this command:"
            echo "  pass show $TOKEN_PATH | head -1 | pass insert -e $TOKEN_PATH"
            ISSUE_COUNT=$((ISSUE_COUNT + 1))
        fi
        echo ""
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Environment: $env"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Status:       ⚪ NOT CONFIGURED"
        echo "  Token:        Not found in Pass"
        echo ""
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Correct:  $SUCCESS_COUNT"
echo "  Issues:   $ISSUE_COUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$ISSUE_COUNT" -gt 0 ]; then
    echo "❌ $ISSUE_COUNT token(s) need to be fixed!"
    echo ""
    echo "Run the suggested commands above to fix the issues."
    echo "After fixing, run this script again to verify."
    exit 1
else
    echo "✅ All configured tokens are stored correctly!"
    echo ""
    echo "You can now run vulnerability scans without authentication errors."
    echo "Example: ./go/bin/get_container_vulnerabilities"
    exit 0
fi
