#!/bin/bash
# The play probe (tools/play_probe.gd): every Hunter driven by real input events; writes
# <out>/play_probe_report.md and <out>/play_probe.json. Nightly: tools/play_probe.sh /tmp/play_probe
# Usage: tools/play_probe.sh <out dir> [--clips] [--heroes=archer,mage]
#   --clips: draw and save an mp4 per FLAG (GPU worker: jobq submit --needs gpu -- tools/play_probe.sh <out> --clips)
set -euo pipefail
out=$(realpath -m "${1:?out dir}"); shift
clips=""; heroes=""
for a in "$@"; do
  case $a in
    --clips) clips="--play-probe-clips" ;;
    --heroes=*) heroes="=${a#--heroes=}" ;;
  esac
done
mkdir -p "$out"
cd "$(dirname "$0")/.."
xdg=$(mktemp -d /tmp/xdg.probe.XXXXXX)
export PROBE_SHA=$(git rev-parse --short HEAD) LP_NUM_THREADS=2
[ -d .godot ] || timeout 900 godot --headless --import >/dev/null 2>&1
XDG_DATA_HOME=$xdg setsid timeout 7000 xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 \
  --path . -- "--play-probe$heroes" "--play-probe-out=$out" $clips > "$out/godot.log" 2>&1 &
pid=$!
echo $pid > "$out/probe.pid"
# a parse error leaves the game waiting forever: stop this run (by its own pid) as soon as one shows
while kill -0 $pid 2>/dev/null; do
  grep -q "Parse Error" "$out/godot.log" && kill -- -$pid 2>/dev/null   # its own process group only
  sleep 5
done
rm -rf "$xdg"
grep -E "SCRIPT ERROR|Parse Error" "$out/godot.log" | head -5 || true
grep -E "^PLAY PROBE DONE" "$out/godot.log" || { echo "play probe did not finish: $out/godot.log"; exit 1; }
