#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== MetalNX GitHub Push Assistant ==="
echo "Working directory: $REPO_ROOT"

# Ensure gh is on PATH
export PATH="/opt/homebrew/bin:$PATH"

if ! command -v gh &>/dev/null; then
    echo "Installing GitHub CLI via Homebrew..."
    brew install gh
fi

# Check authentication status
if ! gh auth status &>/dev/null; then
    echo ""
    echo "-> Logging into GitHub via browser device flow..."
    echo "   (Select: GitHub.com -> HTTPS -> Yes -> Login with a web browser)"
    gh auth login --hostname github.com -p https -w
fi

echo ""
echo "✓ Authenticated with GitHub as: $(gh api user --jq '.login')"

USER_LOGIN="$(gh api user --jq '.login')"
echo ""
echo "Where would you like to push?"
echo "  1) Push directly to origin (seedds/nxnative)"
echo "  2) Push to your personal GitHub account (${USER_LOGIN}/MetalNX)"
echo "  3) Push to your personal fork (${USER_LOGIN}/nxnative)"
echo ""
read -p "Select option [1-3] (default 2): " CHOICE
CHOICE="${CHOICE:-2}"

case "$CHOICE" in
    1)
        echo "Pushing to origin main (seedds/nxnative)..."
        git push origin main
        ;;
    2)
        echo "Ensuring personal repository '${USER_LOGIN}/MetalNX' exists on GitHub..."
        if ! gh repo view "${USER_LOGIN}/MetalNX" &>/dev/null; then
            gh repo create "${USER_LOGIN}/MetalNX" --public --description "Next-gen Apple Silicon graphics tweaker and 1-click Switch-to-Mac port studio"
        fi
        git remote remove personal 2>/dev/null || true
        git remote add personal "https://github.com/${USER_LOGIN}/MetalNX.git"
        echo "Pushing to https://github.com/${USER_LOGIN}/MetalNX.git..."
        git push -u personal main
        echo ""
        echo "✓ Successfully pushed to: https://github.com/${USER_LOGIN}/MetalNX"
        ;;
    3)
        echo "Ensuring personal fork '${USER_LOGIN}/nxnative' exists on GitHub..."
        gh repo fork seedds/nxnative --clone=false 2>/dev/null || true
        git remote remove fork 2>/dev/null || true
        git remote add fork "https://github.com/${USER_LOGIN}/nxnative.git"
        echo "Pushing to https://github.com/${USER_LOGIN}/nxnative.git..."
        git push -u fork main
        echo ""
        echo "✓ Successfully pushed to: https://github.com/${USER_LOGIN}/nxnative"
        ;;
    *)
        echo "Invalid selection."
        exit 1
        ;;
esac

echo ""
echo "=== Push Complete! ==="
