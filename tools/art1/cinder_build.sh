#!/bin/bash
# ART-1 Cinder: scan -> rest pose -> finish -> clips -> into the repo. WT is this worktree, M the Meshy work dir (scan in runA, plate in edit_face).
WT=${WT:-/home/boki/s2-art1-cinder}; M=${M:-/home/boki/meshy/cinder_f}; B=/home/boki/tools/blender-4.5.15-linux-x64/blender
cd "$M" || exit 1
ulimit -v 12000000
[ "$1" = "source" ] && $B -b --factory-startup --python $WT/tools/art1/cinder_source.py -- runA/glb.glb $WT/art/wardens/src/cinder_rig.json stage/source.blend > stage/source.log 2>&1
$B -b --factory-startup --python $WT/tools/art1/cinder_finish.py -- stage/source.blend $WT/art/wardens/src/cinder_rig.json stage/c/cinder.glb edit_f2/image0.png edit_s2/image0.png > stage/finish.log 2>&1
grep -E "^tris|Traceback|Error:" -A6 stage/finish.log | cut -c1-200 | head -12
$B -b --python $WT/tools/art1/cinder_clips.py -- stage/c/cinder.blend stage/c/cinder_out.glb > stage/clips.log 2>&1
grep -E "^exported|Traceback" -A6 stage/clips.log | cut -c1-200 | head
cp stage/c/cinder_out.glb $WT/art/wardens/cinder/cinder.glb
