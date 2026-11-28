"""Re-render loudness outliers from a tools/audio_lufs_report.py json: constant gain (ffmpeg loudnorm linear mode
equivalent) toward the group median, capped so true peak stays <= -1 dBTP. Length, tails, rate, channels unchanged.
python3 tools/audio_lufs_fix.py before.json [--dry]"""
import json, os, re, glob, subprocess, sys, statistics as st, collections
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = json.load(open(sys.argv[1])); dry = "--dry" in sys.argv
cat = {}
for f in glob.glob(os.path.join(ROOT, "content/sfx/*.json")):
    for k, v in (json.load(open(f)).get("sounds") or {}).items(): cat[k] = v
g = collections.defaultdict(list)
ok = lambda x: x["lufs"] is not None and x["lufs"] > -70
for x in rows:
    stem = re.sub(r"(_\d+)?\.(ogg|wav)$", "", os.path.basename(x["file"]))
    c = cat.get(stem); x["grp"] = (x["bus"], c if x["bus"] in ("kit", "voice") else None)
    if ok(x): g[x["grp"]].append(x["lufs"])
out = []
for x in rows:
    if x["bus"] not in ("ui", "kit", "hit", "voice") or not ok(x): continue
    k = x["grp"] if len(g[x["grp"]]) >= 5 else (x["bus"], None)
    ref = st.median(g[k]) if len(g[k]) >= 5 else x["median"]
    if abs(x["lufs"] - ref) <= 3: continue
    gain = ref - x["lufs"]
    if x["tp"] is not None and x["tp"] + gain > -1.0: gain = -1.0 - x["tp"]
    if abs(gain) < 0.5: continue
    out.append((x["file"], round(gain, 2)))
    if dry: continue
    p = os.path.join(ROOT, x["file"]); tmp = p + ".tmp." + p.rsplit(".", 1)[1]
    codec = ["-c:a", "pcm_s16le"] if p.endswith(".wav") else ["-c:a", "libvorbis", "-q:a", "6"]
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-af", "volume=%sdB" % gain, "-map_metadata", "-1"] + codec + [tmp], check=True)
    os.replace(tmp, p)
json.dump(out, open("/tmp/lp/fixed.json", "w"))
print(len(out), "re-rendered" if not dry else "would re-render")
