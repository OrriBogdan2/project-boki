#!/bin/bash
# pipe13.sh NAME [rig13 args...] : build+weights (rig13) -> closed-loop solve per clip (refine13, parallel) -> apply. Output $OUT/cand/NAME_r.glb
set -e; N=$1; shift; OUT=${OUT:-/home/boki/gens/hunter-round-1124/lace/r13}; B=${BLENDER:-$HOME/tools/blender-4.5.15-linux-x64/blender}; T=$(cd $(dirname $0)/../../..; pwd)
mkdir -p $OUT/cand $OUT/ref_$N
$B -b --factory-startup -P $T/tools/art1/hem_r13/rig13.py -- ${LIVE:-$T/art/wardens/hem/hem_meshy.glb} $OUT/cand/$N.glb mode=A sh=0 them=0.05 zlow=0.45 zhigh=0.92 marg=0.05 amax=60 pslow=0.4 "$@" > $OUT/cand/$N.log 2>&1
for c in run Jump_Run Crouch_Walk_with_Torch walk Idle Attack; do $B -b --factory-startup -P $T/tools/art1/hem_r13/refine13.py -- $OUT/cand/$N.glb solve $c $OUT/ref_$N/$c.json amax=${AM:-80} it=10 > $OUT/ref_$N/$c.log 2>&1 & done; wait
$B -b --factory-startup -P $T/tools/art1/hem_r13/refine13.py -- $OUT/cand/$N.glb apply $OUT/cand/${N}_r.glb $OUT/ref_$N/*.json > $OUT/ref_$N/apply.log 2>&1
grep -h DONE $OUT/ref_$N/*.log > $OUT/cand/${N}_r.sum; echo PIPE-DONE $N >> $OUT/cand/${N}_r.sum
