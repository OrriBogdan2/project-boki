"""The quest seats' own sounds (Limited Ways Out: the Sealed Lair and the Uplink; scripts/match/quest_sfx.gd).
Run from tools/. Own seed, so it re-rolls nothing else. Our own synthesis, cool blue-violet glass (the Heart is
warm crimson), so a quest cue never reads as a Heart one:
  quest_take        ui    your squad takes on a quest: a low knock under a rising open fifth
  quest_rival_rise  ui    a rival squad is past 75 % of its quest while yours is on one: a tense, rising
                          tremolo on a minor second that swells and stops short
  quest_win         ui    your squad finished its quest: a bright rising major run that rings
  quest_lose        ui    the quest your squad was on is lost: a muffled thud and a slow falling minor pair
  quest_site        loop  the active quest site's quiet hum (positional, carries 30 m)
"""
import numpy as np
import sfx_lib as S
from sfx_lib import T, mix, at, lpf, bpf

S.reseed(4721)


def knock(f0, d=0.3, decay=0.07):
    return S.kick(f0 * 1.8, f0, d, drop=0.03, decay=decay, drive=1.5)


def take():
    lift = bpf(S.noise(0.5), 600, 3000) * S.shape(0.5, 0.3, 0.0, 0.2) * 0.2
    return mix(knock(62.0) * 0.9, lift, at(S.chime(440.0, 0.9, 0.35), 0.06), at(S.chime(659.0, 1.0, 0.45), 0.2))


def rival_rise():
    d = 1.6
    t = T(d)
    trem = 0.55 + 0.45 * np.sin(2 * np.pi * (6.0 + 6.0 * t / d) * t)       # the flutter quickens as it climbs
    pair = (S.sweep(330.0, 494.0, d, curve=1.6) + 0.8 * S.sweep(349.0, 523.0, d, curve=1.6)) * trem
    swell = S.shape(d, 1.35, 0.15, 0.1)
    grit = bpf(S.noise(d), 1500, 5000) * swell * 0.12
    return mix(pair * swell * 0.5, grit, at(knock(58.0, 0.25, 0.05) * 0.5, d - 0.12))


def win():
    run = mix(*[at(S.chime(f, 1.0, 0.45), 0.08 * i) for i, f in enumerate((587.0, 740.0, 880.0, 1175.0))])
    return mix(run * 0.8, at(S.chime(1480.0, 1.2, 0.6) * 0.4, 0.32))


def lose():
    thud = lpf(knock(50.0, 0.45, 0.1), 900)
    pair = mix(at(S.chime(494.0, 1.0, 0.45), 0.1), at(S.chime(415.0, 1.2, 0.55), 0.42))
    return mix(thud * 1.1, pair * 0.7)


def site():
    d = 3.0                                # whole cycles in 3 s, so the loop is seamless
    t = T(d)
    hum = sum(g * np.sin(2 * np.pi * f * t) for f, g in [(98.0, 1.0), (147.0, 0.5), (196.0, 0.3), (293.0, 0.12)])
    breathe = 0.8 + 0.2 * np.sin(2 * np.pi * (1.0 / 3.0) * t)
    glint = 0.08 * np.sin(2 * np.pi * 587.0 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * (2.0 / 3.0) * t))
    return (hum + glint) * breathe


def main():
    S.save_cat('quest_take', take(), 'ui')
    S.save_cat('quest_rival_rise', rival_rise(), 'ui')
    S.save_cat('quest_win', win(), 'ui')
    S.save_cat('quest_lose', lose(), 'ui')
    S.save_loop('quest_site', site(), 'loop')


if __name__ == '__main__':
    main()
