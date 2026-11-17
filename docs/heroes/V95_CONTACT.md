# v95 swap: does the strike pose still meet the hit? (`--contact-check`)

The v95 swaps (Vex, Cinder, Sable, Kael, Albert, Meeko, Motley, Neve, Sparkle) moved new bodies onto each rig "with clips and
anchors kept". This is the re-measure. For each Hunter: LMB, RMB and one signature move.

**How it is measured** (`tools/contact_check.gd`, run with `--contact-check`). The kit's hit is read from the kit (column
"Kit hit"), the clip time the game shows at the hit is `hit + lead` (`content/rules/warden_anim/<art>.json`, `WardenClips._pick`).
The GLB is then sampled in game (Hunter model, its clips, the Muzzle = weapon tip) every 1/60 s. The clip's own contact is its
strong tip stroke: a local peak of the Muzzle's speed against the body (at least 40% of the fastest in the window, which runs from
the clip's start to 0.35 s after the hit), from the peak to where the tip has slowed to 25% of it. **Bar: the hit lies within
0.05 s of that stroke.** "Tip off" is how far the tip is at the hit from the nearest frame of the stroke (m). A clip whose tip never
moves faster than 4 m/s (a smooth reach: Meeko's seed and lantern) has no snap to measure and is read as on contact.

Limits: the tip-speed stroke is a proxy for "the contact pose", not the clip's authored key, and the first two frames (0.033 s) of a
sample are skipped (the first frame jumps), so a hit at 0.0 s reads at best 0.033 s off. Kit hits are read from the kit code by hand.

**Did the swap move anything?** The same check on the pre-swap `.glb` of each Hunter (parent of the first v95 commit): every strike
window it could measure (Vex, Sable, Albert, Meeko, Motley, Neve, Sparkle; 21 moves) starts at the same frame as now (Sable's Bola 0.400 s against 0.350 s now, both ending at 0.417 s), so the
swap kept the clip timing. Cinder's and Kael's pre-swap files do not load with today's clip setup (no `Warden/Sync`), so they
have no before/after; their rows below are measured on the current files only.

Result: 27 of 27 PASS. Albert's Shield Slam was 0.250 s off and is fixed in data (`lead` 0.25 in breaker.json). Vex's Cinderfall (X) and Motley's Swap (E)
were fixed by re-timing the clip keys, not the kit (`FIRE_T` and the press-time lob are the source's): Vex's `x` holds READY to 0.06 s and snaps the cannon up by 0.14 s (the shell's
frame; it was up by 0.1) and squashes at 0.18 (`tools/art1/vex_clips.py`); Motley's `swap` throws by 0.033 s, with the coil left to the `swap_aim` hold (`tools/art1/ostra_clips.py`;
a `lead` 0.1 had failed `--ostra-combo-check`, this keeps it at 0 so the body hands back as before). Both clips were rebuilt on the shipped .glb with `tools/art1/rebake_from_glb.py` and
copied in with `glb_add_clips.py =x` / `=swap`; every other clip is byte for byte the same. Not changed: `swap_air` (the air lob) still throws at 0.167 s against the same press.


## Vex (gunslinger, art/wardens/vex/vex.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `gunslinger_lmb` (lmb) | 0.00 s, shot leaves on the press | 0.00 | 0.000 s | 0.033..0.033 s | 0.000 s | 0.071 m | **PASS** |
| RMB | `gunslinger_rmb` (rmb) | 0.00 s, Burr leaves on the press | 0.00 | 0.000 s | 0.033..0.050 s | 0.033 s | 0.208 m | **PASS** |
| X | `gunslinger_x` (x) | 0.14 s, `GunslingerUlt.FIRE_T` | 0.00 | 0.140 s | 0.083..0.117 s | 0.023 s | 0.107 m | **PASS** (was 0.057 s off: stroke 0.033..0.083 s) |

## Cinder (ashwick, art/wardens/cinder/cinder.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `as_lance` (lance) | 0.20 s, first stream after the 0.2 s spool | 0.00 | 0.200 s | 0.133..0.183 s | 0.017 s | 0.003 m | **PASS** |
| RMB | `as_shot` (shot) | 0.00 s, cinder leaves on release | 0.00 | 0.000 s | 0.033..0.050 s | 0.033 s | 0.143 m | **PASS** |
| E | `as_cloak` (cloak) | 0.00 s, blast on the press | 0.00 | 0.000 s | 0.033..0.083 s | 0.033 s | 0.240 m | **PASS** |

## Sable (thief, art/wardens/sable/sable.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `thf_lmb_r` (lmb_r) | 0.00 s, bolt leaves on the press | 0.00 | 0.000 s | 0.033..0.050 s | 0.033 s | 0.731 m | **PASS** |
| RMB | `thf_bola` (bola) | 0.40 s, `bola.cast` | 0.00 | 0.400 s | 0.350..0.417 s | 0.000 s | 0.000 m | **PASS** |
| E | `thf_knife` (knife) | 0.12 s, `m.later(0.12)` throw | 0.00 | 0.120 s | 0.100..0.150 s | 0.000 s | 0.000 m | **PASS** |

## Kael (juggernaut, art/wardens/kael/kael.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `jug_slash_r` (slash_r) | 0.00 s, `_strike` on the press | 0.00 | 0.000 s | 0.033..0.083 s | 0.033 s | 3.134 m | **PASS** |
| RMB | `jug_slam` (slam) | 0.60 s, `rmb.windup` | 0.00 | 0.600 s | 0.600..0.617 s | 0.000 s | 0.000 m | **PASS** |
| LMB held | `jug_wave` (wave) | 0.00 s, wave leaves on release | 0.00 | 0.000 s | 0.033..0.117 s | 0.033 s | 2.322 m | **PASS** |

## Albert (bulwark, art/wardens/breaker/breaker.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `bul_smash` (lmb_slam) | 0.00 s, `_strike` on release | 0.00 | 0.000 s | 0.050..0.083 s | 0.050 s | 1.805 m | **PASS** |
| RMB | `bul_slamshield` (shield_slam) | 0.00 s, cone on the press | 0.25 | 0.250 s | 0.250..0.317 s | 0.000 s | 0.000 m | **PASS, fixed: `lead` 0.25 (was 0.250 s off)** |
| X | `bul_ult_slam` (x_slam) | 0.00 s, `_strike(0)` on the slam | 0.00 | 0.000 s | 0.050..0.100 s | 0.050 s | 1.334 m | **PASS** |

## Meeko (tender, art/wardens/pip/pip.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `mm_shot_r` (shot_r) | 0.00 s, ember leaves on the press | 0.06 | 0.060 s | 0.067..0.433 s | 0.000 s | 0.000 m | **PASS** |
| RMB | `mm_seed` (seed) | 0.00 s, seed leaves on the press | 0.06 | 0.060 s | 0.267..0.533 s | 0.000 s | 0.699 m | **PASS** |
| E | `mm_hearth` (hearth) | 0.00 s, lantern lifts on the press | 0.15 | 0.150 s | 0.067..0.667 s | 0.000 s | 0.000 m | **PASS** |

## Motley (ostra, art/wardens/ostra/ostra.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `ostra_orb` (orb) | 0.00 s, orb leaves on release | 0.00 | 0.000 s | 0.050..0.083 s | 0.050 s | 0.187 m | **PASS** |
| RMB | `ostra_snap` (snap) | 0.00 s, shard leaves on release | 0.00 | 0.000 s | 0.033..0.050 s | 0.033 s | 0.924 m | **PASS** |
| E | `ostra_swap` (swap) | 0.00 s, lantern lobbed on the press | 0.00 | 0.000 s | 0.033..0.050 s | 0.033 s | 1.331 m | **PASS** (was 0.117 s off: stroke 0.117..0.150 s, tip 1.065 m) |

## Neve (rimewright, art/wardens/claire/claire.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `tm_dart_r` (dart_r) | 0.00 s, dart leaves on the press | 0.07 | 0.070 s | 0.033..0.083 s | 0.000 s | 0.000 m | **PASS** |
| RMB | `tm_spear` (spear) | 0.00 s, push starts on release | 0.00 | 0.000 s | 0.050..0.117 s | 0.050 s | 0.080 m | **PASS** |
| E | `tm_freeze` (freeze) | 0.00 s, freeze on the recast | 0.13 | 0.130 s | 0.100..0.117 s | 0.000 s | 0.000 m | **PASS** |

## Sparkle (mage, art/wardens/ryzz/ryzz.glb)

| Move | Kit move (clip) | Kit hit | `lead` | Clip time at hit | Strike stroke | Off | Tip off | Result |
|---|---|---|---|---|---|---|---|---|
| LMB | `mage_lmb_r` (lmb_r) | 0.00 s, round leaves the fingertip on the press | 0.00 | 0.000 s | 0.033..0.083 s | 0.033 s | 0.308 m | **PASS** |
| RMB | `mage_rmb` (rmb) | 0.00 s, bolt on release | 0.00 | 0.000 s | 0.033..0.050 s | 0.033 s | 0.361 m | **PASS** |
| E | `mage_e_snap` (sky_snap) | 0.00 s, snap on the press | 0.00 | 0.000 s | 0.033..0.050 s | 0.033 s | 0.000 m | **PASS** |
