#!/bin/bash
# usage: runchecks.sh flag...  (runs each flag headless with a temp XDG, one log per flag)
cd /home/boki/cj/20261117-144549-a1/tree
for f in "$@"; do
  n=${f#--}; mkdir -p OUT/xdg_$n
  XDG_DATA_HOME=$PWD/OUT/xdg_$n timeout 1200 godot --headless --path . -- $f > OUT/chk_$n.log 2>&1
  echo "$f rc=$?" >> OUT/chk_results.txt
done
