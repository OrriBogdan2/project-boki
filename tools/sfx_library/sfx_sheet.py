#!/usr/bin/env python3
"""Build choice sheets from the library index: 4 trimmed, levelled candidates per game cue.
  sfx_sheet.py GAME_DIR LIB_DIR INDEX.jsonl SLOTS.json OUT_DIR
Needs numpy and ffmpeg. Writes OUT_DIR/clips/*.ogg, OUT_DIR/sheet.html and OUT_DIR/mapping.json.
Ranking is by path keywords and clip shape (see slots.json), never by sending audio to an AI service
(Sonniss licence v2.0). Letters A-D are rank order; the 'now' row is the game's current sound."""

import html, json, math, os, re, subprocess, sys
import numpy as np

SR = 44100


def decode(path):
    r = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True
    )
    return np.frombuffer(r.stdout, dtype=np.float32).copy()


def shape_clip(x, trim_max, target_rms_db, peak_db):
    """Cut the lead-in, end where the tail is 40 dB down (or at trim_max, with a longer fade), level to the category."""
    pk = float(np.max(np.abs(x))) if len(x) else 0.0
    if pk < 0.01:
        return None
    on = int(np.argmax(np.abs(x) > pk * 0.05))
    x = x[max(0, on - int(0.004 * SR)) :]
    win = int(0.02 * SR)
    env = np.sqrt(np.convolve(x * x, np.ones(win) / win, mode="same"))
    loud = np.nonzero(env > env.max() * 0.01)[0]
    end = int(loud[-1]) if len(loud) else len(x)
    cut = int(trim_max * SR)
    fade = int((0.015 if end <= cut else 0.06) * SR)
    x = x[: min(end + fade, cut)]
    fade = min(fade, len(x) // 2)
    x = x.copy()
    x[-fade:] *= np.linspace(1, 0, fade)
    aud = np.abs(x) > 0.02 * np.max(np.abs(x))
    rms_db = 20 * math.log10(max(1e-9, float(np.sqrt(np.mean(x[aud] ** 2)))))
    gain = min(10 ** ((target_rms_db - rms_db) / 20), 10 ** (peak_db / 20) / float(np.max(np.abs(x))))
    return x * gain, rms_db


def write_ogg(x, path):
    p = subprocess.Popen(
        [
            "ffmpeg",
            "-v",
            "error",
            "-y",
            "-f",
            "f32le",
            "-ar",
            str(SR),
            "-ac",
            "1",
            "-i",
            "-",
            "-c:a",
            "libvorbis",
            "-q:a",
            "4",
            path,
        ],
        stdin=subprocess.PIPE,
    )
    p.communicate(x.astype(np.float32).tobytes())


def wave_svg(x, w=220, h=34):
    n = max(1, len(x) // w + 1)
    b = [float(np.max(np.abs(x[i : i + n]))) for i in range(0, len(x), n)] or [0.0]
    m = max(b) or 1.0
    bars = "".join(
        '<rect x="%d" y="%.1f" width="1" height="%.1f"/>' % (i, h / 2 - v / m * h / 2, max(1.0, v / m * h))
        for i, v in enumerate(b[:w])
    )
    return '<svg width="%d" height="%d" viewBox="0 0 %d %d" fill="#7aa2ff">%s</svg>' % (w, h, w, h, bars)


def score(d, slot):
    low = (d["pack"] + "/" + d["path"].rsplit("/", 1)[-1]).lower()
    if re.search(slot["neg"], low) or d["duration"] > slot["src_max"] or d["duration"] < 0.03:
        return 0
    return sum(wt for rx, wt in slot["pos"] if re.search(rx, low))


def main(game, lib, index, slots_file, out):
    levels = json.load(open(os.path.join(game, "content/rules/sfx_levels.json")))
    idx = [json.loads(l) for l in open(index)]
    os.makedirs(out + "/clips", exist_ok=True)
    mapping, sections = [], []
    for slot in json.load(open(slots_file))["slots"]:
        tgt, peak = levels["cats"][slot["level"]], levels["peak_db"]
        ranked = sorted(((score(d, slot), d) for d in idx), key=lambda t: (-t[0], t[1]["duration"]))
        picks, packs = [], set()
        for min_score, one_per_pack in ((3, True), (3, False), (2, False)):  # relax until 4 candidates
            for sc, d in ranked:
                if sc < min_score or len(picks) >= 4:
                    break
                if (one_per_pack and d["pack"] in packs) or any(d is q[1] for q in picks):
                    continue
                res = shape_clip(decode(os.path.join(lib, d["path"])), slot["trim_max"], tgt, peak)
                if res is None:
                    continue
                picks.append((sc, d, res))
                packs.add(d["pack"])
        rows = []
        now_wav = os.path.join(game, "audio", slot["cue"] + ".wav")
        now = decode(now_wav)
        write_ogg(now, "%s/clips/%s_now.ogg" % (out, slot["id"]))
        rows.append(
            ("now", "now: audio/%s.wav (%.2f s)" % (slot["cue"], len(now) / SR), "%s_now.ogg" % slot["id"], now, "now")
        )
        cands = []
        for i, (sc, d, (x, rms)) in enumerate(picks):
            L = "ABCD"[i]
            fn = "%s_%s.ogg" % (slot["id"], L)
            write_ogg(x, os.path.join(out, "clips", fn))
            label = "%s / %s  [%s, %.2f s]" % (d["pack"], d["path"].rsplit("/", 1)[-1], d["bundle"], len(x) / SR)
            rows.append((L, label, fn, x, "cand"))
            cands.append(
                {
                    "letter": L,
                    "score": sc,
                    "library_path": d["path"],
                    "bundle": d["bundle"],
                    "pack": d["pack"],
                    "clip": "clips/" + fn,
                    "seconds": round(len(x) / SR, 3),
                    "source_rms_db": round(rms, 1),
                }
            )
        mapping.append(
            {
                "slot": slot["id"],
                "label": slot["label"],
                "cue": slot["cue"],
                "level": slot["level"],
                "now_file": "audio/%s.wav" % slot["cue"],
                "candidates": cands,
            }
        )
        body = "".join(
            '<div class="row %s"><b>%s</b>%s<audio controls preload="none" src="clips/%s"></audio><span>%s</span></div>'
            % (kind, L, wave_svg(x), fn, html.escape(label))
            for L, label, fn, x, kind in rows
        )
        sections.append(
            "<section><h2>%s <small>cue <code>%s</code> &middot; level %s %.0f dB</small></h2>%s</section>"
            % (html.escape(slot["label"]), slot["cue"], slot["level"], tgt, body)
        )
        print(slot["id"], [c["pack"][:28] + ":" + str(c["seconds"]) for c in cands], flush=True)
    css = (
        "body{background:#14161c;color:#dde;font:14px system-ui;margin:20px}section{margin:0 0 26px}h2{font-size:17px}h2 small{color:#889;font-weight:400}"
        ".row{display:flex;align-items:center;gap:12px;padding:6px 10px;margin:4px 0;border:2px solid #2a2e3a;border-radius:6px}"
        ".row.now{border-color:#777;background:#22252d}.row.now svg{fill:#999}.row b{width:34px;font-size:20px}.row span{color:#9ab;font-size:12px}"
        ".warn{background:#2a2118;border:1px solid #6a4;padding:8px 12px;border-radius:6px;margin-bottom:18px}"
    )
    page = (
        '<!doctype html><meta charset="utf-8"><title>SFX library choice sheets</title><style>%s</style><h1>SFX library choice sheets</h1>'
        '<div class="warn">PRIVATE: clips come from the Sonniss GDC Game Audio Bundles (licence v2.0). Do not publish or commit this page or its clips. '
        "A = best guess by name and shape; listen and pick. Grey = what the game plays now.</div>%s"
        % (css, "".join(sections))
    )
    open(out + "/sheet.html", "w", encoding="utf-8").write(page)
    json.dump(mapping, open(out + "/mapping.json", "w"), indent=1)


if __name__ == "__main__":
    main(*sys.argv[1:6])
