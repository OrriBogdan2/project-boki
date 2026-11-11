"""Ultimate cast cues (docs/AUDIO.md, content/sfx/ult_cues.json): you hear an ultimate before you see it.

    python3 tools/gen_sfx_ult_cues.py      (then: godot --headless --import)

One body sound per Hunter, voiced to its element (<arch>_ult_cue: a rising swell that breaks into a hit), and two
short team tags played on top of it by UltCue: ult_tag_ally (a bright rising pair) and ult_tag_foe (a low falling
pair). Both tags sit at the same level, so a rival's ultimate is told apart by colour, never by being louder.
Original synthesis, no samples. Its own seed: running it re-rolls nothing else.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, sub, tail

S.reseed(7301)
DUR = 0.9       # s: swell 0.6 s, then the hit and its tail


def rise(f0, f1, d=0.6, curve=2.0):
    """A tone gliding up (or down) to the cue's hit, swelling in as it goes."""
    return S.sweep(f0, f1, d, curve=curve) * (np.arange(N(d)) / N(d)) ** 1.6


def air(lo0, hi0, lo1, hi1, d=0.6):
    """Noise through a band that sweeps up: wind, a jet, a suction."""
    n = N(d); out = np.zeros(n); k = n // 6
    for i in range(6):
        u = i / 5.0
        out[i * k:(i + 1) * k] = bpf(noise(d), lo0 + (lo1 - lo0) * u, hi0 + (hi1 - hi0) * u)[i * k:(i + 1) * k]
    return out * (np.arange(n) / n) ** 1.4


def hit(f, tone=None, decay=0.25):
    """The break at 0.6 s: a low thump and a soft tail, plus a ringing tone when the hero has one."""
    x = mix(kick(f, f * 0.4, 0.5, drop=0.06, decay=decay), tail(0.4, 1800, decay * 0.8))
    return mix(x, tone) if tone is not None else x


def body(parts, f, tone=None, decay=0.25):
    return mix(*parts, at(hit(f, tone, decay), 0.58))


def cue_archer():     # a drawn thread singing tight, then a high ping
    return body([rise(500, 1500, curve=3.0) * 0.5, air(2500, 5000, 5000, 9000) * 0.25], 140, S.chime(1760, 0.5, 0.3) * 0.6)

def cue_ashwick():    # a jet spooling up
    return body([air(300, 900, 900, 3200) * 1.0, rise(80, 260) * 0.6], 70, None, 0.4)

def cue_bulwark():    # the ground cracking along a lane
    return body([rise(45, 90) * 1.2, lpf(noise(0.6), 300) * (np.arange(N(0.6)) / N(0.6)) ** 2], 55, None, 0.35)

def cue_dolm():       # stone grinding, then a slab dropping
    return body([lpf(S.rattle(0.6, rate=18, lo=200, hi=900), 1200) * 0.9, rise(60, 120) * 0.8], 60, None, 0.3)

def cue_dredge():     # a brass bell swung heavy, then struck
    return body([rise(110, 220) * 0.6, air(400, 1200, 800, 2400) * 0.3], 90, S.fm(220, 1.41, 3.0, 0.8, 0.5) * 0.7)

def cue_gunslinger(): # a falling whistle, then the blast
    return body([S.sweep(2400, 380, 0.6, curve=1.5) * (0.3 + 0.7 * np.arange(N(0.6)) / N(0.6)) * 0.5], 50, None, 0.45)

def cue_juggernaut(): # steel drawn tight, then a ringing guard
    return body([rise(180, 360) * 0.5, air(1500, 4000, 3000, 7000) * 0.35], 100, S.chime(330, 0.8, 0.5) * 0.7)

def cue_mage():       # a charge climbing, crackling, then the clap
    return body([rise(200, 1800, curve=2.5) * 0.5, S.rattle(0.6, rate=70, lo=3000, hi=9000) * 0.3], 80, S.fm(900, 1.5, 6.0, 0.3, 0.1) * 0.4)

def cue_ostra():      # a suction hum drawn inward
    return body([rise(90, 180) * 0.8, air(200, 700, 700, 1800) * 0.7], 65, rise(180, 140, 0.4) * 0.5, 0.4)

def cue_rimewright(): # frost creeping, then a glass crack
    return body([S.sweep(3500, 1800, 0.6) * (np.arange(N(0.6)) / N(0.6)) ** 2 * 0.3, S.rattle(0.6, rate=45, lo=4000, hi=9000) * 0.3],
                120, S.chime(1320, 0.6, 0.35) * 0.7)

def cue_tender():     # a warm swell, a held breath of air, then a soft bloom
    return body([rise(160, 320) * 0.9, rise(240, 480) * 0.5, air(500, 1500, 800, 2600) * 0.15], 90, rise(320, 400, 0.4) * 0.5, 0.4)

def cue_thief():      # blades whirling up, a silver shimmer
    return body([air(3000, 7000, 5000, 10000) * 0.6, rise(700, 2400, curve=2.5) * 0.3], 150, S.chime(2100, 0.5, 0.25) * 0.6)


def tag(freqs, step):
    """Two soft notes `step` s apart (a rising pair for allies, a falling one for rivals)."""
    return mix(*[at(S.chime(f, 0.5, 0.3, ((1.0, 1.0), (2.0, 0.3))), step * i) for i, f in enumerate(freqs)])


def build():
    for arch, fn in sorted((k[4:], v) for k, v in globals().items() if k.startswith('cue_')):
        S.save_cat(arch + '_ult_cue', hpf(fn(), 30), 'signature')
    S.save_cat('ult_tag_ally', tag([784, 1175], 0.12), 'cast')     # G5 up to D6: open, bright
    S.save_cat('ult_tag_foe', tag([392, 277], 0.12), 'cast')       # G4 down to C#4: low, tense


if __name__ == '__main__':
    build()
