#!/bin/bash
# worker-prune: age out idle /root/mcshard/<hash> suite shards on pods (11-19; suites use pods by default, ~20 GB per shard).
# Shard = /root/mcshard/<md5(OUT)[:10]>/ made by suite-pod. A shard is pruned when ALL hold:
#   - newest ctime of any file/dir under it is older than AGE_H hours (default 48). ctime, not mtime: rsync -a/cp -a keep
#     old mtimes, so a shard synced a minute ago would look days old by mtime; ctime is set on every write/create, and
#   - no process has '/root/mcshard/<hash>' anywhere in its command line (godot --path, rsync/cp seed copy, suite-pod), and
#   - it is not the newest shard that has a gw/ seed (merge-candidate import_remote copies /root/mcshard/*/gw as its seed).
# Usage: worker-prune.sh [--apply] [pod ...]     default is dry run; pods default to ~/.mc_pods (alias:slots) entries.
#        worker-prune.sh --local [--apply]       run on this host (what the ssh call executes); MCSHARD_ROOT overrides the root (tests).
# Env: PRUNE_AGE_H=48  SUITE_POD_KEY=~/.ssh/boki_s2_deploy
# Never kills anything: a running shard is skipped. Prints one line per shard and a total.
AGE_H=${PRUNE_AGE_H:-48}; AGE_S=${PRUNE_AGE_S:-$((AGE_H*3600))};  # PRUNE_AGE_S: seconds, for tests
 ROOT=${MCSHARD_ROOT:-/root/mcshard}; APPLY=0; LOCAL=0; PODS=""
for a in "$@"; do case $a in --apply) APPLY=1;; --local) LOCAL=1;; *) PODS="$PODS $a";; esac; done

prune_local() {
  [ -d "$ROOT" ] || { echo "no $ROOT"; return 0; }
  local now cut seed="" best=0 d h m kb tot=0 n=0 cmdl
  now=$(date +%s); cut=$((now - AGE_S))
  cmdl=$(ps -eo args= 2>/dev/null)
  for d in "$ROOT"/*/; do  # newest shard with a gw seed is kept
    d=${d%/}; [ -d "$d/gw" ] || continue
    m=$(find "$d" -printf '%C@\n' 2>/dev/null | sort -n | tail -1); m=${m%.*}; m=${m:-0}
    [ "$m" -gt "$best" ] && { best=$m; seed=$d; }
  done
  for d in "$ROOT"/*/; do
    d=${d%/}; h=$(basename "$d")
    m=$(find "$d" -printf '%C@\n' 2>/dev/null | sort -n | tail -1); m=${m%.*}; m=${m:-$(stat -c %Y "$d")}
    kb=$(du -sk "$d" 2>/dev/null | cut -f1); age=$(( (now - m) / 3600 ))
    if [ "$d" = "$seed" ]; then echo "keep $h ${age}h $((kb/1024))MB (newest gw seed)"; continue; fi
    if [ "$m" -ge "$cut" ]; then echo "keep $h ${age}h $((kb/1024))MB (recent)"; continue; fi
    if printf '%s\n' "$cmdl" | grep -qF -- "$d"; then echo "keep $h ${age}h $((kb/1024))MB (in use by a process)"; continue; fi
    if [ $APPLY = 1 ]; then rm -rf -- "$d" && echo "pruned $h ${age}h $((kb/1024))MB" || { echo "FAILED $h"; continue; }
    else echo "would-prune $h ${age}h $((kb/1024))MB"; fi
    tot=$((tot+kb)); n=$((n+1))
  done
  echo "total: $n shard(s), $((tot/1024)) MB $([ $APPLY = 1 ] && echo freed || echo reclaimable); disk: $(df -h --output=avail "$ROOT" | tail -1 | tr -d ' ') free"
}

if [ $LOCAL = 1 ]; then prune_local; exit 0; fi
[ -n "$PODS" ] || PODS=$(cat "$HOME/.mc_pods" 2>/dev/null)
[ -n "$PODS" ] || { echo "no pods (pass aliases or fill ~/.mc_pods)"; exit 2; }
KEY=${SUITE_POD_KEY:-$HOME/.ssh/boki_s2_deploy}; rc=0
for p in $PODS; do h=${p%%:*}; echo "== $h"
  # ship this script's function body over ssh stdin and run it there with --local
  timeout 600 ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=15 "$h" "PRUNE_AGE_S=$AGE_S bash -s -- --local $([ $APPLY = 1 ] && echo --apply)" < "$0" || { echo "$h: ssh failed"; rc=1; }
done; exit $rc
