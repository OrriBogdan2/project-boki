# Ability sounds against the strike (11-12)

Does each Hero's own fire / cast / impact sound land on what it belongs to? Measured by `--sfx-strike-check`
(tools/sfx_strike_check.gd) first on main d255acbee (11-09); re-run 11-12 on ext/sfx-strike-resync (origin/main +
ext/w0246-audio-vfx + ext/w0246-anim, the 0.24.6 line with the anim wave's re-timed clips): every move of the 12 kits (LMB tap, LMB held
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
| Grimble (dredge) | RMB Abyssal Hand, tap and held | dr_throw | -217 ms off the hook (at the press, before the 0.2 s coil-back) | +0 ms on the launch | played when the hook leaves his hand (`_launch_hook`), not on the press; a coil-back cut short by a stun is silent. 11-12: the coil-back (0.24.5) let `dr_throw` play from its start, so the clip's arm is out at 100 ms, 117 ms before the hook (clip early, below) |

## Over 50 ms, left as they are (re-run 11-12)

All of these play on the gameplay event (the shot or the effect appears on that frame); what is off is the
clip, or the gap is travel time by design. Moving the sound to the clip would pull it off the shot you see and
hear land, so the fix belongs in the clip (an earlier key, or seeking into it) or in the kit's release time,
not in the sound. Listed for the animation pass.

| Hero | Move | Sound @ ms after press | Strike | Hit | Off | Why |
|---|---|---|---|---|---|---|
| Lace (archer) | E | pin_hail @0 | - | 383 | -383 | travel time by design: the volley goes up on the press; pin_rain / pin_patter land with the hits |
| Cinder (ashwick) | R jet | lw_jet @0 / lw_trail @300 / lw_jet_land @1800 | 83 (jet) | 367 | -67..-83 | travel time by design: jet bursts and their trail, timed by the flight, not by a hit; the landing sound starts with the landing clip |
| Sable (thief) | R Encore | dj_blade @400 | 283 (encore) | 500 | -100 | travel time by design: each blade is thrown on the beat and lands when it arrives |
| Grimble (dredge) | LMB shot (tap, held) | dr_shot @17 | - | 100 | -83 | travel: no clip strike; the pellets travel 3 m |
| Sparkle (mage) | LMB bolt (tap, held) | vv_bolt @0 | - | 67 | -67 | travel: no clip strike; the bolt travels 3 m |
| Neve (rimewright) | RMB lance (tap, held) | rime_lance @117 / @600 | 50 (spear / spear_aim) | 183 / 667 | -67 | travel: the lance flies 67 ms to the zone (rime_zone on the hit, +0) |
| Grimble (dredge) | RMB Abyssal Hand | dr_throw @217 | 100 (throw) | 300 | +0 on the launch, +117 on the clip | clip early, new 11-12: the 0.2 s coil-back plays `dr_throw` from its start and the arm is out at 100; the hook leaves at 217. Fix in the clip: hold the coil to `windup` (as Albert's `THROW_WIND`) |
| Vex (gunslinger) | R Sky Shell | vn_nuke_fire @133 | 33 (x) | 1600 | +100 | new 11-12, not a fault: the shot leaves on the clip's kick key (`FIRE_T` 0.14 s); the fastest hand is the barrel lift at 33 |
| Kael (juggernaut) | R Gilded Riposte | jug_riposte @633 | 733 (riposte) | 750 | -100 | new 11-12, not a fault: plays with the lunge; the file's cut sits 0.1 s in (`strike_t`, ef783455b), so the cut lands on the strike (+0) |
| Tenzo (dolm) | E Stone Row | br_crack @0 | 100 (e_row) | - | -100 | the ground-crack tell starts on the press; the hands hit the ground at 100 (br_raise on the first rock, Fixed) |
| Tenzo (dolm) | LMB boulder | br_throw @17 | 100 (lmb_throw) | 83 | -67 | was 150 strike / -67: the boulder spawns on the press and hits before the arm comes through (clip late); ext/anim-tenzo-boulder-sync (READY, not on this line) moves the release to the strike |
| Meeko (tender) | E Hearthlight | tend_hearth @0 | 83 (hearth) | - | -83 | was -133: hearth and its light appear on the press; ext/anim-release-sync-meeko-motley (READY, not on this line) brings the clip to 33 |
| Motley (ostra) | E Brimseed | os_seed @0 | 83 (seed) | - | -83 | was -100: the seed is planted at the aim on the press; ext/anim-release-sync-meeko-motley brings the clip to 33 |

Within 50 ms since the anim wave (11-09 rows dropped): Meeko LMB ember (-67 -> -50) and Neve LMB dart (-67 -> -33).

Travel time (a shot's fire sound before its hit) is right: the fire sound is meant for the release.

## Not measured this way

Lace RMB and R, Albert RMB tap, Sparkle R and Meeko R played none of their own fire/impact sounds in this set-up
(they need a mark, a held state, an ally or a target in their area). They are not timed here.
