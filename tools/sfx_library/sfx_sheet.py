#!/usr/bin/env python3
"""Choice page for the sfx library: per game cue the live sound plus 4 ranked candidates A-D.
  sfx_sheet.py GAME_DIR LIB_DIR INDEX.jsonl SLOTS.json OUT_DIR [MANIFEST.json] [--rescan]
Every library file is decoded, cut into its sounds and measured (loudness, onset, length, spectrum, noise
floor); a cut is ranked by how close those numbers sit to the slot's `fit` profile in slots.json, with the
path keywords only as a small prior. Writes OUT_DIR/choices.html, clips/*.mp3 (levelled like the live
sound), mapping.json (A-D with library path and cut) and, if given, MANIFEST.json (every candidate, pick = A
unless the file already holds a pick; sfx_pack.py turns it into the private pack). Audio is never sent to an AI service (Sonniss licence v2.0)."""

import html
import json
import os
import re
import sys
from multiprocessing import Pool

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfxclip as C

KEEP = 30  # best cuts kept per slot after the scan
MIN_SNR = 25.0  # dB between the clip peak and the file's quietest stretch
LOOP_STEP = 0.3
LETTERS = "ABCDEFGH"


def trap(v, a, b, c, d):
    if v < a or v > d:
        return 0.0
    if v < b:
        return (v - a) / (b - a)
    return 1.0 if v <= c else (d - v) / (d - c)


def centred(v, a, b, c, d):
    """Full credit only inside [b, c] (best in the middle, 0.65 at the edges); partial credit up to 0.65 outside."""
    m = trap(v, a, b, c, d)
    if m < 1:
        return m * 0.65
    return 0.65 + 0.35 * max(0.0, 1 - abs(v - (b + c) / 2) / max((c - b) / 2, 1e-9))


def fit_score(f, fit):
    """Weighted mean of how well each measured number sits in its range, plus how clean the source is (peak over noise)."""
    tot = sum(r[4] for r in fit.values()) + 1.0
    clean = min(1.0, max(0.0, (f["snr"] - MIN_SNR) / 35))
    return (sum(centred(f[k], *r[:4]) * r[4] for k, r in fit.items()) + clean) / tot


def prior(slot, name, pack):
    """Name match 0..1 (the measurements cannot tell a gun from a door slam): whole words, the file name in full and the
    pack name at half. None if a word is excluded or no main word hits."""
    if slot["neg"] and re.search(slot["neg"], name + " " + pack):
        return None

    def hits(text):
        return sum(w for rx, w in slot["pos"] if re.search(r"\b(?:%s)(?:s|es)?\b" % rx, text))

    kw = min(1.0, (hits(name) + 0.5 * hits(pack)) / 6)
    return kw if kw >= 0.5 else None


def cuts(x, slot):
    """(start, end, clip) for each sound of the file that suits the slot's mode."""
    if slot["mode"] == "loop":
        n = int(slot["trim_max"] * C.SR)
        for s in range(0, len(x) - n, int(LOOP_STEP * C.SR)):
            yield s, s + n, C.loop_cut(x, s, slot["trim_max"])
        return
    for s, e in C.events(x):
        if (e - s) / C.SR <= slot["src_max"]:
            yield s, e, C.cut(x, s, e, slot["trim_max"])


def scan_file(args):
    index_row, path, slots = args
    x = C.decode(path)
    if len(x) < 2000 or float(np.max(np.abs(x))) < 0.01:
        return []
    noise = float(np.min(C.env_db(x)))
    name, pack = index_row["path"].rsplit("/", 1)[-1].lower().replace("_", " "), index_row["pack"].lower()
    out = []
    for slot in slots:
        kw = prior(slot, name, pack)
        loop = slot["mode"] == "loop"
        if kw is None or (loop and len(x) / C.SR < slot["trim_max"] + 0.6):
            continue
        for s, e, y in cuts(x, slot):
            f = C.features(y, noise)
            if f["clip"] > 0.002 or (f["snr"] < MIN_SNR and not loop):
                continue
            fs = fit_score(f, slot["fit"])
            out.append(
                {"slot": slot["id"], "path": index_row["path"], "pack": index_row["pack"], "start": s, "end": e}
                | {"score": 0.55 * fs + 0.45 * kw, "fit": fs, "kw": kw, "f": f}
            )
    return out


def scan(index, lib, slots, work):
    cache = os.path.join(work, "scan.json")
    if os.path.exists(cache):
        return json.load(open(cache))
    jobs = [(d, os.path.join(lib, d["path"]), slots) for d in index if d["duration"] <= 90]
    best = {s["id"]: [] for s in slots}
    with Pool(8) as pool:
        for n, rows in enumerate(pool.imap_unordered(scan_file, jobs, chunksize=4)):
            for r in rows:
                best[r["slot"]].append(r)
            if n % 200 == 0:
                print("scanned", n, "/", len(jobs), flush=True)
                for k in best:  # keep memory flat
                    best[k] = sorted(best[k], key=lambda r: -r["score"])[: KEEP * 4]
    best = {k: sorted(v, key=lambda r: -r["score"])[:KEEP] for k, v in best.items()}
    os.makedirs(work, exist_ok=True)
    json.dump(best, open(cache, "w"))
    return best


def choose(rows, n=4):
    """Top n (a slot's "picks", 4 if it has none) in score order: one per pack and file first, then relax."""
    picks = []
    for one_per_pack in (True, False):
        for r in rows:
            if len(picks) >= n:
                break
            if any(
                r["path"].rsplit("/", 1)[-1] == p["path"].rsplit("/", 1)[-1] for p in picks
            ):  # same file, other bundle
                continue
            if one_per_pack and any(r["pack"] == p["pack"] for p in picks):
                continue
            picks.append(r)
    return picks


def render(slot, r, x):
    s, e = r["start"], r["end"]
    y = C.loop_cut(x, s, slot["trim_max"]) if slot["mode"] == "loop" else C.cut(x, s, e, slot["trim_max"])
    return y


def describe(f, fit, pack):
    tone = "tonal" if f["flat"] < 0.12 else "noisy" if f["flat"] > 0.4 else "mixed"
    if fit is None:
        return "%.2f s, %s, %.1f kHz centre, %.0f dB over noise" % (f["len"], tone, f["centroid"] / 1000, f["snr"])
    return "%.2f s, %.0f ms attack, %s, %.1f kHz centre, %.0f%% below 250 Hz, %.0f dB over noise; %s" % (
        f["len"],
        f["attack_ms"],
        tone,
        f["centroid"] / 1000,
        f["low"] * 100,
        f["snr"],
        pack.split(" - ")[-1][:38],
    )


def wave_svg(y, w=200, h=30):
    n = max(1, len(y) // w + 1)
    b = [float(np.max(np.abs(y[i : i + n]))) for i in range(0, len(y), n)][:w] or [0.0]
    m = max(b) or 1.0
    bars = "".join(
        '<rect x="%d" y="%.1f" width="1" height="%.1f"/>' % (i, h / 2 - v / m * h / 2, max(1, v / m * h))
        for i, v in enumerate(b)
    )
    return '<svg width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % (w, h, w, h, bars)


CSS = (
    "body{background:#14161c;color:#dde;font:14px system-ui;margin:20px;max-width:1100px}h1{font-size:20px}section{margin:0 0 24px}"
    "h2{font-size:16px;margin:0 0 6px}h2 small{color:#889;font-weight:400}"
    ".row{display:flex;align-items:center;gap:12px;padding:6px 10px;margin:4px 0;border:3px solid #333;border-radius:6px}"
    ".row.now{border-color:#777;background:#22252d}.row.g{border-color:#3c9d4e}.row.r{border-color:#b04040}"
    ".row b{width:30px;font-size:20px}.row svg{fill:#7aa2ff}.row.now svg{fill:#999}.row .t{flex:1;font-size:12px;color:#9ab}"
    ".tag{background:#3c9d4e;color:#fff;border-radius:4px;padding:1px 6px;font-size:11px;margin-left:4px}.legend{color:#889;font-size:12px}"
)


def page(sections):
    legend = (
        '<p class="legend">Grey = the live sound. Green / red border = measured fit to the slot (length, onset, spectrum) above / '
        "not above the live sound's; nobody has listened yet. A is the default pick. PRIVATE: Sonniss GDC clips (licence v2.0), do not publish or commit.</p>"
    )
    return (
        '<!doctype html><meta charset="utf-8"><title>SFX choices</title><style>%s</style><h1>Sound choices: 12 most-heard sounds</h1>%s%s'
        % (
            CSS,
            legend,
            "".join(sections),
        )
    )


def main(game, lib, index_file, slots_file, out, *rest):
    manifest = next((a for a in rest if not a.startswith("--")), None)
    work = os.path.join(out, "work")
    if "--rescan" in rest and os.path.exists(work + "/scan.json"):
        os.remove(work + "/scan.json")
    os.makedirs(out + "/clips", exist_ok=True)
    slots = json.load(open(slots_file))["slots"]
    index = [json.loads(line) for line in open(index_file)]
    best = scan(index, lib, slots, work)
    mapping, sections, picked = [], [], []
    for slot in slots:
        now = C.decode(os.path.join(game, "audio", slot["cue"] + ".wav"))
        ev = C.events(now)
        s0, e0 = (ev[0][0], ev[-1][1]) if ev else (0, len(now))
        live = C.cut(now, s0, e0, 99)
        noise = float(np.min(C.env_db(now)))
        live_f = C.features(live, noise)
        live_fit = fit_score(live_f, slot["fit"])
        target = C.active_rms_db(now)
        C.write_audio(now, "%s/clips/%s_now.mp3" % (out, slot["id"]))
        rows = [
            (
                "now",
                "Live sound: audio/%s.wav, %s" % (slot["cue"], describe(live_f, None, "")),
                "%s_now.mp3" % slot["id"],
                now,
                "now",
            )
        ]
        cands = []
        for i, r in enumerate(choose(best[slot["id"]], slot.get("picks", 4))):
            x = C.decode(os.path.join(lib, r["path"]))
            y = C.level(render(slot, r, x), target)
            fn = "%s_%s.mp3" % (slot["id"], LETTERS[i])
            C.write_audio(y, os.path.join(out, "clips", fn))
            kind = "g" if r["fit"] > live_fit + 0.03 else "r"
            why = "%s (fit %.2f vs live %.2f, name match %.2f)" % (
                describe(r["f"], r["fit"], r["pack"]),
                r["fit"],
                live_fit,
                r["kw"],
            )
            rows.append((LETTERS[i], why, fn, y, kind))
            cands.append(
                {
                    "letter": LETTERS[i],
                    "library_path": r["path"],
                    "pack": r["pack"],
                    "start": r["start"],
                    "end": r["end"],
                    "fit": round(r["fit"], 3),
                    "clip": "clips/" + fn,
                    "seconds": round(len(y) / C.SR, 3),
                }
            )
        mapping.append(
            {
                "slot": slot["id"],
                "label": slot["label"],
                "cue": slot["cue"],
                "mode": slot["mode"],
                "live_fit": round(live_fit, 3),
                "rms_db": round(target, 1),
                "candidates": cands,
            }
        )
        picked.append(
            {
                "slot": slot["id"],
                "label": slot["label"],
                "cue": slot["cue"],
                "mode": slot["mode"],
                "trim_max": slot["trim_max"],
                "rms_db": round(target, 1),
                "tester": slot.get("tester", False),
                "pick": "A" if cands else "",
                "candidates": [
                    {"letter": c["letter"], "src": c["library_path"], "start": c["start"], "end": c["end"]}
                    for c in cands
                ],
            }
        )
        body = "".join(
            '<div class="row %s"><b>%s</b>%s<audio controls preload="none" src="clips/%s"></audio><span class="t">%s</span>%s</div>'
            % (kind, L, wave_svg(y), fn, html.escape(why), '<span class="tag">default pick</span>' if L == "A" else "")
            for L, why, fn, y, kind in rows
        )
        sections.append(
            "<section><h2>%s <small>cue <code>%s</code> &middot; %s</small></h2>%s</section>"
            % (html.escape(slot["label"]), slot["cue"], html.escape(slot["why"]), body)
        )
        print(slot["id"], "live fit %.2f" % live_fit, [(c["letter"], c["fit"]) for c in cands], flush=True)
    open(out + "/choices.html", "w", encoding="utf-8").write(page(sections))
    json.dump(mapping, open(out + "/mapping.json", "w"), indent=1)
    if manifest:
        keep = {}  # the letters already chosen survive a rerun
        if os.path.exists(manifest):
            keep = {x["slot"]: x["pick"] for x in json.load(open(manifest))["slots"]}
        for x in picked:
            x["pick"] = keep.get(x["slot"], x["pick"])
        json.dump(
            {
                "_doc": "Library sounds as pointers (file, start, end), never audio. pick = the letter the built game "
                "plays (sfx_pack.py build); tester = all candidates also go to the in-game Sound tester "
                "(sfx_pack.py tester). Written by sfx_sheet.py.",
                "slots": picked,
            },
            open(manifest, "w"),
            indent=1,
        )


if __name__ == "__main__":
    main(*[a for a in sys.argv[1:]])
