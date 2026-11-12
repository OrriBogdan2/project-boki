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

## Knock and hit-feel reds (ext/feel-w0246-knock-reds)
Each check run alone (xvfb, opengl3, 600 s): all four were cross-branch stale asserts, no game bug. Checks fixed, game code untouched.
- knock-chain (script error, so it hung to the timeout): the reel fixture read `rmb.gap`; feel-grimble-reel renamed it `stop_gap` and DredgeKit builds the gap as both radii + stop_gap. The fixture now builds it the same way. Then 1 red: "Grimble reel -> Storm Rod into a wall wall-stuns". The content data wins: Storm Rod's full push is 6.6 m/s (sparkle-rmb-knock, in main; feel-knock-override's base had 9), under Hunter's 8 m/s wall-slam speed, so it never slams, alone or chained. The wall row expects a slam only from a knock over 8 m/s (Kael/Albert and Vex still must).
- launch-arc (5 red): feel-launch-arc was written on a base with no PadFlight and the old low air control. Decision 0024 plus the DECISIONS 11-08 line ("jump-pad and updraft auto-glides are unchanged") back PadFlight's glider opening by itself at the apex. The owner's 11-08 "real matches HAVE air control" backs Loco.air_step. So the throw is measured from launch to apex: travel 4.5-7 m, reversed keys turn it back (<= -3 m/s), sideways keys carry it >= 3 m aside, auto-glide >= 1. The dash ratio holds (2.2x). The updraft "no glider, no lift" row is dropped: it contradicts 0024, and --pad-check asserts the opposite. docs/MOVEMENT_FEEL.md "Launch arcs" updated to match.
- impact-weight (1 red, ashwick LMB dealt nothing): feel-point-blank starts the lance's flame at Cinder's body (ShotOrigin). feel-impact-tiers' 20-step tap let go before the flame reached the dummy 3 m off. The LMB hold is now LMB_HOLD 40 steps. The point-blank rule is kept.
- hitstop-input (parse error, timed out): feel-impact-tiers removed Feel.HITSTOP (T0-T5), so the injected freeze is ImpactWeight.hold_s("heavy"). Gil, the 13th Hunter, came after the check: added with Riptide (E) as his top own-body hit.
- Not this group, seen on the way: --pad-check still says "keys barely steer the rise (air_control 0.015)", and its RISE_DRIFT 0.6 m contradicts Loco.air_step (5 m sideways by the apex). Its move-feel doc line in MOVEMENT_FEEL "Jump pads and updrafts" says the same.
