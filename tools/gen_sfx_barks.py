"""Hunter callouts (docs/AUDIO.md "Hunter callouts", content/sfx/barks.json): short wordless barks in each
Hunter's own voice, played by HunterBarks.

    python3 tools/gen_sfx_barks.py      (then: godot --headless --import)

Four barks per Hunter, four takes each (<arch>_call_<kind>.wav + _1.._3):
  ult    your ultimate is back: a short syllable, then a higher held one (eager, ready)
  boki   your Boki went down: a two-note alarm call, higher than any other line (your squad hears it too)
  low    you are low on health: a strained, breathy groan, lower and rougher than the hurt line
  knock  you knocked a rival: one sharp, bright "hah", sometimes with a short tag

Every Hunter's voice is the one its own sound script gives its hurt line (pitch, body, breath, rasp); the
profiles below copy those numbers. Original synthesis, no samples, no words. Its own seed: running it re-rolls
nothing else.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, hpf, env, mix, at, pad

S.reseed(6061)

# f0: speaking pitch (Hz); scale: formant shift (body size); breath, rasp, vib: as S.voice; cut: low-pass (Hz);
# double: a second voice a few cents up at this gain (Neve's floating siren voice). From each hurt() line.
VOICES = {
    'archer':     dict(f0=255, scale=1.12, breath=0.45, rasp=0.08, vib=0.0, cut=5500),           # Lace
    'ashwick':    dict(f0=335, scale=1.16, breath=0.3, rasp=0.18, vib=0.0, cut=6000),            # Cinder
    'bulwark':    dict(f0=112, scale=0.8, breath=0.3, rasp=0.4, vib=0.0, cut=4000),              # Albert
    'dolm':       dict(f0=175, scale=0.93, breath=0.2, rasp=0.3, vib=0.0, cut=4500),             # Tenzo
    'dredge':     dict(f0=215, scale=1.06, breath=0.65, rasp=0.75, vib=0.01, cut=5000),          # Grimble
    'gunslinger': dict(f0=245, scale=1.12, breath=0.3, rasp=0.18, vib=0.0, cut=5500),            # Vex
    'juggernaut': dict(f0=135, scale=0.84, breath=0.15, rasp=0.45, vib=0.0, cut=4500),           # Kael
    'mage':       dict(f0=330, scale=1.2, breath=0.3, rasp=0.15, vib=0.0, cut=6000),             # Sparkle
    'ostra':      dict(f0=210, scale=1.0, breath=0.4, rasp=0.2, vib=0.0, cut=4500),              # Motley
    'rimewright': dict(f0=540, scale=1.2, breath=0.55, rasp=0.0, vib=0.015, cut=7000, double=0.45),  # Neve
    'tender':     dict(f0=620, scale=1.38, breath=0.35, rasp=0.0, vib=0.006, cut=7500),          # Meeko
    'thief':      dict(f0=370, scale=1.13, breath=0.18, rasp=0.12, vib=0.0, cut=6000),           # Sable
}
TAKES = 3       # name.wav + name_1..3.wav: four takes per bark


def syl(v, d, k0, k1, vowel, breath=0.0, rasp=0.0, a=0.01):
    """One syllable in voice v, gliding from k0 to k1 times its speaking pitch, its tail eased out."""
    f0 = v['f0']
    x = S.voice(d, f0 * k0, f0 * k1, vowel, breath=min(1.0, v['breath'] + breath), rasp=min(1.0, v['rasp'] + rasp),
                vib=v['vib'], scale=v['scale'], a=a, decay=d * 0.5)
    if v.get('double'):
        x = x + v['double'] * S.voice(d, f0 * k0 * 1.006, f0 * k1 * 1.006, vowel, breath=v['breath'] * 0.6,
                                      vib=v['vib'], scale=v['scale'] * 1.02, a=a, decay=d * 0.5)
    return lpf(x * S.shape(d, 0.0, d * 0.6, d * 0.4), v['cut'])


def call_ult(v, i):
    vow = (('uh', 'ah'), ('eh', 'ah'), ('uh', 'eh'), ('oh', 'ah'))[i]
    lift = 1.0 + 0.04 * i
    return pad(mix(syl(v, 0.09, 1.0, 1.04, vow[0]), at(syl(v, 0.2, 1.2 * lift, 1.3 * lift, vow[1]), 0.11)), 0.4)


def call_boki(v, i):
    vow = (('oh', 'eh'), ('ah', 'eh'), ('oh', 'ah'), ('eh', 'oh'))[i]
    hi = 1.45 + 0.05 * (i % 2)
    a = syl(v, 0.12, 1.3, 1.35, vow[0], rasp=0.05)
    b = syl(v, 0.22, hi, hi * 0.78, vow[1], rasp=0.05)
    return pad(mix(a, at(b, 0.15)), 0.45)


def call_low(v, i):
    vow = ('uh', 'oh', 'ah', 'uh')[i]
    d = 0.32 + 0.03 * (i % 2)
    groan = syl(v, d, 0.95, 0.78, vow, breath=0.3, rasp=0.15, a=0.03)
    exhale = lpf(hpf(noise(0.2), 900), 5000) * env(N(0.2), 0.02, 0.07) * 0.12
    return pad(mix(groan, at(exhale, d * 0.7)), 0.5)


def call_knock(v, i):
    vow = ('ah', 'eh', 'ah', 'uh')[i]
    hah = syl(v, 0.14 + 0.02 * (i % 2), 1.25, 0.95, vow, a=0.005)
    if i % 2:
        hah = mix(hah, at(syl(v, 0.08, 1.15, 1.25, 'eh') * 0.6, 0.18))
    return pad(hah, 0.32)


KINDS = {'ult': call_ult, 'boki': call_boki, 'low': call_low, 'knock': call_knock}

if __name__ == '__main__':
    for arch, v in VOICES.items():
        for kind, fn in KINDS.items():
            S.takes_cat('%s_call_%s' % (arch, kind), lambda i, fn=fn, v=v: fn(v, i), TAKES, 'grunt')
    print('wrote %d barks' % (len(VOICES) * len(KINDS)))
