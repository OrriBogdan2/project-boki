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

## Combo reds settled (ext/feel-w0246-combo-reds)
The five combo rows below (archer, ashwick, bulwark combo checks, air-cast, ally-cc) are all checks new in this wave, red against another wave branch or 0.24.5's code. Each row keeps the side the source or an owner note backs and fixes the other. Move-feel and camera rows are out of scope here.

| Check, row | Branch A | Branch B | Kept, and why | Fixed |
|---|---|---|---|---|
| air-cast: every LMB "no", every jump glides | parity-jump-pads (updraft opens the glider, decision 0024) | feel-air-casts (its test arena kept the map's updrafts) | jump-pads: decision 0024 | dash_flow_check's flattened arena drops updrafts and pads near it, as it drops walls/props/stairs |
| air-cast: Kael RMB | jugg-downslam (0.24.4: owner spec 11-10, Meteor Drop is a straight drop) | feel-air-casts row (footage read as a slide to the cursor disc) | owner spec 11-10 | row: zero/drop, verdict owner 11-10 |
| air-cast: Kael R, Vex E, Cinder LMB, Motley R "slow" | 0.24.5 Loco air model (owner 11-08 air control; a cast's walk slow caps the air speed; Vex E self_slow is game data) | feel-air-casts [?] rows, measured on a pre-Loco base | 0.24.5 code ([?] rows follow ours) | rows: slow |
| air-cast: Cinder R hover | 0.24.5 flight (eases down from the top) | feel-air-casts [?] row | 0.24.5 code ([?]) | row: push/slow |
| air-cast: Motley E, R "no" | air-cast-b (0.24.5: casts them in the air; data has no ground-only rule, as her glide rows) | feel-air-casts rows | air-cast-b: data | rows: cast in the air |
| air-cast: Gil missing | Gil (0.24.5) | feel-air-casts (based before him) | n/a | his rows added (ours, no source kit) |
| air-cast exit code | n/a | n/a | n/a | exits 1 on a failure (it exited 0 with 26 fails) |
| ally-cc: Tenzo R moves an ally | 0.24.5 Basalt Spine (an ally on the line steps aside: owner rule, the check's move_only exception) | feel-ally-safe (_excused splits effects on ", ", but the move text printed a Vector3) | spine: owner rule | the move text has no comma |
| archer: Lace draw rows (no damage) | feel-point-blank (shots sweep from the body, reach as the data: Empowered 12 m, longbow.json) | feel-hold-release-rules (dummy at 14 m) | point-blank: data | draw rows' dummy at 10 m |
| archer: Heavy Shot down mid-hold keeps the pose | feel-knock-moment (KnockMoment.cut cleared rmb_down itself) | feel-hold-release-rules (_drop_rmb + kit _rmb_dropped clears the pose) | both want the same rule (a knock cancels a held channel, source) | KnockMoment.cut goes through ArchKit._drop_rmb |
| bulwark: air Shift with the aegis up | 0.24.5 edfaf87cf (Shield Charge from the aegis in the air too: data, shielding + Shift = Shield Bash, no ground rule; owner item 183, air dash = ground dash) | combat-albert-aegis-input ([ours] lumber: "the Bash only seen on the ground") | 0.24.5: data + item 183 | check and bulwark.md row: the Charge |
| bulwark: stun mid-hold keeps the guard pose | feel-hold-release-rules (a stun drops the hold through _drop_rmb, no release) | combat-albert-aegis-input (pose cleared through the old release) | both: no hold pose without the hold | BulwarkKit._rmb_dropped lowers the aegis, ends the pose |
| ashwick: cloak rank 3 +80% | the check compared raw shields; a level gained between the two blasts (LevelGrowth, 0.24.5) raised max health | most likely feel-point-blank's longer lance holds in the same check (0.7 to 0.8 s, more XP earlier). Not confirmed: wave commits between the merges hang or fail to compile | data rank_shield 1.8 | the assert compares shield shares of max health |

Checks on the stacked tree: --archer-combo-check 176/0, --bulwark-combo-check 185/0, --ashwick-combo-check 131/0, --air-cast-check 0 fail, --ally-cc-check 12/0, --knock-moment-check 0 fail.
