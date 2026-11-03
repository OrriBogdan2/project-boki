"""Synthesizes Tarek's (dolm) and Ostra's ability sounds into audio/*.wav (mono, 22.05kHz, 16-bit).

    python3 tools/gen_stone_sfx.py           (then: godot --headless --import)

Pure Python (wave, math, random; the helpers are tools/gen_pair_sfx.py's): no numpy. Every sound is
original. Tarek is stone and magma (low thumps, cracks, rubble grains, a molten hiss); Ostra is void glass
(sine sweeps pulled down, glassy partials, a soft hum). Names are in scripts/core/sfx_kits.gd.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_pair_sfx import n, fade, lowpass, highpass, noise, sine_sweep, env_exp, mix, at, level, save, rng


def env(x, tau):
    return [a * b for a, b in zip(x, env_exp(len(x), tau))]


def ramp_in(x, k=2.0):
    N = len(x)
    return [v * (i / max(1, N - 1)) ** k for i, v in enumerate(x)]


def tone(f, d, tau, amp=1.0):
    return [math.sin(2 * math.pi * f * i / SR) * math.exp(-i / SR / tau) * amp for i in range(n(d))]


SR = 22050


def grains(total, t0, t1, decay, lo=700, hi=2600, gap=(0.02, 0.08)):
    out = [0.0] * n(total)
    t = t0
    while t < t1:
        g = env(lowpass(noise(0.03), rng.uniform(lo, hi)), 0.008)
        amp = rng.uniform(0.25, 0.7) * math.exp(-(t - t0) * decay)
        b = n(t)
        for i, v in enumerate(g):
            if b + i < len(out): out[b + i] += v * amp
        t += rng.uniform(*gap)
    return out


def hiss(d, tau, hz=3500):
    return env(highpass(lowpass(noise(d), hz + 2500), hz), tau)


# ---------------------------------------------------------------- Tarek
def br_throw():
    T = 0.4
    whoosh = env(ramp_in(lowpass(noise(0.18), 1400), 1.5), 0.08)
    grunt = env(sine_sweep(150, 90, 0.15), 0.06)
    save('br_throw', level(mix(at(whoosh, 0, T), at([v * 0.6 for v in grunt], 0.02, T), at([v * 0.3 for v in hiss(0.3, 0.08)], 0.05, T))))


def br_boulder_hit():
    T = 0.6
    thump = env(sine_sweep(120, 50, 0.3, 0.8), 0.08)
    fire = env(lowpass(noise(0.4), 900), 0.12)
    save('br_boulder_hit', level(mix(at(thump, 0, T), at([v * 0.6 for v in fire], 0, T), grains(T, 0.03, 0.4, 5.0))))


def br_wind():
    T = 0.9
    rumble = ramp_in(env(lowpass(noise(0.9), 260), 0.6), 0.8)
    rise = ramp_in(sine_sweep(60, 120, 0.9, 1.2), 1.0)
    save('br_wind', level(mix(rumble, [v * 0.5 for v in rise], at([v * 0.25 for v in hiss(0.6, 0.3, 2500)], 0.2, T)), 0.1))


def br_punch():
    T = 0.7
    smack = env(highpass(lowpass(noise(0.08), 4000), 600), 0.02)
    thump = env(sine_sweep(140, 45, 0.4, 0.7), 0.1)
    crack = env(highpass(noise(0.1), 2000), 0.02)
    save('br_punch', level(mix(at(smack, 0, T), at([v * 1.2 for v in thump], 0, T), at([v * 0.5 for v in crack], 0.01, T), grains(T, 0.05, 0.5, 6.0)), 0.16))


def br_launch():
    T = 0.6
    crack = env(highpass(lowpass(noise(0.1), 5000), 1500), 0.03)
    roar = env(ramp_in(lowpass(noise(0.5), 700), 0.6), 0.25)
    save('br_launch', level(mix(at(crack, 0, T), at([v * 0.8 for v in roar], 0.02, T), at([v * 0.4 for v in hiss(0.5, 0.2)], 0.0, T))))


def br_burst():
    T = 1.0
    boom = env(sine_sweep(95, 36, 0.6, 0.8), 0.16)
    blast = env(lowpass(noise(0.6), 1500), 0.14)
    save('br_burst', level(mix(at(boom, 0, T), at([v * 0.7 for v in blast], 0, T), grains(T, 0.05, 0.9, 3.0, 900, 3200)), 0.16))


def br_rise():
    T = 0.6
    grind = env(lowpass(noise(0.45), 500), 0.2)
    up = env(sine_sweep(50, 110, 0.3), 0.15)
    save('br_rise', level(mix(at(grind, 0, T), at([v * 0.6 for v in up], 0, T), grains(T, 0.0, 0.35, 4.0, 600, 1800, (0.015, 0.04)))))


def br_roll():
    T = 0.9
    rum = env(lowpass(noise(0.85), 300), 0.4)
    wob = [v * (0.6 + 0.4 * math.sin(2 * math.pi * 11 * i / SR)) for i, v in enumerate(rum)]
    save('br_roll', level(mix(wob, grains(T, 0.0, 0.8, 1.5, 500, 1500, (0.04, 0.1)))))


def br_shove():
    T = 0.4
    w = env(lowpass(noise(0.3), 900), 0.08)
    thud = env(sine_sweep(100, 60, 0.2), 0.05)
    save('br_shove', level(mix(at(w, 0, T), at(thud, 0.04, T))))


def br_leap():
    T = 0.5
    up = env(sine_sweep(80, 160, 0.3, 0.8), 0.15)
    w = env(ramp_in(lowpass(noise(0.35), 1600), 1.2), 0.15)
    save('br_leap', level(mix(at(up, 0, T), at(w, 0, T))))


def br_slam():
    T = 1.4
    sub = env(sine_sweep(75, 28, 0.9, 0.8), 0.28)
    crack = env(highpass(lowpass(noise(0.12), 5200), 1200), 0.03)
    body = env(lowpass(noise(0.8), 600), 0.2)
    ring = tone(220, 0.8, 0.25, 0.15)
    save('br_slam', level(mix(at([v * 1.3 for v in sub], 0, T), at(crack, 0, T), at([v * 0.7 for v in body], 0, T), at(ring, 0.02, T), grains(T, 0.08, 1.2, 2.2, 700, 2800)), 0.18))


def br_crack():
    T = 0.35
    c = env(highpass(lowpass(noise(0.3), 3000), 500), 0.05)
    h = hiss(0.3, 0.12, 3000)
    save('br_crack', level(mix(c, [v * 0.6 for v in h])))


def br_raise():
    T = 0.9
    heave = env(sine_sweep(45, 95, 0.5, 0.9), 0.25)
    grind = env(lowpass(noise(0.7), 450), 0.3)
    save('br_raise', level(mix(at(heave, 0, T), at([v * 0.8 for v in grind], 0, T), grains(T, 0.0, 0.6, 2.5, 600, 2000, (0.02, 0.05))), 0.15))


def br_sense():
    T = 0.6
    pulse = env(sine_sweep(70, 55, 0.5), 0.2)
    save('br_sense', level(mix(pulse, at([v * 0.3 for v in env(lowpass(noise(0.4), 250), 0.15)], 0, T)), 0.08))


# ---------------------------------------------------------------- Ostra
def glass(fs, d, tau, amp=0.3):
    return mix(*[tone(f, d, tau, amp / (1 + i * 0.5)) for i, f in enumerate(fs)])


def os_orb():
    T = 0.3
    zip_ = env(sine_sweep(900, 420, 0.18, 0.7), 0.06)
    save('os_orb', level(mix(at(zip_, 0, T), at(glass([1760, 2640], 0.25, 0.06, 0.2), 0, T)), 0.1))


def os_orb_hot():
    T = 0.6
    beam = env(sine_sweep(1400, 380, 0.35, 0.6), 0.12)
    hum = env(sine_sweep(180, 120, 0.5), 0.2)
    save('os_orb_hot', level(mix(at(beam, 0, T), at([v * 0.5 for v in hum], 0, T), at(glass([2093, 3136, 4186], 0.5, 0.15, 0.3), 0, T))))


def os_prime():
    save('os_prime', level(glass([1568, 2349], 0.35, 0.12, 0.3), 0.06))


def os_snap_wind():
    T = 0.3
    suck = ramp_in(env(sine_sweep(200, 900, 0.25, 1.4), 0.2), 1.5)
    save('os_snap_wind', level(mix(suck, at([v * 0.4 for v in ramp_in(lowpass(noise(0.25), 1500), 2.0)], 0, T)), 0.1))


def os_snap():
    T = 0.6
    shards = mix(*[at(tone(f, 0.3, 0.06, 0.4), dt, T) for f, dt in [(2489, 0.0), (3322, 0.015), (2793, 0.03), (3729, 0.045)]])
    whip = env(sine_sweep(2000, 300, 0.2, 0.5), 0.05)
    save('os_snap', level(mix(shards, at(whip, 0, T), at([v * 0.4 for v in hiss(0.2, 0.05, 4000)], 0, T)), 0.14))


def os_snap_hit():
    T = 0.8
    shatter = grains(T, 0.0, 0.3, 8.0, 3000, 6000, (0.008, 0.02))
    stun = glass([1319, 1661, 1976], 0.7, 0.25, 0.35)
    save('os_snap_hit', level(mix(shatter, at(stun, 0.05, T), at(env(sine_sweep(300, 90, 0.3), 0.1), 0, T)), 0.14))


def os_swap_lob():
    T = 0.8
    up = env(sine_sweep(300, 1200, 0.6, 1.2), 0.35)
    save('os_swap_lob', level(mix(at([v * 0.6 for v in up], 0, T), at(glass([1047, 1568], 0.7, 0.3, 0.25), 0.05, T)), 0.1))


def os_swap():
    T = 0.9
    pull = env(sine_sweep(1500, 120, 0.25, 0.4), 0.1)
    pop = env(lowpass(noise(0.15), 2200), 0.04)
    save('os_swap', level(mix(at(pull, 0, T), at(pop, 0.2, T), at(glass([784, 1175, 1568], 0.6, 0.25, 0.3), 0.22, T)), 0.14))


def os_seed():
    T = 0.7
    drop = env(sine_sweep(900, 300, 0.25, 0.7), 0.08)
    plop = env(sine_sweep(180, 80, 0.2), 0.06)
    hum = ramp_in(env(sine_sweep(110, 140, 0.5), 0.4), 1.0)
    save('os_seed', level(mix(at(drop, 0, T), at(plop, 0.22, T), at([v * 0.4 for v in hum], 0.25, T)), 0.11))


def os_full():
    T = 1.2
    col = ramp_in(glass([523, 784, 1047, 1568], 1.2, 0.8, 0.3), 1.0)
    save('os_full', level(col, 0.08))


def os_pop():
    T = 1.3
    rise = ramp_in(sine_sweep(200, 1400, 0.18, 1.6), 2.0)
    pull = env(sine_sweep(1100, 45, 0.45, 0.5), 0.2)
    sub = env(sine_sweep(60, 30, 0.7), 0.25)
    save('os_pop', level(mix(at([v * 0.4 for v in rise], 0, T), at(pull, 0.16, T), at([v * 1.1 for v in sub], 0.2, T), at(glass([1865, 2489, 3136], 0.7, 0.2, 0.25), 0.22, T)), 0.17))


def os_empower():
    T = 1.4
    sw = ramp_in(sine_sweep(150, 900, 0.6, 1.3), 1.4)
    chord = glass([659, 988, 1319, 1976], 0.9, 0.4, 0.3)
    save('os_empower', level(mix(at([v * 0.5 for v in sw], 0, T), at(chord, 0.55, T), at(env(lowpass(noise(0.4), 2500), 0.12), 0.55, T)), 0.13))


def br_spine():
    """Basalt Spine: a ground rumble swelling under the 0.2s cracks, then staggered rock cracks centre-out."""
    T = 1.3
    rumble = ramp_in(env(lowpass(noise(1.1), 220), 0.5), 0.6)
    sub = env(sine_sweep(40, 70, 0.9, 0.9), 0.4)
    parts = [at([v * 1.2 for v in rumble], 0, T), at(sub, 0.05, T), at(br_crack_hit(), 0.0, T)]
    for i in range(7):
        parts.append(at([v * (0.9 - i * 0.08) for v in br_crack_hit()], 0.2 + i * 0.065, T))
    save('br_spine', level(mix(*parts, grains(T, 0.2, 1.0, 2.0, 500, 2200, (0.02, 0.05))), 0.17))


def br_crack_hit():
    return env(highpass(lowpass(noise(0.14), rng.uniform(2600, 4200)), 400), 0.035)


def os_well():
    """Nightwell cast: a hand-thrust glass ping, then a suction whoosh rising over the 1.0s dome."""
    T = 1.15
    ping = glass([1175, 1760], 0.4, 0.15, 0.25)
    suck = ramp_in(env(lowpass(noise(1.05), 1600), 2.0), 2.2)
    rise = ramp_in(sine_sweep(120, 420, 1.0, 0.6), 1.8)
    save('os_well', level(mix(at(ping, 0, T), at([v * 0.8 for v in suck], 0.05, T), at([v * 0.4 for v in rise], 0.05, T)), 0.12))


def os_well_hum():
    """The open well: a low droning hum that beats slowly for 3.5s, then sinks away (no blast)."""
    T = 3.7
    a = sine_sweep(62, 58, 3.6, 0.5)
    b = sine_sweep(93, 87, 3.6, 0.35)
    drone = mix(a, b, env(lowpass(noise(3.6), 300), 2.5))
    wob = [v * (0.7 + 0.3 * math.sin(2 * math.pi * 1.6 * i / SR)) for i, v in enumerate(drone)]
    tail = [v * min(1.0, (len(wob) - i) / (0.5 * SR)) for i, v in enumerate(wob)]
    thump = env(sine_sweep(160, 55, 0.3), 0.08)
    save('os_well_hum', level(mix(at(thump, 0, T), at(tail, 0, T)), 0.11))


ALL = [br_throw, br_boulder_hit, br_wind, br_punch, br_launch, br_burst, br_rise, br_roll, br_shove, br_leap,
       br_slam, br_crack, br_raise, br_sense, os_orb, os_orb_hot, os_prime, os_snap_wind, os_snap, os_snap_hit,
       os_swap_lob, os_swap, os_seed, os_full, os_pop, os_empower, br_spine, os_well, os_well_hum]

if __name__ == '__main__':
    only = sys.argv[1:]          # names to write, or every sound
    done = [f for f in ALL if not only or f.__name__ in only]
    for f in done:
        f()
    print('wrote %d sounds: %s' % (len(done), ' '.join(f.__name__ for f in done)))
