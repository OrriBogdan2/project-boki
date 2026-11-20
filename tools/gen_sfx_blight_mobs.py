"""The Blight mobs' wind-up voices (Mob._begin_attack plays "v_" + kind; content/sfx/blight_mobs.json). Run from
tools/. Before these the two Blight kinds wound up in silence (no v_bl_* file). Each is the plain kind's kind of
call, soured by the Blight: a ring-modulated, rasping voice, three takes each, our own synthesis.
  v_bl_skitter   a small, fast chittering hiss that rises, a sour metallic ring on it
  v_bl_warden    a low, wet growl that sinks, with a hollow ring under it
"""
import numpy as np
import sfx_lib as S
from sfx_lib import T, mix, at, bpf

S.reseed(2417)


def sour(x, f):
    """Ring-modulate a voice by a low tone: the Blight's metallic, hollow edge."""
    return x * (0.55 + 0.45 * np.sin(2 * np.pi * f * T(len(x) / S.SR)))


def bl_skitter(i):
    d = 0.32 + 0.04 * i
    call = S.voice(d, 520.0 + 40 * i, 760.0 + 30 * i, vowel='ah', breath=0.5, rasp=0.6, scale=1.25)
    chitter = bpf(S.noise(d), 2500, 7000) * S.shape(d, 0.02, 0.0, d * 0.8) * 0.25
    return mix(sour(call, 61.0 + 7 * i), at(chitter, 0.03))


def bl_warden(i):
    d = 0.75 + 0.08 * i
    growl = S.voice(d, 95.0 - 6 * i, 70.0 - 4 * i, vowel='oh', breath=0.35, rasp=0.9, vib=0.03, scale=0.8)
    ring = S.sweep(140.0, 105.0, d) * S.shape(d, 0.1, 0.2, d * 0.6) * 0.2
    return mix(sour(growl, 33.0 + 3 * i), ring)


def main():
    S.takes_cat('v_bl_skitter', bl_skitter, 3, 'grunt')
    S.takes_cat('v_bl_warden', bl_warden, 3, 'grunt')


if __name__ == '__main__':
    main()
