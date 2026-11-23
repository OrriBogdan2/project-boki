#!/usr/bin/env bash
# branch_reaper.sh: delete origin ext/* branches whose tip is already an ancestor of origin/main.
# usage: tools/branch_reaper.sh [--apply] [--min-age-hours N] [--log FILE] [--keep REGEX]
#   no --apply = dry run (prints the plan). Restore one: git push origin <sha>:refs/heads/<branch>  (sha is in the log).
# Safety: only ext/*; never ext/agent-briefs; skips tips committed < N hours ago (default 24: a fresh branch cut from
# main looks "merged" until its first commit); --keep REGEX protects names; fails closed if fetch or ls-remote fails.
set -euo pipefail
APPLY=0; MINH=24; LOG="${HOME}/cj/branch-reaper.log"; KEEP='^ext/agent-briefs$'
while [ $# -gt 0 ]; do case "$1" in
  --apply) APPLY=1;; --min-age-hours) MINH="$2"; shift;; --log) LOG="$2"; shift;;
  --keep) KEEP="$KEEP|$2"; shift;; *) echo "bad arg $1" >&2; exit 2;; esac; shift; done
git fetch -q origin main '+refs/heads/ext/*:refs/remotes/origin/ext/*' --prune
main=$(git rev-parse origin/main); now=$(date +%s); cut=$((now - MINH * 3600))
plan=$(mktemp); trap 'rm -f "$plan"' EXIT
total=0
while read -r sha ref; do
  b=${ref#refs/remotes/origin/}; total=$((total + 1))
  [[ "$b" =~ $KEEP ]] && continue
  git merge-base --is-ancestor "$sha" "$main" || continue
  [ "$(git log -1 --format=%ct "$sha")" -lt "$cut" ] || continue
  echo "$sha $b" >> "$plan"
done < <(git for-each-ref --format='%(objectname) %(refname)' refs/remotes/origin/ext/)
n=$(wc -l < "$plan"); echo "ext branches: $total, fully merged and older than ${MINH}h: $n"
[ "$APPLY" = 1 ] || { head -5 "$plan"; echo "(dry run; --apply deletes)"; exit 0; }
mkdir -p "$(dirname "$LOG")"; { echo "# $(date -u +%FT%TZ) main=$main"; cat "$plan"; } >> "$LOG"
split -l 50 "$plan" "$plan.part."
for f in "$plan".part.*; do
  # --force-with-lease style: delete only if remote tip is still the sha we checked
  args=(); while read -r sha b; do args+=("--force-with-lease=refs/heads/$b:$sha" ":refs/heads/$b"); done < "$f"
  git push -q origin "${args[@]}" || echo "chunk failed: $f (continuing)" >&2
  rm -f "$f"
done
git fetch -q origin '+refs/heads/ext/*:refs/remotes/origin/ext/*' --prune
echo "deleted ~$n; ext/* merged-into-main left: $(git branch -r --merged origin/main | grep -c ' origin/ext/' || true)"
