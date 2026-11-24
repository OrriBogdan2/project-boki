#!/bin/bash
# meas.sh NAME GLB [slit=1]: clipcheck11 + geo_check + stretch + hipyaw -> after/<NAME>_*.txt
N=$1; G=$2; S=$3; W=/home/boki/gens/lace-r11; T=/home/boki/cj/20261124-055726-a1/tree; cd $T
~/tools/blender-4.5.15-linux-x64/blender -b -P $W/tools/clipcheck11.py -- $G 8 $S 2>&1 | grep -E "^(CLIP|TOTAL|FOOTHITS|ZHIST)" > $W/after/${N}_clip.txt &
python3 $T/tools/anim/geo_check.py $G --out $W/after/${N}_geo > $W/after/${N}_geo.txt 2>&1 &
python3 $W/tools/stretch3.py $T/tools/art1 $G $T/tools/art1 > $W/after/${N}_stretch.txt 2>&1 &
python3 $W/tools/hipyaw.py $G $W/tools 2>&1 | grep "Idle.*rot" > $W/after/${N}_yaw.txt &
wait
echo "== $N"; grep -E "TOTAL|FOOTHITS" $W/after/${N}_clip.txt; tail -3 $W/after/${N}_geo.txt | cut -c1-200; grep -E "skirt" $W/after/${N}_stretch.txt | cut -c1-200; cut -c1-150 $W/after/${N}_yaw.txt
