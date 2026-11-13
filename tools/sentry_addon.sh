#!/usr/bin/env bash
# Installs the pinned Sentry addon (getsentry/sentry-godot) into res://addons/sentry/ for the desktop exports:
# Windows x86_64, macOS universal, Linux x86_64. The addon is not committed (it is ~35 MB of native
# libraries per SDK version); the release and itch workflows run this before they import and export.
# Usage: tools/sentry_addon.sh   (then `godot --headless --import` so Godot registers the extension)
# To update the SDK: change VER, ZIP and SHA together (sha256 of the release zip). See docs/SENTRY.md.
set -euo pipefail
VER=2.5.0
ZIP="sentry-godot-$VER+96bfb46.zip"
SHA=32e11abe7adbc180a4dd849ae4345fc15514ca7d5404f6a20433021aecb22beb
OUT="$(cd "$(dirname "$0")/.." && pwd)/addons/sentry"
[ -f "$OUT/VERSION" ] && [ "$(cat "$OUT/VERSION")" = "$VER" ] && { echo "sentry addon $VER already installed"; exit 0; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
curl -sSfL -o "$TMP/sdk.zip" "https://github.com/getsentry/sentry-godot/releases/download/$VER/${ZIP//+/%2B}"
echo "$SHA  $TMP/sdk.zip" | sha256sum -c --quiet
unzip -q "$TMP/sdk.zip" -d "$TMP/x" 'addons/sentry/sentry.gdextension' 'addons/sentry/LICENSE.md' \
	'addons/sentry/bin/windows/x86_64/*' 'addons/sentry/bin/linux/x86_64/*' 'addons/sentry/bin/macos/*'
rm -rf "$OUT"; mkdir -p "$(dirname "$OUT")"
mv "$TMP/x/addons/sentry" "$OUT"
echo "$VER" > "$OUT/VERSION"
echo "sentry addon $VER installed in addons/sentry"
