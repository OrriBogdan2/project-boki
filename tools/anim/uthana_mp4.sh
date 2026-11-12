#!/bin/bash
# uthana_mp4.sh <frames dir> <out.mp4> [loops=1]: uthana_view.gd frames (30 fps) to an H.264 MP4, played <loops> times.
L=${3:-1}
ffmpeg -loglevel error -y -stream_loop $((L - 1)) -framerate 30 -i "$1/f%04d.png" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$2"
