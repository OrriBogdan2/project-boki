#!/usr/bin/env python3
"""Lint gate for Project Boki: one ratchet over gdlint, gdformat, ruff, vulture, gltf-validator, Godot warnings.

Usage (normally through tools/check.sh, which sets up the venv):
  lint_gate.py                  all checks over the whole repo; exit 1 when any file is worse than the baseline
  lint_gate.py --files a b ...  only those files (pre-commit); skips the Godot warning count
  lint_gate.py --changed [BASE] all checks, and every .gd the branch changes against BASE (origin/main) must be gdformat
                                clean; only for branches cut after this rule (their merge base has tools/format_batch.py)
  lint_gate.py --update         write tools/lint_baseline.json: counts only ever go down, a missing baseline is created

Baseline: {check: {file: problems}}. Old debt is listed there and may not grow; a file that is not listed must be clean.
For gdformat and ruff-format the count is 1 when the file would be reformatted.
"""

import json, os, re, shutil, subprocess, sys, tempfile, urllib.request
from concurrent.futures import ThreadPoolExecutor
from multiprocessing import Pool

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, "tools", "lint_baseline.json")
GD_DIRS = ("scripts", "tools", "tests")
LINE_LENGTH = 120
GLTF_VERSION = "2.0.0-dev.3.10"
GLTF_URL = f"https://github.com/KhronosGroup/glTF-Validator/releases/download/{GLTF_VERSION}/gltf_validator-{GLTF_VERSION}-linux64.tar.xz"
# Godot warnings tracked in the suite, by message: the unused-code ones (UNUSED_VARIABLE / _PARAMETER / _SIGNAL / ...)
# and shadowing (SHADOWED_VARIABLE / _VARIABLE_BASE_CLASS / SHADOWED_GLOBAL_IDENTIFIER: a name Godot already defines)
GODOT_WARNINGS = {
    "godot-unused": re.compile(r"never (explicitly )?used|never emitted|isn't used"),
    "godot-shadow": re.compile(r"is shadowing an already-declared|has the same name as a (built-in|native|global)"),
}


def tracked(*suffixes):
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return sorted(p for p in out.split("\0") if p.endswith(suffixes) and os.path.exists(os.path.join(ROOT, p)))


def gd_lint_config():
    import yaml
    from gdtoolkit.linter import DEFAULT_CONFIG

    with open(os.path.join(ROOT, "gdlintrc"), encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}
    return {**DEFAULT_CONFIG, **config}


def gd_one(path):
    """(gdlint problem messages, gdformat would change) for one .gd file; a file gdtoolkit cannot parse is 1 problem."""
    from gdtoolkit.formatter import format_code
    from gdtoolkit.linter import lint_code

    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        code = f.read()
    try:
        problems = [f"{path}:{p.line}: {p.description} ({p.name})" for p in lint_code(code, gd_lint_config())]
        changed = format_code(code, LINE_LENGTH) != code
    except Exception as e:
        return [f"{path}: gdtoolkit cannot parse this file ({type(e).__name__})"], False
    return problems, changed


def run_gd(files):
    with Pool() as pool:
        results = pool.map(gd_one, files, chunksize=8)
    lint = {p: r[0] for p, r in zip(files, results) if r[0]}
    fmt = {p: ["would be reformatted by gdformat --line-length 120"] for p, r in zip(files, results) if r[1]}
    return {"gdlint": lint, "gdformat": fmt}


def tool(name):
    for d in (os.path.dirname(sys.executable), *os.environ.get("PATH", "").split(os.pathsep)):
        if os.access(os.path.join(d, name), os.X_OK):
            return os.path.join(d, name)
    sys.exit(f"lint_gate: {name} not found (tools/check.sh installs it)")


def run_ruff(files):
    base = [tool("ruff")]
    out = subprocess.run(
        base + ["check", "--output-format", "concise", "--no-cache"] + files, cwd=ROOT, capture_output=True, text=True
    ).stdout
    lint, fmt = {}, {}
    for line in out.splitlines():
        m = re.match(r"^(\S+?):\d+:\d+: (.*)", line)
        if m:
            lint.setdefault(m.group(1), []).append(line)
    out = subprocess.run(
        base + ["format", "--check", "--no-cache", "--output-format", "concise"] + files,
        cwd=ROOT,
        capture_output=True,
        text=True,
    ).stdout
    for line in out.splitlines():
        m = re.match(r"^(\S+?):\d+:\d+: unformatted", line)
        if m:
            fmt[m.group(1)] = ["would be reformatted by ruff format"]
    return {"ruff": lint, "ruff-format": fmt}


def run_vulture(files):
    out = subprocess.run(
        [tool("vulture"), "--min-confidence", "80"] + tracked(".py"), cwd=ROOT, capture_output=True, text=True
    ).stdout
    found = {}
    for line in out.splitlines():
        m = re.match(r"^(\S+?):\d+: ", line)
        if m and m.group(1) in files:
            found.setdefault(m.group(1), []).append(line)
    return {"vulture": found}


def gltf_binary():
    for d in os.environ.get("PATH", "").split(os.pathsep) + [
        os.path.expanduser("~/tools"),
        os.path.expanduser("~/.cache/boki-lint"),
    ]:
        p = os.path.join(d, "gltf_validator")
        if os.access(p, os.X_OK):
            return p
    cache = os.path.expanduser("~/.cache/boki-lint")
    os.makedirs(cache, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        archive = os.path.join(tmp, "v.tar.xz")
        urllib.request.urlretrieve(GLTF_URL, archive)
        subprocess.run(["tar", "xf", archive, "-C", cache, "gltf_validator"], check=True)
    return os.path.join(cache, "gltf_validator")


def gltf_one(args):
    binary, path = args
    out = subprocess.run([binary, "-o", path], cwd=ROOT, capture_output=True, text=True).stdout
    try:
        issues = json.loads(out)["issues"]
    except (ValueError, KeyError):
        return path, [f"{path}: gltf_validator gave no report (file unreadable?)"]
    errors = [
        f"{path}: {m['code']} {m['message']} {m.get('pointer', '')}" for m in issues["messages"] if m["severity"] == 0
    ]
    return path, errors


def run_gltf(files):
    if not files:
        return {"gltf": {}}
    binary = gltf_binary()
    with ThreadPoolExecutor(8) as ex:
        results = list(ex.map(gltf_one, [(binary, p) for p in files]))
    return {"gltf": {p: e for p, e in results if e}}


def run_godot_warnings():
    """Load every script in a debug headless Godot (it prints GDScript warnings only with --debug) and count GODOT_WARNINGS."""
    godot = os.environ.get("GODOT", "godot")
    if not shutil.which(godot):
        sys.exit(f"lint_gate: {godot} not found: set GODOT=<path to godot>, or pass --no-godot")
    env = {**os.environ, "XDG_DATA_HOME": tempfile.mkdtemp(prefix="lint-xdg-")}
    out = subprocess.run(
        [godot, "--headless", "--debug", "--path", ROOT, "-s", "res://tools/warn_count.gd"],
        capture_output=True,
        text=True,
        env=env,
        timeout=600,
    )
    lines = (out.stdout + out.stderr).splitlines()
    found = {check: {} for check in GODOT_WARNINGS}
    for i, line in enumerate(lines):
        check = next((c for c, rx in GODOT_WARNINGS.items() if line.startswith("WARNING:") and rx.search(line)), None)
        at = re.search(r"\(res://(.+?):(\d+)\)", lines[i + 1]) if check and i + 1 < len(lines) else None
        if at:
            found[check].setdefault(at.group(1), []).append(f"{at.group(1)}:{at.group(2)}: {line[9:]}")
    return found


def changed_unformatted(base):
    """The .gd files changed since the merge base with `base` that gdformat would change (None: branch predates the rule)."""

    def git(*a):
        return subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True).stdout.strip()

    mb = git("merge-base", base, "HEAD")
    if not mb or not git("ls-tree", "--name-only", mb, "tools/format_batch.py"):
        return None
    files = git("diff", "--name-only", "--diff-filter=d", mb, "--", "*.gd").split()
    return [p for p in files if p.startswith(GD_DIRS) and gd_one(p)[1]]


def run_all(only, selected):
    gd = [p for p in tracked(".gd") if p.startswith(GD_DIRS) and (only is None or p in only)]
    py = [p for p in tracked(".py") if only is None or p in only]
    glb = [p for p in tracked(".glb", ".gltf") if only is None or p in only]
    res = {}
    if gd:
        res.update(run_gd(gd))
    if py:
        res.update(run_ruff(py))
        res.update(run_vulture(set(py)))
    res.update(run_gltf(glb))
    if only is None and selected:
        res.update(run_godot_warnings())
    return res


def main():
    args = sys.argv[1:]
    only = set(args[args.index("--files") + 1 :]) if "--files" in args else None
    res = run_all(only, "--no-godot" not in args)
    base = json.load(open(BASELINE, encoding="utf-8")) if os.path.exists(BASELINE) else {}
    if "--update" in args:
        new = {}
        for check, per_file in res.items():
            old = base.get(check)
            # first run of a check seeds it; after that a file's count can only go down
            new[check] = {
                p: len(m) if old is None else min(old[p], len(m))
                for p, m in per_file.items()
                if old is None or p in old
            }
        for check in base.keys() - res.keys():
            new[check] = base[check]
        with open(BASELINE, "w", encoding="utf-8") as f:
            json.dump(new, f, indent=1, sort_keys=True)
            f.write("\n")
        print("lint baseline written: " + ", ".join(f"{c} {sum(v.values())}" for c, v in sorted(new.items())))
        return
    failed = False
    for check, per_file in sorted(res.items()):
        old = base.get(check, {})
        worse = {p: m for p, m in per_file.items() if len(m) > old.get(p, 0)}
        print(
            f"lint {check}: {sum(len(m) for m in per_file.values())} problems in {len(per_file)} files"
            f" (baseline {sum(old.values())} in {len(old)}), {'FAIL ' + str(len(worse)) + ' files worse' if worse else 'ok'}"
        )
        for p, msgs in sorted(worse.items())[:15]:
            print(f"  {p}: {old.get(p, 0)} -> {len(msgs)}")
            for m in msgs[:5]:
                print("    " + m)
        failed = failed or bool(worse)
    if "--changed" in args:
        i = args.index("--changed") + 1
        dirty = changed_unformatted(args[i] if i < len(args) and not args[i].startswith("--") else "origin/main")
        if dirty is None:
            print("lint gdformat-changed: branch is older than the rule, skipped")
        else:
            print(f"lint gdformat-changed: {len(dirty)} changed files need gdformat --line-length {LINE_LENGTH}")
            print("".join(f"  {p}\n" for p in dirty), end="")
            failed = failed or bool(dirty)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
