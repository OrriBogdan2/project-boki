# 0019: Going down turns you into a Wisp

- **Status:** accepted
- **Date:** 2026-11-07
- **Area:** match presentation / cosmetics

## Problem
Owner decision (briefs/DECISIONS.md, 2026-11-07): a downed Hunter should not lie down in a crawl clip.
The hero vanishes in a quick pop and a Wisp takes their place; a revive pops the hero back.

## Decision
- A downed Hunter shows as a Wisp. `HunterWisp` (scripts/match/hunter_wisp.gd) is a small state machine
  (`""` → `fall` → `in` → `on` → `out`) kept in the hunter's meta `wisp`, driven from `Hunter.render`. It reads
  `downed` and `out` only, so nothing new is replicated: remote players and bots get the Wisp from the
  state they already receive (flag bit 1 in the `st` snapshot, the `knock` and `up` events).
- Gameplay is unchanged: the downed timers, the 40% crawl speed, the revive channel, who can revive, the
  hitbox and the revive UI are all as before. Only the picture changes. `Hunter._anim_state` now feeds
  `downed = false` to HunterAnim, so the hero never plays the crawl; the per-hero `downed` clips are no
  longer picked (the files stay).
- Going down (2026-11-11, ext/anim-downed's fall merged with the round Wisp): the hero is hit and falls to
  the floor first, 0.3 s (`HunterWisp.FALL_T`; the source shows the wisp ~0.4 s after the knock), playing its
  own death clip up to `states.floor_t` in `content/rules/warden_anim/<art>.json` (where the body lies still),
  fed to the clips as the state `wisp_fall`. Then the puff (0.25 s): flash, ring, burst, sound; the hero hides
  and the Wisp swells out. A Hero with no clips (Gil, a procedural model) puffs at once. Revive (0.3 s): the
  Wisp brightens and fades while the hero grows from 0.6 to full with a small squash and stands up, the fall
  played backwards (from where it got to, if the revive beat the puff). Death or a bleed-out snuffs the Wisp
  with a spark burst. It all follows `downed`/`out`, so remotes play it with no Net change.
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
- Check: `--wisp-check` (the fall, puff and rise too); `--wisp-shots --wisp-heroes=<ids>` films them.

## Boki wisps (the other outline, DECISIONS 2026-11-09)
Round = Hunter, critter = Boki. `BokiWispLook` (scripts/kin/boki_wisp_look.gd) builds a Boki's wisp from its
species: its own palette (the shiny one when it shimmers), its ears and tail tip from `look` (or a small table
for the hand-built bodies), one baked mesh on one shared unlit material (`shaders/boki_wisp.gdshader`), a quick
hop-and-squash idle (`pose`) and a 24-sparkle trail. Only the look so far: the wisp prototype wires it into
matches. See it with `tests/kin_gallery.tscn -- --kin-wisps [--kin-shiny]`; check: `--boki-wisp-check`.
