"""The grounded pass, wave 2 (docs/AUDIO.d/1126-grounded-sfx.md): the next 28 combat and movement sounds.

    cd tools && python3 gen_sfx_grounded2.py [--out DIR]       (then: godot --headless --import)

Run it AFTER gen_sfx_grounded.py and the group generators of these names (it rewrites them). --out writes
somewhere else (the old-vs-new listening pack) instead of audio/.

Same recipe as wave 1: transient + body + a dark room tail, weight in the lower mids, the top rolled off (no band
over ~5 kHz), foley instead of tones (no bells, rings, chimes or upward sweeps), 3-4 takes that each draw their own
layer gains and timings.

  fire / casts   vn_cock vn_throw vn_nuke_fire mage_zap mage_miss mage_bolt_tail gil_thrust jug_chain flyby_bullet
  hits           hit_in mage_hit hit_magic hit_thrown gil_thrust_hit jug_lunge_hit
  movement       land ledgegrab_light/medium/heavy  archer/mage/gunslinger_foley (+_dash)
  pickups        pickup inv_grab
"""

import argparse, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise, click, crack, sub, tail, grains
from gen_sfx_grounded import g, room, air, HIT_DB

S.reseed(11262)  # after the import: wave 1 seeds its own stream

KICK = 0.4  # a kick's sub weight sits under the mids: on a phone or laptop speaker a 60 Hz thump is silence


def kick(*a, **k):
    """sfx_lib.kick scaled down, so the sound's weight is in the 100-800 Hz body and not in the sub."""
    return S.kick(*a, **k) * KICK


# ------------------------------------------------------------------ fire and casts
def cock(i):
    """The drum running dry: two dull knocks of a bolt, a grit slide between them, a woody clack at the end."""
    k1 = kick(230 + 12 * i, 120, 0.1, 0.006, 0.02, 1.2) * 0.7 * g()
    slide = at(bpf(noise(0.14), 450, 2400) * env(N(0.14), 0.04, 0.05) * 0.9 * g(), 0.05)
    k2 = at(kick(190 + 10 * i, 95, 0.12, 0.006, 0.03, 1.3) * 0.9 * g(), 0.22 + 0.01 * i)
    tick = at(click(0.0015, 1200, 4200) * 1.0 * g(), 0.225 + 0.01 * i)
    return lpf(mix(at(click(0.0015, 1200, 4200) * 0.5, 0.0), k1, slide, k2, tick, room(tail(0.2, 900, 0.05) * 0.3)), 4800)


def throw(i):
    """Burr Charge toss: leather grip, an arm's worth of moved air, a low whump."""
    grip = bpf(noise(0.1), 400, 1800) * env(N(0.1), 0.015, 0.03) * 0.35 * g()
    swing = at(air(0.26, 900 * g(0.9, 1.1), 320, 0.1, 0.03, 0.14, 0.55, 150, 3200) * 1.0, 0.03)
    whump = at(kick(120 + 6 * i, 60, 0.2, 0.01, 0.05, 1.4) * 0.5 * g(), 0.05)
    return lpf(mix(grip, swing, whump, room(tail(0.12, 900, 0.03) * 0.15)), 4500)


def nuke_fire(i):
    """The big launcher: a chest-deep thump, a dull crack, a long dark rumble of room behind."""
    d = 0.9
    thump = kick(88 + 5 * i, 38, d, 0.02, 0.2, 1.9) * 0.95 * g()
    crack_ = crack(d, 120, 900, 0.03) * 2.0 * g()
    snap = crack(d, 500, 2600, 0.012) * 1.1 * g()
    rumble = at(bpf(noise(0.6), 60, 420) * env(N(0.6), 0.05, 0.28) * 0.6 * g(), 0.03)
    whoosh = at(air(0.5, 800, 280, 0.12, 0.05, 0.3, 0.5, 120, 2400) * 0.35, 0.04)
    return lpf(mix(thump, crack_, snap, rumble, whoosh, room(tail(0.55, 700, 0.12) * 0.5, 1.4)), 4200)


def zap(i):
    """Static jumping onto a foe: a spit of crackle in the mids on a low mains buzz and a thump, no glassy top."""
    d = 0.32
    crackle = grains(0.22, 70 + 6 * i, 350, 3400, 0.0008, 0.003, fall=0.07) * 0.55 * g()
    buzz = bpf(noise(0.26), 80, 260) * env(N(0.26), 0.004, 0.09) * 1.1 * g()
    zip_ = at(crack(0.12, 500, 2800, 0.012) * 1.6 * g(), 0.0)
    thump = kick(140 + 6 * i, 62, 0.2, 0.008, 0.05, 1.5) * 0.7 * g()
    return lpf(mix(crackle, buzz, zip_, thump, room(tail(0.2, 1000, 0.05) * 0.25)), 4600)


def miss(i):
    """A finger bolt that hit nothing: a little air and a soft dying pop, falling not rising."""
    puff = air(0.3, 1100 * g(0.9, 1.1), 350, 0.04, 0.03, 0.2, 0.5, 150, 2800) * 1.0
    pop = at(kick(165 + 8 * i, 80, 0.14, 0.006, 0.03, 1.3) * 0.4 * g(), 0.01)
    spit = at(grains(0.15, 40, 300, 2600, 0.001, 0.003, fall=0.05) * 0.3 * g(), 0.02)
    return lpf(mix(puff, pop, spit, room(tail(0.15, 800, 0.04) * 0.2)), 3800)


def bolt_tail(i):
    """The bolt leaving the rod: a fwoomp of air and a low pressure thud, falling away (it was 11 kHz hiss)."""
    d = 0.4
    fwoomp = air(d, 1300, 360, 0.05, 0.05, 0.25, 0.55, 150, 3200) * 1.1 * g()
    body = kick(105, 55, 0.3, 0.015, 0.08, 1.6) * 0.7 * g()
    crackle = at(grains(0.2, 36, 400, 2800, 0.001, 0.003, fall=0.06) * 0.25, 0.01)
    return lpf(mix(fwoomp, body, crackle, room(tail(0.2, 900, 0.05) * 0.2)), 4200)


def thrust(i):
    """A spear thrust: leather grip, a short whip of air, a push from the back foot."""
    grip = bpf(noise(0.06), 500, 2000) * env(N(0.06), 0.008, 0.02) * 0.4 * g()
    whip = at(air(0.15, 1300 * g(0.9, 1.1), 480, 0.05, 0.01, 0.07, 0.55, 200, 3400) * 1.2, 0.005)
    push = kick(118 + 8 * i, 60, 0.15, 0.008, 0.03, 1.4) * 0.6 * g()
    return lpf(mix(grip, whip, push, room(tail(0.06, 900, 0.02) * 0.1)), 4500)


def chain(i):
    """The chain thrown: links paying out as dull knocks, a whoosh, a low snap of weight."""
    links = grains(0.4, 34 + 4 * i, 300, 2600, 0.001, 0.004, fall=0.2) * 0.45 * g()
    swoosh = air(0.45, 1000 * g(0.9, 1.1), 320, 0.15, 0.08, 0.22, 0.55, 150, 3000) * 0.9
    weight = at(kick(95, 52, 0.3, 0.012, 0.08, 1.6) * 0.7 * g(), 0.08)
    lead = click(0.0015, 1000, 3600) * 0.6
    return lpf(mix(lead, links, swoosh, weight, room(tail(0.3, 900, 0.07) * 0.25)), 4400)


def flyby_bullet(i):
    """A shot passing close: a thin crack of moved air on a short low whoomp, no whistle."""
    d = 0.18
    zip_ = air(d, 2400 * g(0.9, 1.1), 700, 0.01, 0.01, 0.1, 0.5, 300, 3600) * 1.4
    thud = kick(120, 70, 0.14, 0.008, 0.03, 1.4) * 0.35 * g()
    return lpf(mix(zip_, thud), 4200)


# ------------------------------------------------------------------ hits
def hit_in(i):
    """You are hit: a dull body thud with a cloth slap; short and low so it cuts through a fight without sparkle."""
    d = 0.14
    body = kick(125 + 9 * i, 62, d, 0.006, 0.035, 1.6) * 0.8 * g()
    slap = crack(d, 300, 2400, 0.01) * 2.0 * g()
    tick = click(0.001, 1200, 3600) * 0.5
    return lpf(mix(tick, body, slap, room(tail(0.09, 900, 0.03) * 0.2)), 4600)


def mage_hit(i):
    """The kit's hit tick: a muted electric spit on a thud."""
    d = 0.18
    spit = grains(0.1, 50, 400, 3200, 0.0008, 0.0025, fall=0.03) * 0.5 * g()
    slap = crack(d, 350, 2600, 0.012) * 1.8 * g()
    thud = kick(140 + 8 * i, 66, d, 0.006, 0.035, 1.5) * 0.55 * g()
    return lpf(mix(spit, slap, thud, room(tail(0.1, 900, 0.03) * 0.2)), 4600)


def hit_magic(i):
    """Magic landing: a crackle on a soft pressure thump (it was glassy inharmonic partials)."""
    d = 0.24
    crackle = grains(0.16, 42, 350, 3000, 0.001, 0.003, fall=0.07) * 0.9 * g()
    body = kick(112 + 7 * i, 58, d, 0.01, 0.06, 1.6) * 0.75 * g()
    puff = at(air(0.18, 900, 350, 0.04, 0.02, 0.12, 0.5, 150, 2600) * 0.5, 0.01)
    return lpf(mix(crackle, body, puff, room(tail(0.14, 900, 0.04) * 0.25)), 4400)


def hit_thrown(i):
    """A thrown thing landing: a pebble tick, a dull knock, a scrape."""
    d = 0.2
    tick = click(0.0015, 1300, 4000) * 1.8 * g()
    knock = kick(170 + 9 * i, 90, d, 0.006, 0.04, 1.4) * 0.5 * g()
    scrape = at(grains(0.12, 24, 500, 2800, 0.001, 0.003, fall=0.04) * 0.7 * g(), 0.015)
    return lpf(mix(tick, knock, scrape, room(tail(0.1, 900, 0.03) * 0.2)), 4400)


def thrust_hit(i):
    """A spear point going in: a dull thunk and a wet cloth slap."""
    d = 0.19
    thunk = kick(120 + 8 * i, 60, d, 0.008, 0.045, 1.6) * 0.85 * g()
    slap = crack(d, 300, 2200, 0.014) * 1.8 * g()
    tick = click(0.0015, 1100, 3600) * 0.5
    return lpf(mix(tick, thunk, slap, room(tail(0.1, 900, 0.03) * 0.2)), 4500)


def lunge_hit(i):
    """Kael's lunge connecting: a low heavy slam, crunch and grit, a damped scrape, a big dark room."""
    d = 0.6
    slam = kick(80 + 5 * i, 42, d, 0.012, 0.12, 1.8) * 1.0 * g()
    crunch = crack(d, 150, 1500, 0.04) * 2.0 * g()
    grit = at(grains(0.3, 60, 400, 2600, 0.001, 0.004, fall=0.12) * 0.35 * g(), 0.02)
    scrape = at(crack(0.2, 900, 3200, 0.03) * 0.5 * g(), 0.01)
    return lpf(mix(slam, crunch, grit, scrape, room(tail(0.4, 800, 0.1) * 0.5, 1.3)), 4600)


# ------------------------------------------------------------------ movement
def land(i):
    """A landing: a boot thump on packed earth with a puff of dust (it had no tail)."""
    d = 0.2
    thump = kick(98 + 7 * i, 54, d, 0.008, 0.05, 1.6) * 0.8 * g()
    dust = crack(d, 200, 1300, 0.04) * 1.4 * g()
    grit = at(grains(0.12, 24, 600, 2400, 0.001, 0.003, fall=0.05) * 0.2 * g(), 0.012)
    return lpf(mix(thump, dust, grit, room(tail(0.12, 800, 0.04) * 0.25)), 2600)


LEDGE = {"light": (1.2, 0.8, 0.5), "medium": (1.0, 1.0, 0.8), "heavy": (0.8, 1.25, 1.1)}


def ledgegrab(w, i):
    """A hand slapping the lip and gripping: a palm tap and a thump of the body weight, a gritty slide of the grip."""
    p, L, body = LEDGE[w]
    tap = bpf(noise(0.06 * L), 400 * p, 2400 * p) * env(N(0.06 * L), 0.001, 0.02 * L) * 1.0 * g()
    grip = at(grains(0.16 * L, 40, 300 * p, 2400, 0.001, 0.004, fall=0.06 * L) * 0.3 * g(), 0.03)
    thump = kick((130 + 8 * i) * p, 65 * p, 0.14 * L, 0.01, 0.04 * L, 1.4) * body * 0.7 * g()
    return lpf(mix(click(0.002, 900, 3000) * 0.5, tap, grip, thump), 3400)


# Each Hunter's foley keeps what it wears or carries, with the ring taken out.
def foley_archer(dash, i):
    """Quiver leather and arrow shafts knocking: dull wood ticks and cloth."""
    d = 0.4 if dash else 0.22
    knock = kick(190 + 14 * i, 110, 0.07, 0.004, 0.015, 1.3) * 0.5 * g()
    knock2 = at(kick(260, 150, 0.05, 0.003, 0.012, 1.2) * 0.35 * g(), 0.04)
    leather = bpf(noise(d), 300, 1800) * env(N(d), 0.01 if not dash else 0.05, d * 0.35) * (0.5 if dash else 0.3)
    return lpf(mix(knock, knock2, leather), 3300 if dash else 3000)


def foley_gunslinger(dash, i):
    """The brass ammo strap and coin chain: a low dull clink of brass on leather, no jingle."""
    d = 0.4 if dash else 0.24
    clinks = grains(d * 0.7, 30 if dash else 16, 700, 3000, 0.001, 0.004, fall=d * 0.3) * 0.5 * g()
    strap = bpf(noise(d), 250, 1500) * env(N(d), 0.01 if not dash else 0.05, d * 0.35) * (0.45 if dash else 0.25)
    thud = kick(150 + 8 * i, 90, 0.08, 0.005, 0.015, 1.3) * 0.35 * g()
    return lpf(mix(clinks, strap, thud), 3400 if dash else 3200)


def foley_mage(dash, i):
    """Sparkle's copper wrist coils: muted static crackle and a soft cloth sleeve, not a ring."""
    d = 0.45 if dash else 0.25
    crackle = grains(d * 0.8, 50 if dash else 26, 400, 3200, 0.0008, 0.003, fall=d * 0.4) * 0.5 * g()
    sleeve = bpf(noise(d), 250, 1700) * env(N(d), 0.01 if not dash else 0.06, d * 0.4) * (0.55 if dash else 0.3)
    return lpf(mix(crackle, sleeve), 3500 if dash else 3200)


# ------------------------------------------------------------------ pickups
def pickup(i):
    """Picking something up: a pouch rustle, a small dull thunk, a wooden tick; no chime."""
    rustle = bpf(noise(0.2), 500, 2600) * env(N(0.2), 0.02, 0.07) * 0.45 * g()
    thunk = at(kick(185 + 12 * i, 100, 0.16, 0.006, 0.04, 1.4) * 0.7 * g(), 0.05)
    tick = at(click(0.0015, 1000, 3200) * 0.5, 0.05)
    clack = at(kick(300, 180, 0.06, 0.004, 0.012, 1.2) * 0.3 * g(), 0.13)
    return lpf(mix(rustle, thunk, tick, clack, room(tail(0.15, 900, 0.04) * 0.15, 0.6)), 3400)


def inv_grab(i):
    """Grabbing an inventory item: cloth and a felt tap."""
    cloth = bpf(noise(0.1), 400, 2200) * env(N(0.1), 0.012, 0.03) * 0.5 * g()
    tap = at(kick(210 + 10 * i, 120, 0.08, 0.005, 0.02, 1.3) * 0.5 * g(), 0.02)
    return lpf(mix(cloth, tap, click(0.0015, 900, 3000) * 0.4), 3200)


def build():
    cat = S.takes_cat
    cat("vn_cock", cock, 2, "cast")
    cat("vn_throw", throw, 2, "cast")
    cat("vn_nuke_fire", nuke_fire, 2, "cast")
    cat("mage_zap", zap, 3, "signature")
    cat("mage_miss", miss, 3, "impact")
    cat("mage_bolt_tail", bolt_tail, 2, "cast")
    cat("gil_thrust", thrust, 3, "fire")
    cat("jug_chain", chain, 2, "cast")
    cat("flyby_bullet", flyby_bullet, 2, "dash")
    cat("hit_in", hit_in, 3, "impact")
    cat("mage_hit", mage_hit, 3, "impact")
    S.C.takes("hit_magic", hit_magic, 3, rms_db=HIT_DB, peak_db=S.PEAK_DB)
    S.C.takes("hit_thrown", hit_thrown, 3, rms_db=HIT_DB, peak_db=S.PEAK_DB)
    cat("gil_thrust_hit", thrust_hit, 2, "impact")
    cat("jug_lunge_hit", lunge_hit, 2, "impact")
    S.C.takes("land", land, 3, rms_db=-22, peak_db=S.PEAK_DB)
    for w in LEDGE:
        cat("ledgegrab_" + w, lambda i, w=w: ledgegrab(w, i), 3, "step")
    for arch, fn in (("archer", foley_archer), ("gunslinger", foley_gunslinger), ("mage", foley_mage)):
        cat(arch + "_foley", lambda i, fn=fn: fn(False, i), 3, "step")
        cat(arch + "_foley_dash", lambda i, fn=fn: fn(True, i), 2, "dash")
    cat("pickup", pickup, 3, "ui")
    cat("inv_grab", inv_grab, 3, "ui")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", help="write here instead of audio/ (the listening pack)")
    args = ap.parse_args()
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        S.C.OUT = args.out
    build()
    print("grounded sfx wave 2 written")
