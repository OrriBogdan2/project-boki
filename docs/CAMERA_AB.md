# Camera A/B: our framing vs the source's (decision sheet)

For the owner's call on DEBT "Camera framing vs the source". Nothing here changes a default: the flag is the Settings camera style
`source_scale` ("Far view, big Hunters (test)", `content/rules/camera.json`, built in ext/feel-camera-source-flag, see
docs/MOVEMENT_FEEL.md "Source scale flag"). Off is the Supervive style.

## The shots

`docs/shots/camera-ab/{lace,kael,vex,albert}.jpg`: one sheet per Hunter, three rows (open ground fight, ledge drop while gliding,
3 squads at range), flag off on the left, flag on on the right. 1280x720 renders on a 4090 worker (jobq `--needs gpu`), shown
at 960x540. Made by `godot -- --camera-ab-shots --hero=<id> --shots-dir=<dir>` (`tools/camera_ab_shots.gd`) and
`python3 tools/camera_ab_sheet.py <dir> docs/shots/camera-ab`.

- Both styles of a Hunter run in the same seeded match setup (Dusk Isles, seed 5), the same placements and the same scripted
  ability rota; the bots' rolls differ a little between the two sides, so fights match in setup, not frame for frame.
- The glide row is the same run-up to the same edge: the hero walks off, opens the glider and is shot 1.4 s later.
- The squads row: three squads of three, 12 m apart, the hero in the first.
- The cursor lean is off in these shots (the idle cursor would lean the view onto the HUD); the glide look-ahead and the glide
  zoom (1.25x) are on, as in a match.

## The numbers

| | Ours now (Supervive) | Flag on (source_scale) | Source (hero-ref sheets, camcal, game data) |
|---|---|---|---|
| Pitch | 66° | 66° | 65.5° ±1.5 |
| Vertical lens (FOV) | 32° | 32° | ~32° (25–34) |
| Distance back from the focus | 23.0 m | 36.3 m | not given: `CameraDistance` 5500 uu is unproven as an arm length; the ground it shows (below) is what was measured |
| Aim point above the ground | 1.2 m | 1.9 m | feet 3–4% of the screen below the centre |
| Ground across a 16:9 screen | 23.4 m | 37.0 m | ~37 m (Void's 3.5 m Black Hole reads ~2 bh; run pans of 205–250 px/s) |
| Pixels per metre of ground at the hero, scaled to 1080p (measured by the A/B tool) | 78 | 50 | ~51 (the data's run speeds against the pan px/s) |
| Ground up and down the screen (flat ground, zoom 1; computed) | 15.5 m (9.3 ahead of you, 6.2 behind) | 24.5 m (14.7 ahead, 9.8 behind) | follows from pitch, lens and distance |
| Medium Hunter, share of screen height | 6.47% | 8.66% | 8.3–9.3% (90–100 px of 1080) |
| Hunter drawn size | 1.12x the model (`Hunter.VIS_SCALE`) | 2.35x (1.12 x `hunter_scale` 2.1) | ~2x the size of the world ours are |
| Look-ahead, cursor lean | 42% of the cursor's distance past 1.4 m, capped at 7.5 m (x zoom), eased 6/s | the same metres (the flag does not touch it) | not measurable in the sheets: the view sits still through 1–2 bh moves and pans with the aim |
| Look-ahead, glide | 0.2 s of speed, capped 1.8 m (the opening drop: 3x); zoom 1.25x | the same | only ability zoom-outs seen |

Sources: docs/MOVEMENT_FEEL.md "Camera framing vs the source" and "Source scale flag"; the numbers are `content/rules/camera.json`
and the `--cam-framing-check` / `--move-feel-check` rows. The supervive-data and hero-ref sheets themselves are not in this
tree; the rows above are the ones those docs quote from them.

## What changes on screen

- **How far you see:** 58% more ground across (23.4 to 37.0 m) and 2.5x the area. A foe 12 m away straight up the screen is off the
  top edge today (9.3 m of ground ahead of you) and well inside it with the flag (14.7 m). The three-squad row shows it: with the flag off the far squads sit at the top and side edges, with it on the fight has room round it (see the sheets).
- **Hunter size:** the Hunters get 34% bigger on screen (6.47% to 8.66% of the screen height) although the camera moved back
  58%: they are drawn 2.1x bigger to pay for it. The world does not scale, so against a Hunter the world is half as big: a 1.5 m
  ledge is a step, cover and doorways are smaller than the body, the Boki are knee-high.
- **Look-ahead:** the same metres cover less of the screen with the flag: the 7.5 m lean cap is 32% of the screen across today and
  20% with the flag. If the flag were kept, the lean cap should be re-measured against the source, not the metres.
- **What breaks (visual only, not hit shapes):** the hit circle and shot heights stay at the old size, so the top ~44% of a drawn
  body is shot through, bodies in contact overlap, shots leave at knee height, overhead tags sit inside the body (full list in
  docs/MOVEMENT_FEEL.md "What breaks at the new scale"). Net and saves are not touched.

## Recommendation

**Keep Supervive as the default and delete nothing yet; do not turn `source_scale` on as it is.** The far view is the
part of the source worth having (you can see a fight coming), but the big-Hunters half is a gameplay change in disguise: to read right it needs the
hit circle, shot heights, overhead UI, Boki and mounts, and the world's low cover scaled with it, which is a model pass, not a camera setting.

**Alternative, if you want the far view now:** a middle style, 29 m back, with no Hunter scale (about 30 m across, 1.3x the
ground, Hunters 0.8x of today on screen, about 5%). It needs none of the fixes above, and the cost is the silhouette
size you asked to keep readable (tender at 3.8% would drop to ~3%). The other alternative is to go all the way: turn
`source_scale` on and fix the list in docs/MOVEMENT_FEEL.md first. Either is a one-line change in `camera.json`; neither is made here.
