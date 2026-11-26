# 0172: Boki ride as wisps by default

- **Status:** accepted
- **Date:** 2026-11-22
- **Area:** boki

## Problem
Owner rule 11-21: a Boki that is not summoned gives its hunter perks; the hunter summons it for a while on a
cooldown, and the perks are off while it is out. That is the wisp prototype (decisions 0038, 0039), but the
`boki_wisps` setting defaulted to off, so expeditions showed the walking Boki.

## Options
1. Keep it off and ask players to find the toggle.
2. Default on; keep the toggle; saved files from before get it on once (saves wrote every key, so an untouched
   toggle reads as a saved "off").

## Choice
Option 2. `Settings.DEFAULTS.boki_wisps` is true; `wisps_v` 1 marks a file written after the flip, and a file
without it loads with wisps on once. A later hand-off stays off. The perks were already right:
`Hunter.kin_carry_on` needs the Boki settled on the shoulder on Return, which a burst leaves (state active,
cmd follow) until the fold finishes (`KinSummon._back`). `--summon-check` now asserts it. One plain line in the
Field Book card, the Boki tooltip, the Words page and the tutorial's summon step.

## Affects
Settings (load_file), overlay label (no "prototype"), dex_view, boki_hud, words.json, tutorial.json,
boki_summon.json. Alternative: tell apart "never touched" from "turned off by hand" needs a flag the old build
never wrote, so a player who had turned it off must switch it off again once.

## Follow-up 2026-11-26: no toggle, and C is only the summon
The owner (itch 0.24.27) still got the walking Boki: a settings file holding `boki_wisps=false` next to
`wisps_v=1` (a toggle-off or a check run that wrote the player's file before #810) stayed off for good, and
that is the only state that gives a walking Boki (every menu path and both builds were probed). The rule is the
game now, so the menu row is gone and `load_file` sets `boki_wisps` on whatever the file says (`wisps_v` is in
`Settings.REMOVED`); checks still set it in memory. And C is both the Summon key and the Boki key: the press
burst the wisp, the release then sent the fresh Boki leaping at the cursor (the old C). With wisps a Summon
press swallows its own Boki-key tap (`KinCommand.poll`). `--wisp-default-check` covers both.
