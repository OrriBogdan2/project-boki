#!/bin/bash
# review_gifs.sh <shots-dir>: the GIFs of a --boki-rig-shots run, from its frames/<clip>/ folders, plus a contact sheet.
set -e
dir=$1
for clip in "$dir"/frames/*/; do
	name=$(basename "$clip")
	ffmpeg -y -loglevel error -framerate 15 -i "$clip/%03d.png" \
		-filter_complex "scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" \
		-loop 0 "$dir/$name.gif"
done
ffmpeg -y -loglevel error -framerate 8 -pattern_type glob -i "$dir/frames_turn_*.png" \
	-filter_complex "scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse" \
	-loop 0 "$dir/turntable.gif"
inputs=""
n=0
for strip in idle walk run attack ability hop sleep eat pet chop mine carry tend; do
	inputs="$inputs -i $dir/anim_$strip.png"
	n=$((n + 1))
done
# shellcheck disable=SC2086
ffmpeg -y -loglevel error $inputs -filter_complex "vstack=inputs=$n" "$dir/animation_sheet.png"
