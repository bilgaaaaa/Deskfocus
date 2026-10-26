#!/usr/bin/env bash
# Builds Deskfocus, signs it with your Developer ID, notarizes it with Apple and packages build/Deskfocus-<version>.dmg.
# One-time setup is described in README › "Share Deskfocus as a download".
set -euo pipefail

readonly NOTARY_PROFILE="${NOTARY_PROFILE:-deskfocus-notary}"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_DIR="$ROOT_DIR/build"
readonly ARCHIVE_PATH="$BUILD_DIR/Deskfocus.xcarchive"
readonly EXPORT_DIR="$BUILD_DIR/export"
readonly STAGING_DIR="$BUILD_DIR/dmg"
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
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
    || fail "No 'Developer ID Application' certificate found. Create it in Xcode › Settings › Accounts › Manage Certificates."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "Notary credentials '$NOTARY_PROFILE' not found. Run: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id YOUR_APPLE_ID --team-id $TEAM_ID"
echo "Team $TEAM_ID, notary profile $NOTARY_PROFILE"

log "Generating Xcode project"
xcodegen generate --quiet

log "Archiving (Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
xcodebuild archive \
    -project Deskfocus.xcodeproj \
    -scheme Deskfocus \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -quiet

log "Exporting with Developer ID signing"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    -quiet

APP_PATH="$EXPORT_DIR/Deskfocus.app"
[[ -d "$APP_PATH" ]] || fail "Export did not produce Deskfocus.app."
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_PATH="$BUILD_DIR/Deskfocus-$VERSION.dmg"
codesign --verify --deep --strict "$APP_PATH" || fail "Signature check failed for Deskfocus.app."
echo "Signed Deskfocus $VERSION"

log "Creating disk image"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "Deskfocus" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" -quiet
codesign --sign "Developer ID Application" --timestamp "$DMG_PATH"

log "Notarizing with Apple (usually 1-5 minutes)"
RESULT_JSON="$BUILD_DIR/notary-result.json"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$RESULT_JSON"
STATUS="$(plutil -extract status raw -o - "$RESULT_JSON")"
if [[ "$STATUS" != "Accepted" ]]; then
    SUBMISSION_ID="$(plutil -extract id raw -o - "$RESULT_JSON")"
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" || true
    fail "Notarization finished with status '$STATUS'. Apple's log is printed above."
fi

log "Stapling the notarization ticket"
xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"

log "Done: $DMG_PATH"
open -R "$DMG_PATH"
