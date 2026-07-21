#!/bin/bash
# One-line installer: downloads the prebuilt .pkg from this repo and installs it.
# Usage: curl -fsSL https://raw.githubusercontent.com/arturious/caps-signal-for-agents/main/install-remote.sh | bash
set -euo pipefail

PKG_URL="https://raw.githubusercontent.com/arturious/caps-signal-for-agents/main/agent-signal.pkg"
TMP_PKG="$(mktemp -t agent-signal).pkg"

echo "Downloading agent-signal.pkg..."
curl -fsSL "$PKG_URL" -o "$TMP_PKG"

echo "Installing (requires sudo)..."
sudo installer -pkg "$TMP_PKG" -target /

rm -f "$TMP_PKG"

echo ""
echo "Installed. Claude Code hooks were wired up automatically."
echo "Restart your Claude Code session (/exit, then run claude again) to pick them up."
