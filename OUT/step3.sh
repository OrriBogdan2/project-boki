cd /home/boki/cj/20261117-144652-a4/tree
for f in --check --hudref-check --hatch-check --level-hud-check --knock-feed-check --first-match-guide-check --title-check --loading-check; do
  echo "RUN $f"; timeout 1500 godot --headless --path . -- $f > OUT/c_${f#--}.log 2>&1; echo "RC $f $?"; tail -n 2 OUT/c_${f#--}.log
done
echo STEP3_DONE
