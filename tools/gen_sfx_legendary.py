"""Legendary Boki presence sounds (docs/AUDIO.md). Run from tools/.

  leg_roar        the shared roar every player hears when a legendary turns up (a low, long, wordless cry)
  leg_roar_<theme> the same roar with the species' theme in its timbre: titan (metal ring), swarm (a buzz),
                  tempest (a rushing shriek); a theme without one falls back to leg_roar
  leg_loop        the low presence loop within earshot of it (a slow sub swell with a breath of wind)
  leg_sting       the short sting when it is captured or defeated
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise

S.reseed(8113)
ROAR_D = 2.4


def roar_base(extra=None):
    """A big wordless cry: a falling voice with a growl, a sub under it and a long dark tail."""
    d = ROAR_D; n = N(d)
    cry = S.voice(d, 150, 78, 'ah', breath=0.2, rasp=0.5, vib=0.015, scale=0.7, a=0.12, decay=d * 0.6)
    low = S.sweep(64, 38, d) * S.shape(d, 0.15, d * 0.35, d * 0.5) * 0.7
    air = bpf(noise(d), 300, 1400) * S.shape(d, 0.2, d * 0.3, d * 0.5) * 0.18
    x = mix(cry, low, air, extra if extra is not None else np.zeros(n))
    return S.reflections(x, ((0.09, 0.3, 1400), (0.21, 0.2, 900), (0.38, 0.12, 700)))


def roar(i):
    return roar_base()


def roar_titan(i):
    """Stone and metal: a struck, ringing partial set over the cry."""
    ring = S.fm(180, 2.76, 2.0, ROAR_D, decay=1.1) * 0.35
    return roar_base(ring)


def roar_swarm(i):
    """A swarm's roar: the cry torn into a fast buzz."""
    n = N(ROAR_D); t = np.arange(n) / S.SR
    buzz = (0.55 + 0.45 * np.sin(2 * np.pi * 70 * t)) * bpf(noise(ROAR_D), 400, 2400) * S.shape(ROAR_D, 0.2, 0.9, 1.2)
    return roar_base(buzz * 0.5)


def roar_tempest(i):
    """A storm's roar: a rushing wind that swells and a rising shriek riding on the cry."""
    wind = bpf(noise(ROAR_D), 500, 3600) * S.shape(ROAR_D, 0.6, 0.6, 1.2) * 0.45
    shriek = S.sweep(420, 900, ROAR_D) * S.shape(ROAR_D, 0.5, 0.5, 1.4) * 0.18
    return roar_base(mix(wind, shriek))


def loop():
    """Four seconds of a slow sub swell (two beating tones) with a breath of wind, seamless."""
    d = 4.0; n = N(d); t = np.arange(n) / S.SR
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / d)
    tone = np.sin(2 * np.pi * 55 * t) + 0.8 * np.sin(2 * np.pi * 57 * t) + 0.25 * np.sin(2 * np.pi * 110 * t)
    wind = lpf(noise(d), 500) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / d + 1.0)) * 1.4
    return tone * swell * 0.5 + wind * 0.4


def sting(i):
    """It is gone: a low falling tone and a soft, short ring-out."""
    d = 1.1
    fall = S.sweep(150, 52, d) * S.shape(d, 0.01, 0.15, 0.9)
    ring = S.chime(330, d, 0.4, ((1.0, 0.6), (2.0, 0.25))) * 0.3
    return S.reflections(mix(fall, ring), ((0.07, 0.25, 1500), (0.16, 0.14, 900)))


def main():
    S.takes_cat('leg_roar', roar, 0, 'impact')
    S.takes_cat('leg_roar_titan', roar_titan, 0, 'impact')
    S.takes_cat('leg_roar_swarm', roar_swarm, 0, 'impact')
    S.takes_cat('leg_roar_tempest', roar_tempest, 0, 'impact')
    S.save_loop('leg_loop', loop(), 'loop')
    S.takes_cat('leg_sting', sting, 0, 'impact')


if __name__ == '__main__':
    main()
