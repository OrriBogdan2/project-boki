"""Tenzo (dolm) and Grimble (dredge): the cues their kits were missing, so every ability has a cast, a travel,
a hit and an end (the "bar" block in content/sfx/dolm.json and dredge.json, docs/AUDIO.md).

    python3 tools/gen_sfx_ability_bar.py      (then: godot --headless --import)

Each ability's hit on a target is its own (HeroSfx.hit_sound picks <arch>_hit_<slot>):
  Tenzo, stone that crunches:  dolm_hit_rock (a punched or raised rock shattering on a body), dolm_hit_rmb (the slam:
  a deep ground thump and a gravel crunch), dolm_hit_dash (the hop's stomp: a flat stamp and a skid), dolm_hit_r (the
  Basalt Spine: a glassy basalt crack with a stony ring). His left click keeps dolm_hit (gen_sfx_hero_hits.py).
  Grimble, scrap that clangs:  dredge_hit_rmb (the gaff hook biting: a high iron tchk and a chain snap),
  dredge_hit_e (the anchor fist: a big iron clang and scrap bouncing), dredge_hit_r (a brass slug: a bright
  ricochet ping). His blunderbuss keeps dredge_hit.
Travel and end: br_boulder_fly (the thrown boulder tumbling through the air, a loop held while it flies),
dr_reach_fly (the Deep Reach paying out chain, a loop held while the hand flies), dr_let_go (the hand letting go,
after a miss or at the end of the reel: a wet slap, slack chain and sludge), dr_blast_end (the Broadside done: spent brass casings tinkling down,
the barrels hissing).

Original synthesis, no samples (CC0, docs/CREDITS.md). Its own random stream, so it never changes the files the
other generators write.
"""

import os, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, ring, grains, pad
import gen_sfx_tarek as TZ
import gen_sfx_grimble as GR

S.reseed(11205)
P = [1.0, 1.05, 0.95, 1.09]  # each take's pitch


def g(x, k):
    return np.asarray(x) * k


# ------------------------------------------------------------------ Tenzo: rock crunch
def hit_rock(i):
    """A rock (punched along the lane or one of his raised ones) shattering on a body: a split and a burst of rubble."""
    p = P[i]
    return mix(
        g(click(0.004, 1500, 6000), 1.0),
        g(TZ.thud(190 * p, 0.8, 0.3), 1.0),
        g(crack(0.09, 600, 3800, 0.014), 1.5),
        g(TZ.crunch(0.3, 900, 350, 3400, fall=0.05, big=4), 1.0),
        at(g(TZ.gravel(0.22, 160, 0.06), 0.4), 0.03),
    )


def hit_rmb(i):
    """The slam landing on a body: a deep ground thump with the earth giving under it, a low gravel crunch."""
    p = P[i]
    return mix(
        g(click(0.005, 700, 3000), 0.8),
        g(kick(120 * p, 38, 0.38, 0.03, 0.09, 3.0), 1.0),
        g(sub(64 * p, 34, 0.38, 0.12), 0.5),
        g(TZ.crunch(0.28, 380, 180, 1600, fall=0.07, big=3), 0.9),
        g(TZ.rumble(0.35, 260, 0.004, 0.1), 0.5),
    )


def hit_dash(i):
    """The hop's stomp landing on a body: a flat stamp of a stone foot, its sole skidding through grit."""
    p = P[i]
    skid = bpf(noise(0.16), 350, 1700) * env(N(0.16), 0.006, 0.05)
    return mix(
        g(click(0.004, 900, 3500), 0.8),
        g(kick(230 * p, 85, 0.2, 0.012, 0.04, 2.4), 1.0),
        at(g(skid, 1.1), 0.01),
        at(g(TZ.gravel(0.14, 120, 0.04), 0.35), 0.02),
    )


def hit_r(i):
    """A Basalt Spine rock bursting up under a body: a glassy basalt crack, a stony ring, cold grit."""
    p = P[i]
    return mix(
        g(click(0.003, 2500, 8000), 1.0),
        g(crack(0.12, 2200, 7500, 0.02), 1.6),
        g(TZ.stone_tok(880 * p, 0.32, 1.2), 1.0),
        g(TZ.thud(140 * p, 0.5, 0.25), 1.0),
        at(g(grains(0.25, 300, 2500, 7000, 0.001, 0.004, fall=0.06), 0.6), 0.015),
    )


def boulder_fly():
    """The boulder in the air: a low tumbling whoosh with a knock each turn, grit trailing (a seamless loop)."""
    d = 0.6
    t = T(d)
    air = bpf(noise(d), 160, 900)
    turn = 0.55 + 0.45 * np.abs(np.sin(np.pi * 5 * t))  # five turns a second: 3 in the loop, so it repeats
    grit = lpf(grains(d, 90, 900, 3500, 0.001, 0.004), 4500)
    return mix(air * turn * 1.0, grit * 0.35, lpf(noise(d), 120) * 0.5)


# ------------------------------------------------------------------ Grimble: scrap clang
def hit_hook(i):
    """The gaff hook biting a body: a high iron tchk and the chain snapping taut."""
    p = P[i]
    return mix(
        g(click(0.003, 2500, 8000), 1.0),
        g(GR.clank(620 * p, 0.06, 3.0), 0.8),
        g(kick(300 * p, 140, 0.12, 0.008, 0.02, 1.6), 0.6),
        at(g(GR.chain(0.12, 160, 0.03), 0.6), 0.01),
    )


def hit_anchor(i):
    """The anchor fist on a body: a big iron clang, a thud, scrap bouncing off."""
    p = P[i]
    return mix(
        g(click(0.005, 1500, 5500), 1.0),
        g(kick(130 * p, 45, 0.4, 0.03, 0.08, 2.8), 0.9),
        g(GR.clank(210 * p, 0.18, 3.8), 0.8),
        at(g(GR.clatter(0.3, 5, 0.08), 0.45), 0.04),
    )


def hit_slug(i):
    """A brass slug of the Broadside: a bright ricochet ping and a small dull pock (many land at once)."""
    p = P[i]
    return mix(
        g(click(0.003, 3000, 9000), 0.9),
        g(ring([2400 * p, 3710 * p], 0.16, [0.05, 0.03], [0.45, 0.25]), 1.0),
        g(kick(340 * p, 170, 0.08, 0.006, 0.018, 1.6), 0.6),
    )


def reach_fly():
    """The Deep Reach in flight: chain paying out link by link under a wet rush (a seamless loop)."""
    d = 0.6
    links = GR.chain(d, 70)
    rush = bpf(noise(d), 300, 1400) * GR.slow(d, 8, 0.3)
    return mix(links * 0.8, rush * 0.6, lpf(noise(d), 180) * 0.3)


def let_go():
    """The hand letting go (a miss, or the reel done): a wet slap, slack chain clattering, a sludge splash."""
    d = 0.55
    slap = mix(
        click(0.004, 600, 3000) * 0.8,
        kick(180, 70, 0.2, 0.01, 0.03, 1.6) * 0.6,
        bpf(noise(0.18), 250, 1600) * env(N(0.18), 0.002, 0.04) * 0.9,
    )
    slack = at(GR.chain(0.35, 55, 0.12) * 0.7, 0.03)
    splash = at(lpf(grains(0.3, 120, 300, 1500, 0.004, 0.012, fall=0.08), 2000) * 0.6, 0.02)
    return TZ.fade_out(mix(slap, slack, splash, pad(np.zeros(1), d)), 0.06)


def blast_end():
    """The Broadside done: spent brass casings tinkling down round his feet, the barrels hissing as they cool."""
    d = 0.9
    casings = mix(*[at(GR.coin(), 0.05 + 0.09 * k + S.rng.uniform(0, 0.04)) * (0.8 - 0.08 * k) for k in range(7)])
    hiss = hpf(noise(0.7), 3000) * env(N(0.7), 0.04, 0.25) * 0.25
    return TZ.fade_out(mix(casings, at(hiss, 0.02), pad(np.zeros(1), d)), 0.08)


def loop(name, x):
    """save_loop, its start turned so the seam lands where the sound is loud enough (--sfx-set-check: a loop's
    last sample is over 2% of its middle's peak, the jump at the seam under 5% of full scale)."""
    for k in range(0, len(x), 97):
        S.save_loop(name, np.roll(x, -k), "loop")
        w = wave.open(os.path.join(S.C.OUT, name + ".wav"))
        y = np.frombuffer(w.readframes(w.getnframes()), np.int16) / 32768.0
        mid = np.abs(y[len(y) // 2 : len(y) // 2 + 200]).max()
        if abs(y[-1]) >= mid * 0.05 and abs(y[-1] - y[0]) < 0.02:
            return
    raise SystemExit(name + ": no seam found")


def build():
    TZ.takes("dolm_hit_rock", hit_rock, 3, "impact")
    TZ.takes("dolm_hit_rmb", hit_rmb, 3, "impact")
    TZ.takes("dolm_hit_dash", hit_dash, 3, "impact")
    TZ.takes("dolm_hit_r", hit_r, 3, "impact")
    loop("br_boulder_fly", boulder_fly())
    S.takes_cat("dredge_hit_rmb", hit_hook, 3, "heavy_impact")
    S.takes_cat("dredge_hit_e", hit_anchor, 3, "heavy_impact")
    S.takes_cat("dredge_hit_r", hit_slug, 3, "heavy_impact")
    loop("dr_reach_fly", reach_fly())
    S.save_cat("dr_let_go", let_go(), "cast")
    S.save_cat("dr_blast_end", blast_end(), "cast")


if __name__ == "__main__":
    build()
    print("gen_sfx_ability_bar: done")
