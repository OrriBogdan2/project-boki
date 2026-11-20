# suite-fast.sh: merge-first Godot suite on hetzner that remote workers (boki-worker.sh) can share.
# Env (defaults = the owner's manual merge run):
#   OUT  results dir (flags.txt must exist there or is built from GW)   GW merge tree   MW main tree
# Every flag runs on the merge tree (top-down here; workers go bottom-up and claim flags with
# merge/<flag>.claim). Then main runs only where the merge is red. Results go to OUT/summary.txt
# (NEW-RED / WORSE / FIXED). While it runs, /home/boki/suite-active tells workers what to do.
# Usage on hetzner as boki:  [OUT=.. GW=.. MW=.. CHECK_MAP=check_map.json] bash suite-fast.sh [PARALLEL]
#
# Timing: every flag run on this server writes <n>.secs next to <n>.rc and appends "flag side secs where date" to
# /home/boki/suite-cache/durations.tsv (rolling, last 6000 lines). Worker runs have no .secs (not measured).
#
# RESULT CACHE (CHECK_MAP=<check_map.json> from check-map.py build; SUITE_CACHE=0 disables; no map = no cache).
# Before a flag runs, its fingerprint on that side's tree is looked up in /home/boki/suite-cache/<fp>.rc. Only a recorded
# PASS ("0 0") is reused: rc+log are copied into OUT and <n>.cached is written. Reds are never stored or reused (flakes).
# After the suite (and after workers delivered), every pass in OUT is stored under its fingerprint (a side's fingerprints
# are recomputed first and nothing is stored if the tree changed mid-run). Entries unused for 14 days are pruned.
# The fingerprint (check-map.py fingerprint) is sha256 of: godot binary id (version+size+mtime), the flag, its registry
# entry, its main.gd block, its entry scripts, its mapped deps + the children of every hub it depends on (+ their .import
# files), the content id (git blob; disk hash for modified/untracked files) of each, and the file listing of every
# directory holding one (a new file in a scanned directory changes it). On top, a GLOBAL part is mixed into every
# fingerprint because the static map can miss dynamic loads: project.godot, all_triggers (autoloads, main.tscn, ...),
# every hub script, check_registry.gd without its entry lines, main.gd without any flag block, and the names of all
# tracked code/data files (a new .gd/.json/.tscn anywhere invalidates everything). A flag the map does not resolve is
# never cached; neither are timing/perf-sensitive flags (SUITE_NOCACHE_RE, default perf|bench|hitch|load|net-check|title-check).
# SUITE_CACHE_STRICT=1 additionally hashes every .gd file (any script change -> no reuse).
# Main-tree and merge-tree flags with identical dependencies share fingerprints, so main passes serve merge and back.
#
# 11-12 (merge-candidate speed-up; the 20261111-2230 candidate took 14 h):
# - NOT-RUN results are rerun here: rc 126/127 (command not found / not executable) means Godot never started. The Mac
#   worker's hide_cfg was not exported to its xargs children, so since 11-08 every check it claimed came back "127 <n>"
#   next to a stale log, and was counted as red on both sides ("same"): about half of each suite was never really run.
# - TIMEOUT BREAKER: when >= SUITE_BREAK_TIMEOUTS (12) merge-side checks time out and they are >= half of the results
#   so far, the candidate hangs at boot: the remaining merge checks are not started (rc "125 0", log says why), the main
#   side is skipped and summary.txt gets a "BREAKER:" line. Timeouts are retried in the second pass only when there are
#   <= SUITE_RETRY_TIMEOUTS (8) of them (load flakes); more than that is the candidate, not the box. (2230: 114 checks x
#   1200 s, run twice, on 6 slots = 11 h.)
# - POD SHARDS: SUITE_PODS="rpc3:10 rpc5:10" (alias:slots) starts ~/bin/suite-pod per pod: a third claimant that runs
#   merge-side checks over ssh and delivers only passes (reds are rerun here). See suite-pod.
# - 11-13 POD MAIN SIDE: the same pods then also run the main side (suite-pod ... main; run() claims main/<n>.claim too), passes
#   only, the rest is rerun here. The 0810 gate ran its 208 main checks 4 h on the server alone (load 35, 52 x 1200 s timeouts).
# 11-13 (owner: faster gate, and stop early on a broken environment; the 0245 gate ran 50 min with 277/287 red):
# - CANARY: before anything else, SUITE_CANARY (~10 fast checks green for weeks; "" disables) runs on BOTH trees here. If >= half
#   are red on both, or >= half the runs exit with a code that contradicts the check's own "failures: N", summary.txt gets an
#   "ENV-BROKEN:" line, coord/SUITE_ALERT is written (fleet-watch / stall-watch report it) and the suite exits 3 within ~3 min.
#   A green canary removes SUITE_ALERT. The canary results are normal results (not rerun).
# - MASS-RED: once >= SUITE_MASSRED_MIN (30) merge results exist and >= SUITE_MASSRED_PCT (75) % failed outright (timeouts and
#   not-run excluded; normal is ~20 %), the suite stops the same way ("MASS-RED:" line, exit 3) and kills only its own Godot runs
#   (found by their XDG_DATA_HOME /tmp/xdg.<SID>.*). Catches what the canary cannot see: a broken worker or merge tree.
# - MAIN-TREE CACHE: main-side results, pass AND red (timeouts too), are stored in SUITE_CACHE_DIR/main-tree/ keyed by
#   sha256(main tree sha + Godot id + flag) when the main worktree is clean (git status empty), and reused by later suites
#   on the same tree (a release tag, origin/main). A cached red counts as red. Not stored: rc 125-127, not-run logs,
#   SUITE_NOCACHE_RE flags, aborted suites. SUITE_TREE_CACHE=0 disables; rm -r .../main-tree clears it.
# - LONGEST FIRST: both sides run in order of each flag's median of its last 5 server runs (durations.tsv; unknown = 60 s),
#   so the 20-min checks start first instead of forming the tail. flags.txt stays the canonical list (workers, compare).
#   OPT-IN ONLY (SUITE_ORDER=longest). Measured 11-13 (0245c vs 0245b, same trees): the first 40 flags ran a median 2.3x
#   slower when the heavy ones ran together (CPU contention), giving 4 extra 1200 s timeouts = false NEW-RED. Needs a
#   heavy-flag concurrency cap before it can be the default.
# 11-15 LOAD GATE (gate-0249 + anim-lane suite ENV-BROKEN: the aimkit canary timed out rc124 on BOTH trees at load 26-34 on 16
#   cores; the trees were fine). load_wait waits while loadavg1 > SUITE_MAX_LOAD (default 1.5 x nproc; 0 disables):
#   - before the canary: max SUITE_LOAD_WAIT s (900), and while >= SUITE_MAX_SUITES (default 3) other suites are live
#     (pid files in SUITE_CACHE_DIR/running/), so merge lanes / candidates / regates cap themselves by load and count.
#   - before every run(): max SUITE_RUN_LOAD_WAIT s (300), after the memory gate (back-pressure between concurrent suites);
#     a run whose wait hits the cap writes OUT/LOADCAP, and runs skip this wait for 10 min after that.
#   - canary runs that timed out (rc124) are rerun once after another wait before the ENV-BROKEN verdict; the verdict line
#     carries loadavg1 so an overloaded box is visible. SUITE_RUN_TIMEOUT (1200) and SUITE_CANARY_ONLY=1 are test hooks.
set -u
P=${1:-6}
OUT=${OUT:-/home/boki/suite-claude}; MW=${MW:-/home/boki/wt-main-claude}; GW=${GW:-/home/boki/wt-merge-claude}
GODOT_BIN=${GODOT_BIN:-/opt/godot/godot-bin}   # override only for tests
export OUT MW GW GODOT_BIN LP_NUM_THREADS=2; T0=$(date +%s)
mkdir -p $OUT/merge $OUT/main
LMAX=${SUITE_MAX_LOAD:-$(( $(nproc) * 3 / 2 ))}; export LMAX
load1() { awk '{print int($1 + 0.5)}' /proc/loadavg; }; export -f load1
load_wait() { # MAXSECS [WHY]: wait while loadavg1 > LMAX (max MAXSECS); prints only when it waited
  local t=0 l; [ "$LMAX" = 0 ] && return 0; l=$(load1)
  while [ $l -gt $LMAX ] && [ $t -lt $1 ]; do sleep 5; t=$((t + 5)); l=$(load1); done
  [ $t -gt 0 ] && echo "suite-fast: load gate waited ${t}s${2:+ ($2)}, loadavg1 now $l (limit $LMAX)"; return 0; }
export -f load_wait
SC=${SUITE_CACHE_DIR:-/home/boki/suite-cache}; DUR=$SC/durations.tsv; mkdir -p $SC; export DUR
CHECK_MAP=${CHECK_MAP:-}; CMAP_PY=${CMAP_PY:-/home/boki/bin/check-map.py}
NOCACHE_RE=${SUITE_NOCACHE_RE:-perf|bench|hitch|load|net-check|title-check}
CACHE_ON=0; [ "${SUITE_CACHE:-1}" != 0 ] && [ -s "$CHECK_MAP" ] && [ -f "$CMAP_PY" ] && CACHE_ON=1
fname() { echo "$1" | tr -c 'a-z0-9\n' _; }
# 11-13: NO-DISPLAY = NOT RUN. boki-worker-2's Xvfb :99 died ~11-11 05:30 and w2-dispatch runs Godot with DISPLAY=:99, so every
# flag w2 claimed came back "1 0" in ~1 s with "X11 Display is not available" on BOTH sides (0245 gate: 277/287 red, NEW-RED 0).
# A log matching NOTRUN_RE is rerun here like rc 126/127, a leftover is ignored by compare and counted in summary.txt.
NOTRUN_RE='Unable to create DisplayServer|X11 Display is not available'; export NOTRUN_RE
notrun() { grep -qsE "$NOTRUN_RE" $OUT/$1/$2.log; }; export -f notrun
[ -s $OUT/flags.txt ] || { { grep -ohE '"--[a-z0-9-]+-check"' $GW/tools/check_registry.gd $GW/scripts/main.gd | tr -d '"'; echo --check; } | sort -u > $OUT/flags.txt; echo "--simtest --seed=5" >> $OUT/flags.txt; }
# ---- result cache helpers (see header) ----
GODOT_ID="$GODOT_BIN $($GODOT_BIN --version 2>/dev/null | head -1) $(stat -c '%s-%Y' $GODOT_BIN 2>/dev/null)"
fpgen() { # side tree outfile: "flag<TAB>fingerprint" for every mapped flag; empty file on any failure (= nothing cached)
  python3 $CMAP_PY fingerprint --map "$CHECK_MAP" --repo "$2" --flags $OUT/flags.txt --godot "$GODOT_ID" $([ "${SUITE_CACHE_STRICT:-0}" = 1 ] && echo --strict) > "$3.tmp" 2>"$3.err" && mv "$3.tmp" "$3" || : > "$3"; }
cache_apply() { # side listfile: copy cached passes into OUT/<side> for the flags in listfile that have no result yet
  [ $CACHE_ON = 1 ] || return 0; local side=$1 list=$2 f fp n k=0; declare -A FP=()
  while IFS=$'\t' read -r f fp; do FP[$f]=$fp; done < $OUT/fp.$side.tsv
  while IFS= read -r f; do fp=${FP[$f]:-}; [ -n "$fp" ] || continue
    echo "$f" | grep -qE -- "$NOCACHE_RE" && continue
    n=$(fname "$f"); [ -f $OUT/$side/$n.rc ] && continue
    [ "$(cat $SC/$fp.rc 2>/dev/null)" = "0 0" ] || continue
    cp $SC/$fp.log $OUT/$side/$n.log 2>/dev/null || : > $OUT/$side/$n.log
    echo "[suite-cache] result reused (fingerprint ${fp:0:12}, stored $(date -r $SC/$fp.rc +%FT%TZ -u))" >> $OUT/$side/$n.log
    touch $OUT/$side/$n.cached; touch -c $SC/$fp.rc $SC/$fp.log; echo "0 0" > $OUT/$side/$n.rc; k=$((k+1))
  done < $list
  echo "suite-fast: cache reused $k $side results"; }
cache_store() { # after the suite: store every pass in OUT (server and worker runs) unless the tree changed meanwhile
  [ $CACHE_ON = 1 ] || return 0; local side T f fp fp2 n r c k=0; declare -A F1 F2
  for side in merge main; do T=$([ $side = main ] && echo $MW || echo $GW)
    fpgen $side $T $OUT/fp.$side.end.tsv; F1=(); F2=()
    while IFS=$'\t' read -r f fp; do F1[$f]=$fp; done < $OUT/fp.$side.tsv
    while IFS=$'\t' read -r f fp; do F2[$f]=$fp; done < $OUT/fp.$side.end.tsv
    while IFS= read -r f; do n=$(fname "$f"); fp=${F1[$f]:-}
      [ -n "$fp" ] && [ "$fp" = "${F2[$f]:-x}" ] || continue
      echo "$f" | grep -qE -- "$NOCACHE_RE" && continue
      [ -f $OUT/$side/$n.cached ] && continue
      [ -f $OUT/$side/$n.rc ] || continue; read r c < $OUT/$side/$n.rc; [ "$r $c" = "0 0" ] || continue
      [ -f $SC/$fp.rc ] && continue
      cp $OUT/$side/$n.log $SC/$fp.log.$$ 2>/dev/null && mv $SC/$fp.log.$$ $SC/$fp.log && echo "0 0" > $SC/$fp.rc.$$ && mv $SC/$fp.rc.$$ $SC/$fp.rc && k=$((k+1))
    done < $OUT/flags.txt
  done
  [ -f $DUR ] && [ "$(wc -l < $DUR)" -gt 7000 ] && { tail -n 6000 $DUR > $DUR.tmp.$$ && mv $DUR.tmp.$$ $DUR; }
  find $SC -maxdepth 2 -type f \( -name '*.rc' -o -name '*.log' \) -mtime +14 -delete 2>/dev/null
  echo "suite-fast: cache stored $k new passes"; }
# ---- main-tree cache (see header): main results (pass AND red) keyed by main tree sha + Godot id + flag
TC=$SC/main-tree; MTREE=""
mdirty() { git -C $MW status --porcelain 2>/dev/null | grep -vE '^\?\? .*\.(import|uid)$'; }   # godot --import sidecars are derived, not inputs
[ "${SUITE_TREE_CACHE:-1}" != 0 ] && [ -z "$(mdirty)" ] && MTREE=$(git -C $MW rev-parse 'HEAD^{tree}' 2>/dev/null)
tkey() { printf '%s|%s|%s' "$MTREE" "$GODOT_ID" "$1" | sha256sum | cut -c1-40; }
tree_apply() { # listfile: reuse stored main results for flags in listfile that have none yet
  [ -n "$MTREE" ] || return 0; local f n key k=0
  while IFS= read -r f; do n=$(fname "$f"); key=$(tkey "$f")
    [ -f $OUT/main/$n.rc ] || [ ! -s $TC/$key.rc ] && continue
    echo "$f" | grep -qE -- "$NOCACHE_RE" && continue
    cp $TC/$key.log $OUT/main/$n.log 2>/dev/null || : > $OUT/main/$n.log
    echo "[suite-cache] main result reused from main tree ${MTREE:0:12} (stored $(date -r $TC/$key.rc +%FT%TZ -u))" >> $OUT/main/$n.log
    cp $TC/$key.rc $OUT/main/$n.rc; touch $OUT/main/$n.cached; touch -c $TC/$key.rc $TC/$key.log; echo "$f" >> $OUT/main_tree_cached; k=$((k+1))
  done < $1
  echo "suite-fast: main-tree cache reused $k main results"; }
tree_store() { # after the suite: store every main result run in this suite (not cached, not not-run), if the tree is unchanged
  [ -n "$MTREE" ] && [ "$(git -C $MW rev-parse 'HEAD^{tree}')" = "$MTREE" ] && [ -z "$(mdirty)" ] || return 0
  local f n key k=0; mkdir -p $TC
  while IFS= read -r f; do n=$(fname "$f"); key=$(tkey "$f")
    [ -f $OUT/main/$n.rc ] && [ ! -f $OUT/main/$n.cached ] || continue
    grep -qE '^(125|126|127) ' $OUT/main/$n.rc && continue; notrun main $n && continue
    echo "$f" | grep -qE -- "$NOCACHE_RE" && continue
    cp $OUT/main/$n.log $TC/$key.log.$$ && mv $TC/$key.log.$$ $TC/$key.log && cp $OUT/main/$n.rc $TC/$key.rc.$$ && mv $TC/$key.rc.$$ $TC/$key.rc && k=$((k+1))
  done < $OUT/flags.txt
  echo "suite-fast: main-tree cache stored $k main results (tree ${MTREE:0:12})"; }
order() { # listfile: its flags longest first (median of the last 5 server runs in durations.tsv, timeouts included; unknown 60 s)
  [ "${SUITE_ORDER:-file}" = longest ] || { cat "$1"; return; }   # OFF by default, see LONGEST FIRST above
  python3 -c 'import collections, statistics, sys
d = collections.defaultdict(list)
for l in open(sys.argv[2], errors="replace"):
    p = l.split("\t")
    if len(p) > 2 and p[2].isdigit() and int(p[2]) >= 1: d[p[0]].append(int(p[2]))
fl = [l.rstrip("\n") for l in open(sys.argv[1]) if l.strip()]
fl.sort(key=lambda f: -statistics.median(d[f][-5:]) if d[f] else -60)
print("\n".join(fl))' "$1" $DUR 2>/dev/null || cat "$1"; }
# ---- early abort (see header): canary or MASS-RED -> summary.txt + coord/SUITE_ALERT (fleet-watch, stall-watch), exit 3
ALERT=${SUITE_ALERT:-/home/boki/coord/SUITE_ALERT}; SID=$(echo "$OUT" | md5sum | cut -c1-8); export SID
stop_suite() { { echo "flags: $(wc -l < $OUT/flags.txt)"; echo "$1"; echo "No NEW-RED/WORSE verdict: suite stopped, nothing cached. Logs: $OUT/merge, $OUT/main"; echo DONE; } > $OUT/summary.txt
  echo "$1 ($OUT)" > $ALERT; echo "suite-fast: $1"; exit 3; }
rm -f $OUT/BREAKER $OUT/NORETRY $OUT/ABORT $OUT/main_tree_cached $OUT/LOADCAP
run() { side=$1; flag=$2; T=$([ $side = main ] && echo $MW || echo $GW)
  n=$(echo "$flag" | tr -c 'a-z0-9\n' _); [ -f $OUT/ABORT ] && return
  if [ -f $OUT/$side/$n.rc ]; then   # done, except not-run results (126/127) and timeouts (retried unless too many)
    grep -qE "^(126|127) " $OUT/$side/$n.rc || notrun $side $n || { grep -q "^124 " $OUT/$side/$n.rc && [ ! -f $OUT/NORETRY ] && [ ! -f $OUT/BREAKER ]; } || return
  fi
  if [ $side = merge ] && [ -f $OUT/BREAKER ]; then
    [ -f $OUT/merge/$n.rc ] || { echo "suite-fast: not run, timeout breaker: $(cat $OUT/BREAKER)" > $OUT/merge/$n.log; echo "125 0" > $OUT/merge/$n.rc; }
    return; fi
  # 11-15 MEMORY GATE: several suites (merge lanes, merge-candidate) share hetzner; 23 Godot runs = 22G pushed it to 3G free and
  # Claude Code reaped shells. Wait (max 15 min) while MemAvailable < SUITE_MIN_FREE_MB (default 6000) before starting a run.
  for _w in $(seq 180); do [ $(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo) -ge ${SUITE_MIN_FREE_MB:-6000} ] && break; sleep 5; done
  # 11-15 LOAD GATE (header). A wait that hits its cap writes OUT/LOADCAP; for 10 min after that, runs do not wait again
  # (a box that stays loaded must not add 300 s to every run).
  if [ -z "$(find $OUT/LOADCAP -mmin -10 2>/dev/null)" ] && [ $(load1) -gt $LMAX ]; then
    load_wait ${SUITE_RUN_LOAD_WAIT:-300} "$side $flag" >&2; [ $(load1) -gt $LMAX ] && touch $OUT/LOADCAP; fi
  (set -o noclobber; echo server > $OUT/$side/$n.claim) 2>/dev/null || return   # pods (suite-pod) claim both sides
  X=$(mktemp -d /tmp/xdg.$SID.XXXX); t0=$(date +%s)
  (cd $T && XDG_DATA_HOME=$X timeout ${SUITE_RUN_TIMEOUT:-1200} xvfb-run -a $GODOT_BIN --rendering-driver opengl3 --audio-driver Dummy --path . -- $flag 2>&1 | timeout -k 5 1300 tail -c 20000000 >$OUT/$side/$n.log; exit ${PIPESTATUS[0]})  # cap 20 MB: Godot leak spam made 2 GB logs (11-11 disk full)
  rc=$?; rm -rf $X; secs=$(( $(date +%s) - t0 )); rm -f $OUT/$side/$n.cached
  echo $secs > $OUT/$side/$n.secs; printf '%s\t%s\t%s\tserver\t%s\n' "$flag" $side $secs "$(date -u +%FT%TZ)" >> $DUR
  echo "$rc $(grep -cE 'FAIL|SCRIPT ERROR' $OUT/$side/$n.log)" > $OUT/$side/$n.rc
  rm -f $OUT/merge/$n.claim.server $OUT/$side/$n.claim
  if [ $side = merge ] && [ $rc = 124 ]; then local nt nd
    nt=$(grep -l '^124 ' $OUT/merge/*.rc 2>/dev/null | wc -l); nd=$(ls $OUT/merge/*.rc 2>/dev/null | wc -l)
    [ $nt -ge ${SUITE_BREAK_TIMEOUTS:-12} ] && [ $((nt * 2)) -ge $nd ] && [ ! -f $OUT/BREAKER ] && \
      echo "$nt of $nd merge-side checks timed out at 1200 s by $(date -u +%H:%MZ): the candidate hangs" > $OUT/BREAKER
  fi
  if [ $side = merge ]; then local nf nd p   # MASS-RED: most merge results failed outright (timeouts, not-run excluded)
    nd=$(ls $OUT/merge/*.rc 2>/dev/null | wc -l)
    nf=$(( $(grep -LE '^(0 0|12[4-7] )' $OUT/merge/*.rc 2>/dev/null | wc -l) - $(grep -lsE "$NOTRUN_RE" $OUT/merge/*.log | wc -l) ))
    [ $nd -ge ${SUITE_MASSRED_MIN:-30} ] && [ $((nf * 100)) -ge $((nd * ${SUITE_MASSRED_PCT:-75})) ] && \
      (set -o noclobber; echo "MASS-RED: $nf of $nd merge-side results failed outright by $(date -u +%H:%MZ) (normal ~20%; the canary was green on this box, so the merge tree or a worker is broken)" > $OUT/ABORT) 2>/dev/null && \
      for p in $(pgrep -f -- "$GODOT_BIN"); do grep -qsz "^XDG_DATA_HOME=/tmp/xdg\.$SID\." /proc/$p/environ && kill $p; done
  fi
}
export -f run
export SC
red() { local n r fc; n=$(echo "$1" | tr -c 'a-z0-9\n' _); read r fc < $OUT/merge/$n.rc 2>/dev/null || return 1; [ "$r$fc" != 00 ]; }   # local: must not clobber the caller's loop var f
CANARY=${SUITE_CANARY:---check --base-check --aimkit-check --ability-check --boki-wisp-check --cam-framing-check --nook-check --race-check --roster-check --evo-check}
canary() { # run the canary on both trees; ENV-BROKEN when >= half are red on BOTH or exit codes contradict the checks' own verdicts
  local f n s r c v bad both=0 tot=0 mm=0
  for f in $CANARY; do grep -qxF -- "$f" $OUT/flags.txt && echo "$f"; done > $OUT/canary.txt
  [ -s $OUT/canary.txt ] || return 0
  { sed 's/^/merge /' $OUT/canary.txt; sed 's/^/main /' $OUT/canary.txt; } | nice -n 10 xargs -P $P -d '\n' -I{} bash -c 'run {}'
  local to; to=$(while IFS= read -r f; do n=$(fname "$f"); for s in merge main; do grep -qs '^124 ' $OUT/$s/$n.rc && echo "$s $f"; done; done < $OUT/canary.txt)
  if [ -n "$to" ]; then   # 11-15: a timed-out canary run means a loaded box more often than a broken tree: wait, rerun once
    echo "suite-fast: $(echo "$to" | wc -l) canary runs timed out (loadavg1 $(load1)), rerunning them once after the load gate"
    load_wait ${SUITE_RETRY_LOAD_WAIT:-${SUITE_LOAD_WAIT:-900}} "canary retry"; echo "$to" | nice -n 10 xargs -P $P -d '\n' -I{} bash -c 'run {}'; fi
  while IFS= read -r f; do n=$(fname "$f"); tot=$((tot + 1)); bad=0
    for s in merge main; do read r c < $OUT/$s/$n.rc; [ "$r$c" != 00 ] && bad=$((bad + 1))
      v=$(grep -oE 'failures: [0-9]+' $OUT/$s/$n.log | tail -1); v=${v#failures: }
      [ -n "$v" ] && [ $((r == 0)) != $((v == 0)) ] && mm=$((mm + 1)); done
    [ $bad = 2 ] && both=$((both + 1))
  done < $OUT/canary.txt
  echo "suite-fast: canary $both of $tot red on both trees, $mm of $((tot * 2)) runs exit != own verdict"
  [ $((both * 2)) -lt $tot ] && [ $mm -lt $tot ] && { rm -f $ALERT; return 0; }
  stop_suite "ENV-BROKEN: $both of $tot canary checks red on BOTH trees, $mm of $((tot * 2)) runs exit != the check's own 'failures: N' ($(date -u +%H:%MZ), $(( $(date +%s) - T0 )) s in, loadavg1 $(load1) of limit $LMAX; canary: $(tr '\n' ' ' < $OUT/canary.txt))"; }
RUND=$SC/running; mkdir -p $RUND; echo "$OUT" > $RUND/$$; trap 'rm -f $RUND/$$' EXIT   # live-suite count for the cap
nlive() { local f k=0; for f in $RUND/*; do [ -f "$f" ] || continue; [ "${f##*/}" = $$ ] && continue
  kill -0 "${f##*/}" 2>/dev/null && k=$((k + 1)) || rm -f "$f"; done; echo $k; }
_t=0; while [ "$LMAX" != 0 ] && [ $_t -lt ${SUITE_LOAD_WAIT:-900} ] && { [ $(load1) -gt $LMAX ] || [ $(nlive) -ge ${SUITE_MAX_SUITES:-3} ]; }; do sleep 5; _t=$((_t + 5)); done
[ $_t -ge ${SUITE_LOAD_WAIT:-900} ] && [ $(load1) -gt $LMAX ] && touch $OUT/LOADCAP   # gave up: no per-run waits for 10 min
echo "suite-fast: start gate ${_t}s: loadavg1 $(load1) (limit $LMAX), $(nlive) other suites live (cap ${SUITE_MAX_SUITES:-3})"
canary
[ "${SUITE_CANARY_ONLY:-0}" = 1 ] && { echo "suite-fast: SUITE_CANARY_ONLY, stopping after the canary ($(( $(date +%s) - T0 )) s)"; exit 0; }
order $OUT/flags.txt > $OUT/order.txt
if [ $CACHE_ON = 1 ]; then fpgen merge $GW $OUT/fp.merge.tsv; fpgen main $MW $OUT/fp.main.tsv; cache_apply merge $OUT/flags.txt; fi
# One suite owns the worker pointer at a time (two suites used to overwrite and delete each other's, 2026-11-06).
# A live owner keeps it; this suite then runs on the server alone. On exit we remove it only if it is still ours.
PTR=${SUITE_PTR:-/home/boki/suite-active}; PTRV="$OUT $GW $MW"
# Priority (SUITE_PRIORITY=1, set by merge-candidate.sh) takes the pointer from a non-priority owner (a worker job's
# suite); workers finish their current check into the old dir and move over. A suite that starts without the pointer
# keeps trying to take it every 60 s, so the PC/Mac join as soon as the other suite ends (2026-11-07: the 16:30
# candidate ran 2 h server-only because a job's suite held the pointer at its start and never re-checked).
take() { echo "$PTRV" > $PTR; echo $$ > $PTR.pid; echo "${SUITE_PRIORITY:-0}" > $PTR.prio; echo "suite-fast: took the worker pointer ($1)"; }
held() { [ -s $PTR ] && kill -0 "$(cat $PTR.pid 2>/dev/null)" 2>/dev/null; }
# Minutes the holder still needs: its unfinished checks / its finish rate over the last 10 min (999 = unknown).
eta() { local d tot done rate; d=$(cut -d' ' -f1 $PTR 2>/dev/null); [ -s "$d/flags.txt" ] || { echo 999; return; }
  tot=$(wc -l < $d/flags.txt); done=$(ls $d/merge/*.rc 2>/dev/null | wc -l)
  rate=$(find $d/merge $d/main -name '*.rc' -mmin -10 2>/dev/null | wc -l)
  [ $rate -gt 0 ] && echo $(( (tot - done) * 10 / rate + 3 )) || echo 999; }   # +3: its main-side reruns
# Waiting is cheaper than running without the PC/Mac when the holder is nearly done: a server-only suite takes
# ~2 h, a shared one ~1 h, so waiting up to WAIT_MAX (default 20) min for the workers wins.
WAIT_MAX=${WAIT_MAX:-20}
if held; then e=$(eta)
  if [ $e -le $WAIT_MAX ]; then echo "suite-fast: $(cut -d' ' -f1 $PTR) holds the workers, ~${e} min left: waiting for it"
    for i in $(seq 1 $((WAIT_MAX * 2 + 10))); do held || break; sleep 30; done; fi; fi
if ! held; then take free
elif [ "${SUITE_PRIORITY:-0}" = 1 ] && [ "$(cat $PTR.prio 2>/dev/null)" != 1 ]; then take "priority over $(cut -d' ' -f1 $PTR), its eta ~$(eta) min"
else echo "suite-fast: another suite ($(cut -d' ' -f1 $PTR)) owns the worker pointer (~$(eta) min left); server-only until it ends"
  ( while kill -0 $$ 2>/dev/null; do sleep 60; kill -0 $$ 2>/dev/null || exit; [ "$(cat $PTR 2>/dev/null)" = "$PTRV" ] && exit; held || { take "freed mid-run"; exit; }; done ) & fi
PODPIDS=""; PODS=${SUITE_PODS:-}; PODK=${SUITE_POD_KEY:-$HOME/.ssh/boki_s2_deploy}
pod_stop() { local p h; [ -n "$PODPIDS" ] || return 0; for p in $PODPIDS; do pkill -P $p 2>/dev/null; kill $p 2>/dev/null; done
  for h in $PODS; do h=${h%%:*}; timeout 30 ssh -i $PODK -o BatchMode=yes -o ConnectTimeout=10 $h "pkill -f -- '--path /root/mcshard/$(echo "$OUT" | md5sum | cut -c1-10)/'" 2>/dev/null; done
  PODPIDS=""; rm -f $OUT/merge/*.log.pod $OUT/main/*.log.pod; }
trap 'rm -f $RUND/$$; pod_stop; [ "$(cat $PTR 2>/dev/null)" = "$PTRV" ] && rm -f $PTR $PTR.pid $PTR.prio' EXIT
for p in $PODS; do h=${p%%:*}; sl=${p#*:}; [ "$sl" = "$p" ] && sl=8
  OUT=$OUT GW=$GW SUITE_POD_KEY=$PODK bash ${SUITE_POD_BIN:-/home/boki/bin/suite-pod} $h $sl > $OUT/pod-$h.log 2>&1 & PODPIDS="$PODPIDS $!"; done
# 1. merge side, every flag
nice -n 10 xargs -P $P -d '\n' -I{} bash -c 'run merge "{}"' < $OUT/order.txt
[ -f $OUT/ABORT ] && stop_suite "$(cat $OUT/ABORT)"
# wait for flags a worker still holds (max 25 min; then reclaim and run them here)
for i in $(seq 1 50); do ls $OUT/merge/*.claim >/dev/null 2>&1 || break; sleep 30; done
rm -f $OUT/merge/*.claim
pod_stop
NR=$(grep -lE '^(126|127) ' $OUT/merge/*.rc $OUT/main/*.rc 2>/dev/null | wc -l); [ $NR -gt 0 ] && echo "suite-fast: $NR worker results were not-run (rc 126/127), rerun here"
NT=$(grep -l '^124 ' $OUT/merge/*.rc 2>/dev/null | wc -l); [ $NT -gt ${SUITE_RETRY_TIMEOUTS:-8} ] && echo "$NT timeouts" > $OUT/NORETRY
[ -f $OUT/BREAKER ] && echo "suite-fast: BREAKER $(cat $OUT/BREAKER)"
nice -n 10 xargs -P $P -d '\n' -I{} bash -c 'run merge "{}"' < $OUT/order.txt
[ -f $OUT/ABORT ] && stop_suite "$(cat $OUT/ABORT)"
# 2. main side, only where the merge is red (workers already ran main for their own reds)
: > $OUT/main_needed; [ -f $OUT/BREAKER ] || while read f; do red "$f" && echo "$f" >> $OUT/main_needed; done < $OUT/flags.txt
tree_apply $OUT/main_needed; cache_apply main $OUT/main_needed
order $OUT/main_needed > $OUT/main_order.txt
# pods join the main side too (passes only); the server takes what they leave, then waits for their claims (max 25 min)
if [ -s $OUT/main_order.txt ]; then for p in $PODS; do h=${p%%:*}; sl=${p#*:}; [ "$sl" = "$p" ] && sl=8
  OUT=$OUT GW=$GW MW=$MW SUITE_POD_KEY=$PODK bash ${SUITE_POD_BIN:-/home/boki/bin/suite-pod} $h $sl main > $OUT/pod-$h.main.log 2>&1 & PODPIDS="$PODPIDS $!"; done; fi
nice -n 10 xargs -P $P -d '\n' -I{} bash -c 'run main "{}"' < $OUT/main_order.txt
if [ -n "$PODPIDS" ]; then
  for i in $(seq 1 50); do ls $OUT/main/*.claim >/dev/null 2>&1 || break; sleep 30; done
  pod_stop; rm -f $OUT/main/*.claim
  while IFS= read -r f; do [ -f $OUT/main/$(fname "$f").rc ] || echo "$f"; done < $OUT/main_order.txt > $OUT/main_left.txt
  [ -s $OUT/main_left.txt ] && echo "suite-fast: $(wc -l < $OUT/main_left.txt) main checks the pods left (red/timeout there) rerun here"
  nice -n 10 xargs -P $P -d '\n' -I{} bash -c 'run main "{}"' < $OUT/main_left.txt
fi
cache_store; tree_store
# 3. compare
cd $OUT
while read flag; do n=$(echo "$flag" | tr -c 'a-z0-9\n' _); mr=.; mf=.
  read gr gf < merge/$n.rc; gs=$([ "$gr$gf" = 00 ] && echo pass || echo red); ms=pass
  if [ -f main/$n.rc ] && ! notrun main $n; then read mr mf < main/$n.rc; [ "$mr$mf" != 00 ] && ms=red; fi
  t=same; [ $ms = pass ] && [ $gs = red ] && t=NEW-RED; [ $ms = red ] && [ $gs = pass ] && t=FIXED
  [ $ms = red ] && [ $gs = red ] && [ "$gf" -gt "$mf" ] 2>/dev/null && t=WORSE
  echo "$t $flag main=$mr/$mf merge=$gr/$gf"
done < flags.txt > compare.txt
{ echo "flags: $(wc -l < flags.txt)"; echo "NEW-RED: $(grep -c ^NEW-RED compare.txt)  WORSE: $(grep -c ^WORSE compare.txt)  FIXED: $(grep -c ^FIXED compare.txt)  red on merge: $(wc -l < main_needed)"
  echo "cached: $(ls merge/*.cached main/*.cached 2>/dev/null | wc -l)  pod passes: $(ls merge/*.pod 2>/dev/null | wc -l) merge, $(ls main/*.pod 2>/dev/null | wc -l) main"
  [ -s main_tree_cached ] && echo "main-tree cache (tree ${MTREE:0:12}): $(wc -l < main_tree_cached) main results reused, $(while IFS= read -r f; do read r c < main/$(fname "$f").rc; [ "$r$c" != 00 ] && echo; done < main_tree_cached | wc -l) of them red"
  nd=$(grep -lsE "$NOTRUN_RE" merge/*.log main/*.log | wc -l); [ $nd -gt 0 ] && echo "NOT-RUN (no display, Godot never started): $nd results; this suite is INVALID"
  [ -f BREAKER ] && echo "BREAKER: $(cat BREAKER); main side skipped, remaining merge checks not run"
  grep -E "^(NEW-RED|WORSE|FIXED)" compare.txt; echo DONE; } > summary.txt
