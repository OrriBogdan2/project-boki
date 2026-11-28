## Sable and Motley re-check on main d49f4f321d (2026-11-23, branch ext/parity-recheck-sable-motley)

Every Sable (`thief`, source ref-thief) and Motley (`ostra`, source Void) row of this file and of `docs/heroes/{thief,ostra}.md` was re-read against `content/archetypes/{thief,ostra}.json`, `content/weapons/{arc_bolts,tether_lantern}.json`, `content/rules/{dash_feel,kit_parity,hunter_move}.json`, the kits (`thief_kit.gd`, `ostra_kit.gd`) and the commits to them since the last full read (11-12, main 88b06b9e7), with the 11-15..11-22 merges as the focus. This note supersedes the stale numbers in the older rows above (listed under "Rows now stale").

Owner rows left alone: Sable Bola pair stun 0.9 and slow 30% (item 53), the air Cartwheel = the ground one (item 183), quick bolts after the Vault (11-11), 2 Marks on the empowered hit; Motley orb range 12.25 m and Trade drift 67.5% (owner 11-10), LMB charge (items 60, 117), RMB cd 10 and wind-up (item 40).

### Drift, with the commit that moved it

| # | Number | Was (doc / source) | Now | Moved by | Reason | Action |
|---|---|---|---|---|---|---|
| 1 | Sable Vault recharge | 5 s (D Quickflip 5 s @IV, no cooldown upgrade; `a9d07cc94b`, 11-12) | 4.5 s | PR #49 merge-batch-1113 `f851f083bf` (11-13) took the older 4.5 back; `679b010fc5` (11-14) then dropped the kit_parity row ("owner call which source wins") | none found: no owner item, no source line says 4.5 | **fixed**: `dash.cd` 5.0, row restored, `Vault recharge stays 5` green again (was red on main) |
| 2 | Cartwheel distance in `--dancer-combo-check` | 4.5 m | read 5.1 m at 0.55 s (red) | `23343e0bb6` (11-16): the ground long dash is no longer cut at 0.12 s, so keys held run on 0.07 s at her hasted run after the 0.48 s flip | the kit is right (felt dash 4.67 m ground, 4.50 m air, `--move-feel-check` ok); the check measured past the flip | **fixed in the check**: distance read when the flip ends (tolerance 0.6 kept) |
| 3 | Cartwheel curve ("open" row above, `VAULT_CURVE` rms 27% vs the dash-curves-b fit 14%) | open | closed: the fit is data, `dash_feel.json` `thief.curve` [[0,0],[0.36,1.84],[1,0.25]] (`d7e9241995`, 11-09); `VAULT_CURVE` no longer exists in `thief_kit.gd` | `d7e9241995` | the port the open row asked for was done in 11-09/11-10 | row closed. In a clean run: peak at 0.362 of the dash, 1.767x the mean, exit 0.679x, distance 1.042x, time 1.007x |
| 4 | `--move-feel-check` Sable rows | green on 11-12 | 6 red: `dash_curve_thief_peak_u/_k/_dist/_time` (0.100, 1.547, 0.429, 0.521) and `vault_exit_run` 0.479, `vault_slow_frames` 9 | `23343e0bb6` (11-16: the cut only runs when she was aloft at the press) and `5b1b8f6913` (11-17: haste moved to `speed_bonus`, the exit row still divided by the unhasted run) | the curve rows pressed the dash in the first step after a kit swap, with her not yet grounded, so the flip was cut at 0.25 s; the exit row's run was 1.18x too slow | **fixed in the check**: 30 settling steps after the swap (as `_vault_exit` has), exit run uses `move_k() + speed_bonus()`. Clean run: all Sable rows ok, 0 failures. The full run still shows `vault_exit_run` 0.406 and `vault_slow_frames` 11: state left by earlier rows (the same rows pass alone), not Sable data; left |
| 5 | Dagger range | 14 m (KIT_PARITY row, `thief.md` E rows) | 15 m, `kit_parity.json` locked (tol 0.5) | `509c64d23a` (11-16): frame re-read 284 px / 34 px = 15.0 m (16.2 on 11-11, 14 after the 11-11 merge) | parity (frame read) | none; `thief.md` text fixed. Speed 40 m/s, slow 50% for 2.5 s, cd 15, 6 s recall, refunds 0.25 / 0.5, 5 ghosts: unchanged |
| 6 | Bola damage | 5 and +13 for a pair | 3 and +6.1 | `83386bb77c` (11-11): the source's share of the target (Chain Bolas 46 and +94 on 154) | parity | none; `thief.md` text fixed (Scaling, RMB rows). Range 7, wind-up 0.4, Ground 1.5 s, slow 30%, pair stun 0.9, lane 1.8, cd 7, bounces 1: unchanged |
| 7 | Encore (ring of blades) | ring 2.3 to 5.4 m | grows evenly from 0.3 m to 5.4 m in 0.4 s; 10 blades at 0.2 s over 2 s; 4.5 each, 7.6 from the outer band (past 4 m, rim 0.75 of reach), blight 6 s; cd 24 | `67feb8b9a3` (11-12, the 0.3 m start), `83386bb77c` (damage); looks `ffbdad145a` (11-20) | parity (footage grow) and the damage share | none; `thief.md` row fixed |
| 8 | Marks | "knock heals 15% extra" | 20% extra, 25% in all; +1.3 flat per Mark | `bb98efbc5e` (11-12), undone by a merge, back with `e24c3fb3cb` (11-14) | owner 11-12 spec | none (stale text only) |
| 9 | Empowered bolt knock | 3.0 (0.47 m) | 0 | `fcd6f69208` (11-20) | the card has "+214 dmg", no knock | none (row above already says cut) |
| 10 | Sable run cadence (`Sable timing run`, in `--dancer-combo-check`) | 2.3 Hz (sheet) | 2.51 Hz at 5.64 m/s (red by 0.01), 2.15 Hz in `--foot-slide-check` STEP at 5.39 m/s (planted, +0.2 cm a step) | `e060d2391a` (11-20: `foot_mps` run 3.18 to 3.55 to stop foot slide), body size 1.059 to 1.155 (`3a50a38abb`, 11-18), the Meshy-native glb (11-21) | foot-slide fit against the sheet's stride | **fixed 11-28 (ext/sable-run-cadence)**: see "Row 10: Sable's run cadence" below. The clip's run stride at `stride` 1.5 was the drift: fitted slide-free (`foot_mps` 3.55) it played 1.94 Hz. Run stride 1.5 to 1.37, `foot_mps` run 3.55 to 3.03 (back 2.7 to 2.4, side 2.56 to 2.29, refitted): 2.27 Hz at 5.39 m/s, +1.1 cm a step. The check now plans the forward run at the model's scale (it fed the raw match speed: 2.51 Hz for a 2.04 Hz run); the 3.00 Hz tree read was her aim-strafe loop. Data and check only, no glb change |
| 11 | Motley orb | 9 dmg, 14 m (older rows) | 14.5 dmg every 0.6 s, 12.25 m, prime +34% / x1.4 speed, slow 6% for 1.5 s | `a27412b9fa` (11-11, source share less the owner's held-fire loss), `0f6711d518` (11-10, owner) | parity and owner | none; `ostra.md` duplicate rows with 9 dmg removed |
| 12 | Motley Brimseed | 12.5 dmg, burn 8.2 | 23.7 up to 3.5x (83 at full), burn 16.2 a second at rank 3, waits at full size (no fizzle), cd 10, 9 m, 6.5 s, 3.2 m (4.2 m Swollen) | `a27412b9fa` (11-11), `4c8617fb5c` (11-09) | parity (365 share, 250 over 365) | none. The pop path (`ostra_kit.gd`) has had only looks and sounds since 11-15 (`7ab62c86a0`, `ad312331e1`, `bb434778b6`) |
| 13 | Motley Lantern Trade | circle 1.5 m, ally shield flat 26 | circle 1.9 m (`a8110b163e`, 11-11), shield 32.6% of health for 3 s (`38857f497b`, 11-12); 12 m, 1.8 s (1.25 s Swollen), drift 67.5% of speed, cd 9.5 | as listed | owner 11-10 (drift), source tier IV (shield) | none; `ostra.md` text fixed |
| 14 | Motley Nightwell | "level 6, 64s" in `ostra.md` | 70 s (data and the source; the 64 was a typo), tell 1.0, 3.5 s, r 3.6 (5.1 Swollen), pull 12, 10 m; cast turn locked after 0.25 s (`ec10a52fd2`, 11-19: 1280 deg/s matches the footage) | docs only; `d1afff4ecb` (11-22) is a close cue | none | `ostra.md` fixed; kit unchanged since 11-14 |
| 15 | Body | size 1.059 / 0.9, hit_r 0.384 / 0.412 | Sable size 1.155, hit_r 0.398, hit_h 1.7; Motley size 0.952, hit_r 0.434, hit_h 2.22 | `a8b4449e37` (11-15), `3a50a38abb` (11-18) | height chart (hurtbox parity) | none |

Not moved since 11-12 (re-read, same): Sable LMB 13 dmg, 0.45 s, 8.5 m (9.5 empowered), 37.5 m/s, walk x0.71 while firing; Vault 4.5 m in 0.48 s, haste +18% for 2 s, prime x1.34 and 2 Marks, window 3 s, i-frames 0.12 s, quick bolts 3 at 0.6x within 1.2 s; Bola, dagger and Encore as above; ranks. Motley Snap 13 m, wind-up 0.32 s, 18 dmg, stun 0.8 to 1.8 s, +44% Swollen, cd 10; Swell 9 s; Swollen Trade 1.25 s; ranks.

### Row 10: Sable's run cadence (2026-11-28, branch ext/sable-run-cadence, from main c78b7cba28)

Which number drifted: not her run speed (`hunter_move.json` thief 4.65 x body_scale 1.16 = 5.39 m/s, as every hunter) and not `foot_mps` on its own: `e060d2391a` fitted `foot_mps` 3.18 to 3.55 to the stride the run clip sweeps at `stride` 1.5 (2.78 m a cycle at match scale, --foot-slide-check STEP), and at that stride a slide-free run plays rate 1.23 on the 0.633 s cycle, 1.94 Hz. The sheet's 2.3 Hz at 5.39 m/s is a 2.34 m cycle. The fix shortens the run stride and refits the foot speeds to it, so the feet stay planted at the new cadence; the walk ring (`stride` 1.5, `foot_mps` 0.73) is untouched (its native walk FAIL +15.6 cm is on main, not this row).

The check (`Sable timing run`, `tools/thief_anim_time_check.gd`) fed the raw match speed into `WardenGait.plan`, which takes the speed at the model's own scale (WardenClips divides the draw scale out: 5.64 m/s is 4.58 there), so it read 1.23x too many cycles. It now plans with the model-scale speed, running straight ahead (60 frames in, so the blend is out of the idle), and prints the tree's own rate for information: in that test she faces the foe, so the tree plays her aim-strafe loop (blend (0.85, -0.53), 3.10 Hz), which is the fragment's "live read 3.00 Hz".

| Read | Main c78b7cba28 | This branch |
|---|---|---|
| `Sable timing run` (`--dancer-combo-check`, 5.64 m/s, model scale 4.58) | 2.51 Hz read (planner at raw speed); the run it plays straight ahead: 2.04 Hz | 2.38 Hz, PASS (band 2.1 to 2.5) |
| `--foot-slide-check` STEP thief (5.39 m/s, cycle 0.633 s) | stride 2.78 m, rate 1.23 (3.9 steps/s = 1.94 Hz), slide -0.5 cm/step | stride 2.33 m, rate 1.44 (4.6 steps/s = 2.27 Hz), slide +1.1 cm/step (bar 5.0) |
| `--foot-slide-check` --fit-dirs thief run (4.6 m/s) | f 3.55, b 2.70, l/r 2.56 (fitted) | f 3.03 cover 1.02, b 2.40 cover 1.01, l 2.29 cover 1.00, r 2.29 cover 0.98 |
| `--step-sync-check` thief | 10 ok rows, 162 rows 0 FAIL in all | same, 162 rows 0 FAIL |
| `--dancer-combo-check` | 194 checks, 1 failure (this row) | 194 checks, 0 failures |
| `--foot-slide-check` FAIL lines | 13 (thief: native walk +15.6 cm, native crouch +8.6 cm; none for her run) | the same 13 |
| `python3 tools/health.py --strict` | HEALTH OK | HEALTH OK |
| `python3 tools/gen_wiki.py --check` | out of date `Rules.md`, `Class-Stone-Seer.md#kit` (on main) | the same two, untouched |

Tried on the way: run stride 1.2 (fit 2.80, 2.47 Hz at the band's edge, and the back and side loops slipped 1.26 m/s), 1.3 (2.27 Hz read but +11.2 cm a step: slide-free it is 2.50 Hz). Open, not this row: her native walk and crouch slide (+15.6 and +8.6 cm a step, on main).

### Rows now stale in the older tables above

Sable: "E 14 m" (now 15), "Bola ... two foes stun .9 + 13" (+6.1), "Encore r 2.3-5.4" (0.3 to 5.4), "knock heals 15% extra" (20%, 25% in all), "Vault ... cd 5" is true again, "Ground Cartwheel curve | open" (closed, drift 3). Motley: "9 dmg every 0.6 s, 14 m", "12.5 dmg", "cd 64 s", "drift 30% / 35%" (67.5%), "1.5 m ring" (1.9 m).

### Checks

| Check | Main (5a246f9696, d49f4f321d for health and wiki) | This branch |
|---|---|---|
| `--thief-combo-check` (`--dancer-combo-check`) | 193 checks, 3 failures (Vault recharge 5, Cartwheel 4.5 m, stride 2.3 Hz) | 193 checks, 1 failure (stride, drift 10) |
| `--ostra-combo-check` | 279 checks, 0 failures | 279, 0 |
| `--card-numbers-check` | 344, 0 | 344, 0 |
| `--kit-parity-check` | 0 failures | 0 failures (one row more: `thief dash.cd` 5.0) |
| `--move-feel-check` | 19 failures | 15 failures (Sable curve rows fixed; the rest are other heroes and the walking brake, as on Lace's 11-22 branch) |
| `python3 tools/health.py --strict` | red: `check_registry.gd` long_line 0 to 1 (`66d289323f`, 11-22), then `camp_clear_check.gd` 0 to 1 on d49f4f321d | green: both comments shortened |
| `python3 tools/gen_wiki.py --check` | out of date `Rules.md` | clean |
