# 0061: Blight nests, the only place Skitters come from

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** Blight, spawns (docs/SPAWNS.md)

## Problem
Owner (11-12): "right now infinite spiders spawn in areas - really annoying and doesn't feel rewarding." Skitters clawed out of the ground at a random spot 13-20 m from a squad whenever its noise heat filled, with no end and no reward, and a Warden's shriek made more. That breaks core principle 1 (no random spawns: placed or timed, telegraphed, finite, and killing them pays).

## Options
1. Keep the heat spawns but cap them per area. Cons: still random, still endless, nothing to win.
2. Burrow mounds that wake on a heat timer. Cons: still a spawner with no stock, so it never runs dry.
3. Nests: fixed spots with a fixed stock and a long cooldown once empty, which you can break for a reward.

## Decision
Option 3 (`scripts/match/blight_nests.gd`, `content/rules/blight_nests.json`).
- **Where.** The match seed and the world pick the spots, so every client places them the same: 1, 1 or 2 nests per island by danger, on roomy open ground. Nests keep 16 m apart, 9 m from camps, exits, Warden posts and drop spots, and stay out of lairs.
- **What they hold.** A nest holds 6, 7 or 8 Skitters.
- **What wakes them.** A hunter in sight within 9 m, a loud noise (shot, blast, chest), a hit, a Warden's shriek within 22 m, or the tide. A nest only releases what it holds.
- **Telegraph.** The nest pulses, swells and hisses with a ground ring for 2 s, then the Skitters climb out at fixed angles.
- **Cooldown.** An empty nest stays empty for 300 s, then refills (and regrows if broken). An idle Skitter far from everyone burrows home into its nest's stock.
- **Reward.** Breaking a nest (120 hp) pays 6 gems through DropMerge, a gear roll (gear.json `bl_nest`: tune 0.5, gear 0.3) and 80 XP to each hunter of the breaking squad within 14 m. The feed reads "Nest broken · quiet for 5:00".
- **Removed.** Heat and noise spawns are gone: `BlightDir.heat`, `_spawn_tick`, `_burrow_spot`, and the shriek ring. A shriek makes nearby Blight hear its target and wakes nests, but never creates Skitters.
- **Tide.** heart.json `tide_heat` is replaced by a timed wake: every 40 s of match clock, each squad outside the ring stirs the nearest stocked nest within 45 m. Each wake is telegraphed like any other.
- **Backstop.** The per-area cap stays: at most 8 Skitters alive within 26 m of a nest, under the global `cap()`. The rest wait in the nest.
- **Boss adds.** Egg sacs now cycle a fixed list (`Boss.BROOD_ADDS`) instead of rolling the add's type.
- **On the map.** Nests show like camps (NestMap). Each is an egg icon with one pip per Skitter held. It flashes while stirring and greys out with a refill clock while cooling. The minimap shows nests within 40 m or stirring ("nest" in MapDetail); the full map shows them all.

## Consequences
- Files: blight_nests.gd and nest_map.gd are new. blight_dir.gd (heat code out, nests in), blight.gd and blight_models.gd (the nest body: static, its pulse read from spot, its stock from cone_a), data.gd (`bl_nest`), heart.gd/heart.json (no tide_heat) and boss.gd also change, plus one line each in match.gd, hud.gd and full_map.gd.
- Net.VERSION goes to 0.24.6 for the "nest" event and the nest body. No save change.
- Checks: --blight-nest-check is new. --blight-check and --heart-check are updated.
- Builds on ext/combat-spawn-audit. NestMap mirrors CampMap from ext/predictable-camps-1111 until that merges (docs/DEBT.md).
- Alternative not taken: wake nests only on proximity and drop the tide. The tide wake keeps pressure on squads that linger outside the ring, which tide_heat used to do.
