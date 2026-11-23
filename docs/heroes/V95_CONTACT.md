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

## In-game drift: does the game load the approved v95 model? (2026-11-20, ext/v95-ingame-drift)

FINDINGS 11-14 found 3 of 13 approved 3D models missing from the game (Albert i1, Sable tilt cand_A, Cinder BA2) and no
tracker. The tracker is now `python3 tools/art1/v95_ingame_drift.py [--ref REF] [--md]`: per Hunter it takes the master
`~/meshy/v95` names (CURRENT_OVERRIDES.txt's last line for it, else `<Name>/current.json`, the rule `v95_to_game.py` uses)
and the `.glb` the game loads (`art/wardens/<art>/<art>.glb`, `WardenGlb.ART`), and compares git blob hash, triangles and
clip names. Exit 1 on any drift, so a later promote that never ships shows up. It needs a host with `~/meshy/v95`
(hetzner, rpc3); CI has none.

Result on origin/main 944be0a109: **13 of 13 match** (same blob, so same tris and same clips). "Mesh check" is
`tools/hunter_mesh_check.py art/wardens` on the same files (tris there are drawn per node, the tracker counts each mesh once:
Tenzo 61,175 vs 60,439).

| Hunter | current.json / override glb (`~/meshy/v95/_main/`) | game glb | blob | tris | clips | mesh check | match |
|---|---|---|---|---|---|---|---|
| Albert | `breaker_bcfdb0558a5.glb` | `breaker/breaker.glb` | bcfdb0558a5 | 62,483 | 60 | WARN | yes |
| Cinder | `cinder_b1903ec3580.glb` | `cinder/cinder.glb` | b1903ec3580 | 63,096 | 46 | WARN | yes |
| Gil | `gil_1e64b2ccbfd.glb` | `gil/gil.glb` | 1e64b2ccbfd | 63,000 | 0 (rig poses) | WARN | yes |
| Grimble | `dredge_cd012c4a01c.glb` | `dredge/dredge.glb` | cd012c4a01c | 62,713 | 45 | **FAIL** | yes |
| Kael | `kael_20f2d6917d5.glb` | `kael/kael.glb` | 20f2d6917d5 | 58,453 | 54 | WARN | yes |
| Lace | `hem_add555c3b6f.glb` | `hem/hem.glb` | add555c3b6f | 60,895 | 53 | WARN | yes |
| Meeko | `pip_25978c74933.glb` | `pip/pip.glb` | 25978c74933 | 61,293 | 47 | WARN | yes |
| Motley | `ostra_514a15fabfc.glb` | `ostra/ostra.glb` | 514a15fabfc | 60,051 | 49 | WARN | yes |
| Neve | `claire_d16bb7eaac7.glb` | `claire/claire.glb` | d16bb7eaac7 | 59,864 | 61 | **FAIL** | yes |
| Sable | `sable_5a037143304.glb` | `sable/sable.glb` | 5a037143304 | 60,261 | 59 | WARN | yes |
| Sparkle | `ryzz_83025eda48a.glb` | `ryzz/ryzz.glb` | 83025eda48a | 60,167 | 49 | WARN | yes |
| Tenzo | `tarek_5db6f1fdd5d.glb` | `tarek/tarek.glb` | 5db6f1fdd5d | 60,439 | 50 | **FAIL** | yes |
| Vex | `vex_fca9acc4961.glb` | `vex/vex.glb` | fca9acc4961 | 60,095 | 41 | WARN | yes |

**Read this with care: the match is partly by construction.** On 11-19 the coordinator pointed every `current.json` and
override line at a copy of main's glb ("owner said /v95 is out of date; page = the exact glb in the game"). So "13/13"
proves the v95 page shows what the game loads, not that the game holds every owner pick. The pre-sync picks the overrides
record ("replaced 11-19 by in-game sync") mostly have a matching main commit: Cinder `cinder-bust2-1118/game/r12_A2.glb`
(19,967,728 B, the exact size of `cinder.glb`; not on rpc3 to hash), Albert `face-albert-1118/final_A` (7acaed12d1),
Sparkle doll A (8de24530d1, #300), Grimble board1117 A (e117f2e7f0). Not traced: Lace eyes C and Neve board1117 B (their
masters are not on rpc3; `hem.glb` and `claire.glb` last changed 11-17 in e5f13f6492 idle rework and 5cd36e3a8c spear paint).
The 11-14 three are superseded by those later picks. No owner 3D pick after the 11-19 sync is in DECISIONS/OVERNIGHT_PICKS.

### Drift: next items

1. **Not merged: rig/weight fix branches that change the game glb** (when one merges, `current.json` must follow, or the
   tracker reports drift): `ext/hunter-fix-<art>-1118` for all 13 (17-108 commits behind main; Cinder 108, Meeko 55),
   `ext/anim-neve-wrist` (Neve right arm onto its bones), `ext/sparkle-3d-ta-1119` (neck joint, height 1.189x -> 1.159x),
   and four drafts that wait on the owner (`ext/rebuild-{dredge,ostra,sable}-1119`, `ext/rebuild-pilot-pip-1119`).
2. **Mesh check FAIL on live models**: Grimble (516 degenerate tris, 624 non-manifold edges), Neve (74 floating islands),
   Tenzo (518 non-manifold edges, 3,284 bad weight sums, 84 collapsed). These are the calibration FAILs the check was built on;
   the fix branches above target them.
3. **Gil has no clips** (0 animations; `warden_model_check` "moves": ""): the rig's generic poses play.
4. **Tracker in the promote flow**: run `v95_ingame_drift.py` after every `v95-promote` and every hunter glb merge; it is
   not in CI (no `~/meshy` there).
5. **`--warden-model-check` is red on main** (944be0a109, 170 checks, 22 failed; nothing here changes a game file): every
   failure is a height or width against the hero sheet, e.g. Gil 1.105x (sheet 0.79x), Meeko 0.807x (0.60x), Kael 1.066x
   (1.24x), Cinder width 0.69x (0.70..1.75). The 60k v95 swaps moved the bodies; the sheet targets or the models need a pass.
