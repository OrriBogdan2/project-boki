cd /home/boki/cj/20261117-144233-a4/tree
for b in "$@"; do
 git checkout -q -B probe origin/main
 cs=$(git log --no-merges --reverse --format=%H origin/main..origin/ext/$b)
 n=$(echo "$cs" | wc -l)
 res=OK
 for c in $cs; do
  if ! git cherry-pick --allow-empty --keep-redundant-commits -x $c >/dev/null 2>&1; then
    f=$(git diff --name-only --diff-filter=U | head -8 | tr '\n' ' ')
    nf=$(git diff --name-only --diff-filter=U | wc -l)
    res="CONFLICT at ${c:0:10} ($nf files: $f)"; git cherry-pick --abort >/dev/null 2>&1; git reset -q --hard; break
  fi
 done
 echo "$b commits=$n $res"
done
git checkout -q ext/merge-lane-hunters7-1117
