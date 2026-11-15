#!/bin/bash
# train_batch_test.sh : train-batch run/hold against a bare origin in /tmp and a stub gate (no GitHub, no cluster).
# REGATE_RUN=ops/merge-train-1114/regate_stub.sh runs it through the delta-gate path (default: full re-gate). p1,p2,p4 are clean, p3 conflicts with p1, p4's pinned sha is stale; the gate "sneaks" a commit onto main during gate 1.
SRC=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d /tmp/tb_test.XXXX); cd "$T" || exit 2
git init -q --bare origin.git; git -C origin.git symbolic-ref HEAD refs/heads/main; git init -q -b main repo; cd repo || exit 2
git config user.email t@t; git config user.name t; git remote add origin "$T/origin.git"
mkdir -p ops/merge-rush-1113; cp "$SRC/merge-rush-1113/merge_batch.sh" ops/merge-rush-1113/; echo a > a.txt; git add -A; git commit -qm init; git push -q origin main
for n in 1 2 3 4; do
	git checkout -qb ext/p$n main; echo p$n > f$n.txt; [ $n = 3 ] && echo p3 > f1.txt; git add -A; git commit -qm p$n
	git push -q origin ext/p$n ext/p$n:refs/pull/$n/head
done
git checkout -q main
cat > "$T/stubgate" <<E
#!/bin/bash
mkdir -p "\$3"; n=\$(( \$(cat $T/gn 2>/dev/null || echo 0) + 1 )); echo \$n > $T/gn
if [ \$n = 1 ]; then d=\$(mktemp -d); git clone -q $T/origin.git \$d; (cd \$d; echo z > z.txt; git add -A; git -c user.email=c@c -c user.name=c commit -qm sneak; git push -q origin HEAD:main); fi
echo "GATE GREEN checks=5 new_red=0 fixed=0 flaky=0 parse_errors=0/0 export_bad=0 wall=1m" > "\$3/summary.txt"
E
export TRAIN_TRUST_IDS=1 REGATE_RUN=${REGATE_RUN-} GATE=$T/stubgate TRAIN_STATE=$T/state TRAIN_WORK=$T/work
tb=$SRC/merge-train-1114/train-batch fail=0
ok() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
p4old=$(git rev-parse origin/ext/p4~0); git checkout -q ext/p4; echo more > g.txt; git add -A; git commit -qm p4b; git push -q origin HEAD:refs/pull/4/head -f; git checkout -q main
ok "no train below the minimum" "[ -z \"\$($tb run --min 9 1 2 2>&1 | grep -c pushed | grep -v '^0')\" ]"
$tb run --dry --min 1 2 > "$T/min.out" 2>&1
ok "--min 1 is not read as PR #1" "grep -q ' + #2 (' $T/min.out"
$tb run 1 2 3 4=${p4old:0:10} > "$T/run.out" 2>&1; echo "run rc=$?"
br=$(git ls-remote origin 'refs/heads/ext/merge-train-*' | awk '{sub("refs/heads/","",$2); print $2}')
ok "train branch pushed" "[ -n '$br' ]"
ok "p3 skipped for conflict" "grep -q 'pr/3: SKIPPED.*f1.txt.*only with the others' $T/run.out"
ok "p4 skipped (head moved)" "grep -q 'PR #4: head .* is not the green' $T/run.out"
ok "main's sneak commit merged in and re-gated" "grep -q 'gate 2:' $T/run.out && git ls-tree -r --name-only origin/$br | grep -q z.txt"
git fetch -q origin; ok "branch holds p1 p2 and main" "git merge-base --is-ancestor origin/ext/p1 origin/$br && git merge-base --is-ancestor origin/ext/p2 origin/$br && git merge-base --is-ancestor origin/main origin/$br"
ok "GATE GREEN text names the full sha" "grep -q \"^GATE GREEN \$(git rev-parse origin/$br):\" $T/state/*/gate-comment.md"
ok "hold is on" "$tb hold > /dev/null"
ok "hold lets the train PR through" "! $tb hold --except $br > /dev/null"
ok "hold releases itself after the cap" "HOLD_MIN=0 $tb hold > /dev/null; [ \$? = 1 ] && grep -q released $T/state/train.log"
$tb publish $br --summary 'GATE GREEN checks=5 new_red=0' --dry > "$T/pub.out" 2>&1
ok "publish --dry lists the folded PRs" "grep -q '^- #2 ' $T/pub.out"
ok "publish writes the GATE GREEN text" "grep -q \"^GATE GREEN \$(git rev-parse origin/$br):\" $T/state/${br#ext/merge-train-}/gate-comment.md"
ok "publish refuses a non-green summary" "! $tb publish $br --summary 'GATE RED x' --dry > /dev/null 2>&1"
d=$(mktemp -d); git clone -q "$T/origin.git" "$d"; (cd "$d" && echo y > y.txt && git add -A && git -c user.email=c@c -c user.name=c commit -qm move && git push -q origin HEAD:main)
ok "publish refuses a train behind main" "$tb publish $br --summary 'GATE GREEN x' --dry 2>&1 | grep -q 'is behind origin/main'"
git fetch -q origin; git checkout -q -B mt origin/main; git merge -q --no-edit origin/$br; git push -q origin HEAD:main; rm -f "$T/state/HOLD"
ok "hold ends when the train is merged" "! $tb hold > /dev/null"
[ -n "$KEEP" ] && echo "$T" || rm -rf "$T"; exit $fail
