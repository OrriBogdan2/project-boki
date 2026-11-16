"""The abyss fall's sounds (docs/AUDIO.md, content/sfx/abyss_fall.json): air, a warning, a lift, a cry.

    cd tools && python3 gen_sfx_abyss_fall.py      (then: godot --headless --import)

  abyss_wind   loop: a deep rush of air past a falling body; the game raises its pitch and level
               through the slow band under the lip (AbyssFallSfx)
  abyss_warn   the point of no return is close: two quick low swells under a thin whistle of air
  abyss_lift   carried back up: a rush that climbs, with a soft whump of air underneath
  abyss_cry    another Hunter dropping under the lip: a short wordless cry that falls away
Original synthesis, no samples.
"""

import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, bpf, env, mix, shape, soft_in, sweep, voice
from gen_sfx_glider import sweep_noise, wobble

S.reseed(7316)


def wind():
    d = 2.0
    body = bpf(noise(d), 160, 1400) * wobble(d, 4, 0.3)
    low = lpf(noise(d), 160) * wobble(d, 3, 0.4) * 1.6
    flutter = bpf(noise(d), 900, 2600) * 0.25 * wobble(d, 11, 0.5)
    return body + low + flutter


def warn():
    d = 0.5
    t = np.arange(N(d)) / S.SR
    tone = lpf(sweep(140, 95, d, "saw"), 900) * (
        np.exp(-(((t - 0.09) / 0.05) ** 2)) + np.exp(-(((t - 0.3) / 0.05) ** 2))
    )
    whistle = bpf(noise(d), 2400, 3600) * shape(d, 0.05, 0.25, 0.2) * 0.35
    return soft_in(mix(tone * 1.4, whistle), 1.0)


def lift():
    d = 0.6
    rush = sweep_noise(d, 300, 3200, 0.45) * shape(d, 0.12, 0.15, 0.3)
    whump = lpf(noise(d), 220) * env(N(d), 0.01, 0.12) * 1.8
    return soft_in(mix(rush * 1.5, whump), 1.0)


def cry():
    return voice(0.6, 430, 190, "ah", breath=0.35, vib=0.02, scale=1.05, a=0.02, decay=0.35)


def build():
    S.save_loop("abyss_wind", wind(), "loop")
    S.save_cat("abyss_warn", warn(), "cast")
    S.save_cat("abyss_lift", lift(), "cast")
    S.save_cat("abyss_cry", cry(), "grunt")


if __name__ == "__main__":
    build()
    print("gen_sfx_abyss_fall: done")
