set -x
cd /home/boki/cj/20261117-144652-a4/tree
git checkout -f -B ext/merge-lane-uihud-1117 origin/ext/merge-lane-uihud-1117 || exit 1
git merge --no-edit origin/main; echo MERGE_RC=$?
git status --short | grep -E '^(UU|AA|DU|UD|AU|UA|DD)' 
echo STEP1_DONE
