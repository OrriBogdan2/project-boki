#!/bin/bash
# Tile --land-weight-shots frames (light | medium | heavy side by side) into <dir>/<way>.mp4 at 30 fps.
# usage: tools/land_weight_video.sh <shots-dir>
d="$1"
for way in jump drop; do
	ffmpeg -y -loglevel error -framerate 30 -i "$d/$way/light/f%03d.png" -framerate 30 -i "$d/$way/medium/f%03d.png" \
		-framerate 30 -i "$d/$way/heavy/f%03d.png" -filter_complex "hstack=inputs=3" -pix_fmt yuv420p "$d/$way.mp4"
done
