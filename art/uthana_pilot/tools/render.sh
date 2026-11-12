#!/bin/bash
# render.sh <jobs.tsv> <log>
export XDG_DATA_HOME=$(mktemp -d /tmp/uth-xdg.XXXX) LP_NUM_THREADS=2
nice -n 10 xvfb-run -a -s "-screen 0 960x480x24" /opt/godot/godot-bin --rendering-driver opengl3 --audio-driver Dummy --path /tmp/uthp -- --jobs=$1 > $2 2>&1
echo "rc=$?" >> $2
