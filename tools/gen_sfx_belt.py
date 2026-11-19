"""Synthesizes the belt cancel cues into audio/ (set content/sfx/belt.json, played by UtilityUse.spill).

    python3 tools/gen_sfx_belt.py      (then: godot --headless --import)

A drink or repair that is cut short (a hit, a stun, a roll, the glider) uses nothing, and everyone near
hears it go:
  belt_spill    : the tonic: a glass clink, a wet splash and a few bubbles popping as it runs out.
  belt_fumble   : the armour kit: plates knocked loose, two dull metal clanks and a short scrape.
Original synthesis, no samples; levelled to the "cast" category through tools/sfx_lib.py. Own random
stream, so no other generator's output moves.
"""

import argparse

import sfx_lib as S

S.reseed(1119)


def spill():
    d = 0.55
    clink = S.chime(2350.0, 0.3, 0.09) * 0.55
    splash = S.bpf(S.noise(0.32), 500, 4200) * S.shape(0.32, 0.004, 0.03, 0.26)
    drip = S.bubbles(0.4, 18, 300, 1100, 0.035) * 0.45
    return S.pad(S.mix(clink, S.at(splash, 0.015) * 0.9, S.at(drip, 0.06)), d)


def fumble():
    d = 0.5
    c1 = S.mix(S.fm(310.0, 2.41, 3.0, 0.22, 0.07), S.click(0.006, 1500, 6000, 0.002) * 0.6)
    c2 = S.fm(240.0, 2.63, 2.5, 0.25, 0.08) * 0.8
    scrape = S.bpf(S.noise(0.18), 1200, 5000) * S.shape(0.18, 0.02, 0.06, 0.1) * 0.35
    return S.pad(S.mix(c1, S.at(c2, 0.11), S.at(scrape, 0.16)), d)


def main():
    argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    S.save_cat("belt_spill", spill(), "cast")
    S.save_cat("belt_fumble", fumble(), "cast")
    print("belt cancel cues written")


if __name__ == "__main__":
    main()
