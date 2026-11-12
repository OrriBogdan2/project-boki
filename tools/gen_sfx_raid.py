"""Heart Raid's cues (docs/design/PVE_HEART_RAID.md; scripts/match/raid_sfx.gd). Run from tools/.

Ember colours: warm low tones, dry ticks, no bright bells (those are the Heart's and the Ways Out's).
  raid_gate_tick      a soft dry ember tick on a marked gate, once a second in the last 3 s (positional)
  raid_wave_open      the wave leaves its gates: a short rising horn-like swell over a low knock
  raid_boss_rise      the boss rises at the Heart: a sub swell, grinding stone and a heavy thump, then a falling chord
  raid_phase          the boss changes phase: a crack, a falling bell and a thump
  raid_rockfall_warn  the Nightmare boss starts a rockfall: a rising rumble and three pebble ticks
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf

S.reseed(2312)


def gate_tick():
    body = S.chime(330.0, 0.16, 0.05, ((1.0, 1.0), (2.0, 0.35)))
    return mix(body, S.click(0.004, 1800, 5000, 0.002) * 0.5)


def wave_open():
    d = 1.0
    horn = sum(S.sweep(f * 0.9, f, d) * S.shape(d, 0.3, 0.2, 0.5) for f in (110.0, 165.0, 220.0)) * 0.4
    grit = bpf(S.noise(d), 200, 1400) * S.shape(d, 0.35, 0.1, 0.5) * 0.25
    return mix(horn, grit, at(S.kick(120.0, 52.0, 0.3, drop=0.03, decay=0.08, drive=1.6), 0.0) * 0.8)


def boss_rise():
    d = 2.4
    swell = S.sweep(38.0, 58.0, d) * S.shape(d, 1.0, 0.5, 0.9)
    grind = lpf(S.noise(d), 500) * S.shape(d, 1.2, 0.4, 0.8) * 0.7
    hit = at(S.kick(130.0, 40.0, 0.6, drop=0.05, decay=0.18, drive=1.8), 1.0)
    chord = sum(S.sweep(f * 1.04, f, 1.4) * S.shape(1.4, 0.05, 0.1, 1.2) for f in (73.0, 110.0, 146.0)) * 0.4
    return mix(swell * 1.1, grind, hit * 1.2, at(chord, 1.0))


def phase():
    crack = S.crack(0.18, 800, 6000, 0.05)
    bell = S.chime(392.0, 0.9, 0.35, ((1.0, 1.0), (2.76, 0.4), (5.4, 0.15)))
    return mix(crack * 0.7, at(S.kick(110.0, 44.0, 0.4, drop=0.04, decay=0.1, drive=1.7), 0.02), at(bell * 0.7, 0.06))


def rockfall_warn():
    d = 1.3
    rumble = lpf(S.noise(d), 260) * S.shape(d, 1.0, 0.0, 0.3)
    ticks = mix(*[at(S.click(0.005, 900, 3500, 0.004), 0.55 + 0.2 * i) for i in range(3)])
    return mix(rumble * 0.9, S.pad(ticks, d) * 0.6)


def main():
    S.save_cat('raid_gate_tick', gate_tick(), 'cast')
    S.save_cat('raid_wave_open', wave_open(), 'cast')
    S.save_cat('raid_boss_rise', boss_rise(), 'signature')
    S.save_cat('raid_phase', phase(), 'impact')
    S.save_cat('raid_rockfall_warn', rockfall_warn(), 'cast')


if __name__ == '__main__':
    main()
