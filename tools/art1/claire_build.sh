#!/bin/bash
# ART-1 Claire: scan -> rest pose -> finish -> clips -> into the repo.
WT=${WT:-/home/boki/s2-art1-claire}; M=${M:-/home/boki/meshy/claire_f}; B=/home/boki/tools/blender-4.5.15-linux-x64/blender
cd "$M" || exit 1; mkdir -p stage/c
ulimit -v 12000000; [ "$1" = "source" ] && $B -b --factory-startup --python $WT/tools/art1/claire_source.py -- runA/glb.glb $WT/art/wardens/src/claire_rig.json stage/source.blend > stage/source.log 2>&1
ulimit -v 12000000; $B -b --factory-startup --python $WT/tools/art1/claire_finish.py -- stage/source.blend $WT/art/wardens/src/claire_rig.json stage/c/claire.glb /home/boki/briefs-wt/briefs/art-refs/claire_head.png > stage/finish.log 2>&1
grep -E "^tris|Traceback|Error:" -A6 stage/finish.log | cut -c1-200 | head -14
ulimit -v 12000000; $B -b --python $WT/tools/art1/claire_clips.py -- stage/c/claire.blend stage/c/claire_out.glb > stage/clips.log 2>&1
grep -E "^clips|^exported|Traceback" -A6 stage/clips.log | cut -c1-260 | head
cp stage/c/claire_out.glb $WT/art/wardens/claire/claire.glb
