# Air cast poses (all 12 Hunters)

Source footage: a Hunter that fires mid-jump or right after a glide cancel keeps an airborne body. Ours stood
planted in the air (feet down, knees locked) whenever the move's clip owned the whole body: full-body moves always,
and `"upper": "moving"` moves whenever he had no horizontal speed (a straight jump, a fall). What is castable in the
air is the Airborne casts job's call; this is only the pose.

**Fix:** per move, `"air_legs": true` in `content/rules/warden_anim/<art>.json` (scripts/heroes/warden_clips.gd). A play
of the move that has been in the air goes on the upper layer, so the fall/rise/glide legs stay under the cast. It
stays there to the move's end: if he lands mid-cast, the legs go through their own layer (fall to idle or run) instead
of snapping into the clip's planted stance halfway through.

## Audit (live match: each key tapped and held on the way up a jump and in a fall)

| Hunter (arch / art) | Stood planted in the air (now `air_legs`) | Left full-body (the legs are the move) |
|---|---|---|
| gunslinger / vex | lmb, rmb, e (+ knock) | dash, dash_ex |
| juggernaut / kael | slash_r/l, wave_wind, wave, chain | meteor (the leap) |
| ashwick / cinder | lance, lance_end, aim, shot, cloak (+ stoke lance) | jump, leap, hop, jet |
| tender / pip | shot_r/l, shot_emp, seed (+ aim), toss, hearth, flare | skip, float |
| dolm / tarek | throw, wind, punch, raise | crouch (Quakefall tuck), dive |
| archer / hem | heavy_wind, heavy | (the bow moves were upper already) |
| dredge / dredge | throw (+ reel, pullend), anchor (+ blast) | jump, dive |
| rimewright / claire | dart_r/l (+ heavy), spear (+ aim), wall, shatter (+ freeze, clench) | skate moves |
| mage / ryzz | none: every cast was upper already | |
| bulwark / breaker | throw, smash_wind, smash, guard, mend | whirl, charge, lumber |
| thief / sable | lmb_r/l (+ primed), bola, knife (+ encore dance, reset, flourish) | vaults, exdash |
| ostra / ostra | none: he rides his box, no legs to plant (his clips key from the box up; legs measured 0.001 rad off the fall) | |

The merge fusion (`mf_xform`) stays a whole-body show. In brackets: the same move's other halves or the
`"moving"` casts the run didn't reach, tagged so the whole family behaves the same.

## Strips (`<arch>.jpg`)

The move pressed 0.15 s into a standing jump, filmed at 30 fps with the camera following him up, through the landing.
Top row: `air_legs` taken out (planted). Bottom: as shipped. Labels turn red once the move has ended.
GPU job 20261109-103621-21130; `--air-cast-shots` + `tools/air_cast_strip.py`.

## Checks

- `--warden-clips-check`: per Hunter, every `air_legs` move in the air keeps the plain fall's leg bones (two models
  side by side, worst 0.001 rad; 0.6 to 1.5 rad without the fix), and landing mid-cast never hands the legs to the clip.
- `--clip-live-check`: the audit above in a real match, all 12; nothing outside the legs list stands planted in the
  air and no cast that lands snaps into its stance (21 failures with the fix taken out).
