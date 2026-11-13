#!/usr/bin/env python3
"""suite_speed: faster, safer check-suite gates (canary, main-side cache, changed-files selection, longest-first).

Subcommands (all stdlib; see README.md):
  flags TREE                       suite flags: registry -check keys + main.gd inline -check flags
  stats HIST                       p50/p90 per flag and the slowest 10, from a history TSV or a dir of *.secs
  order FLAGS HIST                 FLAGS (file, one per line) longest-first by p90 history
  select TREE BASE [HEAD]          flags whose inputs changed in BASE..HEAD ("ALL" when a shared file changed)
  gate --main T --merge T --out D  the whole gate: canary, cache, order, parallel run, mass-red guard, summary.txt
"""

import argparse
import hashlib
import heapq
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

FAIL_RE = re.compile(r"failures:\s*(\d+)")
ERR_RE = re.compile(r"^(SCRIPT ERROR|ERROR): ", re.M)
DEFAULT_SECS = 60.0  # a flag with no history is ordered as if it took the overall p90 (or this)
# Files every check goes through: a change here selects the whole suite.
SHARED = (
    "project.godot",
    "scripts/main.gd",
    "tools/check_registry.gd",
    "tools/check.gd",
)
# Paths that never feed a check.
INERT = re.compile(
    r"^(docs|briefs|ops|\.github|blender|art_src)/|\.(md|txt|import|uid)$|^[^/]+\.md$|^export_presets\.cfg$"
)
GAME_EXT = re.compile(
    r"\.(gd|tscn|tres|gdshader|gdshaderinc|json|cfg|csv|tsv|glb|gltf|png|jpg|webp|wav|ogg|mp3|ttf|otf|res)$"
)


# ---------------------------------------------------------------- flags
def suite_flags(tree):
    tree = Path(tree)
    reg = (tree / "tools/check_registry.gd").read_text()
    block = reg.split("const CHECKS := {", 1)[1].split("\n}", 1)[0]
    flags = re.findall(r'^\s*"(--[a-z0-9-]+-check)":', block, re.M)
    main = (tree / "scripts/main.gd").read_text()
    flags += re.findall(r'"(--[a-z0-9-]+-check)" in args', main)
    seen, out = set(), []
    for f in flags:
        if f not in seen:
            seen.add(f)
            out.append(f)
    return out


# ---------------------------------------------------------------- history / stats / order
def load_history(src):
    """{flag: [secs, ...]} from a TSV (flag<TAB>secs per line) or a dir tree of <flag>.secs files."""
    hist = {}
    p = Path(src) if src else None
    if not p or not p.exists():
        return hist
    if p.is_file():
        for line in p.read_text().splitlines():
            parts = line.split("\t")
            if len(parts) >= 2 and parts[0].startswith("--"):
                try:
                    hist.setdefault(parts[0], []).append(float(parts[1]))
                except ValueError:
                    pass
        return hist
    for f in p.rglob("*.secs"):
        try:
            hist.setdefault(f.stem, []).append(float(f.read_text().split()[0]))
        except (ValueError, IndexError, OSError):
            pass
    return hist


def pct(xs, q):
    xs = sorted(xs)
    if not xs:
        return 0.0
    k = (len(xs) - 1) * q
    lo = int(k)
    hi = min(lo + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def stats_rows(hist):
    rows = [(f, pct(v, 0.5), pct(v, 0.9), len(v)) for f, v in hist.items() if v]
    return sorted(rows, key=lambda r: -r[2])


def order_flags(flags, hist):
    p90 = {f: pct(v, 0.9) for f, v in hist.items() if v}
    unknown = pct(list(p90.values()), 0.9) if p90 else DEFAULT_SECS
    return sorted(flags, key=lambda f: (-p90.get(f, unknown), f))


def simulate(flags, secs, jobs):
    """Wall time of a greedy pool of `jobs` workers taking `flags` in order (list scheduling)."""
    free = [0.0] * jobs
    for f in flags:
        i = free.index(min(free))
        free[i] += secs.get(f, DEFAULT_SECS)
    return max(free) if free else 0.0


# ---------------------------------------------------------------- changed-files selection
TEXT_RES = re.compile(r"\.(gd|tscn|tres|gdshader|gdshaderinc|json|cfg|tsv|csv)$")


def git(tree, *args):
    return subprocess.run(["git", "-C", str(tree), *args], capture_output=True, text=True, check=True).stdout


def read_rev(tree, rev, paths):
    """{path: text} for paths at rev, in one git cat-file --batch call."""
    if not paths:
        return {}
    inp = "".join(f"{rev}:{p}\n" for p in paths).encode()
    cmd = ["git", "-C", str(tree), "cat-file", "--batch"]
    raw = subprocess.run(cmd, input=inp, capture_output=True, check=True).stdout
    out, i = {}, 0
    for p in paths:
        nl = raw.index(b"\n", i)
        head = raw[i:nl].split()
        if len(head) < 3 or head[1] == b"missing":
            i = nl + 1
            continue
        n = int(head[2])
        out[p] = raw[nl + 1 : nl + 1 + n].decode("utf-8", "replace")
        i = nl + 1 + n + 1
    return out


def dep_index(tree, rev):
    """(edges {path: referenced paths}, texts {path: text}) for every text resource at rev."""
    files = [ln for ln in git(tree, "ls-tree", "-r", "--name-only", rev).splitlines() if TEXT_RES.search(ln)]
    texts = read_rev(tree, rev, files)
    classes = {}
    for rel, t in texts.items():
        m = re.search(r"^class_name\s+(\w+)", t, re.M) if rel.endswith(".gd") else None
        if m:
            classes[m.group(1)] = rel
    cls_re = re.compile(r"\b(" + "|".join(sorted(classes, key=len, reverse=True)) + r")\b") if classes else None
    edges = {}
    for rel, t in texts.items():
        refs = {r.split("::")[0] for r in re.findall(r'res://([^"\'\s)%{]+)', t)}
        if cls_re and rel.endswith(".gd"):
            code = "\n".join(ln.split("#", 1)[0] for ln in t.splitlines())
            refs |= {classes[c] for c in set(cls_re.findall(code))}
        refs.discard(rel)
        edges[rel] = refs
    return edges, texts


def closure(start, edges):
    seen, todo = set(), [start]
    while todo:
        n = todo.pop()
        if n in seen:
            continue
        seen.add(n)
        todo.extend(edges.get(n, ()))
    return seen


def registry_entries(text):
    block = text.split("const CHECKS := {", 1)[1].split("\n}", 1)[0]
    rows = re.finditer(r'^\s*"(--[a-z0-9-]+)":.*$', block, re.M)
    return {m.group(1): m.group(0).split("#", 1)[0].strip() for m in rows}


def strip_checks(text):
    """The registry without its CHECKS table (the dispatcher and the rest)."""
    head, _, rest = text.partition("const CHECKS := {")
    return head + rest.partition("\n}")[2]


def check_inputs(tree, rev, edges):
    """{flag: set of repo paths the check reads}: the closure of its tool script, or of the tool main.gd loads
    next to an inline flag (main.gd's own closure is the whole game, so it is not followed)."""
    reg, main = read_rev(tree, rev, ["tools/check_registry.gd", "scripts/main.gd"]).values()
    script = {f: re.search(r'"res://([^"]+)"', e).group(1) for f, e in registry_entries(reg).items() if "res://" in e}
    out = {}
    block = reg.split("const CHECKS := {", 1)[1].split("\n}", 1)[0]
    listed = re.findall(r'^\s*"(--[a-z0-9-]+-check)":', block, re.M)
    listed += re.findall(r'"(--[a-z0-9-]+-check)" in args', main)
    for f in listed:
        if f in out:
            continue
        if f in script:
            out[f] = closure(script[f], edges)
        else:
            m = re.search(re.escape(f) + r'" in args:[^\n]*\n(?:[^\n]*\n){0,3}?[^\n]*?res://([^"]+)', main)
            out[f] = closure(m.group(1), edges) if m else set()
    return out


def owners(path, texts, edges):
    """Files that load `path` by a built string: those naming its closest directory as a res:// prefix."""
    d = path
    while "/" in d:
        d = d.rsplit("/", 1)[0]
        needle = f"res://{d}/"
        hit = {rel for rel, t in texts.items() if needle in t}
        if hit:
            return hit
    return set()


def select(tree, base, head="HEAD"):
    """(flags or None for ALL, reason). None: a shared file changed, or a changed game file no check can be tied to."""
    changed = [ln for ln in git(tree, "diff", "--name-only", f"{base}...{head}").splitlines() if ln]
    game = [c for c in changed if not INERT.search(c)]
    if not game:
        return [], f"{len(changed)} changed files, none feed a check"
    edges, texts = dep_index(tree, head)
    inputs = check_inputs(tree, head, edges)
    picked = set()
    reg = [c for c in game if c == "tools/check_registry.gd"]
    if reg:  # only the entries that changed, unless the dispatcher itself did
        rp = "tools/check_registry.gd"
        old, new = (read_rev(tree, r, [rp]).get(rp, "") for r in (base, head))
        if strip_checks(old) != strip_checks(new):
            return None, "tools/check_registry.gd changed outside CHECKS"
        eo, en = registry_entries(old), registry_entries(new)
        picked |= {f for f in en if eo.get(f) != en[f] and f in inputs}
        game.remove("tools/check_registry.gd")
    shared = [c for c in game if c in SHARED]
    if shared:
        return None, "shared file changed: " + ", ".join(shared[:3])
    tied, loose = set(), []
    for c in game:
        if not GAME_EXT.search(c):
            continue  # python/shell helpers: no Godot check reads them
        users = {f for f, deps in inputs.items() if c in deps}
        if not users:
            via = owners(c, texts, edges)
            users = {f for f, deps in inputs.items() if deps & via}
            if not users and not via:
                loose.append(c)
        tied |= users
    if loose:
        return None, f"{len(loose)} changed game files no check can be tied to (e.g. {loose[0]})"
    picked |= tied
    flags = [f for f in inputs if f in picked]
    return flags, f"{len(game)} changed game files -> {len(flags)}/{len(inputs)} flags"


# ---------------------------------------------------------------- running one flag
def godot_id(godot):
    path = shutil.which(godot) or godot
    real = os.path.realpath(path)
    h = hashlib.sha256()
    with open(real, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def tree_key(tree):
    """The tree's content: HEAD's tree sha plus a hash of tracked edits that are not .import churn."""
    sha = git(tree, "rev-parse", "HEAD^{tree}").strip()
    dirty = [ln for ln in git(tree, "status", "--porcelain", "-uno").splitlines() if not ln.endswith(".import")]
    if dirty:
        sha += "-dirty" + hashlib.sha256(git(tree, "diff", "HEAD", "--", ".", ":!*.import").encode()).hexdigest()[:10]
    return sha


def verdict(rc, log):
    """green/red as the suite counts it (rc), plus mismatch when the check's own 'failures: N' disagrees with rc."""
    fails = [int(x) for x in FAIL_RE.findall(log)]
    said_bad = bool(fails) and max(fails) > 0
    said_ok = bool(fails) and max(fails) == 0
    mismatch = (rc == 0 and said_bad) or (rc not in (0, 124, 137) and said_ok and not ERR_RE.search(log))
    return ("green" if rc == 0 else "red"), mismatch


def run_flag(godot, tree, flag, timeout, extra):
    tmp = tempfile.mkdtemp(prefix="suite-")
    env = dict(os.environ, XDG_DATA_HOME=f"{tmp}/data", XDG_CONFIG_HOME=f"{tmp}/config", XDG_CACHE_HOME=f"{tmp}/cache")
    cmd = ["timeout", "-k", "10", str(timeout), godot, "--headless", *extra, "--path", str(tree), "--", flag]
    t0 = time.time()
    try:
        p = subprocess.run(cmd, cwd=tree, env=env, capture_output=True, text=True, errors="replace")
        rc, log = p.returncode, p.stdout + p.stderr
    except OSError as e:
        rc, log = 127, f"launch failed: {e}"
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    secs = round(time.time() - t0, 1)
    v, mm = verdict(rc, log)
    return {"flag": flag, "rc": rc, "secs": secs, "verdict": v, "mismatch": mm, "log": log}


# ---------------------------------------------------------------- the main-side cache
class Cache:
    def __init__(self, root, tree, godot, extra, strikes=2):
        self.strikes = strikes
        args = hashlib.sha1(" ".join(extra).encode()).hexdigest()[:6]
        self.dir = Path(root) / tree_key(tree) / f"{godot_id(godot)}-{args}"

    def get(self, flag):
        p = self.dir / (flag.lstrip("-") + ".json")
        try:
            return json.loads(p.read_text())
        except (OSError, ValueError):
            return None

    def put(self, r):
        """Greens, and reds the check itself judged ('failures: N' > 0). A red with no verdict of its own (crash,
        timeout, bad launch) may be the environment, so it is re-run next time instead of cached. Exception: a
        timeout (rc 124/137) seen in `strikes` finished gates in a row on this same key is cached as red."""
        if r.get("aborted") or r.get("mismatch"):
            return
        self.dir.mkdir(parents=True, exist_ok=True)
        sp = self.dir / (r["flag"].lstrip("-") + ".strikes")
        if r["verdict"] == "red" and not any(int(x) > 0 for x in FAIL_RE.findall(r["log"])):
            if r["rc"] not in (124, 137) or self.strikes <= 0:
                return
            try:
                n = int(sp.read_text()) + 1
            except (OSError, ValueError):
                n = 1
            sp.write_text(f"{n}\n")
            if n < self.strikes:
                return
            r = dict(r, timeout_strikes=n)
        else:
            sp.unlink(missing_ok=True)
        rec = {k: r[k] for k in ("flag", "rc", "secs", "verdict", "mismatch") if k in r}
        if r.get("timeout_strikes"):
            rec["timeout_strikes"] = r["timeout_strikes"]
        rec["log_tail"] = r["log"][-4000:]
        rec["ts"] = int(time.time())
        p = self.dir / (r["flag"].lstrip("-") + ".json")
        tmp = p.with_suffix(".tmp")
        tmp.write_text(json.dumps(rec))
        tmp.replace(p)


# ---------------------------------------------------------------- the gate
class Gate:
    def __init__(self, a):
        a.main, a.merge = os.path.abspath(a.main), os.path.abspath(a.merge)
        self.a = a
        self.out = Path(a.out)
        self.out.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()
        self.res = {"main": {}, "merge": {}}
        self.abort = threading.Event()
        self.t0 = time.time()
        self.extra = a.godot_args.split() if a.godot_args else []

    def log(self, msg):
        line = f"[{time.time() - self.t0:7.1f}s] {msg}"
        print(line, flush=True)
        with open(self.out / "gate.log", "a") as fh:
            fh.write(line + "\n")

    def record(self, side, r, cached=False):
        r["cached"] = cached
        with self.lock:
            self.res[side][r["flag"]] = r
        d = self.out / side
        d.mkdir(exist_ok=True)
        name = r["flag"].lstrip("-")
        (d / f"{name}.log").write_text(r.get("log") or r.get("log_tail", ""))
        (d / f"{name}.rc").write_text(f"{r['rc']}\n")
        if not cached:
            (d / f"{name}.secs").write_text(f"{r['secs']}\n")
            with open(self.out / "history.tsv", "a") as fh:
                fh.write(f"{r['flag']}\t{r['secs']}\t{side}\t{r['verdict']}\n")

    def run_many(self, jobs, label):
        """jobs: list of (side, tree, flag), started in that order on a.jobs workers. With --main-lazy a merge red
        queues its main run at the FRONT, so the pair finishes early and the tail stays short. Stops launching new
        runs on abort."""
        q = [(0, i, j) for i, j in enumerate(jobs)]
        heapq.heapify(q)
        cv = threading.Condition()
        state = {"busy": 0, "seq": len(jobs), "err": None}

        def worker():
            while True:
                with cv:
                    while not q and state["busy"]:
                        cv.wait()
                    if not q or self.abort.is_set() or state["err"]:
                        cv.notify_all()
                        return
                    side, tree, flag = heapq.heappop(q)[2]
                    state["busy"] += 1
                follow = None
                try:
                    r = self._one(side, tree, flag)
                    if label == "body" and r:
                        self.mass_red_check()
                        follow = self.follow_up(side, r)
                except Exception as e:  # noqa: BLE001 - re-raised after the pool drains
                    state["err"] = e
                with cv:
                    if follow:
                        heapq.heappush(q, (-1, state["seq"], follow))
                        state["seq"] += 1
                    state["busy"] -= 1
                    cv.notify_all()

        threads = [threading.Thread(target=worker, daemon=True) for _ in range(max(1, self.a.jobs))]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        if state["err"]:
            raise state["err"]

    def follow_up(self, side, r):
        """--main-lazy: the main side only matters when the merge side is red (green merge = no NEW-RED)."""
        f = r["flag"]
        if not self.a.main_lazy or side != "merge" or r["verdict"] != "red" or f not in self.main_flags:
            return None
        with self.lock:
            if f in self.res["main"]:
                return None
        return ("main", self.a.main, f)

    def _one(self, side, tree, flag):
        if self.abort.is_set():
            return None
        r = run_flag(self.a.godot, tree, flag, self.a.timeout, self.extra)
        if self.abort.is_set():
            r["aborted"] = True
        self.record(side, r)
        return r

    def red_both(self, f):
        return self.res["main"][f]["verdict"] == "red" and self.res["merge"][f]["verdict"] == "red"

    def mass_red_check(self):
        """Mid-run guard: stop when most paired runs are red on both trees, or most merge runs are red at all."""
        with self.lock:
            both = [f for f in self.res["merge"] if f in self.res["main"] and not self.res["main"][f].get("cached")]
            red = [f for f in both if self.red_both(f)]
            mg = list(self.res["merge"].values())
            mred = sum(1 for r in mg if r["verdict"] == "red")
        n, lo, frac = len(both), self.a.massred_min, self.a.massred_frac
        if self.a.main_lazy:  # main only runs after a merge red, so pairs are mostly red: count against all merge runs
            n = len(mg)
        if self.abort.is_set():
            return
        if n >= lo and len(red) / n >= frac:
            self.env_broken(f"mass red: {len(red)}/{n} flags red on BOTH trees")
        elif len(mg) >= lo and mred / len(mg) >= frac:
            self.env_broken(f"mass red: {mred}/{len(mg)} merge-tree flags red (env or the merge itself is broken)")

    def env_broken(self, why):
        self.abort.set()
        line = f"ENV-BROKEN: {why} (gate {self.out}, {time.strftime('%Y-%m-%d %H:%M:%S')})"
        self.log(line)
        with open(self.out / "summary.txt", "a") as fh:
            fh.write(line + "\n")
        if self.a.alert_file:
            p = Path(self.a.alert_file)
            p.parent.mkdir(parents=True, exist_ok=True)
            tmp = p.with_suffix(".tmp")
            tmp.write_text(line + "\n")
            tmp.replace(p)

    def canary(self, flags):
        names = [f for f in self.a.canary.split(",") if f] if self.a.canary else []
        names = [f for f in names if f in flags]
        if not names:
            return True
        self.log(f"canary: {len(names)} flags on both trees")
        self.run_many([(s, t, f) for f in names for s, t in (("main", self.a.main), ("merge", self.a.merge))], "canary")
        both_red = [f for f in names if self.red_both(f)]
        mism = [f"{s}:{f}" for f in names for s in ("main", "merge") if self.res[s][f]["mismatch"]]
        self.log(f"canary: {len(both_red)}/{len(names)} red on both, {len(mism)} rc/verdict mismatches")
        if mism:
            self.env_broken(f"canary rc disagrees with the check's own 'failures: N' ({', '.join(mism[:4])})")
            return False
        if len(both_red) >= self.a.canary_frac * len(names):
            self.env_broken(f"canary {len(both_red)}/{len(names)} red on BOTH trees ({', '.join(both_red[:4])})")
            return False
        return True

    def run(self):
        a = self.a
        flags = suite_flags(a.merge)
        if a.flags:
            keep = set(Path(a.flags).read_text().split())
            flags = [f for f in flags if f in keep]
        main_flags = self.main_flags = set(suite_flags(a.main))
        hist = load_history(a.history)
        self.cache = None if a.no_cache else Cache(a.cache_dir, a.main, a.godot, self.extra, a.timeout_strikes)
        scope = "full"
        if a.select_base:
            picked, why = select(a.merge, a.select_base)
            self.log(f"select vs {a.select_base}: {why}")
            if picked is not None:
                flags = [f for f in flags if f in set(picked)]
                scope = f"selected {len(flags)}"
        if a.order == "lpt":
            flags = order_flags(flags, hist)
        if not a.no_canary and not self.canary(flags):
            return self.summary(flags, scope)
        # main side: cached results count exactly like fresh ones (a cached red is red)
        hits = 0
        for f in flags:
            if f in self.res["main"] or f not in main_flags:
                continue
            c = self.cache.get(f) if self.cache else None
            if c:
                self.record("main", c, cached=True)
                hits += 1
        self.log(f"main cache: {hits} hits, {len(flags)} flags, jobs={a.jobs}, order={a.order}")
        work = []
        for f in flags:  # interleave so both sides of a flag land close together (mass-red sees pairs early)
            if f not in self.res["merge"]:
                work.append(("merge", a.merge, f))
            if f in main_flags and f not in self.res["main"] and not a.main_lazy:
                work.append(("main", a.main, f))
        self.run_many(work, "body")
        return self.summary(flags, scope)

    def summary(self, flags, scope):
        wall = time.time() - self.t0
        m, g = self.res["main"], self.res["merge"]
        new_red = [f for f in flags if g.get(f, {}).get("verdict") == "red" and m.get(f, {}).get("verdict") == "green"]
        fixed = [f for f in flags if g.get(f, {}).get("verdict") == "green" and m.get(f, {}).get("verdict") == "red"]
        both = [f for f in flags if g.get(f, {}).get("verdict") == "red" and m.get(f, {}).get("verdict") == "red"]
        mf = getattr(self, "main_flags", set())
        main_only = [f for f in flags if f not in mf and g.get(f, {}).get("verdict") == "red"]
        ran = sum(1 for s in m.values() if not s.get("cached")) + len(g)
        cached = sum(1 for s in m.values() if s.get("cached"))
        lazy = sum(1 for f in flags if g.get(f, {}).get("verdict") == "green" and f not in m and f in mf)
        lines = [
            f"gate {'ABORTED' if self.abort.is_set() else 'done'}: {scope} suite, {len(flags)} flags,"
            f" wall {wall / 60:.1f} min,"
            f" {ran} runs, {cached} main results from cache, jobs={self.a.jobs}, order={self.a.order}"
            + (f", main skipped for {lazy} merge greens (--main-lazy)" if self.a.main_lazy else ""),
            f"merge red {sum(1 for r in g.values() if r['verdict'] == 'red')}/{len(g)},"
            f" main red {sum(1 for r in m.values() if r['verdict'] == 'red')}/{len(m)}",
            f"NEW-RED {len(new_red)}: {' '.join(new_red)}",
            f"NEW-RED (new flag, no main) {len(main_only)}: {' '.join(main_only)}",
            f"red on both {len(both)}: {' '.join(both)}",
            f"fixed {len(fixed)}: {' '.join(fixed)}",
        ]
        mism = [f"{s}:{f}" for s in ("main", "merge") for f, r in self.res[s].items() if r.get("mismatch")]
        tos = sorted(f for f, r in m.items() if r.get("cached") and r.get("timeout_strikes"))
        if tos:
            lines.append(f"main timeouts from cache (timed out in {self.a.timeout_strikes}+ gates) {len(tos)}: {' '.join(tos)}")
        if mism:
            lines.append(f"RC-MISMATCH {len(mism)}: {' '.join(mism)}")
        with open(self.out / "summary.txt", "a") as fh:
            fh.write("\n".join(lines) + "\n")
        if self.cache and not self.abort.is_set():  # only a finished, sane gate feeds the cache
            for r in m.values():
                if not r.get("cached"):
                    self.cache.put(r)
        print("\n".join(lines))
        rc = 3 if self.abort.is_set() else (1 if new_red or main_only else 0)
        (self.out / "rc").write_text(f"{rc}\n")
        return rc


# ---------------------------------------------------------------- cli
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("flags").add_argument("tree")
    p = sub.add_parser("stats")
    p.add_argument("hist")
    p.add_argument("--top", type=int, default=10)
    p = sub.add_parser("order")
    p.add_argument("flags")
    p.add_argument("hist")
    p = sub.add_parser("simulate")
    p.add_argument("flags")
    p.add_argument("hist")
    p.add_argument("--jobs", type=int, default=8)
    for name in ("cache-get", "cache-put"):  # for shell runners: suite-fast.sh keeps its loop, asks the cache per flag
        p = sub.add_parser(name)
        p.add_argument("tree")
        p.add_argument("flag")
        if name == "cache-put":
            p.add_argument("rc", type=int)
            p.add_argument("log")
            p.add_argument("secs", type=float)
        p.add_argument("--godot", default="godot")
        p.add_argument("--godot-args", default="")
        p.add_argument("--cache-dir", default=os.path.expanduser("~/.cache/boki-suite/main"))
    p = sub.add_parser("select")
    p.add_argument("tree")
    p.add_argument("base")
    p.add_argument("head", nargs="?", default="HEAD")
    p = sub.add_parser("gate")
    p.add_argument("--main", required=True, help="main (release tag) tree")
    p.add_argument("--merge", required=True, help="merge candidate tree")
    p.add_argument("--out", required=True)
    p.add_argument("--jobs", type=int, default=8, help="parallel godot runs in total")
    p.add_argument("--timeout", type=int, default=300)
    p.add_argument("--godot", default="godot")
    p.add_argument("--godot-args", default="", help="extra engine args, part of the cache key")
    p.add_argument("--history", default=os.path.expanduser("~/.cache/boki-suite/history.tsv"))
    p.add_argument("--cache-dir", default=os.path.expanduser("~/.cache/boki-suite/main"))
    p.add_argument("--no-cache", action="store_true")
    p.add_argument("--timeout-strikes", type=int, default=2,
                   help="cache a main-side timeout as red after this many finished gates in a row timed out (0: never)")
    p.add_argument("--main-lazy", action="store_true",
                   help="run the main side only for flags red on merge (a merge green cannot be NEW-RED);"
                   " 'fixed' then lists only flags whose main red is known (cache or run)")
    p.add_argument("--order", choices=("lpt", "registry"), default="lpt")
    p.add_argument("--canary", default="", help="comma list of known-stable flags (canary.txt)")
    p.add_argument("--canary-frac", type=float, default=0.5, help="ENV-BROKEN when this share is red on both")
    p.add_argument("--no-canary", action="store_true")
    p.add_argument("--massred-min", type=int, default=24)
    p.add_argument("--massred-frac", type=float, default=0.6)
    p.add_argument("--alert-file", default="", help="DISK_ALERT-style file the watcher reads")
    p.add_argument("--flags", default="", help="file: run only these flags (one per line)")
    p.add_argument("--select-base", default="", help="merge-candidate runs: only flags whose inputs changed since")
    a = ap.parse_args(argv)

    if a.cmd == "flags":
        print("\n".join(suite_flags(a.tree)))
    elif a.cmd == "stats":
        rows = stats_rows(load_history(a.hist))
        allp = [r[1] for r in rows]
        print(
            f"{len(rows)} flags; per-flag p50: median {pct(allp, 0.5):.0f}s, p90 {pct(allp, 0.9):.0f}s,"
            f" sum {sum(allp) / 60:.0f} min"
        )
        print("slowest (by p90): flag p50 p90 runs")
        for f, p50, p90, n in rows[: a.top]:
            print(f"  {f} {p50:.0f} {p90:.0f} {n}")
    elif a.cmd == "order":
        flags = Path(a.flags).read_text().split()
        print("\n".join(order_flags(flags, load_history(a.hist))))
    elif a.cmd == "simulate":
        flags = Path(a.flags).read_text().split()
        hist = load_history(a.hist)
        secs = {f: pct(v, 0.5) for f, v in hist.items()}
        lpt = order_flags(flags, hist)
        given, longest = simulate(flags, secs, a.jobs), simulate(lpt, secs, a.jobs)
        print(f"jobs={a.jobs}: given order {given / 60:.1f} min, longest-first {longest / 60:.1f} min,"
              f" floor {sum(secs.get(f, DEFAULT_SECS) for f in flags) / a.jobs / 60:.1f} min")
    elif a.cmd in ("cache-get", "cache-put"):
        c = Cache(a.cache_dir, a.tree, a.godot, a.godot_args.split())
        if a.cmd == "cache-get":  # hit: prints rc on line 1 then the log tail, exit 0; miss: exit 1
            r = c.get(a.flag)
            if not r:
                return 1
            print(r["rc"])
            print(r.get("log_tail", ""))
            return 0
        log = Path(a.log).read_text(errors="replace")
        v, mm = verdict(a.rc, log)
        c.put({"flag": a.flag, "rc": a.rc, "secs": a.secs, "verdict": v, "mismatch": mm, "log": log})
    elif a.cmd == "select":
        picked, why = select(a.tree, a.base, a.head)
        print(f"# {why}")
        print("ALL" if picked is None else "\n".join(picked))
    elif a.cmd == "gate":
        return Gate(a).run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
