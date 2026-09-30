#!/bin/zsh
# Builds, signs with Developer ID, notarizes and staples Matrix, then publishes it as a GitHub release.
#
#   scripts/release.sh 1.0.1 "Release notes in Markdown"
#
# One-time setup:
#   - A "Developer ID Application" certificate in the login keychain (Xcode › Settings › Accounts › Manage Certificates).
#   - Notary credentials stored under the profile name below:
#       xcrun notarytool store-credentials matrix --apple-id <apple id> --team-id <team id>
#   - GitHub CLI signed in: gh auth login
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: scripts/release.sh <version> [notes]}
NOTES=${2:-"Matrix $VERSION"}
PROFILE=matrix
IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
[[ -n $IDENTITY ]] || { echo "No Developer ID Application certificate found." >&2; exit 1; }
TEAM=$(sed -n 's/.*(\([A-Z0-9]*\))$/\1/p' <<< "$IDENTITY")
echo "Signing as: $IDENTITY"

APP=build/dist/Matrix.app
ZIP=build/dist/Matrix.zip
rm -rf build/dist && mkdir -p build/dist

# Release build without the git-ignored third-party art, signed with Developer ID and a secure timestamp.
command -v xcodegen >/dev/null && xcodegen generate --quiet
xcodebuild -project Matrix.xcodeproj -scheme Matrix -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/public -quiet clean build \
  EXCLUDE_LOCAL_ASSETS=YES MARKETING_VERSION="$VERSION" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
ditto build/public/Build/Products/Release/Matrix.app "$APP"
[[ -z $(find "$APP" -name '*.jpg') ]] || { echo "Third-party art found in the bundle; aborting." >&2; exit 1; }
codesign --verify --deep --strict "$APP"
# Apple rejects apps carrying the debugging entitlement.
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q get-task-allow; then
  echo "The app still has com.apple.security.get-task-allow; aborting." >&2; exit 1
fi

# Notarize, staple the ticket so the app opens offline too, and zip the stapled app.
ditto -c -k --keepParent "$APP" "$ZIP"
# notarytool exits 0 even when Apple rejects the upload, so check the status explicitly.
RESULT=$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait --output-format json)
STATUS=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["status"])' "$RESULT")
if [[ $STATUS != Accepted ]]; then
  ID=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$RESULT")
  echo "Notarization $STATUS. Log:" >&2
  xcrun notarytool log "$ID" --keychain-profile "$PROFILE" >&2
  exit 1
fi
echo "Notarization accepted."
xcrun stapler staple "$APP"
rm "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute -v "$APP"

SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
gh release create "v$VERSION" "$ZIP" --title "Matrix $VERSION" --notes "$NOTES

SHA-256 of \`Matrix.zip\`: \`$SHA\`"
echo "Published v$VERSION"
