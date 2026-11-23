#!/bin/bash
# train_test.sh MODE : MODE=merge (coordinator sim merges greens) | nomerge (nobody merges) | sneak (another PR lands on main first)
# Local only: a bare origin in /tmp, a stub gate, a fake GitHub API (curl on PATH) and a coordinator that merges every MERGE_READY line.
MODE=${1:-merge}
SRC0=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d /tmp/mt_test.XXXX); cd $T; SRC=$SRC0
git init -q --bare origin.git; git -C origin.git symbolic-ref HEAD refs/heads/main; git init -q -b main repo; cd repo; git config user.email t@t; git config user.name t; git remote add origin $T/origin.git
mkdir -p ops/merge-rush-1113; cp $SRC/merge-rush-1113/merge_batch.sh ops/merge-rush-1113/; echo a > a.txt; git add -A; git commit -qm init; git push -q origin main
for n in 1 2 3; do git checkout -qb ext/p$n main; echo p$n > f$n.txt; git add -A; git commit -qm p$n; git push -q origin ext/p$n ext/p$n:refs/pull/$n/head; done
git checkout -q main
mkdir -p $T/fakebin; cat > $T/fakebin/curl <<'E'
#!/bin/bash
n=${@: -1}; n=${n##*/}; echo "{\"head\":{\"ref\":\"ext/p$n\",\"repo\":{\"full_name\":\"x/y\"}},\"base\":{\"repo\":{\"full_name\":\"x/y\"}}}"
E
cat > $T/stubgate <<E
#!/bin/bash
mkdir -p "\$3"; n=\$(( \$(cat $T/gn 2>/dev/null || echo 0) + 1 )); echo \$n > $T/gn
if [ $MODE = sneak ] && [ \$n = 2 ]; then d=\$(mktemp -d); git clone -q $T/origin.git \$d; (cd \$d; echo z > z.txt; git add -A; git -c user.email=c@c -c user.name=c commit -qm sneak; git push -q origin HEAD:main); fi
echo "gate on: \$(git -C \$2 log --format=%s -3 | tr '\n' '|')" >> $T/gates.log; sleep 2
echo "GATE GREEN checks=5 new_red=0 fixed=0 flaky=0 parse_errors=0/0 export_bad=0 wall=1m (cand x vs main y; jobs 2, main cached 0)" > "\$3/summary.txt"
E
chmod +x $T/fakebin/curl $T/stubgate
if false; then d=$(mktemp -d); git clone -q $T/origin.git $d; (cd $d; echo z > z.txt; git add -A; git -c user.email=c@c -c user.name=c commit -qm sneak; sleep 5; git push -q origin HEAD:main) & fi
if [ $MODE != nomerge ]; then
( seen=0; for i in $(seq 60); do sleep 2; c=$(grep -c . $T/ready.md 2>/dev/null); while [ "${c:-0}" -gt $seen ]; do seen=$((seen+1)); l=$(sed -n ${seen}p $T/ready.md); n=$(sed -E 's/^[^#]*#([0-9]+) .*/\1/' <<<"$l"); s=$(awk '{print $5}' <<<"$l"); d=$(mktemp -d); git clone -q $T/origin.git $d 2>/dev/null; git -C $d fetch -q origin "refs/heads/ext/p$n"; git -C $d -c user.email=c@c -c user.name=c merge -q --no-ff -m "Merge PR $n" $s && git -C $d push -q origin HEAD:main; echo "coord merged #$n ${s:0:10}" >> $T/coord.log; done; done ) &
fi
PATH=$T/fakebin:$PATH GATE=$T/stubgate WAIT_MERGE=20 MERGE_READY=$T/ready.md TRAIN_WORK=$T/work bash $SRC/merge-train-1114/merge-train --no-comment 1 2 3 >/dev/null; echo rc=$?
sleep 3; kill $(jobs -p) 2>/dev/null
cut -c10- $T/work/out/train.log; echo; cat $T/gates.log; cat $T/coord.log 2>/dev/null; cut -c1-110 $T/ready.md; cat $T/work/out/comment-1.md
git -C $T/origin.git log --oneline --graph main | head -14
