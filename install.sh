#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

rm -rf pkgroot
mkdir -p pkgroot/usr/local/bin
cp .build/release/agent-signal pkgroot/usr/local/bin/agent-signal
xattr -c pkgroot/usr/local/bin/agent-signal
chmod 755 pkgroot/usr/local/bin/agent-signal

rm -f agent-signal.pkg
pkgbuild \
    --root pkgroot \
    --scripts pkg-scripts \
    --identifier com.arturious.agent-signal \
    --version 1.0 \
    --install-location / \
    agent-signal.pkg

rm -rf pkgroot

echo "Installing (requires sudo)..."
sudo installer -pkg agent-signal.pkg -target /
