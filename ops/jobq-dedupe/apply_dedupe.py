#!/usr/bin/env python3
"""Add identical-job dedupe to the LIVE jobq (anchored edits; works on newer jobq versions too).
Usage: apply_dedupe.py /home/boki/bin/jobq [--write]   (without --write: prints what it would do, writes JOBQ.dedupe.new)
Idempotent: a jobq that already has find_dupe() is left alone. Run selftest.sh on the result before installing."""
import re, subprocess, sys
path = sys.argv[1]; write = '--write' in sys.argv
s = open(path).read()
if 'find_dupe()' in s: print('already patched'); sys.exit(0)
HELPERS = r'''
tree_sig() {  # DIR -> "HEAD:hash-of-local-changes", or empty if not a git tree (then no dedupe)
  local h; h=$(git -C "$1" rev-parse -q --verify HEAD 2>/dev/null) || return 0
  { git -C "$1" diff HEAD --binary 2>/dev/null
    git -C "$1" ls-files -o --exclude-standard -z 2>/dev/null | (cd "$1" && xargs -0 -r sha1sum 2>/dev/null)
  } | sha1sum | cut -c1-16 | sed "s/^/$h:/"
}
find_dupe() {  # TREE SIG APP NEEDS OUT ONLY ARGS... -> newest matching done id (rc 0, < JOBQ_DEDUPE_H h old)
  local t=$1 sg=$2 ap=$3 nd=$4 ot=$5 on=$6 cut d rc; shift 6
  local want; want=$(printf '%q ' "$@")
  cut=$(date -d "-${JOBQ_DEDUPE_H:-6} hours" +%Y%m%d-%H%M%S)
  for d in $(ls -1 "$Q/done" 2>/dev/null | grep -E '^[0-9]{8}-[0-9]{6}-' | sort -r); do
    [[ $d < $cut ]] && break
    read -r rc _ < "$Q/done/$d/rc" 2>/dev/null || continue
    [ "$rc" = 0 ] || continue
    ( load "$Q/done/$d/job" 2>/dev/null || exit 1
      [ "${TREESIG:-}" = "$sg" ] && [ "$TREE" = "$t" ] && [ "$APP" = "$ap" ] && [ "$NEEDS" = "$nd" ] && [ "$OUT" = "$ot" ] \
        && [ "${ONLY:-}" = "$on" ] && [ "$(printf '%q ' "${ARGS[@]}")" = "$want" ] ) && { echo "$d"; return 0; }
  done
  return 0
}
'''
CHECK = r'''  # 11-23 dedupe: 259 of 1,186 GPU jobs in 35 h were identical re-runs (7.7 GPU-h). If a done job with the same tree
  # STATE (path + git HEAD + hash of uncommitted/untracked changes) and the same app/needs/out/only/args finished rc 0
  # within JOBQ_DEDUPE_H (6) hours, print its id instead of queueing. Opt out: --no-dedupe or JOBQ_DEDUPE=0.
  local sig=
  sig=$(tree_sig "$tree")
  if [ "$dedupe" = 1 ] && [ -n "$sig" ]; then
    local hit; hit=$(find_dupe "$tree" "$sig" "$app" "$needs" "$out" "$only" "$@")
    if [ -n "$hit" ]; then
      echo "jobq: identical job $hit finished rc 0 <${JOBQ_DEDUPE_H:-6}h ago; reusing it (--no-dedupe to rerun)" >&2
      mkdir -p "$Q/dedupe"; echo "$(now) $hit ${label:-}" >> "$Q/dedupe/hits.log"
      echo "$hit"; return 0
    fi
  fi
'''
def sub(pat, rep, what, flags=re.M):
    global s
    s2, n = re.subn(pat, rep, s, count=1, flags=flags)
    if n != 1: sys.exit(f'apply_dedupe: anchor not found: {what} (patch by hand, see INSTALL.md)')
    s = s2
sub(r'^(load\(\) \{.*\n\s*unset )', r'\1TREESIG ', 'load() unset')
sub(r'^(cmd_submit\(\) \{\n)', HELPERS.lstrip('\n').replace('\\', '\\\\') + r'\n\1', 'cmd_submit()')
sub(r'^(cmd_submit\(\) \{\n  local tree=[^\n]*\n)', r'\1  local dedupe=${JOBQ_DEDUPE:-1}\n', 'submit locals')
sub(r'^(      --no-fallback\)[^\n]*\n)', r'\1      --no-dedupe) dedupe=0; shift;;   # time-dependent jobs (random-seed renders, perf runs): always run fresh\n', '--no-fallback option')
sub(r'^(  local id tmp\n  id=\$\(date)', CHECK.replace('\\', '\\\\') + r'\1', 'id creation in submit')
sub(r"^(    printf 'NOFALLBACK=[^\n]*\n)", lambda m: m.group(1) + "    printf 'TREESIG=%q\\n' \"$sig\"\n", 'job file NOFALLBACK line')
s = s.replace('[--label TEXT] --', '[--label TEXT] [--no-dedupe] --', 1)
out = path + '.dedupe.new' if not write else path
open(out, 'w').write(s)
subprocess.run(['bash', '-n', out], check=True)
print('wrote', out, '(bash -n ok)')
