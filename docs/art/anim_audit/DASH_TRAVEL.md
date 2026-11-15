# Dash clips against the body's travel (owner bug 181, KIT_PARITY 2-4 and 11, decision 0020)

KIT_PARITY moved every dash to the source's distance and time and decision 0020 hands a dash over at run
speed, so the run carries on. The clips were keyed for the old numbers: a recovery keyed after the travel now
plays on a body that is already running (a dash pose skating along, then a pop into the run). `--dash-frames-check`
now measures every Hunter's ground dash on the kit clock (`tools/dash_travel.gd`): the body's step per sim step,
how far the clip's feet went with it (the rest is slip), the spine lean, and who owns the body. Verdicts per dash:
the run showing inside the travel (early), the dash pose riding the run after it (ride; at most one footage frame of
recovery, 0.2 s, plus the half of the 0.16 s blend that still shows the pose), and a jerk at the hand-over (pop).
Fixes are clip-side only, in `content/rules/warden_anim/<art>.json`: `rate` (clip seconds per kit second) and
`upper: "moving"` (the torso keeps the pose, the legs run while he moves). Kit numbers untouched.

Refs: briefs/hero-ref sheets (5 fps, 0.2 s a frame); each sheet lands its dash "within a frame".

| Hunter | move | kit travel | clip (s) | before: ride / pop | after | fix | footage |
|---|---|---|---|---|---|---|---|
| Vex (gunslinger) | Slipstep tap | 4.02 m, 0.52 s | dash 0.87 | 0.43 s (the stand-up rides the run) / 8 | 0.25 / 26 | `rate` 1.25: keyed start-to-stand 0.85 -> 0.68 s | venator.md: tap slide 3 frames (0.6 s) start to stand |
| Kael (juggernaut) | Quick Dash | 3.59 m, 0.25 s after the 0.07 s crouch | dash 0.43 | 0.27 / 1 | 0.22 / 10 | `rate` 1.1 | juggernaut.md 0387: ~0.2 s, sword thrust |
| Kael | Lunge, half / full hold | 6.0 m, 0.25 s / 10.5 m, 0.35 s | lunge 0.60 | 0.43 / 0.33 | 0.23 / 0.13 | `rate` 1.5 (the drive 0.05-0.2 s, the ease-back to 0.4 s) | juggernaut.md 0121-0127: ~5 m in ~0.2 s |
| Lace (archer) | roll | 2.87 m, 0.27 s | roll 0.37 | 0.05 | 0.05 | none | pin.md: a quick dodge roll |
| Cinder (ashwick) | Soot Ram | 3.34 m, 0.32 s | leap 0.53 | 0.30 / 8 | 0.22 / 18 | `rate` 1.15 | linwick.md 0160-0161: lands upright within a frame |
| Meeko (tender) | dash | 3.57 m, 0.20 s | skip 0.3 | 0.12 | 0.12 | none | mooshmoosh.md |
| Tenzo (dolm) | Rock Hop: hop 0.26 s (a launch), skid | 0.6 m, 0.3 s | dash_hop 0.27, dash_skate 0.3 (hold), dash_land 0.7 | 0.45 (the landing rides the run) | 0.08 / 17 | dash_land `upper: moving` (the skid stays full-body: two upper moves in a row swap in a frame, see DEBT) | breah.md (Landslide is one dash; the hop chain is the owner's) |
| Grimble (dredge) | Barge | 2.71 m, 0.18 s | lunge 0.37 | 0.27 / 5 | 0.23 / 17 | `rate` 1.1 | dredge.md 0188: lands in a crouch, back to the aim within a frame |
| Neve (rimewright) | Skate tap (0.2 s min) | 1.72 m, 0.20 s | skate_go 0.17, skate loop, skate_stop 0.5 | 0.58 (the braced stop rides the run) / 40 | 0.07 / 12 | skate_stop `upper: moving` | tamsin.md 0169-0296: hold to skate, release to stop |
| Motley (ostra) | Trade (lob, then the teleport) | no body travel | swap_aim, swap 0.85 | - | - | none: the frame count is not asked of a lob (`NO_TRAVEL`) | ostra.md 0152-0200 |
| Albert (bulwark) | 360 Smash | 2.78 m, 0.18 s | shift_whirl 0.75 (spin to 0.58) | 0.60 / 0 | 0.60 / 4 (allowed +0.4) | none: the spin lands on arrival and settles | bjorn.md 0370-0372: dash <= 0.2 s, one spin on arrival, ~0.4 s recovery |
| Sparkle (mage) | Surge (short charge) | 8.12 m, 0.23 s | dash (hold), dash_go 0.5, dash_land 0.43 | 0.53 (the landing crouch rides the run) / 15 | 0.08 / 18 | dash_land `upper: moving` | vireo.md 0161-0166: an abrupt stop on arrival (our run carry is decision 0020's) |
| Sable (thief) | Cartwheel | 4.45 m, 0.47 s | vault_r 0.47 | 0.08 / 2 | 0.08 / 10 | none | dancer.md: a sideways cartwheel, ~2 bh |

Early (the run inside the travel) was 0.00 s for every Hunter before and after. Pop is the hand-over jerk in rad/s summed
over the root, hips, upper arms and thighs (limit 30); the "before" numbers are from the sim-step metric, the first
run's per-drawn-frame numbers read 50-550 on the spin and the folded steps. Lean and slip are printed per row for
the eye (Vex 28 deg, slip 64%: a slide; Sable 40 deg, slip 29%: a cartwheel; Sparkle 84 deg, slip 96%: a streak).

Strips: `--dash-shots=<dir>` on a GPU run (every 4th drawn frame, half size), `tools/dash_travel_strip.py <before> <after> <out>`
puts the two rows under each other per Hunter (`dash_travel_<arch>.jpg` here, top row main's clip rules, bottom row
these; GPU jobs 20261109-100839-04513 before, 20261109-100636-20778 after, RTX 4090). A shot's readback stalls its
frame to 40-150 ms, so a shots run saves 4-5 frames a dash and prints its rows as information: the headless run
judges. At match zoom the Hunter is small in a strip; the rows above and `--dash-out=<csv>` are the evidence. The GPU
run on main's rules confirmed the headless numbers: Kael's Lunge rode 0.38 / 0.35 s, Cinder 0.30 s (jerk 70),
Neve 0.53 s (jerk 101), Sparkle 0.38 s; on these rules none of those rows failed.

Not done here (kit code, not clip data; see docs/DEBT.md): a variable-length dash (Kael's held Lunge, Vex's held slide)
wants its drive pose held and a recovery played by the kit at the end; Kael's enrage roar swaps a dash's clip mid-travel.
