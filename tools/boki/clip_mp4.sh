#!/bin/bash
# clip_mp4.sh <out-dir> <species...>: one review MP4 per species from a --boki-rig-shots run (needs a renderer):
# idle, walk, run, attack, ability, hop, eat, sleep end to end, 15 fps.
set -e
out=$1; shift
for id in "$@"; do
	d="$out/$id"
	mkdir -p "$d"
	godot --path . --rendering-driver vulkan -- --boki-rig-shots --shots-dir="$d" --species="$id" --px=384 >"$d/shots.log" 2>&1 || godot --path . -- --boki-rig-shots --shots-dir="$d" --species="$id" --px=384 >"$d/shots.log" 2>&1
	list="$d/list.txt"
	: >"$list"
	for clip in idle walk run attack ability hop eat sleep; do
		for f in "$d"/frames/$clip/*.png; do echo "file '$f'" >>"$list"; echo "duration 0.0667" >>"$list"; done
	done
	ffmpeg -y -loglevel error -f concat -safe 0 -i "$list" -vf "fps=15,format=yuv420p" "$out/${id}_clips.mp4"
	echo "MP4 $out/${id}_clips.mp4"
done
