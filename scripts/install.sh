#!/bin/zsh
# Builds a Release copy of Matrix and installs it to /Applications, replacing and restarting any running copy.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null && xcodegen generate --quiet
xcodebuild -project Matrix.xcodeproj -scheme Matrix -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath build/release -quiet build

pkill -x Matrix 2>/dev/null && sleep 1 || true
rm -rf /Applications/Matrix.app
ditto build/release/Build/Products/Release/Matrix.app /Applications/Matrix.app
open /Applications/Matrix.app
echo "Matrix installed to /Applications and started."
