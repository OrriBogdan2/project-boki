"""Belt item sounds (briefs/SFX_AUDIT.md row 14): every belt item has its own start cue, and the two
that channel (tonic, armour kit) also a loop, a finish and a cancel. Run from tools/: python3 gen_sfx_belt.py

Which cue belongs to which item is content/rules/belt_sfx.json. All original synthesis, no samples.
  tonic      cork pop; a gulping loop; a bright two-note chime with a breath out; a splash when spilt
  armor_kit  clasp and knock; a ratchet-and-tap loop; a bolt seating with a ring; dropped tools
  medkit     a zip, then a warm rising triad    jump_pad    a spring boing
  scanner    a sonar ping with an echo          shield_cell an energy whine into a ringing bell
  smoke      a canister thud and a long hiss    stim        a syringe click and a double heartbeat
The source utilities (UTILITY_ITEMS) each get a start; the placed ones a loop while they stand, an end
when they go and (fan) a hit; the drinks a loop, end and cancel; Skyfall a 5 s fuse and a boom:
  twin_gate portal hum      warp_seed throbbing anomaly   gust_fan blade whirr   cloud_raft soft wind
  blight_flask bubbling     thorn_wall creaking vines     lookout_lantern hum and tick   bounty_banner drone
  skyfall_charge accelerating fuse beeps, then a boom     deep_draught / lostway_scroll / omen_draught drinks
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise, pad

S.reseed(7014)


def jit(i, spread=0.04):
    """Take i drifts a little in pitch so repeats never sound identical."""
    return 1.0 + (0 if i == 0 else S.rng.uniform(-spread, spread))


def knock(f, d=0.12, decay=0.03):
    """A small metal knock: an inharmonic ring with a bright click on the front."""
    return mix(S.ring([f, f * 2.41, f * 4.1], d, [decay, decay * 0.6, decay * 0.35], [1.0, 0.5, 0.25]),
               0.5 * S.click(0.003, 3000, 9000, 0.001))


def gulp(f, d=0.2):
    """One swallow: a falling gurgle with a wet rasp."""
    return lpf(mix(S.sweep(f, f * 0.45, d) * env(N(d), 0.01, d * 0.5),
                   0.3 * lpf(noise(d), 1500) * env(N(d), 0.01, d * 0.4)), 3600)


def tonic_start(i):
    j = jit(i)
    cork = S.sweep(300 * j, 1300 * j, 0.07) * env(N(0.07), 0.003, 0.04)
    return lpf(mix(cork, at(S.click(0.004, 1500, 6000, 0.003) * 0.7, 0.065), at(gulp(420 * j, 0.14) * 0.6, 0.12)), 5200)


def tonic_loop(i):
    return pad(mix(*[at(gulp((430 - 40 * k) * 1.0, 0.24), 0.3 * k) for k in range(3)]), 0.9)


def tonic_end(i):
    j = jit(i, 0.02)
    notes = mix(S.chime(1318 * j, 0.5, 0.2), at(S.chime(1760 * j, 0.7, 0.3) * 0.8, 0.09))
    return mix(notes, at(bpf(noise(0.3), 1100, 3800) * env(N(0.3), 0.06, 0.1) * 0.2, 0.02))


def tonic_cancel(i):
    j = jit(i)
    splash = hpf(noise(0.3), 1500) * env(N(0.3), 0.004, 0.07) * 0.5
    return lpf(mix(splash, at(gulp(300 * j, 0.2) * 0.6, 0.05), S.kick(170, 70, 0.15, 0.03, 0.07) * 0.5), 5000)


def kit_start(i):
    j = jit(i)
    return lpf(mix(S.click(0.004, 2000, 8000, 0.002), at(knock(1250 * j, 0.14, 0.04), 0.03),
                   at(knock(1700 * j, 0.1, 0.03) * 0.7, 0.11)), 7000)


def kit_loop(i):
    taps = [at(knock(1500 + 220 * (k % 2), 0.08, 0.016) * 0.7, 0.2 * k) for k in range(4)]
    ratchet = [at(S.rattle(0.07, 90, 2500, 6000), 0.2 * k + 0.1) * 0.4 for k in range(4)]
    return pad(lpf(mix(*taps, *ratchet), 7000), 0.8)


def kit_end(i):
    j = jit(i, 0.03)
    seat = mix(S.kick(190, 85, 0.14, 0.02, 0.05), 0.7 * knock(980 * j, 0.2, 0.06))
    shimmer = S.ring([2900 * j, 4300 * j], 0.5, [0.18, 0.12], [0.3, 0.2])
    return lpf(mix(seat, at(shimmer, 0.05)), 8000)


def kit_cancel(i):
    j = jit(i, 0.05)
    clatter = S.rattle(0.35, 60, 1200 * j, 4500, 0.6, 0.12)
    return lpf(mix(clatter, S.kick(130, 60, 0.12, 0.02, 0.05) * 0.5, at(knock(700 * j, 0.14, 0.04) * 0.6, 0.1)), 6500)


def medkit_start(i):
    j = jit(i, 0.015)
    zip_ = bpf(noise(0.14), 2500, 7000) * env(N(0.14), 0.01, 0.07) * 0.35
    notes = [at(S.chime(f * j, 0.5, 0.25) * 0.8, 0.12 + 0.07 * k) for k, f in enumerate((523, 659, 784))]
    return mix(zip_, *notes)


def pad_start(i):
    j = jit(i)
    boing = mix(0.5 * S.fm(220 * j, 1.5, 3.0, 0.5, 0.12), S.sweep(180 * j, 520 * j, 0.25) * env(N(0.25), 0.004, 0.14))
    return lpf(mix(S.kick(120, 55, 0.12, 0.02, 0.05), at(boing, 0.04)), 5000)


def scanner_start(i):
    j = jit(i, 0.02)
    ping = S.sweep(1500 * j, 2100 * j, 0.15) * env(N(0.15), 0.003, 0.18)
    return mix(ping, at(ping * 0.45, 0.22), at(ping * 0.2, 0.44), S.ring([3100 * j], 0.5, [0.2], [0.15]))


def shield_start(i):
    j = jit(i, 0.02)
    whine = S.sweep(300 * j, 1500 * j, 0.28, curve=2.0) * env(N(0.28), 0.05, 0.3) * 0.6
    return mix(whine, at(mix(S.chime(1250 * j, 0.7, 0.4), 0.4 * S.fm(500 * j, 2.0, 1.0, 0.5, 0.25)), 0.26))


def smoke_start(i):
    j = jit(i)
    return lpf(mix(S.kick(95, 45, 0.18, 0.03, 0.09), S.click(0.004, 1000, 5000, 0.003) * 0.5,
                   at(S.hiss(0.9, 900 * j, 5000, 0.08, 0.4) * 0.5, 0.04)), 6000)


def stim_start(i):
    j = jit(i)
    click = S.click(0.004, 3000, 9000, 0.002)
    beat = S.kick(80 * j, 45, 0.12, 0.02, 0.06) * 0.9
    return mix(click, at(beat, 0.1), at(beat * 0.8, 0.28), at(bpf(noise(0.3), 2000, 6000) * env(N(0.3), 0.1, 0.1) * 0.15, 0.1))


# ------------------------------------------------------------------ the source utilities
def tone(f, d, a=0.01, decay=None):
    """A plain sine that swells in over a and falls away over decay (default d / 3)."""
    return np.sin(2 * np.pi * f * np.arange(N(d)) / S.SR) * env(N(d), a, decay or d / 3)


def whoosh(d, lo, hi, a=0.05, decay=None):
    return bpf(noise(d), lo, hi) * env(N(d), a, decay or d / 2)


def bed(d, *layers):
    """A loop bed: layers padded to d seconds (save_loop joins the ends)."""
    return S.pad(mix(*layers), d)[:N(d)]


def lfo(d, hz, depth=0.4):
    """A slow wobble of amplitude between 1 - depth and 1, a whole number of cycles in d so it loops."""
    cycles = max(1, round(hz * d))
    return 1.0 - depth * (0.5 - 0.5 * np.cos(2 * np.pi * cycles * np.arange(N(d)) / N(d)))


def gate_start(i):
    j = jit(i)
    return lpf(mix(S.sweep(160 * j, 700 * j, 0.4) * env(N(0.4), 0.02, 0.2), at(S.sweep(900 * j, 2200 * j, 0.3) * env(N(0.3), 0.02, 0.18) * 0.5, 0.06),
                   S.kick(90, 45, 0.2, 0.04, 0.1) * 0.6), 6500)


def gate_loop(i):
    d = 1.6
    return bed(d, tone(180, d, 0.01, 99) * 0.6, tone(363, d, 0.01, 99) * 0.3 * lfo(d, 3, 0.7), tone(1210, d, 0.01, 99) * 0.1 * lfo(d, 5, 0.9))


def gate_end(i):
    j = jit(i)
    return lpf(mix(S.sweep(1800 * j, 200 * j, 0.3) * env(N(0.3), 0.01, 0.15), at(S.kick(130, 60, 0.12, 0.02, 0.05) * 0.7, 0.28)), 6000)


def seed_start(i):
    j = jit(i)
    plop = S.sweep(500 * j, 180 * j, 0.1) * env(N(0.1), 0.002, 0.04)
    return lpf(mix(plop, at(S.fm(240 * j, 1.5, 2.5, 0.5, 0.2) * 0.6, 0.08), at(S.click(0.004, 2000, 7000, 0.003) * 0.4, 0.02)), 5000)


def seed_loop(i):
    d = 1.6
    return bed(d, tone(62, d, 0.01, 99) * lfo(d, 5, 0.8), tone(124, d, 0.01, 99) * 0.4 * lfo(d, 5, 0.8), S.fm(700, 1.5, 2.0, d, 99, 0.01) * 0.12 * lfo(d, 2, 0.8))


def seed_end(i):
    j = jit(i)
    return lpf(mix(S.kick(220 * j, 70, 0.2, 0.05, 0.09), S.sweep(1400 * j, 300 * j, 0.35) * env(N(0.35), 0.01, 0.15) * 0.5), 6000)


def fan_start(i):
    j = jit(i)
    return lpf(mix(S.kick(100, 50, 0.14, 0.03, 0.06), at(whoosh(0.5, 300 * j, 2200 * j, 0.25, 0.3) * 0.7, 0.03), at(S.click(0.004, 1200, 5000, 0.003) * 0.5, 0.01)), 6000)


def fan_loop(i):
    d = 1.2
    blades = bpf(noise(d), 250, 1600) * lfo(d, 10, 0.7)
    return bed(d, blades * 0.8, tone(95, d, 0.01, 99) * 0.3 * lfo(d, 10, 0.5))


def fan_hit(i):
    j = jit(i)
    return lpf(mix(whoosh(0.4, 400 * j, 3000 * j, 0.03, 0.15), S.kick(110, 55, 0.14, 0.02, 0.06) * 0.8), 6500)


def fan_end(i):
    return lpf(mix(whoosh(0.7, 200, 1400, 0.01, 0.35) * 0.6, S.sweep(180, 60, 0.6) * env(N(0.6), 0.01, 0.3) * 0.4), 4000)


def raft_start(i):
    j = jit(i)
    return lpf(mix(whoosh(0.6, 500 * j, 3500 * j, 0.3, 0.3) * 0.7, at(tone(660 * j, 0.5, 0.1, 0.15) * 0.25, 0.25), S.kick(90, 55, 0.12, 0.02, 0.05) * 0.4), 6000)


def raft_loop(i):
    d = 2.0
    return bed(d, bpf(noise(d), 200, 900) * lfo(d, 1, 0.6), bpf(noise(d), 1500, 3500) * 0.12 * lfo(d, 2, 0.8))


def raft_end(i):
    return lpf(mix(whoosh(0.7, 300, 1800, 0.01, 0.35) * 0.6, S.sweep(500, 200, 0.5) * env(N(0.5), 0.01, 0.2) * 0.3), 4000)


def skyfall_start(i):
    j = jit(i)
    return lpf(mix(S.kick(130, 55, 0.2, 0.05, 0.1), at(whoosh(0.6, 800 * j, 5000 * j, 0.1, 0.3), 0.04), at(S.sweep(300 * j, 1500 * j, 0.5) * env(N(0.5), 0.05, 0.3) * 0.5, 0.1)), 7000)


def skyfall_loop(i):
    """The fuse: 5 s of beeps that come faster and higher, so everyone near knows it is about to land."""
    d, t, k = 5.0, 0.0, 0
    parts = []
    while t < d - 0.12:
        f = 700 + 900 * (t / d)
        parts.append(at(tone(f, 0.09, 0.004, 0.05) * 0.8, t))
        t += max(0.1, 0.62 - 0.52 * (t / d) ** 0.8)
        k += 1
    return bed(d, *parts, tone(90, d, 0.01, 99) * 0.15)


def skyfall_end(i):
    j = jit(i, 0.03)
    boom = S.kick(75 * j, 28, 0.9, 0.12, 0.4, 3.0)
    rumble = lpf(noise(1.6), 380) * env(N(1.6), 0.02, 0.6) * 0.9
    crack_ = S.crack(0.3, 800, 6000, 0.05) * 0.8
    return lpf(mix(boom, rumble, crack_, at(whoosh(0.8, 200, 2000, 0.05, 0.4) * 0.3, 0.1)), 7500)


def blight_start(i):
    j = jit(i)
    glass = mix(S.click(0.006, 3500, 10000, 0.004), S.ring([2900 * j, 4300 * j, 6100 * j], 0.3, [0.06, 0.04, 0.03], [0.4, 0.3, 0.2]))
    return lpf(mix(glass, at(S.hiss(0.7, 500, 3500, 0.03, 0.3) * 0.5, 0.02), at(S.kick(150, 60, 0.15, 0.03, 0.07) * 0.5, 0.01)), 8000)


def blight_loop(i):
    d, parts = 2.0, []
    for k in range(9):
        f = 180 + 90 * ((k * 5) % 7)
        parts.append(at(S.sweep(f, f * 1.8, 0.09) * env(N(0.09), 0.003, 0.04) * 0.5, 0.21 * k + 0.03 * (k % 3)))
    return bed(d, *parts, lpf(noise(d), 700) * 0.2 * lfo(d, 3, 0.6))


def blight_end(i):
    return lpf(mix(S.hiss(0.6, 400, 3000, 0.01, 0.25) * 0.6, S.sweep(400, 120, 0.4) * env(N(0.4), 0.005, 0.15) * 0.5), 5000)


def thorn_start(i):
    j = jit(i)
    thunk = lambda f, dl: at(S.kick(f * j, f * 0.5, 0.09, 0.02, 0.04) * 0.8, dl)
    return lpf(mix(thunk(150, 0), thunk(180, 0.07), thunk(130, 0.15), at(S.rattle(0.35, 70, 1500, 5500, 0.5, 0.15) * 0.5, 0.03)), 6500)


def thorn_loop(i):
    d = 2.0
    one = S.creak(0.6, 80, 55, 0.5, 1800)
    two = S.creak(0.5, 70, 90, 0.5, 1600)
    return bed(d, at(one * 0.4 * S.shape(0.6, 0.1, 0.3, 0.2), 0.3), at(two * 0.3 * S.shape(0.5, 0.1, 0.2, 0.2), 1.2), hpf(noise(d), 3000) * 0.05 * (1.0 - lfo(d, 2, 1.0)))


def thorn_end(i):
    return lpf(mix(S.rattle(0.4, 60, 1200, 5000, 0.6, 0.15) * 0.8, S.kick(120, 60, 0.12, 0.02, 0.05) * 0.5), 6000)


def lantern_start(i):
    j = jit(i, 0.02)
    return mix(S.click(0.004, 1800, 7000, 0.003) * 0.7, at(S.chime(1046 * j, 0.7, 0.3) * 0.8, 0.04), at(S.chime(1568 * j, 0.6, 0.25) * 0.4, 0.1))


def lantern_loop(i):
    d = 1.6
    ticks = [at(S.click(0.003, 3000, 8000, 0.002) * 0.4, 0.8 * k + 0.4) for k in range(2)]
    return bed(d, tone(880, d, 0.01, 99) * 0.18 * lfo(d, 1, 0.5), tone(1320, d, 0.01, 99) * 0.08 * lfo(d, 2, 0.8), *ticks)


def lantern_end(i):
    return mix(S.ring([2400, 3300], 0.4, [0.1, 0.07], [0.5, 0.3]), at(S.chime(784, 0.5, 0.2) * 0.4, 0.04))


def banner_start(i):
    j = jit(i, 0.015)
    horn = lambda f, dl, d: at(lpf(S.fm(f * j, 1.0, 2.2, d, d * 0.8, 0.03), 2600) * env(N(d), 0.04, d * 0.6), dl)
    return mix(horn(220, 0, 0.5), horn(330, 0.32, 0.7), at(S.kick(95, 50, 0.15, 0.03, 0.07) * 0.5, 0))


def banner_loop(i):
    d = 2.0
    return bed(d, tone(110, d, 0.01, 99) * 0.7 * lfo(d, 1, 0.5), tone(165, d, 0.01, 99) * 0.35 * lfo(d, 1, 0.5), tone(221, d, 0.01, 99) * 0.15)


def banner_end(i):
    j = jit(i, 0.02)
    return mix(S.chime(880 * j, 0.9, 0.4), at(S.chime(660 * j, 0.9, 0.4) * 0.8, 0.12), at(S.chime(440 * j, 1.1, 0.5) * 0.8, 0.26))


def pilfer_start(i):
    j = jit(i, 0.03)
    coins = [at(S.ring([3400 * j * (1 + 0.1 * k), 5200 * j], 0.2, [0.05, 0.03], [0.4, 0.2]), 0.05 + 0.055 * k) for k in range(5)]
    return mix(whoosh(0.3, 600, 4000, 0.03, 0.12) * 0.5, *coins)


def hawk_start(i):
    j = jit(i, 0.03)
    trill = np.sin(2 * np.pi * 18 * np.arange(N(0.45)) / S.SR)
    return mix(lpf(S.sweep(1800 * j, 2700 * j, 0.45) * env(N(0.45), 0.03, 0.3) * (1 + 0.3 * trill), 5000) * 0.8, at(whoosh(0.3, 3000, 8000, 0.01, 0.08) * 0.2, 0.0))


def lamp_start(i):
    j = jit(i, 0.02)
    return mix(S.hiss(0.15, 3000, 9000, 0.005, 0.06) * 0.5, at(S.chime(523 * j, 1.0, 0.5) * 0.7, 0.1), at(S.chime(784 * j, 1.0, 0.5) * 0.5, 0.17))


def ember_start(i):
    j = jit(i, 0.02)
    return mix(S.rattle(0.4, 90, 1500, 7000, 0.6, 0.1) * 0.5, at(S.sweep(220 * j, 880 * j, 0.6, curve=2.0) * env(N(0.6), 0.1, 0.3) * 0.5, 0.05), at(S.chime(1175 * j, 0.9, 0.4) * 0.7, 0.4))


def shatter_start(i):
    j = jit(i)
    return lpf(mix(whoosh(0.2, 700, 4000, 0.02, 0.08) * 0.6, at(S.click(0.005, 2200, 9000, 0.003), 0.15), at(S.ring([1900 * j, 2700 * j], 0.3, [0.07, 0.05], [0.4, 0.3]), 0.15)), 8000)


def satchel_start(i):
    j = jit(i)
    return lpf(mix(S.kick(110 * j, 55, 0.14, 0.03, 0.06), at(S.click(0.004, 1500, 6000, 0.003) * 0.6, 0.05), at(S.rattle(0.2, 60, 900, 4000, 0.5, 0.1) * 0.4, 0.03)), 5500)


def satchel_end(i):
    j = jit(i, 0.02)
    return mix(S.chime(659 * j, 0.6, 0.3) * 0.7, at(S.chime(880 * j, 0.6, 0.3) * 0.6, 0.08), whoosh(0.3, 1000, 5000, 0.05, 0.1) * 0.15)


def deep_start(i):
    return lpf(tonic_start(i), 3000) * 0.9


def deep_loop(i):
    d = 1.6
    return bed(d, *[at(gulp(300 - 30 * k, 0.4), 0.5 * k) for k in range(3)], tone(70, d, 0.01, 99) * 0.2 * lfo(d, 1, 0.6))


def deep_end(i):
    j = jit(i, 0.02)
    return mix(S.chime(659 * j, 0.9, 0.4), at(S.chime(988 * j, 0.9, 0.4) * 0.7, 0.1), S.kick(80, 45, 0.2, 0.04, 0.1) * 0.5)


def scroll_start(i):
    j = jit(i)
    return mix(S.rattle(0.35, 55, 800, 4500, 0.6, 0.2) * 0.6, at(S.chime(698 * j, 0.8, 0.4) * 0.5, 0.2), at(S.fm(350 * j, 2.0, 3.0, 0.5, 0.2) * 0.4, 0.25))


def scroll_loop(i):
    d = 1.6
    return bed(d, bpf(noise(d), 500, 1800) * 0.4 * lfo(d, 4, 0.8), S.fm(330, 2.0, 1.5, d, 99, 0.01) * 0.2 * lfo(d, 2, 0.7))


def scroll_end(i):
    j = jit(i)
    return lpf(mix(S.sweep(300 * j, 2400 * j, 0.35) * env(N(0.35), 0.02, 0.18), at(whoosh(0.4, 600, 5000, 0.01, 0.2) * 0.6, 0.12), at(S.kick(110, 50, 0.15, 0.02, 0.07) * 0.6, 0.3)), 7000)


def scroll_cancel(i):
    return mix(S.rattle(0.3, 70, 1200, 5500, 0.7, 0.1) * 0.8, S.sweep(500, 180, 0.3) * env(N(0.3), 0.01, 0.12) * 0.4)


def omen_start(i):
    j = jit(i, 0.02)
    return mix(S.chime(262 * j, 1.4, 0.7), at(S.chime(392 * j, 1.2, 0.6) * 0.5, 0.05), S.kick(85, 45, 0.15, 0.03, 0.07) * 0.4)


def omen_loop(i):
    d = 2.0
    return bed(d, S.fm(523, 3.0, 1.2, d, 99, 0.01) * 0.2 * lfo(d, 2, 0.6), tone(784, d, 0.01, 99) * 0.1 * lfo(d, 3, 0.8), tone(131, d, 0.01, 99) * 0.3)


def omen_end(i):
    j = jit(i, 0.02)
    return mix(S.chime(784 * j, 1.0, 0.5), at(S.chime(1175 * j, 1.0, 0.5) * 0.6, 0.12), at(S.chime(1568 * j, 1.0, 0.5) * 0.4, 0.24))


def omen_cancel(i):
    return mix(S.ring([262, 311], 0.4, [0.1, 0.08], [0.4, 0.3]), S.sweep(500, 150, 0.3) * env(N(0.3), 0.01, 0.12) * 0.3)


# item -> {kind: maker}. A start gets two takes (Sfx rotates them), the other kinds one.
UTILITY_CUES = {
    'twin_gate': {'start': gate_start, 'loop': gate_loop, 'end': gate_end},
    'warp_seed': {'start': seed_start, 'loop': seed_loop, 'end': seed_end},
    'gust_fan': {'start': fan_start, 'loop': fan_loop, 'hit': fan_hit, 'end': fan_end},
    'cloud_raft': {'start': raft_start, 'loop': raft_loop, 'end': raft_end},
    'skyfall_charge': {'start': skyfall_start, 'loop': skyfall_loop, 'end': skyfall_end},
    'blight_flask': {'start': blight_start, 'loop': blight_loop, 'end': blight_end},
    'thorn_wall': {'start': thorn_start, 'loop': thorn_loop, 'end': thorn_end},
    'lookout_lantern': {'start': lantern_start, 'loop': lantern_loop, 'end': lantern_end},
    'bounty_banner': {'start': banner_start, 'loop': banner_loop, 'end': banner_end},
    'pilfer_pouch': {'start': pilfer_start}, 'hawk_whistle': {'start': hawk_start},
    'hearth_lamp': {'start': lamp_start}, 'revive_ember': {'start': ember_start},
    'shatter_charge': {'start': shatter_start}, 'toss_satchel': {'start': satchel_start, 'end': satchel_end},
    'deep_draught': {'start': deep_start, 'loop': deep_loop, 'end': deep_end, 'cancel': tonic_cancel},
    'lostway_scroll': {'start': scroll_start, 'loop': scroll_loop, 'end': scroll_end, 'cancel': scroll_cancel},
    'omen_draught': {'start': omen_start, 'loop': omen_loop, 'end': omen_end, 'cancel': omen_cancel},
}


def main():
    for name, fn in (('belt_tonic_start', tonic_start), ('belt_tonic_end', tonic_end),
                     ('belt_tonic_cancel', tonic_cancel), ('belt_armor_kit_start', kit_start),
                     ('belt_armor_kit_end', kit_end), ('belt_armor_kit_cancel', kit_cancel),
                     ('belt_medkit_start', medkit_start), ('belt_jump_pad_start', pad_start),
                     ('belt_scanner_start', scanner_start), ('belt_shield_cell_start', shield_start),
                     ('belt_smoke_start', smoke_start), ('belt_stim_start', stim_start)):
        S.takes_cat(name, fn, 2, 'cast')
    S.save_loop('belt_tonic_loop', tonic_loop(0), 'loop')
    S.save_loop('belt_armor_kit_loop', kit_loop(0), 'loop')
    for item, kinds in UTILITY_CUES.items():
        for kind, fn in kinds.items():
            name = 'belt_%s_%s' % (item, kind)
            if kind == 'loop':
                S.save_loop(name, fn(0), 'loop')
            else:
                S.takes_cat(name, fn, 1 if kind == 'start' else 0, 'cast')


if __name__ == '__main__':
    main()
