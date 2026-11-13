"""The pickup guns' shots (docs/AUDIO.md, briefs/SFX_AUDIT.md row 3). Run from tools/: python3 gen_sfx_guns.py

The five guns a hunter without a Hunter kit carries (content/weapons smg, rifle, burst_rifle, shotgun,
sniper) each get their own shot, told apart by three things at once:
  body   the pitch and weight of the kick under the crack (a light pop up to a deep boom),
  tail   how long the report hangs and how dark it is (dry and short up to a long roll off the islands),
  pitch  where the crack's noise band sits (a high snap down to a broad, low blast).
SMG: a tiny high pop, almost no tail. Rifle: a mid crack with a short slap. Burst rifle: a tighter,
metallic crack with a bolt clack after it. Shotgun: a low, wide blast and a thick tail. Sniper: the
sharpest crack, a deep body and a long rolling report. Original synthesis, no samples.
"""
import sfx_lib as S
from sfx_lib import mix, at, kick, click, crack, sub, tail, reflections, ring

S.reseed(5309)


def smg(i):
    d = 0.18
    body = kick(470 + 20 * i, 210, d, 0.004, 0.014, 2.0) * 0.45
    snap = crack(d, 2400, 9000 + 300 * i, 0.008) * 2.4
    return mix(click(0.002, 4000, 12000) * 1.4, body, snap, tail(0.12, 3200, 0.025) * 0.5)


def rifle(i):
    d = 0.5
    body = kick(260 + 10 * i, 95, d, 0.012, 0.035, 2.6) * 0.6
    snap = crack(d, 900, 6000 + 200 * i, 0.014) * 2.6
    low = crack(d, 200, 900, 0.03) * 1.8
    return mix(click(0.004, 2800, 11000) * 1.6, body, snap, low, reflections(tail(0.35, 2000, 0.07) * 0.9))


def burst(i):
    d = 0.42
    body = kick(330 + 12 * i, 140, d, 0.008, 0.025, 3.0) * 0.5
    snap = crack(d, 1500, 7500, 0.01) * 2.4
    metal = ring((1850, 2930, 4410), d, (0.03, 0.02, 0.012), (0.25, 0.15, 0.08))
    bolt = at(mix(click(0.003, 1800, 6000) * 1.2, crack(0.05, 700, 3000, 0.008) * 0.9), 0.09)
    return mix(click(0.003, 3500, 12000) * 1.5, body, snap, metal, bolt, tail(0.22, 2600, 0.04) * 0.6)


def shotgun(i):
    d = 1.0
    body = kick(150 + 8 * i, 48, d, 0.025, 0.09, 3.4) * 0.8
    blast = crack(d, 150, 3200, 0.06) * 3.4
    taps = ((0.05, 0.4, 1200), (0.1, 0.3, 900), (0.17, 0.2, 700), (0.26, 0.1, 500))
    return mix(click(0.006, 1800, 8000) * 2.0, body, blast, sub(62, 36, d, 0.12) * 0.5, reflections(tail(0.85, 1200, 0.2) * 1.5, taps))


def sniper(i):
    d = 1.6
    crk = mix(click(0.002, 5000, 15000) * 2.6, crack(d, 2500, 12000, 0.006) * 3.2, crack(d, 400, 2000, 0.03) * 1.6)
    body = kick(210, 50, d, 0.015, 0.1, 3.0) * 0.7
    taps = ((0.11, 0.45, 900), (0.26, 0.32, 650), (0.44, 0.22, 480), (0.66, 0.12, 360))
    return mix(crk, body, sub(58, 32, d, 0.18) * 0.5, reflections(tail(1.4, 1100, 0.38, 0.01) * 1.5, taps))


S.takes_cat('gun_smg', smg, 2, 'fire')
S.takes_cat('gun_rifle', rifle, 2, 'fire')
S.takes_cat('gun_burst', burst, 2, 'fire')
S.takes_cat('gun_shotgun', shotgun, 2, 'heavy_fire')
S.takes_cat('gun_sniper', sniper, 1, 'heavy_fire')
print('pickup gun shots written')
