"""Loudness table per bus (ffmpeg ebur128): python3 tools/audio_lufs_report.py [--json out.json] [--md out.md]
Buses: ui, kit, hit, ambience, music, voice. Flags files >3 LU off their bus median (docs/AUDIO.d/loudness-1128.md)."""
import glob, json, os, re, subprocess, sys, statistics
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOL = 3.0

def cats():
    c = {}
    for f in glob.glob(os.path.join(ROOT, "content/sfx/*.json")):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        for k, v in (d.get("sounds") or {}).items():
            c[k] = v if isinstance(v, str) else (v.get("category") if isinstance(v, dict) else None)
    return c

def bus(path, cat):
    n = os.path.basename(path)
    stem = re.sub(r"(_\d+)?\.(ogg|wav)$", "", n)
    if n.startswith("amb_"): return "ambience"
    if n.startswith("music") or "/music" in path: return "music"
    if "/cries/" in path or n.startswith("v_") or cat in ("grunt", "boki"): return "voice"
    cc = cat.get(stem) or cat.get(re.sub(r"\.(ogg|wav)$", "", n))
    if cc == "ui": return "ui"
    if cc in ("grunt", "boki"): return "voice"
    if n.startswith("hit_") or n == "hit.wav" or (cc or "").startswith("hit"): return "hit"
    return "kit"

def measure(p, loop=False):
    # integrated LUFS needs >=0.4 s; shorter one-shots are looped up to ~2.4 s first (loudness of the sound itself, silence gaps kept)
    af = "aloop=loop=-1:size=2147483647,atrim=0:2.4,ebur128=peak=true" if loop else "ebur128=peak=true"
    r = subprocess.run(["ffmpeg", "-nostats", "-i", p, "-af", af, "-f", "null", "-"], capture_output=True, text=True)
    t = r.stderr.split("Summary:")[-1]
    i = re.search(r"I:\s+(-?[\d.]+|-inf) LUFS", t); tp = re.search(r"Peak:\s+(-?[\d.]+|-inf) dBFS", t)
    f = lambda m: float(m.group(1)) if m else None
    i, tp = f(i), f(tp)
    if not loop and (i is None or i <= -70):
        return measure(p, True)
    return i, tp

def run():
    cat = cats()
    files = sorted(glob.glob(os.path.join(ROOT, "audio/**/*.ogg"), recursive=True) + glob.glob(os.path.join(ROOT, "audio/**/*.wav"), recursive=True))
    with ThreadPoolExecutor(8) as ex:
        res = list(ex.map(measure, files))
    rows = []
    for p, (i, tp) in zip(files, res):
        n = os.path.basename(p); stem = re.sub(r"(_\d+)?\.(ogg|wav)$", "", n)
        cc = cat.get(stem)
        b = "ambience" if n.startswith("amb_") else "music" if n.startswith("music") else "voice" if ("/cries/" in p or n.startswith("v_") or cc in ("grunt", "boki")) else "ui" if cc == "ui" else "hit" if (n.startswith("hit_") or n.startswith("hit.")) else "kit"
        rows.append({"file": os.path.relpath(p, ROOT), "bus": b, "lufs": i, "tp": tp})
    for b in {r["bus"] for r in rows}:
        v = [r["lufs"] for r in rows if r["bus"] == b and r["lufs"] is not None and r["lufs"] > -70]
        m = statistics.median(v) if v else 0
        for r in rows:
            if r["bus"] == b:
                r["median"] = m
                r["off"] = None if r["lufs"] is None or r["lufs"] <= -70 else r["lufs"] - m
                r["flag"] = r["off"] is not None and abs(r["off"]) > TOL
    return rows

if __name__ == "__main__":
    rows = run()
    a = sys.argv
    if "--json" in a: json.dump(rows, open(a[a.index("--json") + 1], "w"))
    for b in ("ui", "kit", "hit", "ambience", "music", "voice"):
        r = [x for x in rows if x["bus"] == b]
        print(b, len(r), "median", round(r[0]["median"], 1) if r else "-", "flagged", sum(x["flag"] for x in r), "tp>-1", sum(1 for x in r if x["tp"] is not None and x["tp"] > -1))
