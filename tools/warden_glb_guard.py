"""Fails when this branch changes a shipped Hunter model (art/wardens/<id>/<id>.glb) that no "Art:" commit made.
On 11-17 merge lanes re-ran glb_relax and took bundle resolutions on the hunters' glbs, so the owner-picked models
were swapped for relaxed ones (flat arms and hands) with no art commit to see it. Each changed glb's blob at HEAD must
be the blob an "Art: ..." commit in <base>..HEAD left (a later merge or tool run that rewrites it fails).
Run: python3 tools/warden_glb_guard.py [base]   (base: $BOKI_BASE or origin/main; no base ref -> skipped)"""
import os
import re
import subprocess
import sys

GLB = re.compile(r"^art/wardens/([^/]+)/\1\.glb$")


def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True, check=False)


def main(args):
    base = args[0] if args else os.environ.get("BOKI_BASE", "origin/main")
    mb = git("merge-base", base, "HEAD")
    if mb.returncode:
        print(f"warden_glb_guard: no {base} here, skipped")
        return 0
    mb = mb.stdout.strip()
    changed = [f for f in git("diff", "--name-only", mb, "HEAD").stdout.split() if GLB.match(f)]
    bad = []
    for f in changed:
        head = git("rev-parse", f"HEAD:{f}").stdout.strip()
        log = git("log", "--no-merges", "--format=%H %s", f"{mb}..HEAD", "--", f).stdout.splitlines()
        ok = any(s.startswith("Art:") and git("rev-parse", f"{h}:{f}").stdout.strip() == head
                 for h, _, s in (line.partition(" ") for line in log))
        if not ok:
            bad.append(f)
    for f in bad:
        print(f"FAILED: {f} changed with no 'Art:' commit that made this exact file (docs/DEBT.md: hunter glbs)")
    print(f"warden_glb_guard: {len(changed)} hunter glb(s) changed, {len(bad)} without an Art: commit")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
