"""Loudness audit: every sound the game names, grouped by category, against the category's median.

    python3 tools/sfx_loudness.py            per-category table (markdown, for docs/AUDIO.md) and the outliers
    python3 tools/sfx_loudness.py --check    exit 1 on an outlier not listed under "outliers_ok"
    python3 tools/sfx_loudness.py --brawl <log> [--undo-duck]  each rival wind-up's level over a brawl's mix
                                             (logs from godot -- --sfx-priority-check --brawl-out=<log>)

Sounds come from content/sfx/*.json ("sounds": name -> category) and the Sfx tables (Sfx.NAMES, Sfx.VOICES,
SfxKits.NAMES, VVSfx.NAMES); a table sound with no set gets its category from "table_cats" in
content/rules/sfx_levels.json. Level = RMS over the audible part (samples above 2% of the peak, as
tools/sfx_lib.py levels), averaged over a sound's takes, plus the gain the game adds in play: "gain_db" in
sfx_levels.json and Sfx.BLAST_DB for the blast sounds. A sound more than tolerance_db from its category's
median level is an outlier. Fix one with "gain_db" (data), never by editing the .wav.
"""

import glob, json, os, re, sys, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = [
    ("scripts/core/sfx.gd", "NAMES"),
    ("scripts/core/sfx.gd", "VOICES"),
    ("scripts/core/sfx_kits.gd", "NAMES"),
    ("scripts/arch/kits/vv_sfx.gd", "NAMES"),
]


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def gd_const(rel, name):
    """The string list (or number) a GDScript const holds."""
    m = re.search(r"^const %s\b[^=]*=\s*(\[.*?\]|-?[\d.]+)" % name, read(rel), re.S | re.M)
    return re.findall(r'"([^"]+)"', m.group(1)) if m.group(1).startswith("[") else float(m.group(1))


def sound_cats(levels):
    cats = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "content", "sfx", "*.json"))):
        with open(f, encoding="utf-8") as fh:
            cats.update(json.load(fh).get("sounds", {}))
    by_name = {n: c for c, names in levels["table_cats"].items() for n in names}
    missing = []
    for rel, const in TABLES:
        for n in gd_const(rel, const):
            if n not in cats:
                if n in by_name:
                    cats[n] = by_name[n]
                else:
                    missing.append(n)
    return cats, missing


def takes(name):
    base = os.path.join(ROOT, "audio", name)
    found = [base + ".wav"] if os.path.exists(base + ".wav") else []
    return found + sorted(glob.glob(base + "_[0-9].wav"))


def measure(path):
    """Peak and RMS (dBFS) of a 16-bit PCM wav; RMS over samples above 2% of the peak."""
    with wave.open(path, "rb") as w:
        ch = w.getnchannels()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    pk = float(np.max(np.abs(x))) if len(x) else 0.0
    act = x[np.abs(x) > pk * 0.02]
    rms = float(np.sqrt(np.mean(act * act))) if len(act) else 0.0
    return 20 * np.log10(max(pk, 1e-6)), 20 * np.log10(max(rms, 1e-6))


def audit():
    with open(os.path.join(ROOT, "content", "rules", "sfx_levels.json"), encoding="utf-8") as f:
        levels = json.load(f)
    cats, missing = sound_cats(levels)
    blast, blast_db = gd_const("scripts/core/sfx.gd", "BLAST"), gd_const("scripts/core/sfx.gd", "BLAST_DB")
    rows = {}
    for name, cat in cats.items():
        files = takes(name)
        if not files:
            missing.append(name + " (no file)")
            continue
        m = [measure(p) for p in files]
        gain = float(levels["gain_db"].get(name, 0.0)) + (blast_db if name in blast else 0.0)
        rows[name] = {"cat": cat, "peak": max(p for p, _ in m), "rms": float(np.mean([r for _, r in m])), "gain": gain}
    groups = {}
    for name, r in rows.items():
        r["level"] = r["rms"] + r["gain"]
        groups.setdefault(r["cat"], []).append(name)
    tol = float(levels["tolerance_db"])
    medians = {c: float(np.median([rows[n]["level"] for n in names])) for c, names in groups.items()}
    outliers = {n: r["level"] - medians[r["cat"]] for n, r in rows.items() if abs(r["level"] - medians[r["cat"]]) > tol}
    return levels, rows, groups, medians, outliers, missing


def table(levels, rows, groups, medians, outliers):
    out = [
        "| category | sounds | median level | target RMS | quietest | loudest | max peak | outliers (accepted) |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for c in sorted(groups, key=lambda c: -medians[c]):
        names = sorted(groups[c], key=lambda n: rows[n]["level"])
        lo, hi = names[0], names[-1]
        bad = [n for n in names if n in outliers]
        ok = sum(1 for n in bad if n in levels["outliers_ok"])
        target = levels["cats"].get(c)
        out.append(
            "| %s | %d | %.1f | %s | %s %.1f | %s %.1f | %.1f | %d (%d) |"
            % (
                c,
                len(names),
                medians[c],
                "%.1f" % target if target is not None else "-",
                lo,
                rows[lo]["level"],
                hi,
                rows[hi]["level"],
                max(rows[n]["peak"] + rows[n]["gain"] for n in names),
                len(bad),
                ok,
            )
        )
    return "\n".join(out)


BRAWL_SR = 22050
WINDUPS = ("hostile_cast", "ult_tag_foe")


def wav_at(name, sr=BRAWL_SR):
    """First take of a sound, mono, resampled to sr."""
    files = takes(name)
    if not files:
        return None
    with wave.open(files[0], "rb") as w:
        n, ch, rate = w.getnframes(), w.getnchannels(), w.getframerate()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(float) / 32768.0
    x = x.reshape(-1, ch).mean(axis=1) if ch > 1 else x
    return x if rate == sr else np.interp(np.arange(int(len(x) * sr / rate)) * rate / sr, np.arange(len(x)), x)


def rms_db(x):
    return 20 * np.log10(max(float(np.sqrt(np.mean(x * x))) if len(x) else 0.0, 1e-6))


CAST_MS = 60  # a rival sound starting this close to a wind-up edge, at the edge's distance, is the cast it rides on


def brawl(path, undo=False):
    """Mix a --sfx-priority-check log ("ms name rank dB duck" per sound) and measure each rival wind-up over it.
    A wind-up is the edge (hostile_cast / ult_tag_foe) plus the caster's own sounds started with it; the masker
    is everything else. undo: the same fight with the logged duck put back (before)."""
    ev, cache = [], {}
    for ln in open(path, encoding="utf-8"):
        f = ln.split()
        t, name, rank, db, duck = f + ["0"] * (5 - len(f))
        if name not in cache:
            cache[name] = wav_at(name)
        if cache[name] is not None:
            ev.append((int(t) / 1000.0, name, float(rank), float(db) - (float(duck) if undo else 0.0)))
    edges = [k for k, (t, n, rk, _) in enumerate(ev) if rk >= 0 and n in WINDUPS]
    cast = {k: e for e in edges for k, (t, n, rk, _) in enumerate(ev)
            if rk >= 0 and abs(t - ev[e][0]) * 1000 <= CAST_MS and abs(rk - ev[e][2]) < 0.5}
    total = max(t + len(cache[n]) / BRAWL_SR for t, n, _, _ in ev) + 0.1
    own = np.zeros(int(total * BRAWL_SR))
    rest = np.zeros_like(own)
    warn = {e: np.zeros_like(own) for e in edges}
    for k, (t, n, rk, db) in enumerate(ev):
        x, i = cache[n] * 10 ** (db / 20), int(t * BRAWL_SR)
        tgt = own if rk == -2.0 else rest
        if k in cast:
            tgt = warn[cast[k]]
        tgt[i:i + len(x)] += x[:len(tgt) - i]
    rows = []
    for e in edges:
        t, n, _, db = ev[e]
        a = int(t * BRAWL_SR)
        b = a + len(cache[n])
        edge = cache[n] * 10 ** (db / 20)
        rows.append((n, rms_db(edge), rms_db(own[a:b]), rms_db(own[a:b] + rest[a:b]), rms_db(warn[e][a:b])))
    return rows


def brawl_report(paths):
    undo = "--undo-duck" in paths
    paths = [p for p in paths if p != "--undo-duck"]
    for path in paths:
        rows = brawl(path, undo)
        m = lambda k: float(np.mean([r[k] for r in rows])) if rows else float("nan")
        for n in sorted({r[0] for r in rows}):
            rr = [r for r in rows if r[0] == n]
            print("  %-14s x%-3d edge %.1f dB, wind-up (edge + cast) %.1f, your sounds %.1f, rest of mix %.1f" % (
                n, len(rr), np.mean([r[1] for r in rr]), np.mean([r[4] for r in rr]),
                np.mean([r[2] for r in rr]), np.mean([r[3] for r in rr])))
        print("%s%s: %d wind-ups; edge over your sounds %+.1f dB, over the rest of the mix %+.1f dB; "
              "wind-up over the rest %+.1f dB, buried %d" % (
                  os.path.basename(path), " (duck undone)" if undo else "", len(rows), m(1) - m(2), m(1) - m(3),
                  m(4) - m(3), sum(1 for r in rows if r[4] < r[3])))


def main():
    if "--brawl" in sys.argv:
        return brawl_report(sys.argv[sys.argv.index("--brawl") + 1:])
    levels, rows, groups, medians, outliers, missing = audit()
    fresh = {n: d for n, d in outliers.items() if n not in levels["outliers_ok"]}
    stale = [n for n in levels["outliers_ok"] if n not in outliers]
    if "--check" not in sys.argv:
        print(table(levels, rows, groups, medians, outliers))
        print()
        for n, d in sorted(outliers.items(), key=lambda kv: -abs(kv[1])):
            r = rows[n]
            print(
                "%-24s %-12s %+5.1f dB  rms %.1f gain %+.1f peak %.1f%s"
                % (n, r["cat"], d, r["rms"], r["gain"], r["peak"], "  (accepted)" if n in levels["outliers_ok"] else "")
            )
    for n in missing:
        print("NO CATEGORY OR FILE: " + n)
    for n in stale:
        print("STALE outliers_ok entry (now within %.0f dB, remove it): %s" % (levels["tolerance_db"], n))
    for n, d in sorted(fresh.items()):
        print(
            "OUTLIER %s (%s) %+.1f dB from its category median: set gain_db in content/rules/sfx_levels.json"
            % (n, rows[n]["cat"], d)
        )
    for n in sorted(n for n, r in rows.items() if r["gain"] > 0 and r["peak"] + r["gain"] > levels["peak_db"]):
        print(
            "GAIN CLIPS %s: peak %.1f + gain %+.1f is past the %.0f dBFS ceiling"
            % (n, rows[n]["peak"], rows[n]["gain"], levels["peak_db"])
        )
        missing.append(n)
    bad = len(fresh) + len(missing) + len(stale)
    print(
        "sfx loudness: %d sounds, %d categories, %d outliers (%d accepted), %s"
        % (len(rows), len(groups), len(outliers), len(outliers) - len(fresh), "FAIL" if bad else "OK")
    )
    if "--check" in sys.argv and bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
