"""Shared helpers for regate-bot, gh-outbox-relay and regate-probe (hetzner crons; stdlib only, no LLM).

gh is used when it is installed and logged in (hetzner). Without it (a worker), reads fall back to the public GitHub
API (read-only, 60 calls/h) and posts are written to an outbox dir instead, so --dry runs work anywhere.
"""

import datetime as dt
import json
import os
import re
import shutil
import subprocess
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
SLUG = os.environ.get("REPO_SLUG", "OrriBogdan2/project-boki")
REPO = os.environ.get("BOKI_REPO", str(HOME / "project-boki"))
CJ = HOME / "cj"
STATE_DIR = Path(os.environ.get("REGATE_STATE", CJ / "regate-bot"))
SSH_KEY = os.environ.get("REGATE_SSH_KEY", str(HOME / ".ssh/boki_s2_deploy"))
GATE_RE = re.compile(r"^\W*GATE GREEN\s+([0-9a-f]{7,40})\b", re.M)
REGATE_RE = re.compile(r"^\W*REGATE (RED|CONFLICT)\s+([0-9a-f]{7,40})\b", re.M)
OWNER_RE = re.compile(r"(\S+) owns this PR until merged")
MARK_RE = re.compile(r"\[regate-bot pr=(\d+) head=([0-9a-f]+) main=([0-9a-f]+)\]")
JOB_ID_RE = re.compile(r"^\d{8}-\d{6}-a\d+$")


def now():
    return time.time()


def iso(t):
    return dt.datetime.fromtimestamp(t, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s):
    return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).timestamp()


def run(cmd, timeout=120, check=False, **kw):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kw)
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        if check:
            raise
        return 124, "", str(e)
    if check and p.returncode:
        raise RuntimeError(f"{cmd[:3]} rc={p.returncode}: {p.stderr.strip()[-300:]}")
    return p.returncode, p.stdout, p.stderr


def git(*args, timeout=180):
    rc, out, _ = run(["git", "-C", REPO, *args], timeout=timeout)
    return out.strip() if rc == 0 else None


def is_ancestor(a, b):
    return run(["git", "-C", REPO, "merge-base", "--is-ancestor", a, b])[0] == 0


class GH:
    """gh when logged in, else the public API (read-only) + outbox files for posts."""

    def __init__(self, outbox=None):
        self.live = bool(shutil.which("gh")) and run(["gh", "auth", "status"], timeout=30)[0] == 0
        self.outbox = Path(outbox or STATE_DIR / "gh-outbox")
        self._login = None

    def api(self, path):
        if self.live:
            rc, out, err = run(["gh", "api", "--paginate", path], timeout=120)
            if rc:
                raise RuntimeError(f"gh api {path}: {err.strip()[-200:]}")
            # --paginate concatenates JSON arrays as "][": join them
            return json.loads(re.sub(r"\]\s*\[", ",", out)) if out.strip().startswith("[") else json.loads(out)
        # public API: 60 calls/h per IP, shared by the whole worker, so reads are cached on disk (REGATE_API_TTL s)
        cache = STATE_DIR / "api-cache" / re.sub(r"[^\w.-]", "_", path)
        ttl = int(os.environ.get("REGATE_API_TTL", 900))
        if cache.exists() and now() - cache.stat().st_mtime < ttl:
            return json.loads(cache.read_text())
        req = urllib.request.Request(f"https://api.github.com/{path}", headers={"User-Agent": "regate-bot"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = json.load(r)
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(data))
        return data

    def login(self):
        if self._login is None:
            self._login = os.environ.get("REGATE_GH_USER") or (self.api("user")["login"] if self.live else SLUG.split("/")[0])
        return self._login

    def open_prs(self):
        return self.api(f"repos/{SLUG}/pulls?state=open&per_page=100")

    def pr(self, n):
        return self.api(f"repos/{SLUG}/pulls/{n}")

    def comments(self, n):
        return self.api(f"repos/{SLUG}/issues/{n}/comments?per_page=100")

    def post(self, n, body, dry=False):
        """Returns a short description of what happened."""
        if dry:
            return f"DRY would post on #{n}: {body.splitlines()[0][:100]}"
        if self.live:
            rc, _, err = run(["gh", "pr", "comment", str(n), "--repo", SLUG, "--body", body], timeout=120)
            if rc:
                raise RuntimeError(f"gh pr comment {n}: {err.strip()[-200:]}")
            return f"posted on #{n}"
        self.outbox.mkdir(parents=True, exist_ok=True)
        f = self.outbox / f"pr{n}-{int(now())}.md"
        f.write_text(body + "\n")
        return f"no gh here: left in {f}"


def workers():
    """name -> ip from ~/cj/workers (any line with a name and an IPv4)."""
    out = {}
    p = CJ / "workers"
    if not p.exists():
        return out
    for line in p.read_text().splitlines():
        line = line.split("#", 1)[0]
        ip = re.search(r"\b\d{1,3}(?:\.\d{1,3}){3}\b", line)
        if not ip:
            continue
        name = next((w for w in re.split(r"[\s,:=]+", line) if w and w != ip.group(0)), ip.group(0))
        out[name] = ip.group(0)
    return out


def ssh_cmd(ip, remote, timeout=60):
    return run(["ssh", "-i", SSH_KEY, "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                "-o", "StrictHostKeyChecking=accept-new", f"boki@{ip}", remote], timeout=timeout)


_STATUS = None


def claude_job_status():
    global _STATUS
    if _STATUS is None:
        rc, out, _ = run(["claude-job", "status"], timeout=60) if shutil.which("claude-job") else (1, "", "")
        _STATUS = out if rc == 0 else ""
    return _STATUS


def job_running(label):
    """Is the job named by an 'owns this PR' label still running? label = a job id or a task label
    (e.g. merge-driver-1114, matched against ~/cj/<id>/prompt). Unknown -> True for 6 h (conservative)."""
    st = claude_job_status()
    ids = [label] if JOB_ID_RE.match(label) else [
        d.name for d in sorted(CJ.glob("2026*-*"))[-400:]
        if (d / "prompt").exists() and label in (d / "prompt").read_text(errors="replace")[-12000:]]
    if not ids:
        return None
    for i in ids:
        if st:
            if any(i in ln and re.search(r"\brunning\b", ln) for ln in st.splitlines()):
                return True
        elif not (CJ / i / "rc").exists() and now() - (CJ / i).stat().st_mtime < 6 * 3600:
            return True
    return False


def load_json(p, default):
    try:
        return json.loads(Path(p).read_text())
    except (OSError, ValueError):
        return default


def save_json(p, data):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=1, sort_keys=True))
    tmp.replace(p)
