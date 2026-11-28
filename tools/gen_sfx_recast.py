"""The recast cues of the ten Hunters with a two-step ability (RecastCue, docs/AUDIO.md "Ability sweep"), and the
end of Albert's raised shield.

    python3 tools/gen_sfx_recast.py      (then: godot --headless --import)

Per Hunter, in the material of its kit (the grounded recipe of docs/AUDIO.d/1126-grounded-sfx.md: foley and a short
body, nothing above about 4 kHz, no bells or rising tones, 3 takes of the tick because it plays up to three times a
window):
  <arch>_recast_open  the window opens, the second press is ready (HeroSfx.of(h, "recast_open"), was the shared
                      ab_ready chime)
  <arch>_recast_tick  the window is closing, one per tick at 0.6, 0.4 and 0.2 s left (the game plays it a little
                      higher each time)
  <arch>_recast_end   the window ran out unused (was a shared click at 0.6 pitch)
  bulwark_shield_down the raised aegis lowered (BulwarkKit._lower): strap and a plate settling
Kael: chain links; Albert: plate and strap; Tenzo: stone and grit; Cinder: valve hiss and flint; Neve: ice;
Sparkle: static; Sable: cloth and a knife tip; Meeko: wood and embers; Motley: rubbery plucks. Gil's open and tick
are in gen_sfx_gil.py; this file adds his end (a dull water plop).

Original synthesis, no samples (CC0, docs/CREDITS.md). Its own random stream (seed 11285), so it never changes the
files the other generators write.
"""

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, bpf, env, mix, at, kick, click, crack, ring, grains

S.reseed(11285)
P = [1.0, 1.04, 0.96, 1.08]  # each take's pitch (take 0 is the plain file)


def soft(x, hz=3800):
    """Everything here stays under the grounded ceiling (about 4 kHz)."""
    return lpf(x, hz)


# ------------------------------------------------------------------ Kael (juggernaut): chain links
def jug_open(i):
    link = ring((620 * P[i], 1480 * P[i], 2300), 0.16, (0.05, 0.03, 0.02), (0.8, 0.5, 0.25))
    return soft(mix(link, at(link * 0.55, 0.075), kick(150, 90, 0.1, 0.01, 0.03) * 0.5))


def jug_tick(i):
    return soft(mix(ring((780 * P[i], 1900), 0.06, (0.02, 0.012), (0.8, 0.4)), click(0.003, 1200, 3500) * 0.4))


def jug_end(i):
    slack = grains(0.22, 60, 500, 2600, 0.003, 0.008, fall=0.07)
    return soft(mix(slack * 0.7, kick(130, 70, 0.18, 0.02, 0.05) * 0.5))


# ------------------------------------------------------------------ Albert (bulwark): plate and strap
def bul_open(i):
    plate = ring((240 * P[i], 520 * P[i], 1120), 0.2, (0.07, 0.04, 0.02), (0.8, 0.55, 0.3))
    strap = bpf(noise(0.14), 400, 1800) * env(N(0.14), 0.02, 0.05) * 0.4
    return soft(mix(plate, at(strap, 0.04), kick(110, 75, 0.12, 0.01, 0.04) * 0.5))


def bul_tick(i):
    return soft(mix(ring((300 * P[i], 760), 0.07, (0.025, 0.012), (0.8, 0.4)), crack(0.03, 600, 2400, 0.006) * 0.4))


def bul_end(i):
    return soft(
        mix(kick(120, 62, 0.2, 0.02, 0.06) * 0.8, bpf(noise(0.15), 300, 1500) * env(N(0.15), 0.004, 0.05) * 0.5)
    )


def bul_shield_down(i):
    """The raised aegis lowered (RMB let go, or a merge): the strap slackens and the plate settles with a dull knock."""
    strap = bpf(noise(0.16), 350, 1600) * env(N(0.16), 0.03, 0.06) * 0.5
    plate = ring((190 * P[i], 410), 0.2, (0.05, 0.025), (0.6, 0.3))
    return soft(mix(strap, at(plate, 0.1), at(kick(105, 60, 0.16, 0.015, 0.05) * 0.8, 0.1)))


# ------------------------------------------------------------------ Tenzo (dolm): stone and grit
def dolm_open(i):
    knock = kick(200 * P[i], 105, 0.18, 0.012, 0.05, 2.0)
    grit = grains(0.16, 90, 500, 2800, 0.002, 0.006, fall=0.05)
    return soft(mix(knock * 0.9, at(grit * 0.6, 0.01), at(kick(240 * P[i], 130, 0.12, 0.01, 0.04) * 0.5, 0.08)))


def dolm_tick(i):
    return soft(mix(ring((520 * P[i], 1250), 0.05, (0.015, 0.008), (0.8, 0.4)), crack(0.02, 700, 2800, 0.004) * 0.5))


def dolm_end(i):
    return soft(mix(grains(0.3, 70, 300, 2000, 0.003, 0.009, fall=0.1) * 0.8, kick(100, 55, 0.2, 0.02, 0.06) * 0.5))


# ------------------------------------------------------------------ Cinder (ashwick): valve hiss and flint
def ash_open(i):
    flint = mix(click(0.004, 1500, 4000) * 0.9, crack(0.05, 900, 3200, 0.01) * 0.5)
    hiss = bpf(noise(0.2), 900, 3500) * env(N(0.2), 0.03, 0.07) * 0.5
    return soft(mix(flint, at(hiss, 0.03), kick(140 * P[i], 85, 0.12, 0.01, 0.04) * 0.4))


def ash_tick(i):
    return soft(mix(click(0.004, 1100, 3500) * 0.9, kick(260 * P[i], 160, 0.04, 0.006, 0.015) * 0.5))


def ash_end(i):
    return soft(
        mix(bpf(noise(0.3), 400, 2600) * env(N(0.3), 0.01, 0.1) * 0.7, kick(110, 60, 0.15, 0.015, 0.05) * 0.4), 3000
    )


# ------------------------------------------------------------------ Neve (rimewright): ice
def rime_open(i):
    snap = crack(0.08, 1300, 4000, 0.012) * 1.0
    frost = grains(0.18, 70, 1800, 4000, 0.002, 0.005, fall=0.06)
    return soft(mix(snap, at(frost * 0.5, 0.02), kick(190 * P[i], 100, 0.12, 0.01, 0.04) * 0.5))


def rime_tick(i):
    return soft(mix(crack(0.03, 1500 * P[i], 4000, 0.005) * 0.9, ring((900 * P[i],), 0.04, (0.01,), (0.3,))))


def rime_end(i):
    return soft(mix(lpf(crack(0.2, 500, 2800, 0.04), 2500) * 0.9, kick(120, 65, 0.18, 0.02, 0.06) * 0.5))


# ------------------------------------------------------------------ Sparkle (mage): static
def mage_open(i):
    zap = grains(0.2, 140, 700, 3800, 0.002, 0.005, fall=0.05)
    return soft(mix(zap * 0.9, kick(120 * P[i], 100, 0.18, 0.05, 0.08, 1.4) * 0.6, click(0.003, 1500, 3800) * 0.6))


def mage_tick(i):
    return soft(
        mix(click(0.004, 1000 * P[i], 3600) * 0.9, grains(0.05, 120, 800, 3600, 0.001, 0.003, fall=0.015) * 0.6)
    )


def mage_end(i):
    return soft(mix(grains(0.3, 80, 500, 3000, 0.002, 0.006, fall=0.09) * 0.7, kick(100, 60, 0.2, 0.03, 0.07) * 0.4))


# ------------------------------------------------------------------ Sable (thief): cloth and a knife tip
def thief_open(i):
    cloth = bpf(noise(0.14), 700, 3300) * env(N(0.14), 0.012, 0.04) * 0.7
    nick = ring((1500 * P[i], 2500), 0.06, (0.012, 0.008), (0.5, 0.25))
    return soft(mix(cloth, at(nick, 0.05), kick(170, 100, 0.1, 0.01, 0.03) * 0.4))


def thief_tick(i):
    return soft(mix(ring((560 * P[i], 1050), 0.045, (0.012, 0.008), (0.8, 0.4)), click(0.003, 1400, 3500) * 0.3))


def thief_end(i):
    return soft(mix(bpf(noise(0.2), 400, 2200) * env(N(0.2), 0.02, 0.06) * 0.6, kick(130, 70, 0.14, 0.015, 0.04) * 0.5))


# ------------------------------------------------------------------ Meeko (tender): wood and embers
def tend_open(i):
    knock = ring((300 * P[i], 650, 1000), 0.18, (0.05, 0.03, 0.015), (0.8, 0.5, 0.2))
    embers = grains(0.25, 45, 900, 3200, 0.002, 0.006, fall=0.08)
    return soft(mix(knock, at(embers * 0.6, 0.03), kick(150, 90, 0.1, 0.01, 0.04) * 0.4))


def tend_tick(i):
    return soft(
        mix(
            grains(0.06, 90, 900 * P[i], 3200, 0.002, 0.005, fall=0.02) * 0.9,
            ring((420 * P[i],), 0.05, (0.014,), (0.5,)),
        )
    )


def tend_end(i):
    return soft(
        mix(bpf(noise(0.3), 500, 2800) * env(N(0.3), 0.02, 0.09) * 0.5, grains(0.2, 40, 800, 2600, fall=0.06) * 0.5)
    )


# ------------------------------------------------------------------ Motley (ostra): rubbery plucks
def os_open(i):
    a = kick(330 * P[i], 250, 0.14, 0.02, 0.05, 1.3)
    b = kick(420 * P[i], 320, 0.14, 0.02, 0.05, 1.3)
    pop = crack(0.03, 500, 2200, 0.005) * 0.5
    return soft(mix(a * 0.8, at(b * 0.8, 0.07), at(pop, 0.07)))


def os_tick(i):
    return soft(mix(kick(380 * P[i], 300, 0.06, 0.012, 0.02, 1.3) * 0.9, crack(0.02, 700, 2500, 0.004) * 0.4))


def os_end(i):
    return soft(
        mix(kick(300, 150, 0.22, 0.08, 0.07, 1.2) * 0.8, bpf(noise(0.12), 400, 1800) * env(N(0.12), 0.01, 0.04) * 0.4)
    )


# ------------------------------------------------------------------ Gil: a dull water plop (his open and tick are in gen_sfx_gil.py)
def gil_end(i):
    plop = kick(380 * P[i], 170, 0.16, 0.03, 0.05, 1.3)
    wet = bpf(noise(0.14), 300, 2200) * env(N(0.14), 0.006, 0.04) * 0.5
    return soft(mix(plop * 0.9, at(wet, 0.01)))


KITS = {
    "juggernaut": (jug_open, jug_tick, jug_end),
    "bulwark": (bul_open, bul_tick, bul_end),
    "dolm": (dolm_open, dolm_tick, dolm_end),
    "ashwick": (ash_open, ash_tick, ash_end),
    "rimewright": (rime_open, rime_tick, rime_end),
    "mage": (mage_open, mage_tick, mage_end),
    "thief": (thief_open, thief_tick, thief_end),
    "tender": (tend_open, tend_tick, tend_end),
    "ostra": (os_open, os_tick, os_end),
}


def build():
    for arch, (op, tk, en) in KITS.items():
        S.takes_cat(arch + "_recast_open", op, 2, "ui")
        S.takes_cat(arch + "_recast_tick", tk, 3, "ui")
        S.takes_cat(arch + "_recast_end", en, 2, "ui")
    S.takes_cat("gil_recast_end", gil_end, 2, "ui")
    S.takes_cat("bulwark_shield_down", bul_shield_down, 2, "cast")


if __name__ == "__main__":
    build()
