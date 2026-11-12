# 0097: Soul echoes from stolen wisps

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** save / match flow / farm

## Problem
DECISIONS 2026-11-09 (soul-linked wisps): a thief keeps a soul echo of what they stole. The species unlocks in the
Field Book, finding or hatching one gets likelier, the next hatch has a small chance at a stolen rare mutation or
shimmer, and extracting alive with stolen wisps pays a bonus. 0041 only counted an echo on the grab.

## Options
1. Echo on the grab (0041). A thief who is downed a second later keeps it: stealing pays without getting out.
2. Echo when the thief extracts carrying the wisp, written home through the match result like the rest of the haul.

## Decision
Option 2 (`SoulEcho`, `KinSteal.extracted`). On extract each stolen wisp you carry pays `extract_gems` into your
match gems, goes home to its owner, and adds an echo to the result; `Game.apply_result` writes it: the Field Book
entry's `echo` count (seen = true) and the wisp's shimmer and mutations into `soul_echo.traits` (newest
`traits_kept`). A nest egg's species leans to the parent with echoes: weight 1 + `hatch_per_echo` per echo, up to
`hatch_echo_cap` echoes. The next hatch (nest or Incubator) rolls `trait_chance` for one stolen trait, then the
traits are spent. Numbers: `content/rules/soul_echo.json`. Left out: wild finds (spawns are shared by the squad).

## Consequences
- Save v14: `soul_echo: {traits: []}` and every dex entry gets `echo` (0). Clashes with the soul-link line's v14
  (wisp cosmetics) and v15 (clans): on merge this step renumbers after them; it only adds what is missing.
- No Net change: each game pays and records its own thief. match.gd +1, home.gd +1, game.gd +1.
- `--soul-echo-check`; `--wisp-steal-check`'s echo row moves from the grab to the extract.
