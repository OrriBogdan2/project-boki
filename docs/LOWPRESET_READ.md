# Very Low against High: does gameplay information survive? (2026-11-09)

Looks may drop on the low presets; information may not (DECISIONS 2026-11-08, perf pass). Every Hunter's LMB, RMB, Shift,
E and R (E and R pressed twice, for the recast marker) were played at the match camera at `--quality=very_low` and
`--quality=high` with `--hero-vfx-reel --reel-generic` on the real GPU (jobq; sheet crops are 3x3 frames per ability).
Side-by-side sheets: `docs/lowpreset_read/<hero>.jpg`, Very Low on the top row, High below, columns LMB RMB Shift E R.
Full-size sheets: the jobq `out` dirs listed at the end. Base: ext/particle-budget (presets, `fx` / `fx_life`).

## What survives (read from the sheets, all 12 Hunters)
- Every ground ring, disc, lane, cone, wall, seed, zone and telegraph is a mesh, not a particle, and no preset touches
  it: the same world size, the same Hunter colour, still readable at the 540 px render height of Very Low (Archer's
  rain lane, Dolm's lane, Bulwark's guard zone, Tender's Hearthlight ring and bloom, Thief's knife ring, Ostra's
  seed, Rimewright's wall and spear zone, Kael's chain, Ashwick's flashover ring).
- Recast markers (Kael's chain pull, Ostra's seed pop, Thief's blink, the second R) show at both presets.
- Hit flashes show at both. Without bloom the white-hot star reads as a plain white blob (Archer R, Ostra pop): the
  same size and place, less glow. Not a loss of information.

## What disappears or thins at Very Low
Very Low draws 25% of each Hero particle layer (`fx`) for half as long (`fx_life`). Particle-only cues are the
ones at risk. Seen on the sheets: Rimewright's frost haze along the Shift skate and the rising frost of the wall
(a path footprint; the frost slab stays), the petals and stars around Tender and Ostra (decor), the ember burst on a
chain hit and the hit sparks (3 particles at the floor). Read from the data (the move is particle-only, so one in four
survives): 

| Hunter | move (cue) | particles at High / Very Low |
|---|---|---|
| Archer | draw, heavy_hold (the charge gathering at the nock), ult_armed, ult_nock, spirit (state) | 12-22 / 3-5 |
| Ashwick | lance (the flame lane), shot_aim, cloak_gather (windup), jets (flight) | 20-108 / 5-27 |
| Kael | wave_charge, slam_wind, lunge_charge, drop_gather, dash_wind (windups), guard (stance), enraged and heat (state), chain_tight (tether), riposte_heal | 7-40 / 1-10 |
| Rimewright | ice_bridge (walkable ice, 6 / 1), rime_creak (the crash warning, 6 / 1), rime_hold (zone), spear_aim, skate, wall_rise | 6-32 / 1-8 |
| Tender | heal_stars (heals), seed_aim, seed_stick, hearth_motes (the zone ticking, 6 / 1) | 6-13 / 1-3 |

Bulwark, Dolm, Dredge, Gunslinger, Mage, Ostra and Thief have no content/vfx file: their looks are the shared cast language (rings,
cones, telegraphs, flashes: meshes) plus `Fx.burst` / `Fx.spark` accents, so nothing there is culled by a preset
beyond the accents' count. None of their zones, telegraphs or recast markers disappeared on the sheets.

Nothing shrank below readable and no ring lost its Hunter colour at Very Low.

## Fix
`"keep": true` on a Hero VFX particle layer (scripts/match/hero_vfx.gd, `_aim_emitter`): the preset's `fx` and `fx_life`
skip it, and `KEEP_RESERVE` (120) of the `MAX_LIVE` (420) cap is only for keep layers, so decor stops first. 45 layers
tagged in the five content/vfx files, exactly the table above (the cue's own layer, plus the smoke that is the skate's
and the wall's footprint). `--hero-vfx-check` asserts it (full count and life at Very Low, decor thinned, the reserve
left alone). Not changed on purpose: smoke and sparks that only dress a hit, the shared `Fx.burst` / `Fx.spark`
(hit sparks keep their floor of 2-3), and ambient emitters (`ParticleCount.tune`).
Cost at Very Low: the keep layers draw their full count while a Hero casts, at most KEEP_RESERVE more particles alive.

## Sources
- jobq reel jobs 20261109-145212-03525 to 20261109-145334-10828 (21 of the 24; Gunslinger Very Low, Mage High and Tender
  Very Low were re-run as 20261109-161037-15822, 20261109-161040-27593, 20261109-161043-31568). Each `out` dir has 5 ability sheets.
- After the `keep` tags, Very Low again: 20261109-154921-04896 (Archer), 154924-27224 (Ashwick), 154928-30156 (Kael),
  154931-18899 (Rimewright), 154934-01551 (Tender). `lowpreset_read/rimewright_dash_keep_before_after_high.jpg`: Rimewright's
  Shift at Very Low before (top), after (middle) and at High (bottom). The shards and stars come back; the big frost haze at High is
  not from a Hero VFX layer, and stays a Very Low loss (decor: the frost slab that marks the path is a mesh and stays).
- The Very Low and High renders are of separate runs, so the ground (grass, desert) and weather differ between rows.
- `--perf-bench --bench-secs=30` ran on the GPU at both presets without a gate failure (20261109-154937-25241 Very Low, 154941-05450 High;
  different workers, so the frame times do not compare, particles at the peak do: 452 against 1588).
