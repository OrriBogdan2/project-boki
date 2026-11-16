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
  ways_tick         the last 10 s before a seat you can still reach shuts: one soft wooden tock with a glassy top,
                    once a second (HeartSfx plays the last 3 louder and a little higher); your own game only
The outpost uplinks (scripts/match/exits.gd), positional, the same crimson glass over an electric mast:
  uplink_start      the uplink is started: a mast clank and a rising electric whine
  uplink_steal      a rival squad takes the uplink over: a bright crackle on a glass ping
  uplink_fizzle     the charge runs dry: a falling, sputtering whine
  uplink_sputter    one flicker as it dies: a short dry crackle (pitched up flicker by flicker)
  uplink_shut       the uplink goes dark: a heavy shutter clunk with a low hum dying under it
  uplink_lift       the lift of light opens: a rising airy column and a bright chord
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


def ways_tick():
    tock = S.chime(1175.0, 0.16, 0.035, ((1.0, 1.0), (2.0, 0.25), (3.98, 0.08)))
    body = S.chime(392.0, 0.12, 0.03, ((1.0, 1.0), (1.5, 0.3)))
    return mix(tock * 0.8, body * 0.6)


def crackle(d, rate=55):
    return S.rattle(d, rate=rate, lo=2500, hi=9000, jitter=0.5, decay=d * 0.5)


def uplink_start():
    whine = S.sweep(180.0, 720.0, 0.9, curve=1.5) * S.shape(0.9, 0.6, 0.1, 0.2) * 0.4
    return mix(thump(80.0, 0.3, 0.05), at(whine, 0.05), at(crackle(0.5) * 0.35, 0.1))


def uplink_steal():
    return mix(crackle(0.12, 90) * 0.6, S.chime(1175.0, 0.35, 0.12, ((1.0, 1.0), (2.0, 0.3))) * 0.7)


def uplink_fizzle():
    d = 0.9
    whine = S.sweep(600.0, 140.0, d, curve=0.7) * S.shape(d, 0.0, 0.2, 0.7) * 0.5
    sputter = crackle(d, 24) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 9.0 * T(d))))
    return mix(whine, sputter * 0.4)


def uplink_sputter():
    return crackle(0.18, 70) * S.shape(0.18, 0.0, 0.03, 0.15)


def uplink_shut():
    hum = lpf(S.sweep(110.0, 55.0, 0.8), 400) * S.shape(0.8, 0.0, 0.1, 0.7) * 0.5
    return mix(thump(50.0, 0.45, 0.1) * 1.2, at(S.rattle(0.15, rate=60, lo=900, hi=4000) * 0.4, 0.02), hum)


def uplink_lift():
    d = 1.4
    column = bpf(S.noise(d), 400, 4000) * S.shape(d, 0.9, 0.1, 0.4) * 0.45
    chord = mix(*[at(S.chime(f, 1.0, 0.45), 0.25 + 0.06 * i) for i, f in enumerate((440.0, 554.0, 659.0, 880.0))])
    return mix(column, chord * 0.7)


def main():
    S.save_loop('heart_charge', charge(), 'loop')
    S.save_cat('heart_take', take(), 'signature')
    S.save_cat('heart_reveal', reveal(), 'cast')
    S.save_loop('heart_beat', beat(), 'loop')
    S.save_cat('heart_gate_open', gate_open(), 'cast')
    S.save_cat('heart_extract', extract(), 'cast')
    for name, make in (("ways_open", ways_open), ("ways_start", ways_start), ("ways_taken_own", ways_taken_own),
            ("ways_taken_other", ways_taken_other), ("ways_warn", ways_warn), ("ways_last", ways_last),
            ("ways_tick", ways_tick)):
        S.save_cat(name, make(), 'ui')
    for name, make in (("uplink_start", uplink_start), ("uplink_steal", uplink_steal), ("uplink_fizzle", uplink_fizzle),
            ("uplink_sputter", uplink_sputter), ("uplink_shut", uplink_shut), ("uplink_lift", uplink_lift)):
        S.save_cat(name, make(), 'cast')


if __name__ == '__main__':
    main()
