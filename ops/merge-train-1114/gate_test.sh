#!/bin/bash
# gate_test.sh : gate-shard's verdict logic offline (fake jobq + fake godot on PATH, two tiny git trees). Prints PASS/FAIL per case.
HERE=$(cd "$(dirname "$0")" && pwd); fails=0
T=$(mktemp -d /tmp/gs_test.XXXX); mkdir -p $T/bin $T/res
FLAGS="--a-check --b-check --c-check --d-check --e-check"
for side in main cand; do
	d=$T/$side; mkdir -p $d/tools $d/scripts; cd $d; git init -q; git config user.email t@t; git config user.name t
	{ echo 'const CHECKS := {'; for f in $FLAGS; do echo "	\"$f\": [\"res://x.gd\", \"x\", null],"; done; echo '}'; } > tools/check_registry.gd
	echo 'extends Node' > scripts/main.gd; printf '[preset.0]\nname="Linux"\n' > export_presets.cfg
	echo $side > side.txt; git add -A; git commit -qm $side
done
cat > $T/bin/godot <<'E'
#!/bin/bash
for a in "$@"; do case $a in *.pck) touch "$a";; esac; done; exit 0
E
# fake jobq: SCEN picks the case; per (side,flag) attempt counter in $T/cnt
cat > $T/bin/jobq <<E
#!/bin/bash
R=$T/res
case \$1 in
submit)
	list=; tree=
	for a in "\$@"; do case \$a in --gate-shard-run=*) list=\${a#--gate-shard-run=};; esac; done
	while [ \$# -gt 0 ]; do [ "\$1" = --tree ] && tree=\$2; shift; done
	side=m; [[ \$tree == *cand* ]] && side=c
	n=\$(( \$(cat $T/submits 2>/dev/null || echo 0) + 1 )); echo \$n > $T/submits
	[ \$n = 2 ] && exit 1   # the relay drops one submit
	id=F\$RANDOM\$RANDOM; : > \$R/\$id
	for f in \${list//,/ }; do
		k=\$(( \$(cat $T/cnt_\${side}_\$f 2>/dev/null || echo 0) + 1 )); echo \$k > $T/cnt_\${side}_\$f
		rc=0
		case \$SCEN:\$side:\$f in
			main127:m:--b-check) rc=127;;      # main never runs b (mac worker every time)
			main127:c:--b-check) rc=1;;        # ... and the candidate breaks b
			mac1:m:--c-check) [ \$k = 1 ] && rc=127;;  # one mac hop, then fine
			candlost:c:--d-check) rc=127;;     # the candidate never gets d run
			newred:c:--e-check) rc=1;;
			flaky:c:--e-check) [ \$k = 1 ] && rc=1;;
		esac
		echo "GS \$f \$rc 0 1" >> \$R/\$id
	done
	echo \$id;;
result) echo "\$2 rc=0 fails=0 worker=x secs=1 needs=any label=l log=\$R/\$2";;
esac
E
chmod +x $T/bin/*
check() {  # check SCEN WANT(GREEN|RED) [NEWRED]
	rm -f $T/cnt_* $T/submits; rm -rf $T/out $T/cache
	(cd $T/main && git checkout -q -- . && git clean -fdq); (cd $T/cand && git checkout -q -- . && git clean -fdq)
	SCEN=$1 PATH=$T/bin:$PATH GS_CACHE=$T/cache GS_SHARDS=2 GS_MAX_WAIT=5 timeout 300 bash "$HERE/gate-shard" $T/main $T/cand $T/out > /dev/null 2>&1
	got=$(head -1 $T/out/summary.txt | awk '{print $2}'); nr=$(grep -o 'NEW-RED: .*' $T/out/summary.txt)
	if [ "$got" = "$2" ] && [[ "$nr" == *"${3:-}"* ]]; then echo "PASS $1 -> $got $nr"; else echo "FAIL $1 -> $got (want $2 ${3:-}) $(head -1 $T/out/summary.txt)"; fails=$((fails+1)); fi
}
check clean GREEN
check main127 RED --b-check
check mac1 GREEN
check candlost RED --d-check
check newred RED --e-check
check flaky GREEN
exit $fails
