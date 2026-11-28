#!/bin/bash
cd "$(dirname "$0")/.."; W=art/wardens/sable; O=.cjr/out; mkdir -p $O
export XDG_DATA_HOME=$(mktemp -d)
for v in live fix; do
  cp .cjr/$v/sable_meshy.glb .cjr/$v/sable_meshy_Image_0_seam.jpg $W/
  timeout 600 godot --headless --import >/dev/null 2>&1
  godot --path . -- --face-closeup-shots --shots-dir=$O --warden=thief --size=900 --tag=$v 2>&1 | tail -2
  godot --path . -- --hunter-gpu-shots --heroes=thief --shots-dir=$O --size=1600x900 --face 2>&1 | tail -2
  for f in $O/thief_*.png; do mv $f $O/${v}_game_$(basename $f); done
done
ls $O
