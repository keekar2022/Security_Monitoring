#!/bin/bash
################################################################################
# Version Bumping Script
# Automates version updates across all project files
#
# Author: Mukesh Kesharwani (mkesharw@adobe.com)
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load current version
if [[ ! -f "VERSION" ]]; then
    echo -e "${RED}ERROR: VERSION file not found${NC}"
    exit 1
fi

# Do not `source` VERSION — values like PROJECT_NAME contain unquoted spaces on macOS.
CURRENT_VERSION="$(grep -E '^VERSION=' VERSION | head -1 | cut -d= -f2- | tr -d '[:space:]')"
if [[ -z "$CURRENT_VERSION" ]]; then
    echo -e "${RED}ERROR: VERSION= not found in VERSION file${NC}" >&2
    exit 1
fi

# Functions
usage() {
    cat << EOF
${BLUE}Version Bumping Script${NC}

USAGE:
    $(basename "$0") [major|minor|patch] "changelog message"

ARGUMENTS:
    major       Bump major version (x.0.0) - Breaking changes
    minor       Bump minor version (0.x.0) - New features
    patch       Bump patch version (0.0.x) - Bug fixes
    message     Changelog entry description (required)

EXAMPLES:
    $(basename "$0") patch "Fix token validation error"
    $(basename "$0") minor "Add multi-cluster support"
    $(basename "$0") major "Breaking: New API endpoint structure"

CURRENT VERSION: ${GREEN}$CURRENT_VERSION${NC}

EOF
    exit 0
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

confirm() {
    local message="$1"
    read -p "$message [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

bump_version() {
    local bump_type="$1"
    local version="$2"
    
    IFS='.' read -r -a parts <<< "$version"
    local major="${parts[0]}"
    local minor="${parts[1]}"
    local patch="${parts[2]}"
    
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

update_version_file() {
    local new_version="$1"
    local build_date=$(date +%Y-%m-%d)
    
    log_info "Updating VERSION file: $CURRENT_VERSION → $new_version"
    
    # Update VERSION file
    sed -i.bak "s/^VERSION=.*/VERSION=$new_version/" VERSION
    sed -i.bak "s/^BUILD_DATE=.*/BUILD_DATE=$build_date/" VERSION
    
    rm -f VERSION.bak
    
    log_info "✓ VERSION file updated"
}

update_monitoring_dashboard_version() {
    local new_version="$1"
    if [[ -f monitoring_dashboard/__init__.py ]]; then
        log_info "Updating monitoring_dashboard/__init__.py"
        sed -i.bak "s/^__version__ = .*/__version__ = \"$new_version\"/" monitoring_dashboard/__init__.py
        rm -f monitoring_dashboard/__init__.py.bak
        log_info "✓ monitoring_dashboard/__init__.py updated"
    fi
    if [[ -f scripts/write_version.py ]]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 scripts/write_version.py || log_warning "write_version.py failed (non-fatal)"
        fi
    fi
}

_changelog_file() {
    if [[ -f docs/CHANGELOG.md ]]; then
        echo "docs/CHANGELOG.md"
    else
        echo "CHANGELOG.md"
    fi
}

update_changelog() {
    local new_version="$1"
    local message="$2"
    local date=$(date +%Y-%m-%d)
    local changelog
    changelog="$(_changelog_file)"

    log_info "Updating $changelog"

    if [[ ! -f "$changelog" ]]; then
        cat > "$changelog" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
    fi
    
    # Create new entry
    local entry="## [$new_version] - $date

$message

"
    
    # Insert after header (after first 5 lines)
    {
        head -n 5 "$changelog"
        echo "$entry"
        tail -n +6 "$changelog"
    } > "${changelog}.tmp"

    mv "${changelog}.tmp" "$changelog"

    log_info "✓ $changelog updated"
}

update_readme() {
    local new_version="$1"
    
    if [[ -f "README.md" ]]; then
        log_info "Checking README.md for version references"
        
        # Update version badges or references if they exist
        if grep -q "Version.*$CURRENT_VERSION" README.md; then
            sed -i.bak "s/Version.*$CURRENT_VERSION/Version $new_version/g" README.md
            rm -f README.md.bak
            log_info "✓ README.md updated"
        else
            log_warning "No version references found in README.md"
        fi
    fi
}

create_git_commit() {
    local new_version="$1"
    local message="$2"
    local bump_type="$3"
    
    log_info "Creating git commit"
    
    # Check if we're in a git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warning "Not a git repository, skipping commit"
        return
    fi
    
    # Add changed files
    git add VERSION CHANGELOG.md docs/CHANGELOG.md README.md monitoring_dashboard/__init__.py monitoring_dashboard/_version.py 2>/dev/null || true
    
    # Create commit
    local commit_msg
    case "$bump_type" in
        major)
            commit_msg="chore: v$new_version - MAJOR RELEASE: $message"
            ;;
        minor)
            commit_msg="chore: v$new_version - $message"
            ;;
        patch)
            commit_msg="chore: v$new_version - $message"
            ;;
    esac
    
    if git commit -m "$commit_msg"; then
        log_info "✓ Git commit created"
        
        # Ask to create tag
        if confirm "Create git tag v$new_version?"; then
            if git tag -a "v$new_version" -m "Version $new_version: $message"; then
                log_info "✓ Git tag v$new_version created"
                log_info "  Push with: git push && git push --tags"
            fi
        fi
    else
        log_warning "Git commit failed or no changes to commit"
    fi
}

show_summary() {
    local old_version="$1"
    local new_version="$2"
    local message="$3"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           VERSION BUMP COMPLETED SUCCESSFULLY            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Old Version: ${RED}$old_version${NC}"
    echo -e "  New Version: ${GREEN}$new_version${NC}"
    echo -e "  Change:      $message"
    echo ""
    echo -e "${YELLOW}Files Updated:${NC}"
    echo -e "  • VERSION"
    echo -e "  • CHANGELOG.md"
    [[ -f "README.md.bak" ]] && echo -e "  • README.md"
    echo ""
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${YELLOW}Git Status:${NC}"
        git status --short
        echo ""
    fi
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Review changes: git diff"
    echo -e "  2. Push changes: git push && git push --tags"
    echo -e "  3. Update any deployment configurations"
    echo ""
}

# Main execution
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        usage
    fi
    
    local bump_type="$1"
    local message="$2"
    
    # Validate bump type
    if [[ ! "$bump_type" =~ ^(major|minor|patch)$ ]]; then
        log_error "Invalid bump type. Must be major, minor, or patch"
        usage
    fi
    
    # Calculate new version
    local new_version=$(bump_version "$bump_type" "$CURRENT_VERSION")
    
    # Show summary and confirm
    echo ""
    echo -e "${BLUE}Version Bump Summary:${NC}"
    echo -e "  Current: ${RED}$CURRENT_VERSION${NC}"
    echo -e "  New:     ${GREEN}$new_version${NC}"
    echo -e "  Type:    $bump_type"
    echo -e "  Message: $message"
    echo ""
    
    if ! confirm "Proceed with version bump?"; then
        log_warning "Version bump cancelled"
        exit 0
    fi
    
    # Execute updates
    update_version_file "$new_version"
    update_monitoring_dashboard_version "$new_version"
    update_changelog "$new_version" "$message"
    update_readme "$new_version"
    create_git_commit "$new_version" "$message" "$bump_type"
    show_summary "$CURRENT_VERSION" "$new_version" "$message"
    
    log_info "Done! 🚀"
}

# Run main
main "$@"

