# 0.24.6 wave 1 (feel): merge notes

Branch ext/w0246-feel on ext/release-integ-0245 (92df78ce4). Plan: docs/MERGE_PLAN_0246.md (ext/merge-plan-0246). Net.VERSION untouched (remove-hex drops the "hex" event and vfx-glider-heat adds glider heat bits 19-24 to the hunter flags: the combine must bump it).

Counts (91 rows): 80 in (77 merged, 3 carried: feel-camera-lead via feel-camera-frame, feel-wall-slide via feel-dash-wall-slide, feel-camera-frame merged early), 8 held, 3 superseded/already in 0245 (feel-aim-steady, move-parity-1, sfx-dash-per-hunter-rebased: 53a365770 already in; the rest is ext/mc-20261110-0630).

-rebased branches that drag in a merge candidate were merged from their own commits: feel-dash-off-ledge 04c0748b2 + cherry-pick 2e18d908d; no-dash-bursts-audit-rebased 76cd0bbac + cherry-pick 45bff0013.

## Held
- feel-cam-dash: trailing dash camera vs feel-camera-fast's locked follow (its READY says pick one); owner pick.
- feel-facing-turn-rebased: FACE_TURN 5400 deg/s (footage) vs HunterMove.turn_rate 1280 (game data, move-parity-1 11-10); owner pick.
- feel-landing-carry: UE low air control vs owner 11-08 strong WASD air control (Loco.air_step).
- feel-summon-on-g, feel-summon-press-rebased: G-key/wisp rework against KinKeys, kin_command, perf_bench zone budgets, wisp_check; over 30 min, better in the boki wave.
- glider-heat-parity: game-data heat and swoop vs owner GLIDE_TIME 9 s and item 8 (no swoop speed); owner pick.
- vex-dash-parity-rebased: eased Shift and lime palette replaced in 0245 (fitted curve, ember); one charge and rifle falloff need a fresh port.
- feel-utility-move: stacked on ext/util-tonic-lamp (not in this wave), 21 conflicts incl. hollowcrown.json.
- feel-reversal: merged, then reverted: its friction-turn walk broke the WASD direction, turn and slow/haste rows.

## Resolutions that pick one side
held-fire-resume over combat-albert-aegis-input's button-up latch (aegis and hold-release asserts follow held fire); 0.24.5 code kept over glide-double-press, dash-glide-all (DashGlide dropped, per its READY), fps-feel, feel-slow-ramp (cap_brake = brake_rate), feel-brake-cast, dash-curves-b's Sable curve (Albert's curve kept), grimble-reel's arm speed (owner 17 m/s + coil; reel 9 m/s and stop_gap kept), feel-cam-dash. dash_flow "glide" doc list renamed glide_rows (glide is glide-cast-rules' table). Inline main.gd checks from step-up and train-inertia went to the registry.

## Suite (each check alone, xvfb, opengl3, -j10, vs the same run on 0245)
Final tree rerun of every red: NEW-RED: --air-cast-check --ally-cc-check --archer-combo-check --archetype-check --ashwick-combo-check --bulwark-combo-check --cam-framing-check --cam-lead-check --camera-fast-check --cc-exit-buffer-check --cinder-art-check --dancer-combo-check --dash-aim-check --dash-jump-check --dash-slope-check --dash-wall-check --dredge-combo-check --fps-feel-check --glide-cast-check --glide-hit-check --gunslinger-combo-check --heart-check --hero-combo-check --hero-title-check --hitch-check --hitstop-input-check --impact-weight-check --knock-chain-check --launch-arc-check --mage-combo-check --move-feel-check --move-fx-check --pad-check --pickup-reach-check --rimewright-combo-check --same-frame-check --support-check --train-check --train-ride-check --tutorial-fight-check --ultbond-check --wallmove-check --yaw-lock-check 
Most are cross-branch: rows one branch asserts against another branch's rule in the shared move-feel, combo, dash and camera checks. camera-fast: the camera updates before the steps (feel-aim-steady, in 0245), so a teleport or Wirerun shows one frame off centre. 600 s timeouts (cam-framing, dash-aim, glide-hit, heart, hitstop-input, knock-chain) need a rerun alone.

## Camera (ext/feel-w0246-camera, stacked on this branch)
The camera reds came from three branches, each with its own rule: feel-aim-steady (in 0245) moved `MatchCam.update` before the steps, so the view followed where the *last* frame drew you; feel-camera-fast locked the across follow on the stepped body; feel-camera-lead measured a dash trail against the old 15/s follow.
- **Picked: the camera follows the stepped body (feel-camera-fast's side).** `MatchCam.update` now runs once, after the fixed steps, at the frame's own alpha. Why: MOVEMENT_FEEL says only the camera and animation read the frame time, on top of a fixed 60 Hz step, and the local body is drawn at the present (`render_pos`). A camera that runs before the steps draws this frame's body with last frame's view, so it can never be on you on the frame you jump (Ostra's dash 30% off, the Abyssal Hand reel 7.6%). The source footage keeps the view locked across (cam_lag_m 0.00). No decision under docs/decisions covers the camera.
- **Kept feel-aim-steady's intent another way.** `MatchCam.steady_aim` runs before each step. It reads the cursor again against the camera moved by `CamRig.follow_shift`, the move `follow` will make once the frame's steps are done (the body is predicted along its velocity by the frame time not yet stepped). So rounds still leave on the reticle as drawn: worst 0.12 m at 15 m, against 0.36 m with the camera after the steps and no re-aim.
- **feel-camera-lead:** its cursor rows (no lean, no drift after a flick) stand as they were. Its "the view trails the dash" row measured the 15/s follow that feel-camera-fast replaced, so it now asserts the locked rule: the view stays within 0.1 m of the running lag through the dash, with no frame jump over 0.5 m. Not taken: a dash-only catch-up like the source's 0.4-0.5 s, kept inside camera-fast's 8%/3% bands. That is an owner call on the footage.
- `--cam-framing-check` / `--cam-framing-shots`: the merge kept main's registry rows for a file that feel-camera-frame renamed to `--camera-frame-check` (648687921). The stale rows are dropped. Prove the framing with `--camera-frame-check`.
- `--dash-aim-check` steady rows: these were stale fixtures, not a game bug. The check called `_mouse_aim()` without the cursor argument the merged code needs, and a practice-area panel (`hud.ui_extra`) sitting over the top of the square headless view swallowed the fire button (0 rounds).
- `--move-feel-check`: the 8-direction rows now clear wild mobs. The camera order moved the wild spawns, and one walked into the W row (150 deg off). The rest of its reds are unchanged: 12 here, 14 on this branch without the camera change, none new, camera rows all ok.
- Checks (rpc5, headless): `--camera-fast-check` 0 fail (Ostra 30.5% -> 0.0%, reel 7.6% -> 0.8%), `--cam-lead-check` PASS, `--camera-frame-check` 0 fail, `--dash-aim-check` 0 fail (5 fail with the re-aim off), `health.py --strict` OK, `gen_wiki.py --check` OK (Rules.md regenerated: stale on the merge).
