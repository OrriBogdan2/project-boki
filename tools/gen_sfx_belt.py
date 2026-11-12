"""Belt item sounds (briefs/SFX_AUDIT.md row 14): every belt item has its own start cue, and the two
that channel (tonic, armour kit) also a loop, a finish and a cancel. Run from tools/: python3 gen_sfx_belt.py

Which cue belongs to which item is content/rules/belt_sfx.json. All original synthesis, no samples.
  tonic      cork pop; a gulping loop; a bright two-note chime with a breath out; a splash when spilt
  armor_kit  clasp and knock; a ratchet-and-tap loop; a bolt seating with a ring; dropped tools
  medkit     a zip, then a warm rising triad    jump_pad    a spring boing
  scanner    a sonar ping with an echo          shield_cell an energy whine into a ringing bell
  smoke      a canister thud and a long hiss    stim        a syringe click and a double heartbeat
"""
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise, pad

S.reseed(7014)


def jit(i, spread=0.04):
    """Take i drifts a little in pitch so repeats never sound identical."""
    return 1.0 + (0 if i == 0 else S.rng.uniform(-spread, spread))


def knock(f, d=0.12, decay=0.03):
    """A small metal knock: an inharmonic ring with a bright click on the front."""
    return mix(S.ring([f, f * 2.41, f * 4.1], d, [decay, decay * 0.6, decay * 0.35], [1.0, 0.5, 0.25]),
               0.5 * S.click(0.003, 3000, 9000, 0.001))


def gulp(f, d=0.2):
    """One swallow: a falling gurgle with a wet rasp."""
    return lpf(mix(S.sweep(f, f * 0.45, d) * env(N(d), 0.01, d * 0.5),
                   0.3 * lpf(noise(d), 1500) * env(N(d), 0.01, d * 0.4)), 3600)


def tonic_start(i):
    j = jit(i)
    cork = S.sweep(300 * j, 1300 * j, 0.07) * env(N(0.07), 0.003, 0.04)
    return lpf(mix(cork, at(S.click(0.004, 1500, 6000, 0.003) * 0.7, 0.065), at(gulp(420 * j, 0.14) * 0.6, 0.12)), 5200)


def tonic_loop(i):
    return pad(mix(*[at(gulp((430 - 40 * k) * 1.0, 0.24), 0.3 * k) for k in range(3)]), 0.9)


def tonic_end(i):
    j = jit(i, 0.02)
    notes = mix(S.chime(1318 * j, 0.5, 0.2), at(S.chime(1760 * j, 0.7, 0.3) * 0.8, 0.09))
    return mix(notes, at(bpf(noise(0.3), 1100, 3800) * env(N(0.3), 0.06, 0.1) * 0.2, 0.02))


def tonic_cancel(i):
    j = jit(i)
    splash = hpf(noise(0.3), 1500) * env(N(0.3), 0.004, 0.07) * 0.5
    return lpf(mix(splash, at(gulp(300 * j, 0.2) * 0.6, 0.05), S.kick(170, 70, 0.15, 0.03, 0.07) * 0.5), 5000)


def kit_start(i):
    j = jit(i)
    return lpf(mix(S.click(0.004, 2000, 8000, 0.002), at(knock(1250 * j, 0.14, 0.04), 0.03),
                   at(knock(1700 * j, 0.1, 0.03) * 0.7, 0.11)), 7000)


def kit_loop(i):
    taps = [at(knock(1500 + 220 * (k % 2), 0.08, 0.016) * 0.7, 0.2 * k) for k in range(4)]
    ratchet = [at(S.rattle(0.07, 90, 2500, 6000), 0.2 * k + 0.1) * 0.4 for k in range(4)]
    return pad(lpf(mix(*taps, *ratchet), 7000), 0.8)


def kit_end(i):
    j = jit(i, 0.03)
    seat = mix(S.kick(190, 85, 0.14, 0.02, 0.05), 0.7 * knock(980 * j, 0.2, 0.06))
    shimmer = S.ring([2900 * j, 4300 * j], 0.5, [0.18, 0.12], [0.3, 0.2])
    return lpf(mix(seat, at(shimmer, 0.05)), 8000)


def kit_cancel(i):
    j = jit(i, 0.05)
    clatter = S.rattle(0.35, 60, 1200 * j, 4500, 0.6, 0.12)
    return lpf(mix(clatter, S.kick(130, 60, 0.12, 0.02, 0.05) * 0.5, at(knock(700 * j, 0.14, 0.04) * 0.6, 0.1)), 6500)


def medkit_start(i):
    j = jit(i, 0.015)
    zip_ = bpf(noise(0.14), 2500, 7000) * env(N(0.14), 0.01, 0.07) * 0.35
    notes = [at(S.chime(f * j, 0.5, 0.25) * 0.8, 0.12 + 0.07 * k) for k, f in enumerate((523, 659, 784))]
    return mix(zip_, *notes)


def pad_start(i):
    j = jit(i)
    boing = mix(0.5 * S.fm(220 * j, 1.5, 3.0, 0.5, 0.12), S.sweep(180 * j, 520 * j, 0.25) * env(N(0.25), 0.004, 0.14))
    return lpf(mix(S.kick(120, 55, 0.12, 0.02, 0.05), at(boing, 0.04)), 5000)


def scanner_start(i):
    j = jit(i, 0.02)
    ping = S.sweep(1500 * j, 2100 * j, 0.15) * env(N(0.15), 0.003, 0.18)
    return mix(ping, at(ping * 0.45, 0.22), at(ping * 0.2, 0.44), S.ring([3100 * j], 0.5, [0.2], [0.15]))


def shield_start(i):
    j = jit(i, 0.02)
    whine = S.sweep(300 * j, 1500 * j, 0.28, curve=2.0) * env(N(0.28), 0.05, 0.3) * 0.6
    return mix(whine, at(mix(S.chime(1250 * j, 0.7, 0.4), 0.4 * S.fm(500 * j, 2.0, 1.0, 0.5, 0.25)), 0.26))


def smoke_start(i):
    j = jit(i)
    return lpf(mix(S.kick(95, 45, 0.18, 0.03, 0.09), S.click(0.004, 1000, 5000, 0.003) * 0.5,
                   at(S.hiss(0.9, 900 * j, 5000, 0.08, 0.4) * 0.5, 0.04)), 6000)


def stim_start(i):
    j = jit(i)
    click = S.click(0.004, 3000, 9000, 0.002)
    beat = S.kick(80 * j, 45, 0.12, 0.02, 0.06) * 0.9
    return mix(click, at(beat, 0.1), at(beat * 0.8, 0.28), at(bpf(noise(0.3), 2000, 6000) * env(N(0.3), 0.1, 0.1) * 0.15, 0.1))


def main():
    for name, fn in (('belt_tonic_start', tonic_start), ('belt_tonic_end', tonic_end),
                     ('belt_tonic_cancel', tonic_cancel), ('belt_armor_kit_start', kit_start),
                     ('belt_armor_kit_end', kit_end), ('belt_armor_kit_cancel', kit_cancel),
                     ('belt_medkit_start', medkit_start), ('belt_jump_pad_start', pad_start),
                     ('belt_scanner_start', scanner_start), ('belt_shield_cell_start', shield_start),
                     ('belt_smoke_start', smoke_start), ('belt_stim_start', stim_start)):
        S.takes_cat(name, fn, 2, 'cast')
    S.save_loop('belt_tonic_loop', tonic_loop(0), 'loop')
    S.save_loop('belt_armor_kit_loop', kit_loop(0), 'loop')


if __name__ == '__main__':
    main()
