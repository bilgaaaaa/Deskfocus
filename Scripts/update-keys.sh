#!/usr/bin/env bash
# One-time setup for in-app updates: creates the update signing key in your Keychain (or reuses it) and writes its public half to project.yml.
# Safe to run again; it never replaces an existing key. Details in README › "In-app updates".
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PACKAGES_DIR="$ROOT_DIR/build/SourcePackages"
readonly PROJECT_SPEC="$ROOT_DIR/project.yml"

log() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

cd "$ROOT_DIR"
command -v xcodegen >/dev/null || fail "XcodeGen is not installed. Run: brew install xcodegen"

log "Fetching Sparkle's tools"
xcodegen generate --quiet
xcodebuild -resolvePackageDependencies -project Deskfocus.xcodeproj -clonedSourcePackagesDirPath "$PACKAGES_DIR" -quiet
GENERATE_KEYS="$(find "$PACKAGES_DIR/artifacts" -path '*/bin/generate_keys' -type f | head -1)"
[[ -x "$GENERATE_KEYS" ]] || fail "generate_keys not found in $PACKAGES_DIR/artifacts."

log "Creating or reading the signing key in your Keychain"
# Creates the key on the first run; later runs just find the existing one.
"$GENERATE_KEYS" >/dev/null
PUBLIC_KEY="$("$GENERATE_KEYS" -p | tr -d '[:space:]')"
[[ -n "$PUBLIC_KEY" ]] || fail "Could not read the public key from the Keychain."

log "Writing the public key to project.yml"
grep -q '^ *SUPublicEDKey:' "$PROJECT_SPEC" || fail "SUPublicEDKey line not found in project.yml."
sed -i '' -E "s|^( *SUPublicEDKey:).*|\1 \"$PUBLIC_KEY\"|" "$PROJECT_SPEC"
echo "SUPublicEDKey: $PUBLIC_KEY"

log "Done. Commit project.yml, and back up the private key somewhere safe:"
echo "  $GENERATE_KEYS -x ~/Desktop/deskfocus-update-key.txt"
echo "Without it, installed copies can never be updated again."
