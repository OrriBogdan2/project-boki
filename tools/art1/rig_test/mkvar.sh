#!/bin/bash
# mkvar.sh <base> <kinds...> : weights + patched glb for base glb/<base>.glb (mesh name from $MESH)
B=~/tools/blender-4.5.15-linux-x64/blender; base=$1; shift
cd tools/art1/rig_test
for k in "$@"; do
  $B -b --python mkweights.py -- glb/$base.glb wt/${base}_$k.npz $k 2>&1 | grep -E "^KIND|AUTO|Traceback|rror:"
  ~/venv-img/bin/python patchglb.py glb/$base.glb wt/${base}_$k.npz glb/${base}_$k.glb ${MESH:-tarek_body} | tail -1
done
