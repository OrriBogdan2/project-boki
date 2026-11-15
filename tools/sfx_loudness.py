"""Loudness audit: every sound the game names, grouped by category, against the category's median.

    python3 tools/sfx_loudness.py            per-category table (markdown, for docs/AUDIO.md) and the outliers
    python3 tools/sfx_loudness.py --check    exit 1 on an outlier not listed under "outliers_ok"

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
TABLES = [("scripts/core/sfx.gd", "NAMES"), ("scripts/core/sfx.gd", "VOICES"),
          ("scripts/core/sfx_kits.gd", "NAMES"), ("scripts/arch/kits/vv_sfx.gd", "NAMES")]


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
    out = ["| category | sounds | median level | target RMS | quietest | loudest | max peak | outliers (accepted) |",
           "|---|---|---|---|---|---|---|---|"]
    for c in sorted(groups, key=lambda c: -medians[c]):
        names = sorted(groups[c], key=lambda n: rows[n]["level"])
        lo, hi = names[0], names[-1]
        bad = [n for n in names if n in outliers]
        ok = sum(1 for n in bad if n in levels["outliers_ok"])
        target = levels["cats"].get(c)
        out.append("| %s | %d | %.1f | %s | %s %.1f | %s %.1f | %.1f | %d (%d) |" % (
            c, len(names), medians[c], "%.1f" % target if target is not None else "-", lo, rows[lo]["level"],
            hi, rows[hi]["level"], max(rows[n]["peak"] + rows[n]["gain"] for n in names), len(bad), ok))
    return "\n".join(out)


def main():
    levels, rows, groups, medians, outliers, missing = audit()
    fresh = {n: d for n, d in outliers.items() if n not in levels["outliers_ok"]}
    stale = [n for n in levels["outliers_ok"] if n not in outliers]
    if "--check" not in sys.argv:
        print(table(levels, rows, groups, medians, outliers))
        print()
        for n, d in sorted(outliers.items(), key=lambda kv: -abs(kv[1])):
            r = rows[n]
            print("%-24s %-12s %+5.1f dB  rms %.1f gain %+.1f peak %.1f%s" % (
                n, r["cat"], d, r["rms"], r["gain"], r["peak"], "  (accepted)" if n in levels["outliers_ok"] else ""))
    for n in missing:
        print("NO CATEGORY OR FILE: " + n)
    for n in stale:
        print("STALE outliers_ok entry (now within %.0f dB, remove it): %s" % (levels["tolerance_db"], n))
    for n, d in sorted(fresh.items()):
        print("OUTLIER %s (%s) %+.1f dB from its category median: set gain_db in content/rules/sfx_levels.json" % (
            n, rows[n]["cat"], d))
    for n in sorted(n for n, r in rows.items() if r["gain"] > 0 and r["peak"] + r["gain"] > levels["peak_db"]):
        print("GAIN CLIPS %s: peak %.1f + gain %+.1f is past the %.0f dBFS ceiling" % (
            n, rows[n]["peak"], rows[n]["gain"], levels["peak_db"]))
        missing.append(n)
    bad = len(fresh) + len(missing) + len(stale)
    print("sfx loudness: %d sounds, %d categories, %d outliers (%d accepted), %s" % (
        len(rows), len(groups), len(outliers), len(outliers) - len(fresh), "FAIL" if bad else "OK"))
    if "--check" in sys.argv and bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
