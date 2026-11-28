"""Fails when a commit in this branch has an author or committer email that could map to a stranger's GitHub account.
On 11-22 commit 397e339568f used coord@users.noreply.github.com, GitHub mapped it to an unrelated account named
"coord", and that stranger showed up as a repo contributor. History is not rewritten; this stops it happening again.
Allowed: noreply@anthropic.com, noreply@github.com, orribogdan@gmail.com, OrriBogdan2's own noreply address
(OrriBogdan2@... or <id>+OrriBogdan2@users.noreply.github.com), the owner's projectboki.com, and local-only
addresses that cannot be claimed (no dot, or .local/.localhost/.invalid/.test/.example TLD).
Anything else fails: any other @users.noreply.github.com address and any real public domain (gmail.com, outlook.com ...).
Run: python3 tools/commit_email_guard.py [base [head]]
  base: $BOKI_BASE or origin/main (not present -> skipped); head: $BOKI_HEAD or HEAD. Checks commits in base..head."""

import os
import re
import subprocess
import sys

KNOWN = {"noreply@anthropic.com", "noreply@github.com", "orribogdan@gmail.com"}
OWN_DOMAINS = {"projectboki.com"}
NOREPLY = "users.noreply.github.com"
OWNER_NOREPLY = re.compile(r"^(\d+\+)?orribogdan2$", re.I)
LOCAL_TLDS = {"local", "localhost", "invalid", "test", "example", "localdomain", "internal"}


def problem(email):
    """Return why this email is not allowed, or '' when it is fine."""
    e = email.strip().lower()
    if e in KNOWN:
        return ""
    local, _, domain = e.rpartition("@")
    if not domain:
        return "" if not e else "no @ domain"
    if domain == NOREPLY:
        return "" if OWNER_NOREPLY.match(local) else "GitHub noreply address of another account"
    if domain in OWN_DOMAINS or "." not in domain or domain.rsplit(".", 1)[1] in LOCAL_TLDS:
        return ""
    return "real public domain (may map to a stranger's GitHub account)"


def main(args):
    base = args[0] if args else os.environ.get("BOKI_BASE", "origin/main")
    head = args[1] if len(args) > 1 else os.environ.get("BOKI_HEAD", "HEAD")
    r = subprocess.run(["git", "log", "--format=%H%x09%ae%x09%ce%x09%s", f"{base}..{head}"], capture_output=True, text=True, check=False)
    if r.returncode:
        print(f"commit_email_guard: no {base}..{head} here, skipped")
        return 0
    bad, n = [], 0
    for line in r.stdout.splitlines():
        n += 1
        sha, ae, ce, subj = (line.split("\t", 3) + ["", "", ""])[:4]
        for role, mail in (("author", ae), ("committer", ce)):
            why = problem(mail)
            if why:
                bad.append(f"FAILED: {sha[:10]} {role} <{mail}>: {why} ({subj[:60]})")
    print("\n".join(bad))
    if bad:
        print("Fix: git config user.email noreply@anthropic.com (or orribogdan@gmail.com), then amend/rebase the commits above.")
    print(f"commit_email_guard: {n} commit(s) checked, {len(bad)} bad email(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
