cd /home/boki/cj/20261117-144233-a4/tree
for b in "$@"; do
 r=origin/ext/$b; mb=$(git merge-base origin/main $r)
 git diff --name-only $mb $r > OUT/own.$b.txt
 n=$(wc -l < OUT/own.$b.txt)
 # files in branch's own change set that still differ between main and tip
 d=$(git diff --name-only origin/main $r -- $(cat OUT/own.$b.txt | tr '\n' ' ') 2>/dev/null | wc -l)
 echo "$b own_files=$n differ_from_main=$d"
done
