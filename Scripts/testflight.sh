#!/usr/bin/env bash
# Builds the iPhone app, signs it for the App Store and uploads it to App Store Connect for TestFlight.
# One-time setup is described in README › "Share the iPhone app with TestFlight".
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_DIR="$ROOT_DIR/build/testflight"
readonly ARCHIVE_PATH="$BUILD_DIR/DeskfocusiOS.xcarchive"
readonly EXPORT_DIR="$BUILD_DIR/export"
readonly SECRETS_FILE="$ROOT_DIR/Config/Secrets.xcconfig"

log() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# Reads "KEY = value" from Secrets.xcconfig.
read_setting() {
    { grep -E "^[[:space:]]*$1[[:space:]]*=" "$SECRETS_FILE" || true; } | tail -1 | cut -d '=' -f 2- | tr -d '[:space:]'
}

cd "$ROOT_DIR"

log "Checking setup"
[[ -f "$SECRETS_FILE" ]] || fail "Config/Secrets.xcconfig is missing. Copy Config/Secrets.xcconfig.example first."
TEAM_ID="$(read_setting DESKFOCUS_TEAM_ID)"
[[ -n "$TEAM_ID" ]] || fail "DESKFOCUS_TEAM_ID is empty in Config/Secrets.xcconfig."
command -v xcodegen >/dev/null || fail "XcodeGen is not installed. Run: brew install xcodegen"
# Every upload needs a build number App Store Connect hasn't seen; the UTC time always grows.
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
echo "Team $TEAM_ID, build $BUILD_NUMBER"

log "Generating Xcode project"
xcodegen generate --quiet

log "Archiving the iPhone app (Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
xcodebuild archive \
    -project Deskfocus.xcodeproj \
    -scheme DeskfocusiOS \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    -quiet

log "Signing for the App Store and uploading to App Store Connect"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    || fail "Upload failed. Check that the app exists in App Store Connect (see README) and that Xcode › Settings › Accounts is signed in."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE_PATH/Info.plist")"
log "Done: Deskfocus $VERSION ($BUILD_NUMBER) is uploaded. App Store Connect › TestFlight shows it after processing, usually 5-15 minutes."
