"""Fusion and evolution sounds (docs/AUDIO.md): every Fusion is an event. Run from tools/.

  boki_fuse_<type>   enter: one shared body (a rising spiral, a warm swell, a bright pop and a bell) under a
                     top layer per type (the 18 types), so each Fusion is the same event with its own colour
  boki_fuse_end      release: the Boki lets go, a soft chord and a long sparkling afterglow tail
  boki_fuse_tired    the Fusion timed out: a sagging sigh, a dull low bell, no sparkle
  boki_evolve        a Boki evolves: a gentle rising run into a long warm bell, never a blast
  boki_form_<form>_cast | _travel | _hit
                     a Fusion form's own ultimate cast, its form dash and where its moves land, for the three
                     forms in content/merge_forms (titan: stone and gravity, stormwing: wind and lightning,
                     tidal_shell: water and crystal); the form file's sound block names them, MergeSfx plays them
Each is one file. The cue name for a Fusion comes from content/rules/merge_forms.json (types[].cue) or the
form file (sound.cue); MergeXform plays it.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise
from gen_sfx_boki import squeak, vowel, soft, room, bubble

S.reseed(7731)
BODY_D = 0.9          # s: the shared body; the pop and bell land at POP_T (the contact of the transformation)
POP_T = 0.5


def body():
    n = N(BODY_D); u = np.arange(n) / n
    spiral = S.sweep(300, 1500, BODY_D, curve=1.6) * np.sin(np.pi * u ** 0.6) * 0.45
    swell = S.sweep(180, 330, BODY_D) * np.sin(np.pi * u ** 1.2) * 0.4
    grain = S.grains(BODY_D, 70, 3000, 8000, 0.002, 0.005, fall=0.4) * 0.22 * u
    bell = at(mix(S.chime(784, 1.0, 0.45, ((1.0, 1.0), (2.76, 0.25))), S.chime(1175, 1.0, 0.45, ((1.0, 0.6),))) * 0.35, POP_T)
    pop = at(bubble(420, 0.1, 2.2) * 0.5, POP_T - 0.02)
    return mix(spiral, swell, grain, bell, pop)


def chimes(notes, step, d=0.9, decay=0.4, g=0.3, partials=((1.0, 1.0), (2.76, 0.3))):
    return mix(*[at(S.chime(f, d, decay, partials) * g, step * k) for k, f in enumerate(notes)])


# ---------------------------------------------------------------- the 18 tops (each starts at 0 and sits near POP_T)
def t_normal():
    return at(chimes([523, 784], 0.07, 1.0, 0.45, 0.3), POP_T - 0.03)


def t_fire():
    crack = S.grains(0.7, 80, 1500, 6000, 0.001, 0.004, fall=0.3) * 0.4
    whoomp = lpf(noise(0.6), 700) * env(N(0.6), 0.15, 0.3) * 0.6
    return mix(at(crack, POP_T - 0.1), at(whoomp, POP_T - 0.15))


def t_water():
    return at(mix(*[at(bubble(300 * (1 + 0.3 * k), 0.09, 1.9) * 0.6, 0.07 * k) for k in range(5)],
                  chimes([880, 1175], 0.12, 0.7, 0.3, 0.25)), POP_T - 0.2)


def t_grass():
    rustle = bpf(noise(0.5), 2500, 6500) * env(N(0.5), 0.12, 0.2) * 0.3
    pluck = chimes([392, 494, 587], 0.08, 0.5, 0.15, 0.4, ((1.0, 1.0), (2.0, 0.4), (3.0, 0.15)))
    return mix(at(rustle, POP_T - 0.25), at(pluck, POP_T - 0.05))


def t_spore():
    puffs = [at(bpf(noise(0.2), 250, 1600) * env(N(0.2), 0.02, 0.06) * g, dl) for dl, g in ((0.0, 0.8), (0.1, 0.5), (0.2, 0.3))]
    fall = chimes([1318, 1175, 988], 0.1, 0.6, 0.2, 0.2, ((1.0, 0.5),))
    return at(mix(*puffs, at(fall, 0.1)), POP_T - 0.05)


def t_electric():
    zap = S.fm(900, 3.0, 5.0, 0.25, 0.08) * 0.35
    snap = S.crack(0.1, 1500, 7000, 0.01) * 0.5
    return mix(at(zap, POP_T - 0.12), at(snap, POP_T), at(S.crack(0.07, 2000, 8000, 0.01) * 0.3, POP_T + 0.12))


def t_ice():
    tinkle = chimes([2093, 2637, 3136, 2349], 0.06, 0.8, 0.25, 0.22, ((1.0, 1.0), (3.1, 0.3)))
    air = bpf(noise(0.6), 5000, 9000) * env(N(0.6), 0.1, 0.25) * 0.12
    return at(mix(tinkle, air), POP_T - 0.12)


def t_rock():
    thud = S.kick(110, 50, 0.3, 0.01, 0.1, 1.6) * 0.8
    gravel = bpf(noise(0.3), 300, 2200) * env(N(0.3), 0.004, 0.1) * 0.35
    return at(mix(thud, gravel), POP_T - 0.02)


def t_psychic():
    d = 0.9; n = N(d); u = np.arange(n) / n
    a = S.sweep(500, 700, d) * np.sin(np.pi * u)
    b = S.sweep(507, 710, d) * np.sin(np.pi * u)
    wob = (0.6 + 0.4 * np.sin(2 * np.pi * 5 * u * d))
    return at(mix(a, b) * wob * 0.3, POP_T - 0.3)


def t_flying():
    d = 0.7; n = N(d); u = np.arange(n) / n
    wind = bpf(noise(d), 600, 3500) * np.sin(np.pi * u) ** 1.5 * 0.5
    lift = S.sweep(600, 1400, d) * np.sin(np.pi * u) * 0.18
    return at(mix(wind, lift), POP_T - 0.35)


def t_dragon():
    growl = S.voice(0.6, 95, 75, 'ah', breath=0.1, rasp=0.15, vib=0.03, scale=0.9, a=0.05, decay=0.3) * 0.55
    sub = S.sweep(90, 55, 0.5) * env(N(0.5), 0.02, 0.2) * 0.5
    gleam = at(S.chime(1568, 0.8, 0.4, ((1.0, 0.6),)) * 0.2, 0.1)
    return at(mix(growl, sub, gleam), POP_T - 0.1)


def t_dark():
    d = 0.9; n = N(d); u = np.arange(n) / n
    drone = S.sweep(220, 110, d) * np.sin(np.pi * u) ** 1.3 * 0.5
    smoke = lpf(noise(d), 800) * np.sin(np.pi * u) ** 2 * 0.4
    return at(mix(drone, smoke), POP_T - 0.35)


def t_poison():
    bubs = [at(bubble(190 * (1 + 0.3 * k), 0.09, 1.8) * 0.7, 0.06 * k) for k in range(5)]
    hiss = bpf(noise(0.5), 3000, 7000) * env(N(0.5), 0.1, 0.2) * 0.14
    return at(mix(*bubs, hiss), POP_T - 0.15)


def t_bug():
    trill = [at(squeak(1700 + 120 * k, 0.04, 0.05, 0.0, a=0.002) * 0.4, 0.045 * k) for k in range(9)]
    hum = S.sweep(180, 200, 0.4) * env(N(0.4), 0.05, 0.2) * 0.2 * (0.6 + 0.4 * np.sin(2 * np.pi * 40 * np.arange(N(0.4)) / S.SR))
    return at(mix(*trill, hum), POP_T - 0.15)


def t_steel():
    ring = S.chime(660, 1.0, 0.5, ((1.0, 1.0), (2.32, 0.6), (4.16, 0.4), (6.7, 0.2)))
    clink = S.crack(0.05, 2500, 8000, 0.006) * 0.4
    return at(mix(ring * 0.4, clink), POP_T - 0.02)


def t_fairy():
    notes = [1568, 1976, 2349, 2637, 3136]
    return at(mix(chimes(notes, 0.06, 0.8, 0.35, 0.2, ((1.0, 1.0), (2.0, 0.3))),
                  S.grains(0.6, 60, 5000, 9500, 0.001, 0.003, fall=0.25) * 0.2), POP_T - 0.15)


def t_crystal():
    bells = [S.chime(f, 0.9, 0.35, ((1.0, 1.0), (2.76, 0.4), (5.4, 0.2))) * (0.9 - 0.12 * k) * 0.3
             for k, f in enumerate([784, 988, 1175, 1568])]
    return at(mix(*[at(b, 0.05 * k) for k, b in enumerate(bells)]), POP_T - 0.12)


def t_sound():
    base = mix(S.chime(660, 0.3, 0.12, ((1.0, 1.0), (2.0, 0.3))), S.kick(140, 70, 0.2, 0.01, 0.05, 1.5) * 0.4)
    out = np.zeros(0)
    cut = 3600
    for k in range(5):
        out = mix(out, at(lpf(base, cut) * 0.65 ** k, 0.13 * k))
        cut *= 0.72
    return at(out * 0.7, POP_T - 0.02)


TOPS = {'normal': t_normal, 'fire': t_fire, 'water': t_water, 'grass': t_grass, 'spore': t_spore, 'electric': t_electric,
        'ice': t_ice, 'rock': t_rock, 'psychic': t_psychic, 'flying': t_flying, 'dragon': t_dragon, 'dark': t_dark,
        'poison': t_poison, 'bug': t_bug, 'steel': t_steel, 'fairy': t_fairy, 'crystal': t_crystal, 'sound': t_sound}


def fuse(kind):
    return lambda i: soft(room(mix(body(), TOPS[kind]()), 0.8), 6000)


# ---------------------------------------------------------------- the ends and the evolution
def fuse_end(i):
    """Let go: a small downward pop, a warm major chord that blooms, then a long sparkle that thins out."""
    pop = mix(bubble(500, 0.08, 1.8) * 0.6, squeak(880, 0.12, -0.1) * 0.35)
    chord = chimes([523, 659, 784], 0.04, 1.8, 0.9, 0.3, ((1.0, 1.0), (2.0, 0.25)))
    glow = S.grains(1.8, 40, 3500, 9000, 0.002, 0.006, fall=0.8) * 0.2
    tail_s = S.sweep(1568, 1175, 1.6) * env(N(1.6), 0.2, 0.9) * 0.08
    return soft(room(mix(pop, at(chord, 0.05), at(glow, 0.1), at(tail_s, 0.2)), 1.0), 5500)


def fuse_tired(i):
    """Out of time: a heavy sigh that sags, a dull low bell and one slow breath. No sparkle."""
    d = 0.9
    sigh = vowel(300, 170, d, 'uh', 1.25, 0.3) * 0.6
    sag = S.sweep(520, 230, d) * env(N(d), 0.02, 0.5) * 0.35
    bell = at(S.chime(262, 1.0, 0.7, ((1.0, 1.0), (2.0, 0.2))) * 0.35, 0.05)
    breath = at(bpf(noise(0.5), 300, 1400) * env(N(0.5), 0.12, 0.25) * 0.3, 0.45)
    return soft(room(mix(sigh, sag, bell, breath), 0.4), 2600)


def evolve(i):
    """Growing up: a gentle rising pentatonic run, a shimmer that lifts and one long warm bell. No hit."""
    notes = [392, 494, 587, 784, 988, 1175]
    run = [at(mix(squeak(f, 0.3, 0.03, 0.01, tail_d=0.15) * 0.4, S.chime(f, 0.9, 0.4, ((1.0, 0.7), (2.0, 0.2))) * 0.4), 0.15 * k)
           for k, f in enumerate(notes)]
    d = 1.3; n = N(d); u = np.arange(n) / n
    lift = S.sweep(300, 900, d, curve=1.4) * np.sin(np.pi * u ** 0.7) * 0.2
    shimmer = S.grains(d, 50, 3500, 9000, 0.002, 0.005, fall=0.3) * 0.2 * np.sin(np.pi * u)
    bell = at(mix(S.chime(784, 1.8, 0.8, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1))), S.chime(1568, 1.8, 0.8, ((1.0, 0.4),))) * 0.4, 0.8)
    return soft(room(mix(*run, lift, shimmer, bell), 1.0), 5200)


# ---------------------------------------------------------------- the forms' own moves (cast, travel, hit)
def titan_cast(i):
    """Heavy Star gathers itself: a sub that sinks while a gravity hum climbs, grit pulled inward, a star glint."""
    d = 0.8; n = N(d); u = np.arange(n) / n
    hum = S.sweep(70, 140, d, curve=1.5) * np.sin(np.pi * u ** 0.5) * 0.6
    sink = S.sub(90, 45, d, 0.5) * 0.5
    grit = bpf(noise(d), 250, 1800) * u ** 2 * 0.25
    glint = at(S.chime(988, 0.5, 0.25, ((1.0, 1.0), (2.76, 0.3))) * 0.2, 0.55)
    return soft(room(mix(hum, sink, grit, glint), 0.5), 4500)


def titan_travel(i):
    """The armoured charge: a low stone rumble that rolls past, with gravel kicked up."""
    d = 0.5; n = N(d); u = np.arange(n) / n
    rumble = lpf(noise(d), 260) * np.sin(np.pi * u) ** 0.8 * 0.9
    body = S.sweep(85, 60, d) * np.sin(np.pi * u) * 0.35
    gravel = bpf(noise(d), 600, 3000) * env(n, 0.05, 0.25) * 0.2
    return soft(mix(rumble, body, gravel), 3000)


def titan_hit(i):
    """The crater: a heavy thud with a sub drop, rock breaking apart and a dull star ring under the dust."""
    thud = S.kick(120, 38, 0.7, 0.04, 0.25, 2.2) * 0.9
    crunch = S.crack(0.25, 300, 2600, 0.07) * 0.5
    debris = at(S.grains(0.6, 60, 700, 3500, 0.003, 0.009, fall=0.25) * 0.3, 0.04)
    star = at(S.chime(330, 0.9, 0.5, ((1.0, 1.0), (2.32, 0.4))) * 0.18, 0.02)
    return soft(room(mix(thud, crunch, debris, star), 0.6), 5000)


def stormwing_cast(i):
    """Stormwing calls the storm: wind that swells upward, crackle building in it, a thunder roll far off."""
    d = 0.9; n = N(d); u = np.arange(n) / n
    wind = bpf(noise(d), 500, 3000) * np.sin(np.pi * u ** 0.7) * 0.5
    lift = S.sweep(400, 1200, d, curve=1.3) * np.sin(np.pi * u) * 0.12
    crackle = S.grains(d, 50, 2500, 8000, 0.001, 0.003) * u ** 1.5 * 0.35
    roll = lpf(noise(d), 180) * np.sin(np.pi * u) ** 2 * 0.5
    return soft(room(mix(wind, lift, crackle, roll), 0.6), 7000)


def stormwing_travel(i):
    """Lightning Blink: a fast bright whoosh with an electric buzz riding it, a snap at the start."""
    d = 0.4; n = N(d); u = np.arange(n) / n
    rush = bpf(noise(d), 1200, 6000) * np.sin(np.pi * u ** 0.6) * 0.5
    buzz = S.fm(320, 3.0, 4.0, d, 0.2) * np.sin(np.pi * u) * 0.25
    snap = S.crack(0.05, 3000, 9000, 0.008) * 0.5
    return soft(mix(rush, buzz, snap), 8000)


def stormwing_hit(i):
    """The strike: a sharp crack, a second split crack and the thunder rolling out after it."""
    crack1 = S.crack(0.08, 1800, 9000, 0.012) * 0.9
    crack2 = at(S.crack(0.06, 1200, 7000, 0.01) * 0.5, 0.035)
    boom = S.kick(90, 40, 0.5, 0.02, 0.15, 1.8) * 0.5
    thunder = at(lpf(noise(0.9), 300) * env(N(0.9), 0.04, 0.4) * 0.6, 0.03)
    return soft(room(mix(crack1, crack2, boom, thunder), 0.5), 8500)


def tidal_shell_cast(i):
    """The shell gathers: water swirling in, glassy notes rising, the shell creaking under the pressure."""
    d = 0.8; n = N(d); u = np.arange(n) / n
    swirl = bpf(noise(d), 300, 1500) * np.sin(np.pi * u ** 0.8) * 0.4 * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * u * d))
    rise = chimes([784, 988, 1175, 1568], 0.12, 0.6, 0.25, 0.22, ((1.0, 1.0), (2.76, 0.35)))
    bubs = mix(*[at(bubble(260 * (1 + 0.25 * k), 0.08, 1.8) * 0.4, 0.09 * k) for k in range(4)])
    return soft(room(mix(swirl, at(rise, 0.2), bubs), 0.7), 6500)


def tidal_shell_travel(i):
    """Mirror Step: a liquid swish with a glassy shimmer across it."""
    d = 0.45; n = N(d); u = np.arange(n) / n
    swish = bpf(noise(d), 700, 3500) * np.sin(np.pi * u ** 0.7) * 0.45
    shimmer = S.sweep(1800, 2600, d) * np.sin(np.pi * u) ** 2 * 0.1
    drip = at(bubble(520, 0.07, 2.0) * 0.4, 0.05)
    return soft(mix(swish, shimmer, drip), 7000)


def tidal_shell_hit(i):
    """Shatter: crystal breaking into many pieces over a splash, a cold ring left after."""
    knock = S.kick(200, 90, 0.25, 0.01, 0.06, 1.6) * 0.5
    glass = S.grains(0.6, 140, 3000, 9500, 0.001, 0.004, fall=0.18) * 0.55
    splash = bpf(noise(0.5), 500, 4000) * env(N(0.5), 0.005, 0.15) * 0.4
    ring = at(S.chime(1318, 0.9, 0.45, ((1.0, 1.0), (2.76, 0.4), (5.4, 0.2))) * 0.2, 0.02)
    return soft(room(mix(knock, glass, splash, ring), 0.6), 8000)


# (cast: the ultimate starting; travel: the form dash; hit: what the form's moves land, its category)
FORM_SOUNDS = {'titan': (titan_cast, titan_travel, titan_hit, 'heavy_impact'),
               'stormwing': (stormwing_cast, stormwing_travel, stormwing_hit, 'impact'),
               'tidal_shell': (tidal_shell_cast, tidal_shell_travel, tidal_shell_hit, 'impact')}


def main():
    for kind in TOPS:
        S.takes_cat('boki_fuse_' + kind, fuse(kind), 0, 'boki')
    S.takes_cat('boki_fuse_end', fuse_end, 0, 'boki')
    S.takes_cat('boki_fuse_tired', fuse_tired, 0, 'boki')
    S.takes_cat('boki_evolve', evolve, 0, 'boki')
    for form, (cast, travel, hit, hit_cat) in FORM_SOUNDS.items():
        S.takes_cat('boki_form_%s_cast' % form, cast, 0, 'cast')
        S.takes_cat('boki_form_%s_travel' % form, travel, 0, 'dash')
        S.takes_cat('boki_form_%s_hit' % form, hit, 0, hit_cat)


if __name__ == '__main__':
    main()
