#!/bin/bash
# rsub2.sh VARIANT TAG MODE(game|video): live-audit render of rt/VARIANT; id -> jobs.txt
V=$1; T=$2; M=$3; D=/home/boki/cj/20261124-055726-a1; X="--close"; [ $M = video ] && X="--close --video"
ID=$(jobq submit --tree $D/rt/$V --needs gpu --only rp1 --out out/${T}_${V}_$M --timeout 1700 -- -- --live-audit --shots-dir=out/${T}_${V}_$M --wardens=archer --size=768 $X 2>&1 | tail -1)
echo "${T}_${V}_$M $ID" >> /home/boki/gens/lace-r11/jobs.txt
