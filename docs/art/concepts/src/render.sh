#!/bin/sh
# Build the sheets and rasterize them with Godot (no other SVG renderer on the box).
# ./render.sh [ids...]   (no ids: every sheet; the lineup is always redone)
cd "$(dirname "$0")" && python3 build.py "$@" || exit 1
args=""
if [ $# -eq 0 ]; then
	for f in ../*.svg; do args="$args $f ${f%.svg}.png"; done
else
	for i in "$@"; do args="$args ../$i.svg ../$i.png"; done
fi
timeout 900 godot --headless --script svg_render.gd -- $args out/lineup.svg ../lineup.png 2>&1 | grep -v "^Godot Engine"
