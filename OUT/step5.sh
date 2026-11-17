cd /home/boki/cj/20261117-144652-a4/tree
for f in --hudref-check --hatch-check --level-hud-check --knock-feed-check; do
  echo "RUN $f"; timeout 1500 godot --headless --path . -- $f > OUT/c_${f#--}.log 2>&1; echo "RC $f $?"; echo "errs $(grep -c 'SCRIPT ERROR' OUT/c_${f#--}.log)"; tail -n 3 OUT/c_${f#--}.log | cut -c1-200
done
echo STEP5_DONE
