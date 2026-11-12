"""The Heartspark's sounds (docs/decisions/0023-heartspark.md; scripts/match/heart_sfx.gd). Run from tools/.

One cue per beat of the Heart loop, all warm crimson glass, our own synthesis:
  heart_charge    loop    a glassy hum on a low fifth with a slow swell; HeartSfx lifts its pitch as the charge
                          fills (the rising hum), placed at the Heart and carrying 70 m
  heart_take      sting   for the one who took it: a heart thump under a rising bell pair
  heart_reveal    sting   for everyone else, map-wide: two falling, hollow pings (somebody is now marked)
  heart_beat      loop    the carrier's own heartbeat (lub-dub), heard by the carrier only
  heart_gate_open sound   the Heart Gate waking: a rising breath and a held chord, positional
  heart_extract   sound   the carrier leaves: a bright rising arpeggio and a whoosh, positional
The Ways Out calls (HeartSfx.call_out), one flat UI sting each, heard by everyone, never positional:
  ways_open         a seat opens: two rising bells a fifth apart over a short airy lift
  ways_start        a squad starts a seat: two low knocks and a falling bell
  ways_taken_own    your squad left: a warm rising major arpeggio
  ways_taken_other  another squad left: one door-shut thud and a falling minor bell pair
  ways_warn         a seat shuts in 30 s: three dry ticks on one pitch
  ways_last         the last way out: a low swell under two bells a semitone apart
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf

S.reseed(2311)


def charge():
    d = 2.0; t = T(d)                      # whole cycles in 2 s, so the loop is seamless
    hum = sum(g * np.sin(2 * np.pi * f * t) for f, g in [(110.0, 1.0), (165.0, 0.7), (220.5, 0.45), (330.0, 0.2)])
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * 1.0 * t)
    shimmer = 0.18 * np.sin(2 * np.pi * 660.0 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.0 * t))
    return (hum + shimmer) * swell


def thump(f0, d=0.3, decay=0.08):
    return S.kick(f0 * 1.9, f0, d, drop=0.03, decay=decay, drive=1.6)


def take():
    low = thump(52.0, 0.5, 0.12)
    bells = mix(at(S.chime(523.0, 0.9, 0.4), 0.05), at(S.chime(784.0, 1.0, 0.5), 0.2))
    return mix(low * 1.2, bells * 0.7)


def reveal():
    a = S.chime(880.0, 0.7, 0.25, ((1.0, 1.0), (2.0, 0.4), (3.01, 0.15)))
    b = S.chime(659.0, 0.9, 0.3, ((1.0, 1.0), (2.0, 0.4), (3.01, 0.15)))
    return mix(a, at(b, 0.22), at(thump(70.0, 0.3, 0.06) * 0.6, 0.0))


def beat():
    one = mix(thump(48.0, 0.28), at(thump(60.0, 0.24) * 0.7, 0.17))
    bed = lpf(S.noise(0.85), 140) * 0.35      # a low body wash under the beats, so the loop never drops to silence
    return S.pad(one, 0.85) + bed


def gate_open():
    d = 1.3
    breath = bpf(S.noise(d), 300, 2400) * S.shape(d, 0.7, 0.0, 0.6) * 0.5
    chord = sum(S.sweep(f * 0.9, f, d) * S.shape(d, 0.5, 0.2, 0.6) for f in (196.0, 294.0, 392.0)) * 0.35
    return mix(breath, chord, at(S.chime(784.0, 0.9, 0.4) * 0.5, 0.55))


def extract():
    d = 1.5
    arp = mix(*[at(S.chime(f, 0.9, 0.35), 0.1 * i) for i, f in enumerate((392.0, 523.0, 659.0, 784.0))])
    whoosh = bpf(S.noise(d), 500, 5000) * S.shape(d, 0.5, 0.0, 0.9) * 0.45
    return mix(arp * 0.8, whoosh)


def ways_open():
    lift = bpf(S.noise(0.6), 800, 3500) * S.shape(0.6, 0.4, 0.0, 0.2) * 0.25
    return mix(lift, S.chime(659.0, 0.9, 0.4), at(S.chime(988.0, 1.0, 0.5), 0.18))


def ways_start():
    knocks = mix(thump(70.0, 0.25, 0.06), at(thump(70.0, 0.25, 0.06) * 0.8, 0.22))
    return mix(knocks * 0.9, at(S.chime(587.0, 0.9, 0.35), 0.3), at(S.chime(440.0, 1.0, 0.4), 0.5))


def ways_taken_own():
    return mix(*[at(S.chime(f, 0.9, 0.4), 0.09 * i) for i, f in enumerate((523.0, 659.0, 784.0, 1047.0))])


def ways_taken_other():
    return mix(thump(55.0, 0.4, 0.09) * 1.1, at(S.chime(554.0, 0.9, 0.35), 0.12), at(S.chime(415.0, 1.0, 0.45), 0.34))


def ways_warn():
    tick = S.chime(880.0, 0.18, 0.06, ((1.0, 1.0), (2.0, 0.3)))
    return mix(*[at(tick, 0.2 * i) for i in range(3)])


def ways_last():
    d = 1.6
    swell = sum(S.sweep(f * 0.95, f, d) * S.shape(d, 0.8, 0.2, 0.6) for f in (98.0, 147.0)) * 0.5
    return mix(swell, at(S.chime(698.0, 1.2, 0.5), 0.5), at(S.chime(740.0, 1.1, 0.5), 0.55))


def main():
    S.save_loop('heart_charge', charge(), 'loop')
    S.save_cat('heart_take', take(), 'signature')
    S.save_cat('heart_reveal', reveal(), 'cast')
    S.save_loop('heart_beat', beat(), 'loop')
    S.save_cat('heart_gate_open', gate_open(), 'cast')
    S.save_cat('heart_extract', extract(), 'cast')
    for name, make in (("ways_open", ways_open), ("ways_start", ways_start), ("ways_taken_own", ways_taken_own),
            ("ways_taken_other", ways_taken_other), ("ways_warn", ways_warn), ("ways_last", ways_last)):
        S.save_cat(name, make(), 'ui')


if __name__ == '__main__':
    main()
