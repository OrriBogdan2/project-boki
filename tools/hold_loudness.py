"""Held-fire loudness, before (full takes) and after (short hold takes), per weapon (docs/AUDIO.md, Held fire).
Run from the repo root: python3 tools/hold_loudness.py [--check]

An offline mix of 3 s of fire at each weapon's real rate (content/weapons/*.json primary.rate) the way
scripts/core/fire_sfx.gd plays it: the first round is take 0 at full level, the rest are either the other full
takes STACK_DB under (before) or the `<shot>_hold` takes HOLD_DB under (after), each round also taking
Sfx.play's own stacking cut (3.5 dB per round of the same sound still inside 90 ms) and FireSfx's 3-voice cap.
Pitch jitter is not modelled. Prints the file peak per weapon and the sustained peak / RMS (0.5 s on).
--check fails when a hold file peaks over -3 dBFS."""

import json, os, sys, wave
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SR = 44100
STACK_DB, HOLD_DB, STACK_MS, VOICES, PAD = 3.5, 1.0, 0.09, 3, 0.06


def load(name):
    out = []
    for suffix in [""] + ["_%d" % i for i in range(1, 5)]:
        p = os.path.join(ROOT, "audio", name + suffix + ".wav")
        if os.path.exists(p):
            with wave.open(p) as w:
                out.append(np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0)
    return out


def db(v):
    return 20 * np.log10(max(v, 1e-9))


def burst(sname, rate, hold):
    shot = load(sname)
    hs = load(sname + "_hold") if hold else []
    secs = 3.0
    out = np.zeros(int((secs + 1.0) * SR))
    recent = {}  # sound -> start times in the last 90 ms
    live = []  # end times of takes sounding
    rr, t, first = 1, 0.0, True
    fired = played = 0
    while t < secs:
        live = [e for e in live if e > t]
        if first:
            snd, off = shot[0], 0.0
        elif hs:
            snd, off = hs[rr % len(hs)], HOLD_DB
        else:
            snd, off = shot[rr], STACK_DB
        key = "hold" if (hs and not first) else "shot"
        fired += 1
        rec = [x for x in recent.get(key, []) if t - x <= STACK_MS]
        if (not first and len(live) >= VOICES) or len(rec) >= 3:
            t += rate
            continue
        played += 1
        gain = 10 ** (-(off + STACK_DB * len(rec)) / 20)
        rec.append(t)
        recent[key] = rec
        live.append(t + len(snd) / SR * 1.03 + PAD)
        i = int(t * SR)
        out[i : i + len(snd)] += snd * gain
        if not first:
            rr = (rr + 1) % len(hs) if hs else 1 + rr % (len(shot) - 1)
        first = False
        t += rate
    sus = out[int(0.5 * SR) : int(secs * SR)]
    return np.max(np.abs(out)), np.max(np.abs(sus)), np.sqrt(np.mean(sus**2)), played, fired


def main():
    held = {}
    for f in sorted(os.listdir(os.path.join(ROOT, "content", "weapons"))):
        w = json.load(open(os.path.join(ROOT, "content", "weapons", f)))
        r, s = float(w["primary"]["rate"]), w["primary"]["sfx"]
        if (r < 0.15 or w["id"] == "hoar_fan") and os.path.exists(os.path.join(ROOT, "audio", s + "_hold.wav")):
            held[w["id"]] = (s, min(r, 0.08) if w["id"] == "hoar_fan" else r)
    bad = 0
    print(
        "%-12s %-12s %5s | %-30s | %-30s"
        % ("weapon", "sound", "rate", "before: whole/sust pk, rms, shots", "after: whole/sust pk, rms, shots")
    )
    for wid, (s, r) in held.items():
        b, a = burst(s, r, False), burst(s, r, True)
        hp = max(db(np.max(np.abs(x))) for x in load(s + "_hold"))
        bad += hp > -3.0
        print(
            "%-12s %-12s %5.2f | %5.1f %5.1f %6.1f %2d/%2d | %5.1f %5.1f %6.1f %2d/%2d  hold file peak %.1f"
            % (wid, s, r, db(b[0]), db(b[1]), db(b[2]), b[3], b[4], db(a[0]), db(a[1]), db(a[2]), a[3], a[4], hp)
        )
    if "--check" in sys.argv and (bad or not held):
        print("FAIL: a hold file peaks over -3 dBFS or none found")
        sys.exit(1)


main()
