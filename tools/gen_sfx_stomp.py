"""The stomp's three cues (Life.start_stomp / tick_stomps / end_stomp, DECISIONS 2026-11-11), set content/sfx/stomp.json.

    python3 tools/gen_sfx_stomp.py      (then: godot --headless --import)

Our own sounds, numpy only, own random stream. All three play at a position, so both squads in reach hear them.
  stomp_windup : ~0.7 s, the stomp commits: a low rising groan and a heel scuff, "locked in, it is coming".
  stomp_finish : ~0.8 s, the last slam as the wisp dies: a deep crushing thud, a crunch and the wisp's light
                 squeezed out under the foot (a falling tone choked off).
  stomp_crack  : ~0.5 s, hard CC breaks the stomp: a bright crack and a short rising ring as the wisp is let go.
"""

import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise

S.reseed(6162)


def windup():
    d = 0.7
    n = N(d)
    swell = np.linspace(0.2, 1.0, n) ** 1.5 * S.shape(d, 0.03, d - 0.1, 0.07)  # louder to the end, a soft cut
    rise = S.sweep(70, 210, d, curve=1.6) * swell * 0.7
    grind = bpf(noise(d), 180, 900) * swell**1.5 * 0.35
    scuff = bpf(noise(0.12), 300, 2400) * env(N(0.12), 0.01, 0.05) * 0.4
    lift = at(S.sweep(400, 900, 0.25) * S.shape(0.25, 0.15, 0.04, 0.06), 0.42) * 0.25
    return lpf(mix(rise, grind, scuff, lift), 6000)


def finish():
    slam = S.kick(110, 34, 0.7, drop=0.035, decay=0.2, drive=3.2)
    body = S.sub(70, 38, 0.6, 0.22) * 0.6
    crunch = at(S.grains(0.22, 420, 300, 4200, fall=0.1), 0.008) * 0.7
    squeeze = at(S.sweep(640, 110, 0.3) * env(N(0.3), 0.005, 0.07), 0.03) * 0.35
    return mix(slam, body, crunch, squeeze, S.tail(0.6, 450, 0.18) * 0.35)


def crack():
    snap = S.crack(0.05, 2500, 11000, 0.008) * 1.4
    glass = at(S.chime(1650, 0.5, 0.12), 0.01) * 0.5
    lift = at(S.sweep(900, 1900, 0.3) * env(N(0.3), 0.02, 0.1), 0.05) * 0.3
    return hpf(mix(snap, glass, lift), 200)


if __name__ == "__main__":
    S.save_cat("stomp_windup", windup(), "cast")
    S.save_cat("stomp_finish", finish(), "heavy_impact")
    S.save_cat("stomp_crack", crack(), "impact")
