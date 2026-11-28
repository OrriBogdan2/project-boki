"""Tenzo (dolm), Grimble (dredge), Sable (thief) and Sparkle (mage): the cues their kits were missing, so every
ability has a cast, a travel, a hit and an end (the "bar" block in content/sfx/<arch>.json, docs/AUDIO.md).

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

Second pass (VFX_QUALITY Snd 3 of 5 for the four): a distinct hit for each of Sable's and Sparkle's abilities
(thief_hit_rmb the bola cord pulling tight, thief_hit_e the knife's stab, thief_hit_r an Encore blade's slice;
mage_hit_rmb the rod's zap, mage_hit_e Skycall's thunder tick, mage_hit_dash the Wirerun's whip crackle, mage_hit_r the
Kitefall's crash); a travel loop for each projectile that flies over 0.3 s (thief_knife_fly, mage_bolt_fly,
dr_slug_fly, br_rock_fly); and a tail layer under the thinnest casts (thief_bolt_tail, mage_bolt_tail, dr_shot_tail,
br_throw_tail: they start after a short lead, so the cast reads body then tail).

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


# ------------------------------------------------------------------ Sable: cord, blade
def hit_bola(i):
    """The bola's cord pulling tight on a body: a whip zip, a dull wooden knock of the weights."""
    p = P[i]
    zip_ = bpf(noise(0.1), 1200 * p, 6500) * env(N(0.1), 0.004, 0.03)
    return mix(
        g(click(0.003, 2000, 7000), 0.8),
        g(zip_, 1.0),
        g(kick(210 * p, 90, 0.14, 0.012, 0.035, 1.8), 0.9),
        at(g(ring([690 * p, 1180 * p], 0.12, [0.03, 0.02], [0.4, 0.25]), 0.7), 0.01),
    )


def hit_knife(i):
    """The shadow knife sinking in: a short stab thunk and a tiny metallic ting."""
    p = P[i]
    return mix(
        g(click(0.003, 1800, 6500), 1.0),
        g(kick(280 * p, 110, 0.12, 0.01, 0.03, 2.0), 1.0),
        at(g(ring([3100 * p, 4700 * p], 0.2, [0.07, 0.04], [0.5, 0.3]), 0.7), 0.004),
    )


def hit_encore(i):
    """An Encore blade slicing a body: a rising shing of air and a bright edge."""
    p = P[i]
    n = N(0.16)
    swish = bpf(noise(0.16), 2500 * p, 9000) * (np.linspace(0.2, 1.0, n) ** 2) * env(n, 0.01, 0.06)
    return mix(
        g(click(0.002, 3500, 10000), 0.7),
        g(swish, 1.1),
        at(g(ring([4200 * p, 6300 * p], 0.14, [0.05, 0.03], [0.5, 0.25]), 0.6), 0.03),
    )


def knife_fly():
    """The knife in the air: a thin spinning whirr, twenty turns a second (a seamless loop)."""
    d = 0.5
    t = T(d)
    spin = 0.5 + 0.5 * np.sin(2 * np.pi * 20 * t)
    air = bpf(noise(d), 900, 4200) * spin
    return mix(air * 0.9, np.sin(2 * np.pi * 1500 * t) * spin * 0.18, hpf(noise(d), 6000) * 0.08)


def bolt_tail_thief():
    """The arc bolt's tail under its zip: a little electric shimmer fading away after it has left the hand."""
    d = 0.45
    shim = ring([2400, 3600, 5100], d, [0.12, 0.09, 0.07], [0.5, 0.35, 0.25])
    sparks = grains(0.3, 90, 3000, 8500, 0.001, 0.004, fall=0.1)
    return TZ.fade_out(mix(at(shim * 0.5, 0.05), at(sparks * 0.35, 0.05), pad(np.zeros(1), d)), 0.06)


# ------------------------------------------------------------------ Sparkle: lightning
def hit_rod(i):
    """The Storm Rod's charge landing on a body: a body-shaking zap, a buzz."""
    p = P[i]
    t = T(0.18)
    buzz = np.sin(2 * np.pi * 120 * p * t) * np.sign(np.sin(2 * np.pi * 7 * t)) * env(N(0.18), 0.003, 0.06)
    return mix(
        g(click(0.003, 2500, 9000), 0.9),
        g(kick(170 * p, 60, 0.2, 0.02, 0.05, 2.4), 0.9),
        g(crack(0.12, 1500, 6000, 0.02), 1.2),
        g(lpf(buzz, 1500), 0.6),
    )


def hit_sky(i):
    """Skycall's strike on a body: a bright tick, a crack, a low thunder under it."""
    p = P[i]
    return mix(
        g(click(0.003, 3000, 10000), 1.0),
        g(crack(0.2, 400, 3000, 0.04), 1.3),
        g(sub(75 * p, 40, 0.3, 0.1), 0.8),
        at(g(TZ.rumble(0.3, 220, 0.004, 0.08), 0.5), 0.02),
    )


def hit_wire(i):
    """The Wirerun's lane catching a body: a whip crackle, a fast zap that falls away."""
    p = P[i]
    return mix(
        g(click(0.002, 4000, 11000), 0.9),
        g(crack(0.1, 3000, 9000, 0.015), 1.3),
        g(kick(2200 * p, 320, 0.1, 0.02, 0.03, 1.6), 0.7),
        at(g(grains(0.14, 160, 3500, 9000, 0.001, 0.003, fall=0.04), 0.5), 0.005),
    )


def hit_kite(i):
    """The Kitefall crashing on a body: a hard thud, a hail of sparks, a ring."""
    p = P[i]
    return mix(
        g(click(0.004, 1500, 6000), 1.0),
        g(kick(110 * p, 36, 0.4, 0.035, 0.1, 3.0), 1.0),
        g(crack(0.18, 800, 5000, 0.035), 1.2),
        at(g(grains(0.3, 140, 2500, 8000, 0.001, 0.004, fall=0.08), 0.6), 0.01),
        at(g(ring([1250 * p, 1900 * p], 0.25, [0.08, 0.05], [0.4, 0.25]), 0.5), 0.02),
    )


def bolt_fly():
    """The finger bolt in the air: a crackling hum with sparks (a seamless loop)."""
    d = 0.5
    t = T(d)
    hum = np.sin(2 * np.pi * 900 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 60 * t))
    return mix(hum * 0.4, grains(d, 600, 2500, 7500, 0.001, 0.003) * 0.7, bpf(noise(d), 1500, 5000) * 0.15)


def bolt_tail_mage():
    """The finger bolt's tail under its snap: sparks pattering down and a fizz fading away."""
    d = 0.4
    fizz = hpf(noise(0.3), 4000) * env(N(0.3), 0.02, 0.1)
    sparks = grains(0.3, 110, 3000, 9000, 0.001, 0.003, fall=0.09)
    return TZ.fade_out(mix(at(sparks * 0.5, 0.05), at(fizz * 0.25, 0.05), pad(np.zeros(1), d)), 0.06)


# ------------------------------------------------------------------ Grimble and Tenzo: flight and tails
def slug_fly():
    """A scrap slug in the air: a heavy whistle, fluttering (a seamless loop)."""
    d = 0.5
    t = T(d)
    flutter = 0.6 + 0.4 * np.sin(2 * np.pi * 24 * t)
    return mix(bpf(noise(d), 1400, 4800) * flutter * 0.7, lpf(noise(d), 300) * 0.4, np.sin(2 * np.pi * 620 * t) * 0.12)


def shot_tail():
    """The blunderbuss's tail under its boom: loose scrap rattling away downrange, a low rumble dying."""
    d = 0.62
    rattle = lpf(grains(0.45, 45, 700, 3200, 0.002, 0.006, fall=0.14), 4000)
    rumble = lpf(noise(0.4), 220) * env(N(0.4), 0.03, 0.15)
    return TZ.fade_out(mix(at(rattle * 0.7, 0.08), at(rumble * 0.5, 0.07), pad(np.zeros(1), d)), 0.08)


def rock_fly():
    """A punched rock in the air: a low tumbling rush with grit, eight turns a second (a seamless loop)."""
    d = 0.5
    t = T(d)
    turn = 0.5 + 0.5 * np.abs(np.sin(np.pi * 8 * t))
    grit = lpf(grains(d, 110, 800, 3000, 0.001, 0.004), 4000)
    return mix(bpf(noise(d), 120, 700) * turn, grit * 0.4, lpf(noise(d), 100) * 0.4)


def throw_tail():
    """The boulder's tail under its heave: stone grinding in the hand, grit falling."""
    d = 0.55
    grind = lpf(bpf(noise(0.4), 150, 900), 1200) * env(N(0.4), 0.03, 0.14)
    grit = lpf(grains(0.35, 50, 500, 2400, 0.002, 0.006, fall=0.1), 3000)
    return TZ.fade_out(mix(at(grind * 0.7, 0.05), at(grit * 0.5, 0.07), pad(np.zeros(1), d)), 0.08)


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
    S.takes_cat("thief_hit_rmb", hit_bola, 3, "impact")
    S.takes_cat("thief_hit_e", hit_knife, 3, "impact")
    S.takes_cat("thief_hit_r", hit_encore, 3, "impact")
    loop("thief_knife_fly", knife_fly())
    S.save_cat("thief_bolt_tail", bolt_tail_thief(), "cast")
    S.takes_cat("mage_hit_rmb", hit_rod, 3, "impact")
    S.takes_cat("mage_hit_e", hit_sky, 3, "impact")
    S.takes_cat("mage_hit_dash", hit_wire, 3, "impact")
    S.takes_cat("mage_hit_r", hit_kite, 3, "impact")
    loop("mage_bolt_fly", bolt_fly())
    S.save_cat("mage_bolt_tail", bolt_tail_mage(), "cast")
    loop("dr_slug_fly", slug_fly())
    S.save_cat("dr_shot_tail", shot_tail(), "cast")
    loop("br_rock_fly", rock_fly())
    S.save_cat("br_throw_tail", throw_tail(), "cast")


if __name__ == "__main__":
    build()
    print("gen_sfx_ability_bar: done")
