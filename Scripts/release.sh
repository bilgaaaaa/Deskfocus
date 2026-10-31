#!/usr/bin/env bash
# Builds Deskfocus, signs it with your Developer ID, notarizes it with Apple, packages build/Deskfocus-<version>.dmg
# and writes the signed update feed build/updates/appcast.xml. With --publish it also creates the GitHub release.
# One-time setup is described in README › "Share Deskfocus as a download" and "In-app updates".
set -euo pipefail

readonly GITHUB_REPO="bilgaaaaa/deskfocus"
readonly FEED_URL="https://github.com/$GITHUB_REPO/releases/latest/download/appcast.xml"

readonly NOTARY_PROFILE="${NOTARY_PROFILE:-deskfocus-notary}"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_DIR="$ROOT_DIR/build"
readonly ARCHIVE_PATH="$BUILD_DIR/Deskfocus.xcarchive"
readonly EXPORT_DIR="$BUILD_DIR/export"
readonly STAGING_DIR="$BUILD_DIR/dmg"
readonly SECRETS_FILE="$ROOT_DIR/Config/Secrets.xcconfig"
readonly PACKAGES_DIR="$BUILD_DIR/SourcePackages"
readonly UPDATES_DIR="$BUILD_DIR/updates"

PUBLISH=false
for argument in "$@"; do
    case "$argument" in
        --publish) PUBLISH=true ;;
        *) printf 'Usage: %s [--publish]\n' "$0" >&2; exit 2 ;;
    esac
done

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
grep -Eq '^ *SUPublicEDKey: *"[^"]+"' project.yml \
    || fail "SUPublicEDKey is empty in project.yml, so this build could never update itself. Run: ./Scripts/update-keys.sh"
if [[ "$PUBLISH" == true ]]; then
    command -v gh >/dev/null || fail "--publish needs the GitHub CLI. Run: brew install gh && gh auth login"
    gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not signed in. Run: gh auth login"
fi
echo "Team $TEAM_ID, notary profile $NOTARY_PROFILE, publish $PUBLISH"

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
    -clonedSourcePackagesDirPath "$PACKAGES_DIR" \
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
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
DMG_PATH="$BUILD_DIR/Deskfocus-$VERSION.dmg"
codesign --verify --deep --strict "$APP_PATH" || fail "Signature check failed for Deskfocus.app."
echo "Signed Deskfocus $VERSION ($BUILD_NUMBER)"

log "Checking the build number against the published feed"
# Sparkle only offers a build with a higher CFBundleVersion, so an unchanged number would never reach anyone.
PUBLISHED_BUILD="$(curl -fsSL "$FEED_URL" 2>/dev/null | sed -n 's|.*<sparkle:version>\([^<]*\)</sparkle:version>.*|\1|p' | sort -V | tail -1 || true)"
if [[ -n "$PUBLISHED_BUILD" ]]; then
    [[ "$(printf '%s\n%s\n' "$PUBLISHED_BUILD" "$BUILD_NUMBER" | sort -V | tail -1)" == "$BUILD_NUMBER" && "$PUBLISHED_BUILD" != "$BUILD_NUMBER" ]] \
        || fail "Build $BUILD_NUMBER is not newer than the published build $PUBLISHED_BUILD. Raise CURRENT_PROJECT_VERSION in project.yml."
    echo "Published build $PUBLISHED_BUILD, new build $BUILD_NUMBER"
else
    echo "No published feed yet; this is the first release with in-app updates."
fi

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

log "Writing the signed update feed"
GENERATE_APPCAST="$(find "$PACKAGES_DIR/artifacts" -path '*/bin/generate_appcast' -type f | head -1)"
[[ -x "$GENERATE_APPCAST" ]] || fail "Sparkle's generate_appcast was not found in $PACKAGES_DIR/artifacts."
mkdir -p "$UPDATES_DIR"
cp "$DMG_PATH" "$UPDATES_DIR/"
# Signs the DMG with the key from your Keychain; the feed lists only this version, which is all Sparkle needs.
"$GENERATE_APPCAST" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/" \
    --link "https://github.com/$GITHUB_REPO/releases" \
    --full-release-notes-url "https://github.com/$GITHUB_REPO/releases/tag/v$VERSION" \
    "$UPDATES_DIR"
APPCAST_PATH="$UPDATES_DIR/appcast.xml"
grep -q 'sparkle:edSignature' "$APPCAST_PATH" || fail "appcast.xml has no signature. Run ./Scripts/update-keys.sh on this Mac first."
echo "Feed: $APPCAST_PATH"

if [[ "$PUBLISH" == true ]]; then
    log "Publishing GitHub release v$VERSION"
    gh release create "v$VERSION" "$DMG_PATH" "$APPCAST_PATH" \
        --repo "$GITHUB_REPO" \
        --title "Deskfocus $VERSION" \
        --generate-notes
    log "Done: installed copies will offer $VERSION within a day, or now from Settings › General › Check Now"
else
    log "Done: $DMG_PATH"
    echo "To ship it as an update, attach both files to a new GitHub release named v$VERSION:"
    echo "  $DMG_PATH"
    echo "  $APPCAST_PATH"
    echo "or run the script again with --publish."
    open -R "$DMG_PATH"
fi
