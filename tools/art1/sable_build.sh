#!/bin/bash
# ART-1 Sable v2: scan -> rest pose -> finish -> clips -> into the repo. WT: this tree; M: the raw run (never in git, ~/meshy/sable_v2).
ulimit -v 12000000
WT=${WT:-$(cd "$(dirname "$0")/../.." && pwd)}; M=${M:-$HOME/meshy/sable_v2}; B=${B:-/home/boki/tools/blender-4.5.15-linux-x64/blender}
cd "$M" || exit 1; mkdir -p stage/c
[ -f stage/base2k.png ] || ffmpeg -v error -y -i runA/tex0_base_color.png -vf scale=2048:2048 stage/base2k.png
if [ "$1" = "source" ]; then
	$B -b --factory-startup --python "$WT/tools/art1/sable_source.py" -- runA/glb.glb stage/base2k.png "$WT/art/wardens/src/sable_rig.json" stage/source.blend > stage/source.log 2>&1
	grep -E "^scan|^ears|^bun|^hem|^Low|Traceback|Error:" -A1 stage/source.log | cut -c1-200 | head -12
	grep -q Traceback stage/source.log && { echo "source failed"; exit 1; }
fi
$B -b --factory-startup --python "$WT/tools/art1/sable_finish.py" -- stage/source.blend "$WT/art/wardens/src/sable_rig.json" stage/c/sable.glb > stage/finish.log 2>&1
grep -E "^tris|Traceback|Error:" -A6 stage/finish.log | cut -c1-200 | head -14
grep -q Traceback stage/finish.log && { echo "finish failed"; exit 1; }
$B -b --python "$WT/tools/art1/sable_clips.py" -- stage/c/sable.blend stage/c/sable_out.glb > stage/clips.log 2>&1
grep -E "^clips|^exported|Traceback" -A6 stage/clips.log | cut -c1-260 | head
ls -la stage/c/sable_out.glb
grep -q Traceback stage/clips.log && { echo "clips failed"; exit 1; }
cp stage/c/sable_out.glb "$WT/art/wardens/sable/sable.glb"
