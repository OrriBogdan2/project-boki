# 0059: Fewer chests, none before the match starts

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** match flow

## Problem
Owner (11-10): no chests in the pre-match phase, and about 40% fewer chests in matches. The pre-match lobby (Prematch) is a UI screen with no world, so it never had chests. The only stretch before the match proper that has a world is the drop: the planning phase while the skyship waits, the flight, and the glide down. All chests are built during loading, so they show from the ship.

## Options
1. Build chests only once the drop is over. Cons: KeyRun deals key carriers per chest at build time, net chest indices depend on build order, and models built mid-play skip the loading screen's shader warm-up and cause a hitch.
2. Build them as before, but hide them until you land. Nobody can open a chest from the ship or the glider anyway.

## Decision
Option 2. `KeyChest.show_all` hides every chest when DropSquad sets up a drop you're riding, and its tick shows them once you're no longer riding or dropping (you landed, or fell short and came back on foot). This covers the tutorial too. The tutorial gets none of its map's 12 grove chests: it keeps exactly one, the chest step's, on the range island where the key step leaves you (long after landing). For the cut, `content/rules/keys.json` chest.keep (0.6) is the one tunable: `KeyChest.thin` keeps that share of the map's chest spots, dropping the most crowded first with no dice (the same chests on every client). SpawnPlan places the same share of item caches. Vaults (2) and sky-train crates stay.

## Consequences
key_chest.gd, drop_squad.gd, spawn_plan.gd (caches), ping_input.gd (no pinging a hidden chest), one line in match.gd (thinned map chests; none in the tutorial). No Net.VERSION bump: hiding is local, and thinning is the same on every client. No save change. Checks: --keys-check part "fewer" (counts and thinning per map, training, the tutorial's one chest), --drop-feel-check (hidden until you land, normal match and tutorial).
