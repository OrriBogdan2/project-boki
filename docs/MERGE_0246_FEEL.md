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

## Move-feel and dash reds (ext/feel-w0246-move-reds)
Each of these checks run alone, headless, on this branch: `--move-feel-check`, `--dash-aim-check` (was a 600 s timeout), `--dash-jump-check`, `--dash-slope-check`, `--dash-wall-check`, `--dash-frames-check`, `--dash-flow-check` all 0 fail. Camera, combo and other reds are not covered here.
- dash-aim: it timed out because the check didn't parse (`_mouse_aim` now takes the screen point). Its steady rows then fired 0 rounds: the kit drill's Skip bar (0.24.5) sits under the 15 m north cursor and takes the mouse. The rows now run with the drill already seen. Fixture only.
- dash-jump (the table rows are `[?]`, with no source data): ground and same-step carry is 0.75, from 0.24.5's single jump-out-of-dash rule (`dash.jump_keep`, 1240289a9), replacing the table's older 0.55. Space on Shift's own step took the standstill's speed (carry 0.05). Decision 0010's same-frame rule says it should act as if pressed after Shift, so `do_jump` now keeps the dash's velocity on that step (code). A press in an air dash is `end`: Space in the air is the glider's second press (owner 11-08, decision 0058). Mage on the same step is `buffer` (same-frame wind-up rule, 047b42a57). Dolm's rise is the new `hop` mode, because Rock Hop climbs (owner's rock-to-rock dash). Gil gets his rows.
- dash-slope (Dolm crest): decision 0046 (dash off a ledge) makes the Rock Hop skid fall off the crest. The HOPS allowance now covers the whole drop, for height as well as airtime.
- dash-wall: the wave merged feel-dash-wall-slide at 696e227f7 without its follow-ups. I cherry-picked 44b426787 (rock rows: deepest push-out first, swept long steps) and c0b44f7be (check rework; this also drops the Rock Hop DEBT line).
- move-feel:
  - The map respawns mobs during the long run, and late rows were knocked off course (WASD 153 deg, brake-cast, haste, felt dash, standing dash). `_reset` now clears mobs (fixture).
  - `glide_press_held_s` counted the canopy landing from a flat jump as a close; it now counts only a close in the air.
  - `jump_buffer_dash_frames`: a flat air dash (vy 0) never counted as about to land, so Space opened the glider. `near_landing` now also takes height-holding bodies within the buffer's fall (code; the 0.24.5 buffer rule wins).
  - `abyss_lift_t`: GunslingerKit played a phantom firing pose on a kit swap (`last_shot` started at 0), which locked the glider. Fixed in code.
  - Dolm `ledge_dash`: the dash-slope fix (Rock Hop flies longer off a drop to clear its rock, 2b42d7b1f, fixing a hop that landed 57% short) beats the ledge row's "lip >= run speed". The floor is now 0.6x run; measured 0.68-0.75x, and it still lands below with no air crash.
