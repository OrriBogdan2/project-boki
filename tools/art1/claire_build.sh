#!/bin/bash
# ART-1 Claire (v2): scan -> rest pose -> finish -> clips; INSTALL=1 copies the result into the repo.
# Usage: claire_build.sh [source|noclips|clips]
WT=${WT:-$(cd "$(dirname "$0")/../.." && pwd)}; M=${M:-/home/boki/meshy/claire_v2}; B=${B:-/home/boki/tools/blender-4.5.15-linux-x64/blender}
cd "$M" || exit 1; mkdir -p stage/c
ulimit -v 12000000
[ "$1" = "source" ] && $B -b --factory-startup --python $WT/tools/art1/claire_source.py -- runA/glb.glb $WT/art/wardens/src/claire_rig.json stage/source.blend > stage/source.log 2>&1
[ "$1" = "source" ] && grep -E "^hem|^islands|^holes|^Low tris|Traceback" -A3 stage/source.log | cut -c1-200
if [ "$1" != "clips" ]; then
  # (the box is shared: wait for room first)
  until [ "$(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)" -ge 12 ]; do perl -e 'select(undef,undef,undef,5)'; done
  rm -f stage/c/claire.glb
  $B -b --factory-startup --python $WT/tools/art1/claire_finish.py -- stage/source.blend $WT/art/wardens/src/claire_rig.json stage/c/claire.glb > stage/finish.log 2>&1
  grep -E "^tris|^exported|Traceback|Error:" -A4 stage/finish.log | cut -c1-200 | head -14
fi
[ "$1" = "noclips" ] && exit 0
$B -b --python $WT/tools/art1/claire_clips.py -- stage/c/claire.blend stage/c/claire_out.glb > stage/clips.log 2>&1
grep -E "^clips|^exported|Traceback" -A6 stage/clips.log | cut -c1-260 | head
[ -n "$INSTALL" ] && cp stage/c/claire_out.glb $WT/art/wardens/claire/claire.glb && cp stage/c/atlas.png /tmp/claire_atlas.png
exit 0
