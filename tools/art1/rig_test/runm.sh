#!/bin/bash
# runm.sh <glbname> : metrics -> r/m_<name>.txt
B=~/tools/blender-4.5.15-linux-x64/blender; cd tools/art1/rig_test; n=$1
{ $B -b --python t4.py -- glb/$n.glb 2>&1 | grep -E "^(METRIC|LOWER)"; $B -b --python t6.py -- glb/$n.glb run_f,run_l,crouch_idle,x_aim,aim,dive,glide,walk_l 2>&1 | grep -E "^WEB "; } > r/m_$n.txt
