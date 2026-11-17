# Item 185b: mantle findings (physics lane, 2026-11-07)

Owner report: "the mantling on the side of the cliff/edge def isn't working yet". Owner clarification: in SUPERVIVE a mantle is
not a climb or a grab. You carry momentum into a ledge while airborne and get pulled up and over, keeping your forward
speed, in one motion.

## SUPERVIVE's model next to ours

| SV setting (supervive_physics.md) | SV value | Ours before | Ours on ext/phys-185b-mantle |
|---|---|---|---|
| MantleSuctionUpwardsForceHeightMax | 1.5 m | MANTLE_REACH 1.5 | unchanged (double-high ground stays out of a jump's reach, LAYOUT_RULES) |
| bAllowsMantlingFromAbyss | true | MANTLE_REACH_ABYSS 4.5 | unchanged |
| MantleSuctionForce (pull toward the ledge, scaled by speed) | force model | keys into the face within ~60 degrees | keys within ~63 degrees, or with keys idle, momentum into the face at >= 2 m/s (MantleCarry.pushing) |
| MiniMantleXYSpeedTargetCoefficient / Min | 0.6 / 3.5 m/s | over the lip: max(0.6 x run speed, 3.5): the approach speed was thrown away | over the lip: max(0.6 x approach speed, the old launch), capped at the approach speed (MantleCarry.exit) |
| MiniMantlePostLaunchDuration | 0.75 s | not modelled | that speed is held 0.75 s while airborne and your keys don't pull back (MantleCarry.step) |
| MiniMantleForwardForceSpeedDeltaMultiplier | 8 | not modelled | held firm instead of a force (air drag otherwise takes it straight off) |
| MantleSuctionUpwardsForceZSpeedCap | 2.5 m/s | rise 14 m/s (LRISE_SPEED, footage) | unchanged: the footage shows rim-to-top in ~0.2 s |
| bCanWallJump (tall-ledge climb) | Myth, Brall | climb_tall: archer, juggernaut | unchanged |

## Repro on the shipped map (--cliff-mantle-check)

The Hollow Crown on the Meadow and Dusk Isles tiers. It covers straight non-sheer terrace faces two terraces (1.6 m)
and four terraces (3.2 m) high, and lipped island rims. Thief, Gunslinger, Juggernaut, Mage and Dredge play each case as
a player. The before column is ext/phys-integrated 38dde07c; main 7907d9af gives the same numbers, since 149 doesn't
touch this.

| Approach | Before: topped, speed in -> over the lip | After |
|---|---|---|
| 1.6 m face, running jump head-on / 30 / 60 degrees | 80/80 each, 4.6 -> 4.6 | same |
| 1.6 m face, jump then air dash into it | 80/80, **10.5 -> 4.5 (0.43x), 0 of 80 keep 0.6x** | 80/80, 10.5 -> 6.3, 80 of 80 keep 0.6x |
| 1.6 m face, glide in | 80/80, 7.2 -> 5.1 | same |
| 3.2 m face, any jump or dash | 0 (by design: double-high ground) | 0, now asserted |
| 3.2 m face, glide in | 150/150 | same |
| island rim from the abyss, heading in | 160/160, 5.5 -> 4.6 | 150/160 topped, 140 of 150 keep 0.6x (still above the check's 90% bar; the 10 misses aren't explained yet) |

- Head-on, you stop at the face for ~0.17-0.2 s while you rise. The wall cancels the into-face speed, and the speed comes
  back over the lip. In SV footage rim-to-top also takes ~0.2 s, with no visible pause.
- My first probe said 60-degree approaches fail. That was the probe's run-up geometry, not the game; they top 80/80.

## SUPERVIVE footage

- **owner_mantle_clip.mp4, 17.9-18.6 s (confirmed).** The player glides in the abyss below a rim, then dashes at the
  island (purple dash trail). They cross the rim at ~18.3-18.4 s and are on the grass by 18.5-18.6 s, still at dash-trail
  speed. No stop, no climb pose, no effect. Rim to top is ~0.2 s.
- **owner_mantle_clip.mp4, 32.0-32.2 s (likely).** The player crosses a raised stone terrace rim with no visible pause.
  The height is hard to read top-down.
- **sv_joule_1v4.mp4, 9.1-9.4 s (likely, an enemy).** It glides up out of the abyss onto a low rim, head-on and slightly
  slanted. It overlaps the rim at 9.20 s and stands firing by 9.27-9.5 s: ~0.2 s, same speed, no animation. At 8.1-8.6 s
  the same hunter is thrown back off that rim, but by a hit (pink ring), not the ledge.
- **sv_tetra_guide.mp4.** No mantle: the guide is ~95% training room, and its traversal is flush.
- **ext/hero-ref-footage.** Only Pin's double-wall jump climb (pin 41-44, 52-56), her passive, not the general mantle.

## The change (ext/phys-185b-mantle, on ext/phys-integrated)

- New `scripts/match/mantle_carry.gd`. `hunter.gd` gets the wiring: three vars, one call in `_physics`, the catch
  condition, the speed carried into the rise, the exit over the lip, and a teleport forgetting the carry.
- `--cliff-mantle-check`: the table above, asserted (it fails on 38dde07c: 0 of 80 dashes keep 0.6x).
- `--mantle-clip`: GPU before/after clips (jump, dash, abyss).
- Not changed: MANTLE_REACH (1.5) and JUMP_V. By the coordinator's ruling, double-high ground needs a glide, a launch,
  an ability or the abyss.

## Clips (GPU, pc-MRROBOTO, match camera, 15 fps, before | after side by side)

/home/boki/clips/185b/mantle185b_{jump,dash,abyss}.mp4, plus a contact sheet for each in sheet_*.png. Jobs
20261107-002904-09394 (before, 38dde07c) and 20261107-002904-06694 (after, bac078b6; branch tip cc3212ae has the same mantle code).
- jump: the same in both (4.6 -> 4.6).
- dash: before 10.5 -> 1.7 m/s over the lip (it stalls at the face); after 10.5 -> 6.3, carried onto the platform.
- abyss: the same in both (5.6 -> 4.6).
