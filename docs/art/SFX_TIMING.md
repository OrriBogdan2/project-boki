# Ability sounds against the strike (11-09)

Does each Hero's own fire / cast / impact sound land on what it belongs to? Measured by `--sfx-strike-check`
(tools/sfx_strike_check.gd) on main d255acbee plus this branch: every move of the 12 kits (LMB tap, LMB held
0.5 s, RMB tap, RMB held 0.5 s, E, R) pressed once in a real match at a dummy 3 m away, 60 steps a second.

- **strike**: the frame the faster hand moves fastest in the skeleton, as the clip is played in the match
  (blends included). A Hero with no clip on that move, or a hand slower than 8 m/s (a rifle's aim), has none.
- **hit**: every frame the dummy takes damage (the gameplay hit).
- Each sound is timed against the nearest strike or hit. Wind-up sounds (draw, aim, tell, charge, whirl, leap,
  prime...) belong before the strike and are not timed. Over 50 ms is listed. Re-run it for fresh numbers:
  `godot --headless --path . -- --sfx-strike-check [--strike-only=<arch>]` prints one `ROW` line per move.

## Fixed (sound now played by the event itself, asserted by --sfx-strike-check)

| Hero | Move | Sound | Was | Now | Change |
|---|---|---|---|---|---|
| Albert (bulwark) | LMB hammer throw | bjorn_throw | -67 ms (at the press) | +17 ms | plays when the hammer leaves his hand (`THROW_WIND`, the clip's release), not on the press |
| Tenzo (dolm) | E Stone Row | br_raise | own `m.later(tell)` timer | +0 ms on the first rock up | played by the first rock that rises; the separate timer is gone, so no sound when no rock rose |

## Over 50 ms, left as they are

All of these play on the gameplay event (the shot or the effect appears on that frame); what lags is the
clip, which reaches its strike after the shot is already out. Moving the sound to the clip would pull it off
the shot you see and hear land, so the fix belongs in the clip (an earlier key, or seeking into it) or in the
kit's release time, not in the sound. Listed for the animation pass.

| Hero | Move | Sound @ ms after press | Strike | Hit | Off | Why |
|---|---|---|---|---|---|---|
| Meeko (tender) | E Hearthlight | tend_hearth @0 | 133 (hearth) | - | -133 | hearth and its light appear on the press; the lantern lift peaks later |
| Motley (ostra) | E Brimseed | os_seed @0 | 100 (seed) | - | -100 | the seed is planted at the aim on the press; the throw gesture follows |
| Tenzo (dolm) | E Stone Row | br_crack @0 | 100 (e_row) | - | -100 | the ground-crack tell starts on the press; the hands hit the ground at 100 |
| Tenzo (dolm) | LMB boulder | br_throw @17 | 150 (lmb_throw) | 83 | -67 | the boulder spawns on the press and hits before the arm comes through (clip late) |
| Meeko (tender) | LMB ember | tend_ember @0 | 83 (shot_r) | 67 | -67 | ember spawns on the press; the arm is straight at `THRUST_T` 0.08 s |
| Neve (rimewright) | LMB dart | rime_shard @0 | 67 (dart_l) | 100 | -67 | dart spawns on the press |
| Neve (rimewright) | RMB held lance | rime_lance @600 | 83 (spear_aim) | 667 | -67 | the lance flies 67 ms to the zone; its spear clip strikes ~0.58 s (the aim clip's twitch is picked as the strike), so on the clip it is within 20 ms |
| Grimble (dredge) | LMB shot | dr_shot @17 | - | 100 | -83 | no clip strike; the pellets travel 3 m |
| Sparkle (mage) | LMB bolt | vv_bolt @0 | - | 67 | -67 | no clip strike; the bolt travels 3 m |
| Sable (thief) | R Encore | dj_blade @400 | 283 (encore) | 500 | -100 | each blade is thrown on the beat and lands when it arrives (travel time) |
| Lace (archer) | E | pin_hail @0 | - | 383 | -383 | the volley goes up on the press; pin_rain / pin_patter land with the hits |
| Cinder (ashwick) | R jet | lw_jet / lw_trail / lw_jet_land | - | 367 | -67..-367 | jet bursts and their trail, timed by the flight, not by a hit; the landing sound starts with the landing clip |

Travel time (a shot's fire sound before its hit) is right: the fire sound is meant for the release.

## Not measured this way

Lace RMB and R, Albert RMB tap, Sparkle R and Meeko R played none of their own fire/impact sounds in this set-up
(they need a mark, a held state, an ally or a target in their area). They are not timed here.
