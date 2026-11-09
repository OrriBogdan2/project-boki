"""Synthesizes the sky train's sounds into audio/: a two-tone horn and a rail clatter.
Kept apart from gen_sfx.py so rerunning it doesn't reshuffle every other sound.
Same soft palette as gen_sfx.py: slow fades in, rounded tones, levelled under the music."""
import numpy as np, wave, os
from scipy.signal import butter, sosfilt
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rng = np.random.default_rng(11)
def t(d): return np.arange(int(SR * d)) / SR
def lpf(x, hz): return sosfilt(butter(2, hz / (SR / 2), 'low', output='sos'), x)
def bpf(x, lo, hi): return sosfilt(butter(2, [lo / (SR / 2), hi / (SR / 2)], 'band', output='sos'), x)
def rc(n): return 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / max(1, n))   # a raised-cosine fade-in, n samples
def save(name, x, rms_db=-20.0):
    x = np.asarray(x, dtype=float)
    x[:64] *= rc(64); fo = int(SR * 0.03); x[-fo:] *= rc(fo)[::-1]
    pk = np.max(np.abs(x)) or 1; act = np.abs(x) > pk * 0.01
    x *= 10 ** (rms_db / 20) / np.sqrt(np.mean(x[act] ** 2))
    x = np.where(np.abs(x) > 0.5, np.sign(x) * (0.5 + 0.2 * np.tanh((np.abs(x) - 0.5) / 0.2)), x)   # soft ceiling at about -3 dB
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())

def saw(f, d, vib=0.0):
    tt = t(d)
    ph = np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 5.0 * tt))) / SR
    return (ph % 1) * 2 - 1

# horn: a mellow minor-third chord, swelling in and out, rounded off so it reads as distant brass
d = 1.4; n = int(SR * d); tt = t(d)
shape = rc(int(SR * 0.16)).tolist() + [1.0] * (n - int(SR * 0.16)); shape = np.array(shape) * np.where(tt > d - 0.35, 0.5 + 0.5 * np.cos(np.pi * (tt - (d - 0.35)) / 0.35), 1)
droop = 1 - .02 * np.maximum(0, tt - (d - .3)) / .3
horn = sum(lpf(saw(f * droop, d, 0.004), 650) * a for f, a in ((220, 1), (261.6, .8), (330, .45)))
save('horn', lpf(horn, 900) * shape, -19)

# rail: wheels rolling over the joints (muted knocks) with a low rumble underneath
d = 1.0; n = int(SR * d)
rum = bpf(rng.uniform(-1, 1, n), 50, 260) * 3.0
clack = np.zeros(n)
for at in (0.0, .12, .5, .62):
    i = int(at * SR); seg = min(n - i, int(.09 * SR)); tt2 = np.arange(seg) / SR
    e = np.minimum(1, tt2 / 0.004) * np.exp(-tt2 / 0.025)
    clack[i:i + seg] += bpf(rng.uniform(-1, 1, seg), 200, 1100) * e
save('rail', rum * .7 + clack, -21)
print('train sounds written')

# train_hit: hit by the sky train. A heavy low thump, an iron clang and a crunch: the loudest thing on
# the map, so nobody wonders what happened
d = 1.3; n = int(SR * d); tt = t(d)
thump = np.sin(2 * np.pi * np.cumsum(40 + 90 * np.exp(-tt / 0.08)) / SR) * np.exp(-tt / 0.35)
clang = sum(np.sin(2 * np.pi * f * tt + p) * a * np.exp(-tt / dk) for f, a, dk, p in
            ((311, 1.0, .5, 0), (467, .7, .4, 1), (733, .5, .3, 2), (1187, .35, .22, 3), (1663, .2, .15, 4)))
crunch = bpf(rng.uniform(-1, 1, n), 300, 3200) * np.exp(-tt / 0.09)
hit = thump * 1.6 + lpf(clang, 2600) * .55 + crunch * .9
hit[:int(SR * .004)] *= np.linspace(0, 1, int(SR * .004))
save('train_hit', hit, -13)

# revive_hum: a deathbox revive being channelled. A seamless two-second loop (every partial a whole
# number of cycles long, no fades) of a low warm hum and a shimmer of chimes; the game raises its
# pitch as the channel fills
d = 2.0; n = int(SR * d); tt = np.arange(n) / SR
hum = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((110, 1.0), (110.5, .6), (165, .45), (220, .35), (330, .12)))
trem = 0.8 + 0.2 * np.sin(2 * np.pi * 3.0 * tt)
chime = np.zeros(n)
for i, (f, at) in enumerate(((880, 0.0), (1108.5, .5), (1318.5, 1.0), (1760, 1.5))):
    ph = (tt - at) % d
    chime += np.sin(2 * np.pi * f * tt) * np.exp(-ph / 0.35) * .35
loop = hum * trem * .55 + chime
loop = loop / np.max(np.abs(loop)) * 0.5
loop *= 10 ** (-17 / 20) / np.sqrt(np.mean(loop ** 2))
with wave.open(os.path.join(OUT, 'revive_hum.wav'), 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((np.clip(loop, -.95, .95) * 32767).astype(np.int16).tobytes())

# revive_done: the revive completes. A bright rising arpeggio of bells over a soft swell
d = 1.6; n = int(SR * d); tt = t(d)
done = np.zeros(n)
for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
    i0 = int(i * .07 * SR); seg = n - i0; t2 = np.arange(seg) / SR
    bell = (np.sin(2 * np.pi * f * t2) + .4 * np.sin(2 * np.pi * f * 2.76 * t2) * np.exp(-t2 / .15)) * np.exp(-t2 / .5)
    done[i0:] += bell * (1 - .12 * i)
swell = sum(np.sin(2 * np.pi * f * tt) for f in (261.6, 392.0)) * np.sin(np.pi * np.minimum(tt / d, 1)) * .25
save('revive_done', done + swell, -15)
print('train hit and revive sounds written')
