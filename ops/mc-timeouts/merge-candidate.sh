#!/bin/bash
# merge-candidate.sh: runs on the hetzner box as `boki` from cron, with no Claude usage.
# 1. Lists every branch posted READY in briefs/EXT_TO_MAIN.md that isn't on main (newest posted commit per branch).
# 2. Merges them onto origin/main in posting order in a private worktree. Credits/registry files are unioned,
#    generated docs are regenerated, and any branch with a real code conflict is skipped and reported.
# 3. Runs every check flag on main and on the candidate side by side (8 at a time, nice 10).
# 4. Pushes the result as ext/mc-<UTC stamp> with MERGE_REPORT.md (merged / skipped / NEW-RED / WORSE / FIXED)
#    and prunes its old report branches (11-12, mc_prune): of the ext/mc-<YYYYMMDD-HHMM> branches on origin the newest 2 are kept,
#    older ones (superseded) and any already merged into origin/main are deleted. Other ext/mc-* names (ext/mc-integ-*,
#    ext/mc-fix-*: hand-made integration branches) are never touched. `merge-candidate.sh --prune` runs only that step.
#    The integrator (S5) or the owner decides what lands on main.
# 5. Also (own sections in MERGE_REPORT.md, neither can fail the run): real-GPU perf hooks on main and candidate via the
#    jobq GPU workers (gpu-perf-report, waits up to 90 min; skipped when no worker is alive, see suite-plan), and a Windows/macOS export dry-run of the candidate
#    (release-dryrun). The report is also published on the private reports repo (OrriBogdan2/project-boki-reports) (report-publish).
# Skips the run if the READY set hasn't changed since the last run, or if a run is already going.
# Exclusions (superseded, rejected or WIP branches): ~/bin/merge-exclude.txt, one branch per line.
#
# 11-12 speed-up (the 20261111-2230 pass took 14 h for 105 merges; see suite-fast.sh, mc-gate, suite-pod):
# - COMPILE GATE: ~/bin/mc-gate (real binary, `--check`, after --import) replaces `godot --quit` through the FIFO wrapper,
#   which queued for its whole timeout on the loaded box and passed a candidate with parse errors. A broken candidate is
#   no longer the end of the pass: the merged branch(es) that last touched the failing scripts are dropped and the
#   candidate is rebuilt (round 1); if it still fails, the first breaking merge is bisected (first-parent merges, import +
#   gate per step). At most MC_GATE_ROUNDS (3) rounds, then exit 3 as before. Dropped branches show as
#   "SKIPPED <b> <sha> breaks compile ...".
# - CONFLICT CACHE ~/.mc_conflicts ("branch sha main-sha epoch kind files"): a branch that conflicted (or broke the compile)
#   at the same sha is skipped without a merge attempt while it is < 24 h old and main has not touched those files since.
#   Approximation: a conflict with another READY branch that later drops out is retried only when the entry expires.
# - In-memory merges (git merge-tree + commit-tree): conflicts are found in ~0.05 s and clean merges never write the
#   ~20 GB-of-assets worktree; one checkout at the end (11-12 test: the worktree loop took 51 min for 1668 branches).
# - "merged*" no longer hides git errors: a merge that fails without conflicted files is aborted and SKIPPED "git error".
# - Rebuild after a drop resumes from the commit before the earliest dropped merge (11-12 test: full rebuild took 17 min).
# - Disk guard: < MC_MIN_FREE_GB (15) free in $HOME skips the run (11-11 merges ran out of disk mid-loop).
# - Worktrees are reused (checkout -f + clean, .godot kept) so --import is incremental (~2.5 min, was 7 min x 2 serial);
#   the main tree imports in the background during the merge loop.
# - Superseded READY copies are archived first (branch-archive --superseded --days 1 --ready-only --apply: archive/ tag +
#   merge-exclude with reason, nothing deleted; MC_ARCHIVE=0 disables).
# - POD SHARDS: reachable, idle pods from MC_PODS / ~/.mc_pods (default "rpc3:10 rpc5:10") get SUITE_PODS (suite-pod).
#   With pods there is no suite-plan wait for a GPU worker. gpu-perf-report runs in the background during the suite.
# - TEST MODE MC_TAG=<tag>: own lock, trees (~/wt-mc-<tag>, ~/wt-mc-main-<tag>), OUT ~/mc-<tag>, tmp /tmp/mc-<tag>,
#   private worker pointer (the Mac/PC keep serving the real suite-active), pushes ext/mc-<tag>-<stamp> only; no
#   ~/.mc_last/.mc_branch, no prune, no report-publish, no LOG.md, no archiving, no GPU perf unless MC_GPU=1. Server
#   parallelism MC_P (default 6, test 3).
set -u
TAG=${MC_TAG:-}; LOCK=/tmp/merge-candidate.v2.lock; [ -n "$TAG" ] && LOCK=/tmp/merge-candidate.$TAG.lock
# Lock via flock -o so child processes (Xvfb/godot) never inherit the lock fd: an orphaned child held the old
# /tmp/merge-candidate.lock for hours on 11-09 and blocked every run. v2 lock file sidesteps those orphans.
if [ -z "${MC_LOCKED:-}" ]; then
  MC_LOCKED=1 flock -n -o -E 75 $LOCK "$0" "$@"; rc=$?
  [ $rc -eq 75 ] && echo "$(date -u +%FT%TZ) already running (lock held; skipped tick)"
  exit $rc
fi
# Release crunch: while ~/release-hold exists (coordinator creates it, removes it after SHIPPED; ignored after 12 h)
# the candidate run skips so its suite does not take the box and the remote workers from the release gate.
if [ -f ~/release-hold ] && [ $(( $(date +%s) - $(stat -c %Y ~/release-hold) )) -lt 43200 ]; then
  echo "$(date -u +%FT%TZ) release hold ($(head -c 80 ~/release-hold)); skipped"; exit 0; fi
REPO=~/project-boki; EXCL=~/bin/merge-exclude.txt; KEYF=~/.ssh/boki_s2_deploy
if [ -n "$TAG" ]; then WT=~/wt-mc-$TAG; OUT=~/mc-$TAG; MWD=~/wt-mc-main-$TAG; TMPD=/tmp/mc-$TAG; CC=~/.mc_conflicts.$TAG; PTR=/tmp/mc-$TAG-ptr; PRIO=0; P=${MC_P:-3}
else WT=~/wt-mc; OUT=~/mc; MWD=~/wt-mc-main2; TMPD=/tmp/mc-cron; CC=~/.mc_conflicts; PTR=/home/boki/suite-active; PRIO=1; P=${MC_P:-6}; fi
MW=${MC_MAIN_WT:-$MWD}; mkdir -p $TMPD $OUT
mc_prune() {  # keep the newest 2 ext/mc-<stamp> report branches; delete older (superseded) and merged ones (never the newest)
  local all keep b n=0
  all=$(git -C $REPO ls-remote --heads origin 'refs/heads/ext/mc-*' | cut -f2 | sed 's|refs/heads/||' | grep -E '^ext/mc-[0-9]{8}-[0-9]{4}$' | sort -r)
  for b in $all; do n=$((n+1))
    if [ $n -gt 2 ]; then gitnet -C $REPO push -q origin --delete "$b" && echo "pruned $b (superseded)"
    elif [ $n -gt 1 ] && git -C $REPO merge-base --is-ancestor "origin/$b" origin/main 2>/dev/null; then
      gitnet -C $REPO push -q origin --delete "$b" && echo "pruned $b (merged)"; fi
  done
}
[ "${1:-}" = --prune ] && { mc_prune; exit 0; }
# 11-12: no git auto-maintenance inside the run. Every merge commit ran `maintenance run --auto` -> `gc --auto`, and the
# thousands of loose objects a merge pass writes (46k seen, threshold 6.7k) kept starting cruft repacks of the ~20 GB repo
# (packs 18 -> 52 in one afternoon) that competed with the merges. One niced `gc --auto` runs after the push (cron mode).
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=gc.auto GIT_CONFIG_VALUE_0=0 GIT_CONFIG_KEY_1=maintenance.auto GIT_CONFIG_VALUE_1=false
TS=$(date -u +%Y%m%d-%H%M); T0=$(date +%s); TP=$T0; TIMING=""
ph() { TIMING="$TIMING $1 $(( ($(date +%s) - TP) / 60 ))m,"; TP=$(date +%s); echo "$(date -u +%FT%TZ) phase $1 done"; }
FREE=$(df -BG --output=avail $HOME | tail -1 | tr -dc 0-9)
[ "${FREE:-0}" -lt ${MC_MIN_FREE_GB:-15} ] && { echo "$TS only ${FREE}G free in $HOME (< ${MC_MIN_FREE_GB:-15}G); skipped"; exit 1; }
ARCH=""
if [ -z "$TAG" ] && [ "${MC_ARCHIVE:-1}" = 1 ]; then
  ARCH=$(cd $REPO && timeout 900 python3 ~/bin/branch-archive --superseded --days 1 --ready-only --apply 2>&1 | tail -1); echo "$TS superseded: $ARCH"; fi
cd $REPO || exit 1; for i in 1 2 3 4; do gitnet fetch -q --prune origin && break; [ $i = 4 ] && { echo "$TS fetch failed x4"; exit 1; }; echo "$TS fetch retry $i"; git remote prune origin >/dev/null 2>&1; sleep $((i*20)); done
M=$(git rev-parse origin/main); NOW=$(date +%s)

# 1. open READY list
git show origin/ext/agent-briefs:briefs/EXT_TO_MAIN.md | grep -iE "READY" \
 | grep -oE "ext/[A-Za-z0-9._/-]+[\` ]+@? ?[0-9a-f]{7,40}" | sed -E 's/[` @]+/ /g' \
 | awk '{b=$1; sub(/[.,;:]+$/,"",b); last[b]=$2; if(!(b in o)){o[b]=++n; nm[n]=b}} END{for(i=1;i<=n;i++) print nm[i], last[nm[i]]}' > $TMPD/mc_all
: > $TMPD/mc_open
while read b h; do
  grep -qxF "$b" "$EXCL" 2>/dev/null && continue
  c=$(git rev-parse -q --verify "$h^{commit}") || continue
  git merge-base --is-ancestor "$c" origin/main && continue
  echo "$b $c" >> $TMPD/mc_open
done < $TMPD/mc_all
# merge-first.txt (one branch per line): those branches merge before all others (release integrations),
# so their conflicts land on the smaller branches instead of skipping the release.
FIRST=~/bin/merge-first.txt
if [ -s "$FIRST" ]; then awk 'NR==FNR{if($0!~/^#/&&NF)f[$1]=1;next} ($1 in f){print;next} {r[++n]=$0} END{for(i=1;i<=n;i++)print r[i]}' "$FIRST" $TMPD/mc_open > $TMPD/mc_open2 && mv $TMPD/mc_open2 $TMPD/mc_open; fi
[ -z "$TAG" ] && cp $TMPD/mc_all /tmp/mc_all.new && mv /tmp/mc_all.new /tmp/mc_all && cp $TMPD/mc_open /tmp/mc_open.new && mv /tmp/mc_open.new /tmp/mc_open   # stall-watch reads these
KEY=$( (echo $M; cat $TMPD/mc_open) | sha1sum | cut -c1-12)
[ -z "$TAG" ] && [ "$KEY" = "$(cat ~/.mc_last 2>/dev/null)" ] && { echo "$TS no change"; exit 0; }
[ -s $TMPD/mc_open ] || { [ -z "$TAG" ] && echo "$KEY" > ~/.mc_last; echo "$TS nothing READY"; exit 0; }

# 2. merge (worktrees reused: .godot survives, so the imports below are incremental)
prep_wt() {  # TREE: detached at origin/main, clean (ignored files such as .godot kept)
  if [ -f "$1/.git" ] && git -C "$1" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    git -C "$1" merge --abort >/dev/null 2>&1; git -C "$1" checkout -qf --detach $M && git -C "$1" clean -fdq && return 0; fi
  [ -d "$1" ] && { git -C $REPO worktree remove --force "$1" 2>/dev/null || rm -rf "$1"; }; git -C $REPO worktree prune
  git -C $REPO worktree add -q --detach "$1" $M
}
import_remote() {  # v7 TREE POD: import on a RunPod CPU pod (503 GB RAM, same 4.6.2 binary) and copy the result back. The box
  # OOM-kills local imports while other sessions' suites hold its RAM (20:16Z: 4 GB free, imports killed 4x). Tree minus .git is
  # rsynced to /root/mcimp/<tree name> (seeded from a suite-pod shard on first use), imported there, and synced back incl. the
  # rewritten *.import files and .godot. Any failure returns 1 and import_tree falls back to the local (memory-gated) import.
  local R=/root/mcimp/$(basename "$1") S="ssh -i $KEYF -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=4" t0=$(date +%s)
  timeout 120 $S $2 "[ -d $R ] || { mkdir -p /root/mcimp; s=\$(ls -d /root/mcshard/*/gw 2>/dev/null | head -1); [ -n \"\$s\" ] && cp -a \$s $R; mkdir -p $R; }" || return 1
  timeout 900 rsync -a --delete --exclude=.git -e "$S" "$1/" "$2:$R/" || return 1
  timeout 1800 $S $2 "cd $R && LP_NUM_THREADS=2 nice -n 10 timeout 1700 /opt/godot/godot-bin --headless --audio-driver Dummy --path . --import >/dev/null 2>&1" || return 1
  timeout 900 rsync -a --exclude=.git -e "$S" "$2:$R/" "$1/" || return 1
  echo "$(date -u +%FT%TZ) import of $1 done on $2 in $(( $(date +%s) - t0 ))s" >&2
}
import_tree() {  # 11-12: the box OOM-kills big Godot imports (cron cgroup oom_kill 74); a killed import (rc 137) is retried, and
  # import_ok exits the run instead of gating/bisecting a half-imported tree (that blames innocent branches or main)
  # v6: the kills are box-wide (global OOM, 6+ suites from other sessions), so each try first waits up to 20 min for
  # MemAvailable >= MC_IMPORT_MEM_GB (default 8) instead of starting into a full box; 4 tries, 120 s apart.
  local i r w p; for p in ${MC_IMPORT_PODS-rpc5 rpc3}; do import_remote "$1" $p && return 0
    echo "$(date -u +%FT%TZ) import of $1 on $p failed, next" >&2; done
  for i in 1 2 3 4; do
    for w in $(seq 120); do [ $(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo) -ge ${MC_IMPORT_MEM_GB:-8} ] && break; sleep 10; done
    (cd "$1" && LP_NUM_THREADS=2 timeout 1800 nice -n 10 /opt/godot/godot-bin --headless --audio-driver Dummy --path . --import >/dev/null 2>&1); r=$?
    [ $r = 137 ] || return $r; echo "$(date -u +%FT%TZ) import of $1 killed (OOM?), try $i, MemAvailable $(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)G" >&2; sleep 120; done; return $r; }
import_ok() { import_tree "$1" || { echo "$TS import of $1 failed (rc $?), no gate verdict"; exit 4; }; }
prep_wt $MW; (import_tree $MW) & MWIMP=$!
prep_wt $WT || { echo "$TS cannot prepare $WT"; exit 1; }
cd $WT; git config user.name "Claude"; git config user.email "noreply@anthropic.com"
is_union() { case "$1" in *check_registry*|*CHECKS*|*.gitignore|docs/DEBT.md|docs/ASSET_CREDITS.md|*STATUS*.md) return 0;; esac; return 1; }
is_generated() { case "$1" in docs/wiki/*|*Rules.md|*.uid) return 0;; esac; return 1; }
R=$OUT/report.txt; : > $R
declare -A CCC=() DROP=()   # conflict cache by branch: "sha mainsha epoch kind files,"; DROP: branches dropped by the gate
[ -f $CC ] || { [ -n "$TAG" ] && [ -f ~/.mc_conflicts ] && cp ~/.mc_conflicts $CC; }
[ -f $CC ] && while read b c m t k f; do [ $((NOW - t)) -lt 86400 ] && CCC[$b]="$c $m $t $k ${f:-}"; done < $CC
cc_save() { local b; for b in "${!CCC[@]}"; do echo "$b ${CCC[$b]}"; done > $CC.new && mv $CC.new $CC; }
merge_all() {  # [LINE COMMIT]: resume at line LINE of mc_open from COMMIT (the candidate state after line LINE-1); R has one line per mc_open line
  cd $WT; git merge --abort >/dev/null 2>&1
  if [ -n "${1:-}" ]; then git checkout -qf --detach $2 && git clean -fdq; head -n $(( $1 - 1 )) $R > $R.k; mv $R.k $R; tail -n +$1 $TMPD/mc_open > $TMPD/mc_rest
  else git checkout -qf --detach $M && git clean -fdq; : > $R; cp $TMPD/mc_open $TMPD/mc_rest; fi
  local b c U f bad cc cm ct ck cf MT T CUR CUR2 nc=0; CUR=$(git rev-parse HEAD)
  # The candidate is built in memory: CUR is the tip; a clean merge is git merge-tree + commit-tree (no worktree writes:
  # the repo is ~20 GB of assets and a worktree merge cost ~5 s under load), conflicts outside the union/generated files are
  # skipped from the same merge-tree result, and only merges that need the union/generated auto-resolve touch the worktree.
  # The worktree is checked out at CUR once at the end. Same ort machinery as `git merge`, same merge commits.
  while read b c; do
    [ -n "${DROP[$b]:-}" ] && { echo "SKIPPED  $b ${c:0:8} ${DROP[$b]}" >> $R; continue; }
    git merge-base --is-ancestor "$c" $CUR && { echo "already  $b" >> $R; continue; }
    if [ -n "${CCC[$b]:-}" ]; then read cc cm ct ck cf <<< "${CCC[$b]}"
      if [ "$cc" = "$c" ] && { [ "$cm" = "$M" ] || { [ -n "$cf" ] && git diff --quiet $cm $M -- ${cf//,/ } 2>/dev/null; }; }; then
        echo "SKIPPED  $b ${c:0:8} $(case $ck in compile) echo "breaks compile";; slow) echo "merge too slow";; *) echo conflicts;; esac) (cached $(( (NOW - ct) / 60 )) min ago, main unchanged there):${cf//,/ }" >> $R; nc=$((nc+1)); continue; fi
      unset "CCC[$b]"; fi
    # 1) against main alone (~0.5-1 s): a branch that conflicts with main itself cannot reach main without a rebase, so it is
    # skipped before the merge into the candidate, which is slow (300 in-memory merges give git several merge bases: 15-30 s each)
    MT=$(timeout ${MC_MERGE_TO:-30} git merge-tree --write-tree --name-only --no-messages $M "$c" 2>/dev/null)
    if [ $? = 1 ]; then bad=""; for f in $(echo "$MT" | tail -n +2); do is_union "$f" || is_generated "$f" || bad="$bad $f"; done
      [ -n "$bad" ] && { echo "SKIPPED  $b ${c:0:8} conflicts with main:$bad" >> $R; bad=${bad# }; CCC[$b]="$c $M $NOW conflict ${bad// /,}"; continue; }; fi
    # 2) into the candidate
    MT=$(timeout ${MC_MERGE_TO:-30} git merge-tree --write-tree --name-only --no-messages $CUR "$c" 2>/dev/null); U=$?
    # a 3-way merge that needs >30 s is a branch ~1000+ commits behind main with ~1000+ files changed (11-12: single merges ran
    # 10 min); skipped like a conflict with the reason, so the owner rebases it instead of every pass paying for it
    if [ $U = 124 ]; then echo "SKIPPED  $b ${c:0:8} merge too slow (>${MC_MERGE_TO:-30}s, stale base: $(git rev-list --count $(git merge-base $c $M)..$M) commits behind main), rebase it" >> $R
      CCC[$b]="$c $M $NOW slow"; continue; fi
    if [ $U = 0 ]; then T=$(echo "$MT" | head -1)
      if CUR2=$(git commit-tree $T -p $CUR -p $c -m "Merge $b ${c:0:8} (READY)" 2>/dev/null); then CUR=$CUR2; echo "merged   $b ${c:0:8}" >> $R
      else echo "SKIPPED  $b ${c:0:8} git error (commit-tree failed)" >> $R; fi; continue; fi
    if [ $U != 1 ]; then echo "SKIPPED  $b ${c:0:8} git error (merge-tree rc $U)" >> $R; continue; fi
    bad=""; for f in $(echo "$MT" | tail -n +2); do is_union "$f" || is_generated "$f" || bad="$bad $f"; done
    if [ -n "$bad" ]; then echo "SKIPPED  $b ${c:0:8} conflicts:$bad" >> $R; bad=${bad# }; CCC[$b]="$c $M $NOW conflict ${bad// /,}"; continue; fi
    # only union/generated files conflict: real merge in the worktree with the auto-resolve
    git checkout -qf --detach $CUR
    git merge -q --no-ff --no-edit -m "Merge $b ${c:0:8} (READY)" "$c" >/dev/null 2>&1
    U=$(git diff --name-only --diff-filter=U)
    if [ -z "$U" ]; then git merge --abort >/dev/null 2>&1; git reset -q --hard $CUR; echo "SKIPPED  $b ${c:0:8} git error (merge failed without conflicted files)" >> $R; continue; fi
    bad=""
    for f in $U; do
      if is_union "$f"; then git show :1:"$f" >$TMPD/b 2>/dev/null || :>$TMPD/b; git show :2:"$f" >$TMPD/o; git show :3:"$f" >$TMPD/t
        git merge-file --union $TMPD/o $TMPD/b $TMPD/t; cp $TMPD/o "$f"; git add "$f"
      elif is_generated "$f"; then git checkout --ours -- "$f" 2>/dev/null; git add "$f"
      else bad="$bad $f"; fi
    done
    if [ -n "$bad" ]; then git merge --abort; echo "SKIPPED  $b ${c:0:8} conflicts:$bad" >> $R; bad=${bad# }; CCC[$b]="$c $M $NOW conflict ${bad// /,}"
    elif git commit -q --no-edit; then CUR=$(git rev-parse HEAD); echo "merged*  $b ${c:0:8} (registry/credits/generated auto-resolved)" >> $R
    else git merge --abort >/dev/null 2>&1; git reset -q --hard $CUR; echo "SKIPPED  $b ${c:0:8} git error (commit failed)" >> $R; fi
  done < $TMPD/mc_rest
  git checkout -qf --detach $CUR && git clean -fdq
  # 11-11: union merges can duplicate "--flag": keys in the registry -> parse error -> the whole suite times out (10 h stuck gate)
  if [ -f tools/check_registry.gd ] && python3 ~/bin/registry-dedupe tools/check_registry.gd >> $R; then git add tools/check_registry.gd; git commit -q -m "Dedupe check registry keys after union merges"; fi
  python3 tools/gen_wiki.py >/dev/null 2>&1; git add -A docs; git diff --cached --quiet || git commit -q -m "Regenerate docs for the merge candidate"
  cc_save; echo "$(date -u +%FT%TZ) merge: $(grep -c '^merged' $R) merged, $(grep -c ^SKIPPED $R) skipped ($nc from the conflict cache)"
}
merge_all; ph merge
[ -n "$TAG" ] && [ "${MC_STOP_AFTER:-}" = merge ] && { echo "$TS stop after merge (MC_STOP_AFTER): $TIMING"; exit 0; }   # timing tests
HEALTH=$(python3 tools/health.py --strict 2>&1 | tail -1)

# 2b. compile gate + culprit drop
merges() { git -C $WT log --first-parent --merges --reverse --format='%H %s' $M..HEAD; }   # "<sha> Merge <branch> <c8> (READY)"
last_touchers() {  # FILES...: per file, the last merged branch whose merge brought a change to it (union files excluded)
  local f C x b; for f in "$@"; do is_union "$f" && continue
    merges | while read C x b x; do git -C $WT diff --quiet $C^1 $C -- "$f" || echo "$b"; done | tail -1; done | sort -u; }
bisect_merge() {  # first merge whose prefix does not compile; empty if main itself fails or nothing found
  local -a L; local lo=0 hi n mid H; mapfile -t L < <(merges); n=${#L[@]}; hi=$n; H=$(git -C $WT rev-parse HEAD)
  [ $n -gt 0 ] || return 0
  git -C $WT checkout -qf --detach $M; import_ok $WT; ~/bin/mc-gate $WT 300 >/dev/null || { git -C $WT checkout -qf --detach $H; echo "MAIN"; return 0; }
  while [ $((hi - lo)) -gt 1 ]; do mid=$(( (lo + hi) / 2 )); git -C $WT checkout -qf --detach ${L[mid-1]%% *}; import_ok $WT
    if ~/bin/mc-gate $WT 300 >/dev/null; then lo=$mid; else hi=$mid; fi; done
  git -C $WT checkout -qf --detach $H; set -- ${L[hi-1]}; echo "$3"; }
ROUND=0; GATE=""
while :; do
  import_ok $WT; G=$(~/bin/mc-gate $WT 300); GRC=$?; GATE="$GATE r$ROUND: $(echo "$G" | head -1);"; echo "$(date -u +%FT%TZ) gate round $ROUND: $(echo "$G" | head -1)"
  [ $GRC = 0 ] && break
  echo "$G" | sed 1d | sed 's/^/    /' | cut -c1-220
  ROUND=$((ROUND + 1)); FILES=$(echo "$G" | sed -n 's/^FILES //p'); CUL=""; HOW=""
  if [ $ROUND -le ${MC_GATE_ROUNDS:-6} ]; then  # v8: FILES fast path every round (2 min) instead of round 1 only; a wrong guess costs one round
    [ -n "$FILES" ] && { CUL=$(last_touchers $FILES); HOW="last merge touching $FILES"; }
    [ -z "$CUL" ] && { CUL=$(bisect_merge); HOW="bisected first breaking merge"; }
  fi
  if [ -z "$CUL" ] || [ "$CUL" = MAIN ]; then
    { echo "PARSE BROKEN, suite skipped ($([ "$CUL" = MAIN ] && echo "origin/main itself fails the gate" || echo "no culprit after $ROUND rounds")):"; echo "$G"; } >> $R
    [ -z "$TAG" ] && echo "$(date -u +%FT%TZ) merge-candidate: candidate does not compile, suite skipped: $(echo "$G" | sed -n 2p | cut -c1-140)" >> /home/boki/coord/LOG.md
    echo "$TS gate failed: $(echo "$G" | head -1)"; exit 3; fi
  # rebuild from just before the earliest dropped merge (the merges before it are unchanged), not from main
  K=""; KC=""; for b in $CUL; do k=$(awk -v b="$b" '$1==b{print NR; exit}' $TMPD/mc_open); kc=$(merges | awk -v b="$b" '$3==b{print $1; exit}')
    [ -n "$k" ] && [ -n "$kc" ] && { [ -z "$K" ] || [ $k -lt $K ]; } && { K=$k; KC=$(git -C $WT rev-parse $kc^1); }; done
  for b in $CUL; do c=$(awk -v b="$b" '$1==b{print $2}' $TMPD/mc_open)
    DROP[$b]="breaks compile (gate round $ROUND, $HOW): $(echo "$G" | sed -n 2p | cut -c1-120)"; CCC[$b]="$c $M $NOW compile $(echo $FILES | tr ' ' ,)"
    echo "$(date -u +%FT%TZ) gate: dropping $b ($HOW)"; done
  merge_all $K $KC
done
ph gate

# 3. suite: merge-first, shared with remote workers (boki-worker.sh) and pods (suite-pod) via suite-fast.sh
S=$OUT/suite; rm -rf $S; mkdir -p $S
# 3-pre. affected-only scope (~/bin/check-map.py, static analysis, no Claude usage). FULL_SUITE=1 runs every flag.
# Any failure leaves $S/flags.txt absent, so suite-fast.sh builds the full list itself (the old behaviour).
SCOPE="Suite scope: full (FULL_SUITE=1 or check-map unavailable)"
HEADSHA=$(git -C $WT rev-parse HEAD); LP=$OUT/last-pass.tsv; GID=$(stat -c '%s-%Y' /opt/godot/godot-bin)
if [ "${FULL_SUITE:-0}" != 1 ]; then
  if python3 ~/bin/check-map.py build --repo $MW --out $S/check_map.json >$S/check_map.log 2>&1 \
     && python3 ~/bin/check-map.py affected --map $S/check_map.json --base $M --head $HEADSHA --repo $WT --explain >$S/flags.sel 2>$S/affected.why \
     && [ -s $S/flags.sel ]; then
    mv $S/flags.sel $S/flags.txt
    SCOPE="Suite scope: affected checks only, $(wc -l < $S/flags.txt) of $(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["flags"]))' $S/check_map.json) (smoke set always on; FULL_SUITE=1 for everything). Why: affected.why on the box."
    # 3-pre-b (11-13). Of those, skip flags unchanged since their last candidate PASS: $LP holds "flag<TAB>head<TAB>godot id"
    # of the latest candidate where each flag passed (a red drops its line). A flag is skipped only when check-map affected
    # from that head to this one leaves it out and the Godot binary is the same. Like the scope above, skipped flags are not
    # in compare: their candidate side is unchanged since a pass, so they cannot be NEW-RED/WORSE.
    if [ -s $LP ]; then
      for L in $(awk -F'\t' -v g="$GID" '$3 == g {print $2}' $LP | sort -u); do
        git -C $WT cat-file -e "$L^{commit}" 2>/dev/null && python3 ~/bin/check-map.py affected --map $S/check_map.json --base $L --head $HEADSHA --repo $WT > $S/aff.$L 2>/dev/null || rm -f $S/aff.$L; done
      while IFS= read -r f; do L=$(awk -F'\t' -v f="$f" -v g="$GID" '$1 == f && $3 == g {print $2; exit}' $LP)
        [ -n "$L" ] && [ -f $S/aff.$L ] && ! grep -qxF -- "$f" $S/aff.$L && echo "$f" >> $S/flags.unchanged || echo "$f"; done < $S/flags.txt > $S/flags.keep
      [ -s $S/flags.keep ] && mv $S/flags.keep $S/flags.txt
      [ -s $S/flags.unchanged ] && SCOPE="$SCOPE Of those, $(wc -l < $S/flags.unchanged) skipped: unchanged since their last candidate pass (flags.unchanged)."
    fi
  fi
fi
wait $MWIMP || { echo "$(date -u +%FT%TZ) main tree import failed (rc $?), redoing it"; import_ok $MW; }   # 11-12: a half-imported main
# tree makes main red, which would hide a NEW-RED
# pods: reachable and idle: fewer than half their cores busy over 3 s, measured in the container's own cgroup (a RunPod
# container's /proc/loadavg is the HOST's load: an idle rpc5 showed 37 on 11-12)
probe_pods() { local p l out=""; for p in "$@"; do
  l=$(timeout 25 ssh -i $KEYF -o BatchMode=yes -o ConnectTimeout=10 ${p%%:*} 'u() { awk "/usage_usec/{print \$2}" /sys/fs/cgroup/cpu.stat; }; a=$(u); sleep 3; b=$(u); echo $(nproc) $(( (b - a) / 3000000 ))' 2>/dev/null)
  [ -n "$l" ] && awk -v l="$l" 'BEGIN{split(l,a," "); exit !(a[2] < a[1]/2)}' && out="$out $p"; done; echo "${out# }"; }
PODS=$(probe_pods ${MC_PODS:-$(cat ~/.mc_pods 2>/dev/null || echo "rpc3:10 rpc5:10")})
# 3-plan. capacity planner (~/bin/suite-plan): estimate the server-only time (durations.tsv, minus cached passes). If no GPU
# worker (owner's PC/Mac) is alive, no pod is usable and the server-only run would take > 45 min, wait for one (poll hello
# every 2 min, up to 90 min), then run anyway; a small suite never waits. Waiting costs no CPU, only report latency.
PLANF=$S/flags.txt
if [ ! -s $PLANF ]; then PLANF=$S/flags.plan; { grep -ohE '"--[a-z0-9-]+-check"' $WT/tools/check_registry.gd $WT/scripts/main.gd | tr -d '"'; echo --check; } | sort -u > $PLANF; echo "--simtest --seed=5" >> $PLANF; fi
PLAN=$(python3 ~/bin/suite-plan --flags $PLANF --map $S/check_map.json --tree $WT 2>&1 | tail -1); echo "$(date -u +%FT%TZ) $PLAN"
PLANWAIT=""
if [ -z "$PODS" ] && echo "$PLAN" | grep -q 'decision=WAIT_FOR_WORKER'; then
  W0=$(date +%s)
  # 11-18 retro (mc ran 6 h 57 m): the wait was 90 min, then every suite ran serially on the server under xvfb. Now max MC_WAIT_MAX (1800 s =
  # 30 min); if no GPU worker took it, split the suites over the idle workers (MC_FALLBACK_WORKERS / ~/.mc_workers: ssh aliases "alias:slots",
  # same suite-pod shard as the pods, same idle test), and only run on the server alone when none is idle.
  while [ $(( $(date +%s) - W0 )) -lt ${MC_WAIT_MAX:-1800} ]; do
    sleep 120
    if python3 ~/bin/suite-plan --alive >/dev/null 2>&1; then PLANWAIT="a GPU worker came alive after $(( ($(date +%s) - W0) / 60 )) min"; break; fi
    echo "$(date -u +%FT%TZ) suite-plan: still no worker alive ($(( ($(date +%s) - W0) / 60 )) min waited)"
  done
  if [ -z "$PLANWAIT" ]; then
    FB=$(probe_pods ${MC_FALLBACK_WORKERS:-$(cat ~/.mc_workers 2>/dev/null)} ${MC_PODS:-$(cat ~/.mc_pods 2>/dev/null || echo "rpc3:10 rpc5:10")})
    if [ -n "$FB" ]; then PODS=$(echo $FB | tr ' ' '\n' | awk '!s[$0]++' | tr '\n' ' '); PODS=${PODS% }
      PLANWAIT="no GPU worker in $(( ($(date +%s) - W0) / 60 )) min, split the suites over idle workers: $PODS"
    else PLANWAIT="no GPU worker in $(( ($(date +%s) - W0) / 60 )) min and no idle worker, ran on the server alone (P=$P)"; fi
  fi
  echo "$(date -u +%FT%TZ) suite-plan: $PLANWAIT"
  PLAN="$PLAN; waited: $PLANWAIT"
fi
SCOPE="$SCOPE
Capacity plan: ${PLAN#suite-plan: }; pods: ${PODS:-none}"
ph prep
# 3b. real-GPU performance (Mac/PC worker via jobq) runs DURING the suite now (was 30 min after it). With no GPU worker alive
# queued jobs would only sit, so skip and say so; a worker that comes alive later is picked up by the next candidate.
RD=$OUT/release.md; GP=$OUT/gpu.md; rm -f $RD $GP; GPPID=""
if [ -n "$TAG" ] && [ "${MC_GPU:-0}" != 1 ]; then echo "## Real-GPU performance"$'\n\n'"Not run (test pass MC_TAG=$TAG; MC_GPU=1 runs it)." > $GP
elif python3 ~/bin/suite-plan --alive >/dev/null 2>&1; then
  (~/bin/gpu-perf-report $WT $MW $GP 7200 || echo "## Real-GPU performance"$'\n\n'"gpu-perf-report failed (rc $?)." > $GP) & GPPID=$!
else
  echo "## Real-GPU performance"$'\n\n'"GPU perf deferred: no GPU worker alive (no heartbeat from the PC or Mac in the last 5 min), so no jobs were queued. It runs on the next candidate once a worker is back." > $GP
fi
# 11-18 retro: whole-run cap MC_MAX_SECS (14400 = 4 h) incl. a MC_TAIL_RESERVE (900 s) for release/report; the suite gets what is left (min 600 s).
# suite-fast runs in its own session so the watchdog can TERM its whole group by the pid WE saved (never by name); TIMEOUT is logged and the
# report says SUITE STOPPED (TIMEOUT) instead of the run hanging for hours.
SBUD=$(( T0 + ${MC_MAX_SECS:-14400} - ${MC_TAIL_RESERVE:-900} - $(date +%s) )); [ $SBUD -lt 600 ] && SBUD=600
rm -f $S/MC_TIMEOUT
SUITE_PODS="$PODS" SUITE_PTR=$PTR CHECK_MAP=$S/check_map.json SUITE_PRIORITY=$PRIO OUT=$S GW=$WT MW=$MW setsid bash ~/bin/suite-fast.sh $P & SFPID=$!
( SD=$(( $(date +%s) + SBUD )); while kill -0 $SFPID 2>/dev/null; do
    if [ $(date +%s) -ge $SD ]; then
      echo "$(date -u +%FT%TZ) TIMEOUT: merge-candidate passed its $(( ${MC_MAX_SECS:-14400} / 60 )) min cap ($(( ($(date +%s) - T0) / 60 )) min in); stopping suite-fast (pid $SFPID): $(ls $S/merge/*.rc 2>/dev/null | wc -l)/$(cat $S/flags.txt 2>/dev/null | wc -l) merge checks done"
      # GNU timeout (run() wraps each godot in it) calls setpgid, so the group TERM misses timeout+xvfb+godot: also TERM every descendant
      # pid of OUR saved $SFPID (collected before the group dies); timeout forwards TERM to its own group (xvfb-run, Xvfb, godot).
      desc() { local c; for c in $(ps -o pid= --ppid $1 2>/dev/null); do echo $c; desc $c; done; }; D=$(desc $SFPID)
      touch $S/MC_TIMEOUT; kill -TERM -- -$SFPID 2>/dev/null; [ -n "$D" ] && kill -TERM $D 2>/dev/null
      for _i in $(seq 18); do kill -0 $SFPID 2>/dev/null || exit 0; sleep 5; done
      kill -KILL -- -$SFPID 2>/dev/null; exit 0; fi
    sleep 20; done ) & WDPID=$!
wait $SFPID; SFRC=$?; wait $WDPID 2>/dev/null
STOP=$(grep -m1 -E '^(ENV-BROKEN|MASS-RED):' $S/summary.txt 2>/dev/null); [ -n "$STOP" ] && touch $S/compare.txt   # suite-fast stopped early
# 11-17: mc-0240 suite-fast got TERM after 334 min (rc 143) -> no compare.txt; the report said "NEW-RED " (blank) + grep errors. A suite
# that dies without results is a STOP: headline says SUITE STOPPED, never a blank/0 NEW-RED.
[ -z "$STOP" ] && [ ! -s $S/summary.txt ] && { STOP="SUITE-INCOMPLETE: suite-fast exited rc $SFRC$([ $SFRC = 143 ] && echo " (killed by TERM)") before writing results"; [ -f $S/MC_TIMEOUT ] && STOP="TIMEOUT: merge-candidate hit its $(( ${MC_MAX_SECS:-14400} / 60 )) min cap, suite-fast stopped (rc $SFRC) before writing results"; touch $S/compare.txt; echo "$(date -u +%FT%TZ) $STOP"; }
sed -i 's/ merge=/ cand=/' $S/compare.txt; cp $S/compare.txt $S/compare; cp $S/flags.txt $S/flags
# (11-17, mc-compare-wire / main-reds-1113) validity check of the suite-vs-main table: rows with no real main result (main never ran the flag, or rc 124 = "no such check")
# are NO-BASELINE / NEW-CHECK, not NEW-RED/WORSE, and a base far behind origin/main at publish time makes the headline INVALID. Report-only: never changes compare.
MCC=""
if [ -z "$STOP" ]; then
  ( cd $S; : > mcc.main; : > mcc.cand
    while IFS= read -r f; do n=$(echo "$f" | tr -c 'a-z0-9\n' _)
      [ -f merge/$n.rc ] && echo "$f $(cat merge/$n.rc)" >> mcc.cand; [ -f main/$n.rc ] && echo "$f $(cat main/$n.rc)" >> mcc.main; done < flags.txt
    { grep -ohE '"--[a-z0-9-]+-check"' $MW/tools/check_registry.gd $MW/scripts/main.gd | tr -d '"'; echo --check; echo "--simtest --seed=5"; } | sort -u > mcc.baseflags
    gitnet fetch -q origin main >/dev/null 2>&1 || true
    python3 ~/bin/mc-compare.py table mcc.main mcc.cand mcc.baseflags $(git -C $WT rev-list --count $M..origin/main 2>/dev/null) > mcc.txt 2>mcc.err ) || true
  [ -s $S/mcc.txt ] && MCC="Compare check (mc-compare): $(sed -n 1p $S/mcc.txt); $(sed -n 2p $S/mcc.txt)"
  echo "$(date -u +%FT%TZ) ${MCC:-mc-compare: no output ($(head -c 120 $S/mcc.err 2>/dev/null))}"
fi
# (11-13) record this candidate's passes for 3-pre-b: newest first, a red drops the flag, flags not run keep their entry
[ -z "$STOP" ] && ! grep -q '^BREAKER' $S/summary.txt && { while IFS= read -r f; do
    [ "$(cat $S/merge/$(echo "$f" | tr -c 'a-z0-9\n' _).rc 2>/dev/null)" = "0 0" ] && printf '%s\t%s\t%s\n' "$f" $HEADSHA "$GID" || printf '%s\tRED\n' "$f"
  done < $S/flags; cat $LP 2>/dev/null; } | awk -F'\t' '!seen[$1]++ && $2 != "RED"' > $LP.tmp && mv $LP.tmp $LP
ph suite
(~/bin/release-dryrun $WT > $RD 2>&1); RDRC=$?
[ -s $RD ] || echo "## Release dry-run"$'\n\n'"release-dryrun produced no output (rc $RDRC)." > $RD
if [ -n "$GPPID" ]; then   # bounded by the same cap (+15 min grace): gpu-perf-report may wait up to 2 h
  while kill -0 $GPPID 2>/dev/null; do
    [ $(( $(date +%s) - T0 )) -ge $(( ${MC_MAX_SECS:-14400} + 900 )) ] && { echo "$(date -u +%FT%TZ) TIMEOUT: gpu-perf-report still running at the cap, stopped (pid $GPPID)"; kill $GPPID 2>/dev/null
      echo "## Real-GPU performance"$'\n\n'"TIMEOUT: gpu-perf-report did not finish within the merge-candidate cap." > $GP; break; }
    sleep 20; done; wait $GPPID 2>/dev/null; fi
ph release+gpu

# 4. publish
cd $WT
GL=$(grep -oE '^\*\*[0-9]+ of' $GP | grep -oE '[0-9]+' | head -1); GL=${GL:-0}
NM=$(grep -c '^merged' $R); NS=$(grep -c ^SKIPPED $R); NC=$(grep -c '(cached ' $R); ND=$(grep -c ' breaks compile (gate' $R)
HL="Headline: NEW-RED $(grep -c ^NEW-RED $S/compare), WORSE $(grep -c ^WORSE $S/compare), FIXED $(grep -c ^FIXED $S/compare) of $(wc -l < $S/flags) checks; $NM merged, $NS skipped; release exports $([ $RDRC -eq 0 ] && echo pass || echo FAIL); GPU jobs not finished: $GL$(grep -q "GPU perf deferred" $GP && echo " (GPU perf deferred: no GPU worker alive)")"
TIMING="Timing: total $(( ($(date +%s) - T0) / 60 )) min ($(echo ${TIMING%,} | sed 's/^ //')). Gate:$GATE Skips from the conflict cache: $NC; dropped by the gate: $ND.$([ -n "$ARCH" ] && echo " Superseded: $ARCH.")"
grep -q '^BREAKER' $S/summary.txt 2>/dev/null && TIMING="$TIMING $(grep '^BREAKER' $S/summary.txt)"
[ -n "$STOP" ] && HL="Headline: SUITE STOPPED, no NEW-RED verdict: $STOP; $NM merged, $NS skipped" && TIMING="$TIMING $STOP"
{ echo "# Merge candidate $TS (built by cron, no Claude usage)$([ -n "$TAG" ] && echo " [test pass $TAG]")"; echo; echo "$HL"; echo; echo "Base: origin/main ${M:0:8}. Health: $HEALTH"; echo "$SCOPE"; echo "$TIMING"; grep -h '^UNCOVERED' $S/affected.why 2>/dev/null | head -10 | sed 's/^/- /'; echo
  echo "## Suite vs main: NEW-RED $(grep -c ^NEW-RED $S/compare), WORSE $(grep -c ^WORSE $S/compare), FIXED $(grep -c ^FIXED $S/compare) of $(wc -l < $S/flags) checks"
  [ -n "$MCC" ] && echo "$MCC" && echo
  grep -E "^(NEW-RED|WORSE|FIXED)" $S/compare | sed 's/^/- /'; echo; echo "## Branches"; sed 's/^/- /' $R
  echo; echo "Exclusions: ~/bin/merge-exclude.txt on the hetzner box."; } > MERGE_REPORT.md
{ echo; cat $GP; echo; cat $RD; } >> MERGE_REPORT.md
git add MERGE_REPORT.md; git commit -q -m "Merge candidate report $TS"
if [ -n "$TAG" ]; then NEW=ext/mc-$TAG-$TS; gitnet push -q origin HEAD:refs/heads/$NEW
else
  NEW=ext/mc-$TS
  gitnet push -q origin HEAD:refs/heads/$NEW && echo $NEW > ~/.mc_branch && echo "$KEY" > ~/.mc_last
  mc_prune   # 11-12: was "delete $OLD" only (strays piled up when ~/.mc_branch was lost); now newest 2 kept, older/merged pruned
  cp MERGE_REPORT.md /tmp/merge-candidate-$TS.md; ~/bin/report-publish /tmp/merge-candidate-$TS.md "Merge candidate $TS"; rm -f /tmp/merge-candidate-$TS.md
fi
[ -z "$TAG" ] && (cd $REPO && GIT_CONFIG_COUNT=0 nice -n 19 ionice -c3 git gc --auto --quiet >/dev/null 2>&1 &)
echo "$TS pushed $NEW: $NM merged, $NS skipped, NEW-RED $(grep -c ^NEW-RED $S/compare); $TIMING"
