#!/bin/bash
# uthana_view.sh <project dir> <jobs.json> <log>: renders uthana_view.gd jobs headless (xvfb, GL compatibility).
# The project dir holds tools/anim/uthana_*.gd|tscn, the rig GLBs and the Uthana motion GLBs (main scene uthana_view.tscn).
export LP_NUM_THREADS=2 GODOT_SLOTS=${GODOT_SLOTS:-30}
nice -n 10 xvfb-run -a -s "-screen 0 1920x480x24" godot --rendering-driver opengl3 --audio-driver Dummy --path "$1" -- --jobs="$2" > "$3" 2>&1
echo "rc=$?" >> "$3"
