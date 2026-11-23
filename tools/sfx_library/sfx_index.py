#!/usr/bin/env python3
"""Index a private sound library: one JSON line per audio file.
  sfx_index.py LIB_DIR OUT.jsonl
Fields: path (relative to LIB_DIR), bundle (first folder), pack (second folder), category, duration, channels,
rate, tags (words from the path). Category is a keyword bucket of the path, so a later job can search it.
Metadata only: audio is never sent to any AI service (licence v2.0 'no AI usage')."""

import json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

CATS = [
    ("weapon", r"gun|rifle|pistol|revolver|smg|shotgun|sniper|weapon|blaster|laser|plasma|bullet|reload|cock|musket"),
    ("ui", r"\bui\b|interface|click|button|menu|hover|select|confirm|pickup|pick up|coin|collect|reward|hud"),
    ("magic", r"magic|spell|cast|zap|elemental|fire ?ball|frost|buff|heal|summon|electric"),
    ("whoosh", r"whoosh|swoosh|swish|swipe|swing|flyby|fly-by|dash|glide|transition"),
    ("impact", r"impact|hit|punch|slam|smash|thud|crack|knock|bodyfall|body fall"),
    ("creature", r"creature|monster|growl|roar|grunt|pain|hurt|death|scream|vocal|groan"),
    ("foot", r"foot|step|jump|land"),
    ("stinger", r"stinger|sting|cinematic"),
]
AUDIO = (".wav", ".flac", ".ogg", ".mp3")


def probe(path):
    r = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=channels,sample_rate:format=duration",
            "-of",
            "json",
            path,
        ],
        capture_output=True,
        text=True,
    )
    try:
        j = json.loads(r.stdout)
        return float(j["format"]["duration"]), int(j["streams"][0]["channels"]), int(j["streams"][0]["sample_rate"])
    except Exception:
        return 0.0, 0, 0


def entry(root, rel):
    dur, ch, sr = probe(os.path.join(root, rel))
    parts = rel.split("/")
    low = rel.lower()
    cat = next((c for c, rx in CATS if re.search(rx, low)), "other")
    tags = sorted(set(w for w in re.split(r"[^a-z0-9]+", low.rsplit(".", 1)[0]) if len(w) > 2 and not w.isdigit()))
    return {
        "path": rel,
        "bundle": parts[0],
        "pack": parts[2]
        if len(parts) > 3 and re.search(r"part ?\d+ ?of ?\d+", parts[1], re.I)
        else parts[1]
        if len(parts) > 2
        else "",
        "category": cat,
        "duration": round(dur, 3),
        "channels": ch,
        "rate": sr,
        "tags": tags,
    }


if __name__ == "__main__":
    root, out = sys.argv[1], sys.argv[2]
    rels = sorted(
        os.path.relpath(os.path.join(d, f), root) for d, _, fs in os.walk(root) for f in fs if f.lower().endswith(AUDIO)
    )
    with ThreadPoolExecutor(8) as ex, open(out, "w") as fh:
        for e in ex.map(lambda r: entry(root, r), rels):
            fh.write(json.dumps(e) + "\n")
    print(len(rels), "files indexed ->", out)
