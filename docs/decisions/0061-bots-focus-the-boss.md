# 0061: Bots in a boss fight focus the boss

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat (bot AI)

## Problem
Owner, 11-11: "bot is trying to kill me when hes in the boss fight". A bot sealed in a lair with an awake boss still ran its usual pick (nearest rival hunter first, monsters only when no hunter was in reach), so it turned its back on the boss to shoot the player sealed in beside it.

## Options
1. Never target hunters in a boss fight: simple, but a rival can then shoot a bot for free inside the seal.
2. Target the boss; a rival sealed in with us only once they (or their Boki) land a hit on us after the seal closed.
3. Keep hunter-first targeting, only lower hunter scores: still shoots the player when the boss is far.

## Decision
Option 2. "In a boss fight" is `Lairs.boss_fight(h)`: sealed in a lair whose boss is up (not the post-kill victory lock). `Lairs.spares(h, o)` reads `Ent.hit_by` (the time of each rival's last landed hit, already kept for DashReset) against the lair's `lock_at`, so a hit from before the seal doesn't count. Bot._choose skips spared rivals; the fight's boss is always in reach and outranks its adds. It also covers finishing a downed rival and the revive "danger" pick, and the bot's Boki (`KinTactics.spares`): it kept meleeing the player all fight, credited to the bot.

## Consequences
`scripts/match/bot.gd`, `scripts/match/lairs.gd`, `scripts/combat/kin_tactics.gd`, `scripts/match/kin.gd`. No Net or save change. Check: `--boss-focus-check`.
