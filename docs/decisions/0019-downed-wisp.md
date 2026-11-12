# 0019: Going down turns you into a Wisp

- **Status:** accepted
- **Date:** 2026-11-07
- **Area:** match presentation / cosmetics

## Problem
Owner decision (briefs/DECISIONS.md, 2026-11-07): a downed Hunter should not lie down in a crawl clip.
The hero vanishes in a quick pop and a Wisp takes their place; a revive pops the hero back.

## Decision
- A downed Hunter shows as a Wisp. `HunterWisp` (scripts/match/hunter_wisp.gd) is a small state machine
  (`""` → `in` → `on` → `out`) kept in the hunter's meta `wisp`, driven from `Hunter.render`. It reads
  `downed` and `out` only, so nothing new is replicated: remote players and bots get the Wisp from the
  state they already receive (flag bit 1 in the `st` snapshot, the `knock` and `up` events).
- Gameplay is unchanged: the downed timers, the 40% crawl speed, the revive channel, who can revive, the
  hitbox and the revive UI are all as before. Only the picture changes. `Hunter._anim_state` now feeds
  `downed = false` to HunterAnim, so the hero never plays the crawl; the per-hero `downed` clips are no
  longer picked (the files stay).
- Pop-in (0.25 s): flash, ring, puff, sound. Pop-out on revive (0.3 s): the Wisp brightens and the hero
  scales from 0.6 to full with a small squash. Death or a bleed-out snuffs the Wisp with a spark burst.
- The look is data: `content/rules/wisp_looks.json`, built by `WispLook` (scripts/match/wisp_look.gd)
  procedurally. The id is `Save.d["look"]["wisp"]`, the same pattern as glider skins; unknown ids give
  `default`.
- **The outline rule** (owner, briefs/DECISIONS.md 2026-11-09, "round = Hunter, critter = Boki"): a Hunter
  Wisp is a round "person" outline (a squashed round body with a head) in the team colour with a white
  core, floating low (body centre 0.4 m), slow and heavy, with a steady glow and a quiet hum. It must read
  differently from any Boki at match zoom, and a Boki wisp is the opposite (critter outline, quick and
  bouncy, shoulder height, sparkles, chirps). So the Hunter Wisp has no eyes, no motes, no sparkle trail
  and no flicker. The body is one shared mesh in one material (`shaders/wisp_core.gdshader`: team rim,
  white core), so thirty of them stay cheap. Motion: a slow bob; when the hunter crawls the body hangs
  back in the world (up to `drag`), leaning back, and catches up over `settle` seconds once they stop. The
  hum (`audio/wisp_hum.wav`, tools/gen_wisp_sfx.py, a seamless loop) is held through `Sfx.loop_hold` each
  frame, positional, and stops with the Wisp; a Wisp the local player cannot see keeps quiet, like its pops.
  Every look must keep the outline: `--wisp-check` asserts it for each entry.

## How to add a Wisp
Add an entry under `looks` in `wisp_looks.json` with only the keys that differ from `default`
(nested keys merge): colours, body size, hover, drift, hum, pop effects. No code. `--wisp-check` covers
every entry, including the outline rule (round body with a head, team rim, white core, low, steady).

## Consequences
- The local player's Wisp look is not sent to other players (they see `default`, tinted by their side colour, SideColor). Sending it
  needs a join-kit field and a Net.VERSION bump: see docs/DEBT.md.
- (done) HunterAnim's downed crawl code is removed; the clip files stay.
- Check: `--wisp-check`.

## Boki wisps (the other outline, DECISIONS 2026-11-09)
Round = Hunter, critter = Boki. `BokiWispLook` (scripts/kin/boki_wisp_look.gd) builds a Boki's wisp from its
species: its own palette (the shiny one when it shimmers), its ears and tail tip from `look` (or a small table
for the hand-built bodies), one baked mesh on one shared unlit material (`shaders/boki_wisp.gdshader`), a quick
hop-and-squash idle (`pose`) and a 24-sparkle trail. Only the look so far: the wisp prototype wires it into
matches. See it with `tests/kin_gallery.tscn -- --kin-wisps [--kin-shiny]`; check: `--boki-wisp-check`.

## Clarity pass and Boki riding the downed Hunter (owner 2026-11-11)
Owner: "very confusing when someone wisps ... a big circle and unclear. Copy how Supervive does this ... their
pets always come back to them and go into wisp form when they're downed".
- **Marks (`DownedMarks`):** the always-on ground ring the size of the revive range is gone. A downed Hunter shows
  a compact ring hugging their Wisp in their side colour (ally or rival): the bleed-out drains round it, revive
  progress fills inside it, it flashes over the last 5 s and turns red and pulses while stomped. Only a teammate
  within 9 m sees the revive reach on the ground (thin, filling as they revive) and one HUD line, "Step onto
  <name>'s wisp to revive" (screen space: no words on world objects, owner 11-11). The squad's offscreen arrows
  carry the same ring. The plate, squad frame and own-screen "You're down" stay as they were.
- **Boki (`KinWispForm`, Kin state `wisp`, which replaces `reviving`):** when its Hunter is knocked every Boki of
  theirs that is up zips back (blinks from beyond 14 m or when it can't walk there) and circles the Hunter Wisp as
  its Boki wisp (`BokiWispLook`, round = Hunter, critter = Boki). It does not fight, cast or take orders and
  can't be hit. It still pulls its Hunter up as the old kin revive did (same wait and `kin_revive_time`, bleed
  paused meanwhile); a stomp stops the pull (as Supervive's stomp blocks self-revives). Revived: back on the
  shoulder with its old order. Dead: `KinLoss` as before. A Boki that is down itself stays down (KinDowned).
  The old guard (attacking whoever stood on the Wisp) is removed.
- **Net:** `wisp` takes `reviving`'s slot in `Match.KIN_STATES`, so the snapshot shape is unchanged.
- **With Boki wisps on (the `boki_wisps` prototype, decisions 0038/0039/0041/0044):** the Boki already rides as a
  wisp, so a knock does not use this form: KinSteal breaks it loose where its Hunter fell (stealable), and a summoned
  Boki fights out its window first (`KinWispForm.wants` skips it), then breaks loose. With the setting off (the
  default) this form runs as above. Folding stealing into this form, if the prototype ships, is the open step.
- Checks: `--kin-wisp-form-check`, `--clarity-check`. Frames: `--wisp-clarity-shots --shots-dir=<dir>`.
