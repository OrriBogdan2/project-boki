#!/bin/bash
# proof-check.sh LIVE_TREE FIX_TREE GLB LIVE_SHOTS_DIR FIX_SHOTS_DIR
# 11-19: owner asked "are you looking at the wrong files?" after before/after looked identical.
# Proves (1) the fix tree's glb differs from live, (2) BOTH trees' Godot import cache was rebuilt from
# their own glb (a stale .godot/imported copy would render the OLD model), (3) how many pixels changed.
lt=$1 ft=$2 g=$3 ls=$4 fs=$5; ok=1
# 11-24: native hunters load <g>_meshy.glb in game (hunter_visual native path); check THAT file when it exists,
# else the contract <g>.glb (Sable + Lace reviews 11-24 both got a false "GLB IDENTICAL" from the contract file).
f=$g; { [ -f "$lt/art/wardens/$g/${g}_meshy.glb" ] || [ -f "$ft/art/wardens/$g/${g}_meshy.glb" ]; } && f=${g}_meshy
echo "checking art/wardens/$g/$f.glb (the file the game draws)"
for t in "$lt" "$ft"; do
  src=$(md5sum "$t/art/wardens/$g/$f.glb" | cut -c1-32)
  rec=$(grep -ho 'source_md5="[0-9a-f]*"' "$t"/.godot/imported/$f.glb-*.md5 2>/dev/null | head -1 | cut -d'"' -f2)
  [ -n "$src" ] && [ "$src" = "$rec" ] && echo "import OK  $(basename $t): cache built from ${src:0:12}" || { echo "IMPORT STALE $(basename $t): glb ${src:0:12} but cache from ${rec:-none}"; ok=0; }
done
[ "$(md5sum < $lt/art/wardens/$g/$f.glb)" != "$(md5sum < $ft/art/wardens/$g/$f.glb)" ] && echo "glb differs: yes" || { echo "GLB IDENTICAL: fix tree has the live model"; ok=0; }
python3 - "$ls" "$fs" <<'PY'
import os,sys,numpy as np
from PIL import Image
a,b=sys.argv[1:3]; r=[]
for root,_,fl in os.walk(a):
  for f in fl:
    if not f.endswith(('.jpg','.png')): continue
    p=os.path.join(root,f); q=os.path.join(b,os.path.relpath(p,a))
    if not os.path.exists(q): continue
    x=np.asarray(Image.open(p).convert('L'),dtype=np.int16); y=np.asarray(Image.open(q).convert('L'),dtype=np.int16)
    r.append(int((np.abs(x-y)>12).sum())*100.0/x.size)
r.sort(); n=len(r)
print("frames %d identical %d changed%%: median %.2f p90 %.2f"%(n,sum(v==0 for v in r),r[n//2],r[int(n*.9)]) if n else "NO MATCHING FRAMES")
PY
[ $ok = 1 ] || exit 2
