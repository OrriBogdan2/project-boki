#!/usr/bin/env bash
# Prepares one CI job (pr-checks, release, itch) on a GitHub-hosted OR a self-hosted runner, with no sudo:
#   tools/ci/ci_env.sh [--templates]
# Needs GODOT_VERSION. Installs Godot (and with --templates the export templates) once per machine into
# $BOKI_CI_CACHE (default ~/.cache/boki-ci; flock'd, so concurrent runners on one box never race), puts it first on
# the job's PATH (before any `godot` wrapper installed on the box), and points XDG_DATA_HOME at a per-job dir so the
# job never reads or writes the box user's own ~/.local/share/godot. Uses python's zipfile when `unzip` is missing.
# On a self-hosted runner it also gives the lint venv a per-runner home (tools/check.sh reads BOKI_LINT_VENV).
set -euo pipefail
V="${GODOT_VERSION:?GODOT_VERSION not set}"
CACHE="${BOKI_CI_CACHE:-$HOME/.cache/boki-ci}"
mkdir -p "$CACHE"
exec 9>"$CACHE/.install.lock"
flock 9

unpack() { # zip dest
	if command -v unzip >/dev/null 2>&1; then unzip -q "$1" -d "$2"; else python3 -I -m zipfile -e "$1" "$2"; fi
}
base="https://github.com/godotengine/godot/releases/download/${V}-stable"
tmp="$(mktemp -d "$CACHE/dl.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

if [ ! -x "$CACHE/godot-$V/godot" ]; then
	curl -fsSL --retry 3 -o "$tmp/godot.zip" "$base/Godot_v${V}-stable_linux.x86_64.zip"
	unpack "$tmp/godot.zip" "$tmp/g"
	chmod +x "$tmp/g/Godot_v${V}-stable_linux.x86_64"
	mkdir -p "$CACHE/godot-$V.new"
	mv "$tmp/g/Godot_v${V}-stable_linux.x86_64" "$CACHE/godot-$V.new/godot"
	rm -rf "$CACHE/godot-$V"
	mv "$CACHE/godot-$V.new" "$CACHE/godot-$V"
fi

XDG="${RUNNER_TEMP:-$(mktemp -d)}/xdg"
mkdir -p "$XDG/godot/export_templates"
if [ "${1:-}" = "--templates" ]; then
	if [ ! -d "$CACHE/templates-$V" ]; then
		curl -fsSL --retry 3 -o "$tmp/tpl.tpz" "$base/Godot_v${V}-stable_export_templates.tpz"
		unpack "$tmp/tpl.tpz" "$tmp/t"
		mv "$tmp/t/templates" "$CACHE/templates-$V"
	fi
	ln -sfn "$CACHE/templates-$V" "$XDG/godot/export_templates/${V}.stable"
fi

PATH="$CACHE/godot-$V:$PATH" godot --version
SHIM="$(cd "$(dirname "$0")" && pwd)/shim"
if [ -n "${GITHUB_ENV:-}" ]; then
	echo "$CACHE/godot-$V" >> "$GITHUB_PATH"
	echo "XDG_DATA_HOME=$XDG" >> "$GITHUB_ENV"
	# no `unzip` on the box (and no sudo to install it): tools/sentry_addon.sh and others still need one
	command -v unzip >/dev/null 2>&1 || echo "$SHIM" >> "$GITHUB_PATH"
	if [ "${RUNNER_ENVIRONMENT:-}" = "self-hosted" ]; then
		echo "BOKI_LINT_VENV=${RUNNER_TOOL_CACHE:-$HOME/.cache}/boki-lint/venv" >> "$GITHUB_ENV"
	fi
fi
