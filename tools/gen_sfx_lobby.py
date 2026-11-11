"""The pre-match lobby's sounds (docs/AUDIO.md): a pick, a teammate locking in, the last-seconds ticks, and
twelve lock-in stings, one per Hunter, about 0.6 s, each in the mood of that Hunter's ability colour.
Run from tools/: python3 gen_sfx_lobby.py   (then: godot --headless --import)

The hover tick is the shared UI "hover". Ticks and the pick/teammate cues are the UI's felt-mallet family
(see gen_sfx_ui.py); the ticks are a woodblock knock, the last five higher and doubled. The stings are
named <arch>_lock and level to the "signature" category.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, noise
from gen_sfx_ui import pluck, room, finish, jit, NOTE

S.reseed(5230)
LEN = 0.6      # s: every sting is padded to this


def sting(x):
    return S.pad(x, LEN)[:N(LEN)]


# ---------------------------------------------------------------- the lobby's own cues
def pick(i):
    j = jit(i, 0.02)
    return finish(room(mix(pluck(NOTE['A5'] * j, 0.22, 0.05), at(pluck(NOTE['E6'] * j, 0.3, 0.09), 0.05)), 0.4), 4600)


def mate(i):
    """A teammate locked in: one soft low-mid note, no sparkle, so it never competes with your own pick."""
    return finish(room(pluck(NOTE['D5'] * jit(i, 0.02), 0.3, 0.1, 0.4), 0.5), 3200)


def tick(i):
    f = 760 * jit(i, 0.02)
    return finish(mix(pluck(f, 0.07, 0.015, 0.4), 0.3 * pluck(f * 1.5, 0.05, 0.01, 0.2)), 3800)


def tick_urgent(i):
    f = 1010 * jit(i, 0.02)
    one = mix(pluck(f, 0.07, 0.016, 0.5), 0.35 * pluck(f * 1.5, 0.05, 0.01, 0.3))
    return finish(mix(one, at(one * 0.7, 0.07)), 4600)


# ---------------------------------------------------------------- the twelve stings
def gunslinger(i):
    """Vex: a servo whine winds up, a brass snap, a green-fire flare."""
    whine = S.sweep(260, 900, 0.14, 'saw') * env(N(0.14), 0.02, 0.1) * 0.3
    snap = at(mix(S.crack(0.05, 1800, 7000, 0.012), S.kick(300, 90, 0.1, 0.02, 0.04)), 0.14)
    flare = at(mix(S.hiss(0.4, 1500, 6500, 0.01, 0.12) * 0.6, S.fm(520, 1.41, 3.0, 0.3, 0.1) * 0.4), 0.15)
    return sting(room(mix(whine, snap, flare), 0.4))


def archer(i):
    """Lace: a plucked red thread, a needle's ping, scissors that snip shut."""
    thread = S.ring([392, 784, 1180], 0.5, [0.2, 0.1, 0.05], [1.0, 0.4, 0.2], 0.001)
    needle = at(S.chime(2350, 0.4, 0.12, ((1.0, 1.0), (2.9, 0.3))) * 0.4, 0.1)
    snip = at(mix(S.crack(0.03, 3500, 9000, 0.006), at(S.crack(0.03, 3500, 9000, 0.006), 0.05) * 0.7), 0.36)
    return sting(room(mix(thread, needle, snip), 0.3))


def juggernaut(i):
    """Kael: a white-hot ring of struck iron over a low thud, a hiss of heat; never a roar."""
    ring = S.ring([880, 1318, 2103, 3320], 0.55, [0.3, 0.22, 0.14, 0.08], [1.0, 0.6, 0.35, 0.2])
    heat = S.hiss(0.45, 3000, 9000, 0.02, 0.2) * 0.35
    thud = S.sub(120, 52, 0.3, 0.1) * 0.9
    return sting(room(mix(ring, heat, thud), 0.4))


def bulwark(i):
    """Breaker: a ship's bell tolled under strained timber and a slow wave."""
    bell = S.chime(330, 0.6, 0.45, ((1.0, 1.0), (2.0, 0.5), (2.76, 0.4), (4.1, 0.15)))
    wood = S.creak(0.3, 110, 70, 0.5, 900) * 0.5
    wave = lpf(noise(0.5), 700) * S.shape(0.5, 0.2, 0.05, 0.25) * 0.45
    return sting(room(mix(bell, wood, wave), 0.5))


def ostra(i):
    """Motley: a music-box comb a little out of true, a cap bell, a hollow Void swell."""
    comb = [at(S.chime(f, 0.3, 0.1, ((1.0, 1.0), (3.1, 0.3))), 0.07 * k)
            for k, f in enumerate([988, 1175, 1480, 1319])]
    cap = at(S.chime(2093, 0.4, 0.2) * 0.4, 0.3)
    void = lpf(noise(0.55), 400) * S.shape(0.55, 0.25, 0.0, 0.3) * 0.5
    return sting(room(mix(*comb, cap, void), 0.5))


def ashwick(i):
    """Cinder: an ember breath, a warm exhale with crackles settling in it."""
    breath = lpf(noise(0.55), 1400) * S.shape(0.55, 0.12, 0.08, 0.35) * 0.9
    glow = S.sweep(150, 240, 0.5) * S.shape(0.5, 0.1, 0.05, 0.3) * 0.35
    embers = S.grains(0.55, 70, 1400, 6000, 0.001, 0.004, 0.2) * 0.6
    return sting(room(mix(breath, glow, embers), 0.4))


def dredge(i):
    """Grimble: a greedy jingle of coins, a clatter of junk, a gaff hook's chink."""
    coins = S.rattle(0.35, 70, 3000, 8000, 0.5, 0.15)
    junk = at(S.rattle(0.25, 40, 800, 2800, 0.6, 0.1) * 0.7, 0.18)
    chink = at(S.chime(1480, 0.3, 0.12, ((1.0, 1.0), (2.4, 0.5))) * 0.6, 0.38)
    return sting(room(mix(coins, junk, chink), 0.3))


def rimewright(i):
    """Claire: glass-clear ice, a crystal cluster ringing out into frosty air."""
    ice = [at(S.chime(f, 0.45, 0.25, ((1.0, 1.0), (2.76, 0.5), (5.4, 0.3))), 0.05 * k)
           for k, f in enumerate([1568, 2093, 2637])]
    frost = at(S.hiss(0.4, 5000, 9500, 0.05, 0.15) * 0.25, 0.04)
    return sting(room(mix(*ice, frost), 0.6))


def tender(i):
    """Pip: a lantern's warm chord that opens up, with a small star sparkle."""
    chord = mix(*[at(pluck(f, 0.55, 0.22, 0.5), 0.04 * k) for k, f in enumerate([392, 494, 587, 784])])
    star = at(S.chime(2349, 0.4, 0.2, ((1.0, 1.0), (2.76, 0.3))) * 0.3, 0.2)
    return sting(room(mix(chord, star), 0.7))


def thief(i):
    """Sable: a flint's snap, a shimmer of stolen silver, a thin blade's zing."""
    flint = mix(S.click(0.01, 3000, 9000, 0.003) * 1.5, at(S.crack(0.03, 2500, 8000, 0.01), 0.01))
    silver = at(S.rattle(0.3, 60, 4000, 9000, 0.4, 0.12) * 0.5, 0.06)
    zing = at(S.sweep(1800, 4200, 0.3) * S.shape(0.3, 0.01, 0.02, 0.25) * 0.35, 0.18)
    return sting(room(mix(flint, silver, zing), 0.3))


def mage(i):
    """Ryzz: hot-pink lightning, a crackling zap, a copper coil ringing, thunder rolling off."""
    zap = S.crack(0.18, 2500, 10000, 0.05) * (1 + 0.8 * np.sign(noise(0.18)))
    coil = at(S.ring([1100, 1650, 2750], 0.45, [0.2, 0.15, 0.1], [0.8, 0.4, 0.3]), 0.04)
    thunder = at(lpf(noise(0.45), 220) * env(N(0.45), 0.05, 0.18) * 1.4, 0.06)
    return sting(room(mix(zap, coil, thunder), 0.4))


def dolm(i):
    """Tarek: two stone knocks, a low tremor underneath, a spray of gravel."""
    knock = lambda: mix(S.kick(240, 90, 0.18, 0.015, 0.06), 0.5 * S.crack(0.03, 900, 3500, 0.01))
    tremor = S.sub(70, 45, 0.5, 0.25) * 0.8
    gravel = at(S.grains(0.3, 80, 1000, 4500, 0.002, 0.006, 0.1) * 0.5, 0.12)
    return sting(room(mix(knock(), at(knock() * 0.8, 0.13), tremor, gravel), 0.4))


def main():
    S.takes_cat('lobby_pick', pick, 2, 'ui')
    S.takes_cat('lobby_mate', mate, 2, 'ui')
    S.takes_cat('lobby_tick', tick, 3, 'ui')
    S.takes_cat('lobby_tick_urgent', tick_urgent, 3, 'ui')
    for a in (gunslinger, archer, juggernaut, bulwark, ostra, ashwick, dredge, rimewright, tender, thief, mage, dolm):
        S.save_cat(a.__name__ + '_lock', a(0), 'signature')


if __name__ == '__main__':
    main()
