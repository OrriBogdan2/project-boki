cd /home/boki/cj/20261117-144233-a4/tree
for f in --quality-check --hero-title-check --hatch-check; do
  X=$(mktemp -d); XDG_DATA_HOME=$X timeout 1200 xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy --path . -- $f > OUT/chk$f.log 2>&1; echo "$f rc=$?" >> OUT/checks.log
done
echo DONE >> OUT/checks.log
