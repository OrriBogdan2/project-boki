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
- Going down (2026-11-09, ext/anim-downed): the hero first plays a 0.35 s fall (its own `hit_f` clip from
  `content/rules/warden_anim/<art>.json`, stretched over `pop_in.time`; fed to the clips as state `fall`),
  the Wisp fades in over the last `pop_in.fade` s (0.12), then the hero hides and the Wisp puffs (ring,
  sound). Revive: a 0.3 s rise (`pop_out.time`), the same clip backwards with the Wisp brightening away.
  A hero with no clips file just stands through it. Death or a bleed-out snuffs the Wisp with a spark burst.
  All of it follows `downed`/`out`, so remotes play it with no Net change; timers and speed are untouched.
- The look is data: `content/rules/wisp_looks.json`, built by `WispLook` (scripts/match/wisp_look.gd)
  procedurally (glow-shader core, halo, eyes, motes, trail). The id is `Save.d["look"]["wisp"]`, the same
  pattern as glider skins; unknown ids give `default`.

## How to add a Wisp
Add an entry under `looks` in `wisp_looks.json` with only the keys that differ from `default`
(nested keys merge). No code. `--wisp-check` covers every entry.

## Consequences
- The local player's Wisp look is not sent to other players (they see `default`, tinted by their side colour, SideColor). Sending it
  needs a join-kit field and a Net.VERSION bump: see docs/DEBT.md.
- `HunterAnim`'s downed crawl code is dead and can go.
- Check: `--wisp-check`.
