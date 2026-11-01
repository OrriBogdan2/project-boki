# Movement feel: targets, sources, measurements

The owner's note (Oct 31 2026): dropping, gliding and moving felt sloppy. SUPERVIVE is the bar: snappy and responsive, especially the glide, and Shift into a glide should give you more momentum.

Every target below is checked by `--move-feel-check` (`tools/move_feel_check.gd`). The check drives the real match step with scripted inputs. It counts fixed 60 Hz simulation steps, never wall-clock time, so a loaded machine can't skew it. It never touches the save.

```
XDG_DATA_HOME=<scratch> godot --headless --path . -- --move-feel-check
```

It prints one `MFEEL <key> = <value> target <op> <target> ok|FAIL (source)` line per measurement and ends with `MOVE FEEL CHECK DONE, failures: N`.

Source tags follow SUPERVIVE_FEEL.md / SUPERVIVE_DATA.md:

- `[wiki]` is supervive.wiki.gg.
- `[guide]` is a published guide (Deltia's Gaming gliding guide, ludo.guide).
- `[footage]` is a frame measurement from SUPERVIVE_FEEL.md.
- `[spec]` is docs/EXPEDITION_SPEC.md.
- `[est]` is our own estimate, tuned for feel and labelled as such.

Nothing here comes from SUPERVIVE's files.

## What the public sources say (and don't)

- **Glider momentum [wiki]:** "Gliding right after a lateral Impulse in the same direction keeps some momentum and increases glide speed." This works with dashes, relics, consumables and terrain. The wiki also says gliding "preserves momentum".
- **Air dashes [guide]:** mid-air dashes, jump pads and relics combine with gliding to go faster. Some hunters "dash mid-air before gliding for a fast speed gain".
- **Opening the glider [guide]:** you hold jump while already jumping or falling, and letting go closes it. No engage delay is published anywhere.
- **Abyss lift [wiki]:** a rapid upward impulse to ground level, then a rapid deceleration on arrival. Letting go before the top keeps the upward momentum.
- **Fall depth and glide speed [footage]** (SUPERVIVE_FEEL.md): 1s off an edge is ~8m deep. Glide speed is ~5 m/s, about run speed. The hunter stays roughly centred on screen.
- **Ground movement [spec]:** near-instant acceleration and deceleration (a 0.05–0.1s ramp). Camera follow smoothing is 0.08–0.15s.
- **Not published:**
  - Jump height or arc.
  - Glide turn rate.
  - Drop dive speed.
  - Whether jump height is variable. Nothing suggests SUPERVIVE has it, and holding jump is already the glide input, so **no variable jump height** was added.
  - Coyote time or buffer values. These use FeelConfig's 0.1s / 0.12s.

## Targets and results

"Before" is main at e7c7086, measured with the same check. "After" is branch `movefeel`.

| Key | Before | After | Target | Source |
|---|---|---|---|---|
| ground_input_frames | 1 | 1 | <= 1 step | press acts the same step |
| ground_t95 (to 95% run speed) | 0.083s | 0.067s | <= 0.07s | [spec] 0.05–0.1s |
| ground_stop_t | 0.067s | 0.050s | <= 0.06s | [spec] near-instant |
| ground_stop_dist | 0.10m | 0.075m | <= 0.2m | [spec] no slide |
| ground_reverse_t (180 degrees) | 0.150s | 0.117s | <= 0.12s | [spec] crisp |
| ground_turn90_t | 0.100s | 0.083s | <= 0.09s | [spec] crisp |
| speed light / medium / heavy | 5.2 / 5.0 / 4.73 | same | class data | KINFALL_CLASSES |
| jump_input_frames | 1 | 1 | <= 1 | |
| jump_apex | 1.28m | 1.28m | 1.2–1.6m | [est] one terrace + mantle |
| jump_airtime | 0.633s | 0.550s | <= 0.6s | [est] tight arc |
| coyote_frames | 7 | 7 | >= 6 | FeelConfig 0.1s |
| jump_buffer_frames | 6 | 7 | >= 7 | FeelConfig 0.12s |
| freefall_1s_depth | 6.37m | 8.69m | 7.5–9m | [footage] ~8m |
| glide_open_press_frames (second press) | 1 | 1 | <= 1 | [guide] |
| glide_open_hold_s (Space held from the jump) | 0.150s | 0.117s | <= 0.12s | tap/hold split |
| glide_open_button_frames (glide button) | 6 | 1 | <= 1 | no tap ambiguity |
| glide_catch_t (terminal fall to sink rate) | 0.383s | 0.133s | <= 0.2s | opens "instantly" |
| glide_speed / glide_sink | 5.0 / 2.2 | same | ~5 / 2–2.6 | [footage] / [spec] |
| glide_turn90_t | 0.617s | 0.200s | <= 0.3s | [est] |
| glide_reverse_t | 0.950s | 0.433s | <= 0.45s | [est] brake by steering back |
| glide_brake_ratio (10 m/s, 0.4s against vs let go) | 0.60 | 0.00 | <= 0.8 | brake stays |
| reglide_frames | 1 | 1 | <= 1 | |
| dashglide_reopen_frames | 1 | 1 | <= 1 | |
| dashglide_open_speed | 6.9 m/s | 10.35 m/s | >= 9 | [wiki] momentum + speed |
| dashglide_1s_speed | 5.7 m/s | 8.85 m/s | >= 7.5 | [wiki] preserved |
| dashglide_2s_speed | 5.0 m/s | 7.35 m/s | >= 6 | [wiki] preserved |
| abyss_lift_t (4m deep to balloon line) | 1.05s | 0.82s | <= 1.0s | [footage] ~1s |
| updraft_rise_t (to 8 m/s climb) | 0.333s | 0.233s | <= 0.3s | [est] powerful |
| drop_dive_vy_t (90% of dive fall) | 0.583s | 0.333s | <= 0.4s | [est] punchy |
| drop_dive_steer_t (90% of commanded) | 0.783s | 0.233s | <= 0.3s | [est] responsive |
| drop_deploy_frames | 1 | 1 | <= 1 | |
| drop_deploy_settle_t | 0.267s | 0.217s | <= 0.3s | [est] |
| drop_glide_steer_t | 0.583s | 0.217s | <= 0.3s | [est] |
| drop_land_dead_frames / land_dead_frames | 1 / 1 | 1 / 1 | <= 1 | no dead time |
| land_squash | 0.00 | 0.16 | >= 0.05 | landing reads |
| e2e_input_frames (key to sim, via Match._process) | 1 | 1 | <= 1 | |
| e2e_render_frames (key to model moving) | 2 | 1 | <= 1 | no interpolation lag |
| render_lag_m (model behind sim at a run) | 0.083m | 0.000m | <= 0.03m | |
| cam_lag_m (camera behind you at a run) | 0.65m | 0.29m | <= 0.40m | [footage] centred |
| cam_settle_t (after a stop) | 0.35s | 0.15s | <= 0.35s | |
| cam_glide_lead_m | -0.67m (trailing) | +0.70m | >= 0.4m | lead in glide |

Mantles are measured by `--mantle-check` and were not changed: 0.40–0.58s from a ledge, against [footage] ~0.8s from a full second deep.

## What changed (all in clearly marked `(movefeel)` blocks)

- **Input to screen:**
  - Input was already read and applied in the same frame. The local player is now drawn at the present: extrapolated by the fraction of a step since the last one (`Hunter.render_pos`, `LOCAL_RENDER_LEAD`). Before, it was interpolated up to a step in the past, so a press showed one frame later and the camera trailed.
  - Everyone else is still interpolated. A teleport snaps.
- **Ground:** acceleration 70 → 90 and deceleration 90 → 110 m/s².
- **Air:**
  - Air steering went from 22/3 to 40/9 m/s², so letting go in a jump stops you.
  - Speed above run speed (a dash, a pad, a knockback) still carries at the old 3 m/s².
- **Falls:**
  - The 3.2/s ease into a 9 m/s terminal speed is gone. Falls now use gravity x1.2 straight to 10 m/s, which matches the footage depth and tightens the jump arc.
  - The camera's soft vertical follow was kept, so a fall doesn't jolt the view.
- **Glider:**
  - New `glide_steer()`: turns at 420°/s at cruise, in wider arcs above cruise down to 45%. It accelerates at 20 m/s², and over-speed bleeds slowly (1.5 m/s²). Steering more than 115° against your heading brakes at 26 m/s². Letting go drifts.
  - The canopy catches a fall at 60 m/s² instead of 16.
  - Space opens the glider after 0.1s (was 0.15s), since a tap is a jump. The glide button (Mouse 5) opens it at once (`inp.glide_btn`, local input only, nothing new is synced).
  - The abyss lift's brake zone rises at 3.5 m/s per metre left (was 2), so the last metre no longer crawls.
  - Updrafts grab at 45 m/s² (was 30).
- **Dash into glide** (`glide_handoff(dir, speed)`, `_take_glide_handoff()`):
  - The Shift dash's end, and a jump out of a dash, register the burst.
  - If the glider opens within 0.3s heading within about 70° of it, the glider starts at 45% of the burst's speed (max 11 m/s) with a whoosh, a streak and a small camera punch.
  - Archetype dashes can call `glide_handoff()` as they end. If the glider is still open, it's spent that same step.
- **Drop:**
  - Dive fall 11 → 13 m/s, reached in about 0.3s.
  - Dive and canopy steering rates 3/4 → 10/11 per second.
  - Deploying checks your fall to -1.6 m/s (the canopy biting), then settles to 4.2 m/s in about 0.2s. It also gets the glider-open sound, a ring and a small camera punch.
- **Landing:**
  - Every landing faster than 4 m/s gets a brief squash (0.07–0.16), a puff of dust and a soft thud.
  - There is still no lockout. The drop's own landing feedback is unchanged.
  - Jump buffering now means "within 0.12s of the ground at your fall speed" rather than a fixed 0.9m, so it still works at the faster fall speed.
- **Jump:** a small dust kick on take-off.
- **Camera:**
  - Across follow 8 → 15 per second (about 0.07s). The spec band is 0.08–0.15s; the footage says you stay centred, and the owner asked for no lag.
  - Vertical follow is unchanged (3.5).
  - New glide lead: the view leans 0.2s of your glide velocity ahead (max 1.8m), eased at 3 per second.
  - The pitch, distance, FOV presets and cursor pan are unchanged.

## Not touched

- Dash kits (the archetype branch owns them). Only the generic `glide_handoff()` hook was added.
- The network protocol. Movement runs on the owning machine, and remote hunters still use `net_follow`.
- Landing performance (branch `landhitch`).
