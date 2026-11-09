"""Synthesizes legendary_sting into audio/: the sound every player hears when a legendary Boki turns up
(LegendaryReveal). A low swell rising under it, then three bright crystal notes climbing an open fifth
and octave, with an airy shimmer that trails off. About 2.4 s, levelled as a signature sound.
Original synthesis, no samples. Kept apart so rerunning it doesn't reshuffle every other sound.

    python3 tools/gen_legendary_sfx.py      (then: godot --headless --import)
"""
import numpy as np
import sfx_lib as S

S.reseed(1109)
D = 2.4

# the swell: a soft low tone gliding up a fourth, fading in and out
swell = S.sweep(98.0, 130.8, D, curve=0.7) * S.shape(D, 0.6, 0.4, 1.3) * 0.55
swell += S.sweep(196.0, 261.6, D, curve=0.7) * S.shape(D, 0.7, 0.3, 1.3) * 0.18

# the call: three crystal notes, D5 A5 D6, a beat apart, ringing on
notes = [S.at(S.chime(f, D - t0, 0.9), t0) for t0, f in [(0.35, 587.3), (0.6, 880.0), (0.85, 1174.7)]]

# the shimmer: high airy noise opening behind the last note
air = S.at(S.bpf(S.noise(1.5), 4000, 9000) * S.shape(1.5, 0.3, 0.2, 1.0) * 0.12, 0.8)

x = S.mix(swell, *notes, air)[:S.N(D)]
S.save_cat('legendary_sting', S.reflections(x), 'signature')
print('wrote legendary_sting')
