# Merge audit, 0.24.6 waves

A running audit of the ext/w0246-* wave merges (plan: docs/MERGE_PLAN_0246.md on ext/merge-plan-0246).
For every merge commit M (parents P1 = wave, P2 = source branch, B = their merge base), every code line one side
added since B that is in neither M nor the wave tip is listed (tools: /tmp/audtool/lost.py on rpc5, a
stand-in for `git show --remerge-diff`, which git 2.34 lacks). Hits are then read by hand. Doc strings, docs/,
wiki, style baseline and Net.VERSION lines are skipped (each wave bumps Net.VERSION once).

Fixes go on ext/w0246-audit-fix (off the feel wave tip) and ext/w0246-audit-fix-misc (off the misc wave tip),
one commit per fix, with the source branch named.

## Pass 1 (2026-11-11 ~09:30-10:30 UTC): w0246-feel b4933b647 (78 merges), w0246-misc eb2b8857c (47 merges)

Then w0246-ui f88d90a3a (46 merges) appeared and was scanned too. combat-a, anim, boki, tutorial, garden, sfx, vfx: not on
origin yet.

### Fixed

| # | Wave | Source branch | What the merge lost | Fix |
|---|---|---|---|---|
| 1 | feel | ext/dash-curves-b d7e924199 | Sable's fitted Cartwheel curve: the thief_kit `curved` dash, the dash_feel.json `thief` curve and the 3 `dash_curve_thief_*` rows in --move-feel-check. The resolution kept 0.24.5's hand-set VAULT_CURVE (merge e1142afea) | The charge Cartwheel runs on the fitted curve on the ground and in the air (0.24.5's item 183 rule: the air one is the ground one), VAULT_CURVE/VAULT_MEAN deleted, rows back |
| 2 | feel | ext/fps-feel cbdde0a86 | All of its movement code (merge 52e12c542 took only tools/fps_feel_check.gd, which was then red: 20 FAIL at the wave tip, jump apex 1.517 m against the [game data] 1.573 m) | HunterMove.fall (gravity at the step's mean speed) and the exp-form dash steer. Its dash_end_step is not ported: 0.24.5's HunterMove.dash_rest already does the dash's last part step |
| 3 | 4 | misc | ext/telegraph-audit-b-rebased d42fe2ce6 | Its owner-rule ring cuts ("a ground ring means gameplay"): Tenzo's decorative fist, Molten Guard and blast rings, Breah's spine crack ring, Lace's ult self ring, and Tenzo's rock tell sized to the rock (`len * 0.5`, not 0.75). Merge e6a0de29c kept 0.24.5's dolm_kit (recoloured blue) and lost them | Cuts replayed on 0.24.5's colours |
| 3 | misc | ext/boki-state-clips 6791e0ddc | The resolution dropped its flinch layer (KinFlinch from 0.24.5 does the jolt) but kept `if _hit_k > 0.3: return "sad"` in BokiRig._clip_face: `_hit_k` is undeclared, so boki_rig.gd does not parse and every rigged Boki falls back | The sad face reads KinFlinch's jolt (`_flinch.jolt`) |

### Open (not changed here; owner or wave job to decide)

| Wave | Branches | Finding | Evidence |
|---|---|---|---|
| feel | ext/combat-albert-aegis-input 91c3dba10 vs ext/feel-held-fire-resume | aegis-input's "a press made behind the aegis is spent" (BulwarkKit.hold_blocked) is gone: held-fire-resume deleted the latch (owner top-15 #14: held LMB fires the moment a lock ends). Both claim PARITY FIRST. The aegis check (bjorn_aegis_input_check, run inside --archer-bulwark-combo-check) still asserts the old rule | merge 86f507083; 8b218660e restored only the guard pose. --bulwark-combo-check at the feel tip: 2 FAIL, both aegis-input rows (Shift held in the air raises the Shield Charge; a held RMB raises the aegis again after a stun) |
| feel | ext/fps-feel | Even with fix 2, --fps-feel-check keeps 9 FAIL (dash hold and knock distance across 1/30, 1/60, 1/144 s steps). The match always steps at Match.DT 1/60 s, and --fps-parity-check (ext/feel-fps-parity-check) drives the real Match._process at 30/60/144 fps, so this is a second check for the same property. Suggest retiring fps_feel_check (the owner's call: it would delete a check) | fps-feel-check log |
| feel | ext/feel-slow-ramp 4461103ce | --move-feel-check haste_land_0p1s 0.333 and haste_end_0p1s 2.498 (want 1.0). The slow rows pass; HunterMove.cap_brake is gone because 0.24.5's brake_rate walk is the same rule, so the haste rows fail on something else | move-feel-check at the wave tip |
| feel | ext/feel-brake-cast aed5121a9 | HunterMove.brake(h, hv, walk, ...) dropped for 0.24.5's UE ApplyVelocityBraking; its rows fail: brake_cast_gap_m 0.312 (want <= 0.05), thief stops 0.339 m under a cast vs 0.651 m plain | same |
| feel | ext/dash-glide-all 07957d143 | DashGlide dropped by its READY's own instruction (fec1e1b41); its rewrite of tools/airdash_glide_check.gd (52 lines) went with it, the 0.24.5 check is kept. Accepted | merge 3f59300e8 |
| feel | ext/feel-reversal | Held and reverted by the wave (790dbe6a3): its friction-turn walk broke the WASD direction rows. Accepted | |
| feel | tools/move_feel_check.gd | Order-dependent: a thief-only change (fix 1 alone) flips slow_land/slow_end vs haste_land/haste_end, brake_cast and other Hunters' standing-dash rows. Those rows read state an earlier section leaves behind, so their pass/fail does not say much. Worth a check-hygiene pass (reset per section) | three runs: wave tip, fix 1 only, fix 1+2 |
| feel | (move-feel-check at the wave tip) | 14 FAIL in total (15 with both fixes, a different set: see the row above), including the owner-facing glide_press_held_s 0.433 s (want >= 1.0: jump, let go, press and hold, the glider must stay open) and jump_buffer_dash_frames 3 (want >= 7). Not compared with 0.24.5 in this pass | |
| misc | ext/boki-state-clips | The merge commit also added 21 Godot `.import` files under docs/shots/cinder-bust and albert-appeal (editor output for doc images; docs/shots should not be imported) | merge 7e66135b8 --stat |
| misc | ext/perf-fight-pools 907d1f4e4 | Its bolt pool (Fx.bolt_pool, _make_bolt) is not in the merge; 0.24.5's Fx.bolt draws pooled beams, and perf_throttle_check was trimmed to match. Looks deliberate; no note in the wave | merge d02b24b52 |

Checks run on ext/w0246-audit-fix (feel + fixes 1-2), headless with --audio-driver Dummy: --move-feel-check 15 FAIL (tip 14; the Sable rows pass: peak_u 0.362, peak_k 1.837, exit_k 0.276), --fps-feel-check 9 FAIL (tip 20), --air-control-check 1 FAIL (item 7, worst step loss 82%; Sable's jump > Shift reach 7.0 m against a median of 8.7 m passes), --bulwark-combo-check 2 FAIL (aegis, above), health --strict OK. The tip was not run against 0.24.5 for these checks, so NEW-RED vs 0245 is not settled here.

### Checked and fine

UI wave: tonic and armor kit numbers kept through ui-belt-six's rewrite (42 HP, 1.0 s, kit move 0.45), the
legendaries close the Field Book (by tier), spectate cycle on Spectate, keybinds-1108 merged as SUPERSEDED (history
only) on purpose, the "hold Space to glide" loading tips gone (owner 11-08 double-press rule).

Feel and misc:

Kael's Lunge walk (cast-move-a: `hold_move` is 0.24.5's `walk_k` 0.8), Vex's needle turn lock (yaw-lock-12: one
GunslingerKit.aim_lock, 53bb881b9), --step-up-check and --train-ride-check (in the registry, not main.gd), the
Shift dash rule (dash_feel.json: 0.24.5's parity default 1.0/1.0 and the 0.85/1.15 rows kept; Albert's row is
1.0/1.0 as the parity default, not dash-curves-b's 0.85/1.15 from its older base), save VERSION 15 with every
migration 1-14, Grimble's hook (0.24.5's speed 17 + windup 0.2 kept, feel-grimble-reel's pull_speed 9 and stop_gap 0.1 taken), the Boki species and clip lists in boki_rig_check, boki_system_check's parts.
