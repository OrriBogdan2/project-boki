# 0061: Bots in a boss fight focus the boss

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat (bot AI)

## Problem
Owner, 11-11: "bot is trying to kill me when hes in the boss fight". A bot sealed in a lair with an awake boss still ran its usual pick (nearest rival hunter first, monsters only when no hunter was in reach), so it turned its back on the boss to shoot the player sealed in beside it.

## Options
1. Never target hunters in a boss fight: simple, but a rival can then shoot a bot for free inside the seal.
2. Target the boss; a rival sealed in with us only once they land a hit of their own on us after the seal closed. Their Boki's hits don't count: a Boki picks its own fights, and the player's Boki nipping the bot turned the bot on the player.
3. Keep hunter-first targeting, only lower hunter scores: still shoots the player when the boss is far.

## Decision
Option 2. "In a boss fight" is `Lairs.boss_fight(h)`: sealed in a lair whose boss is up (not the post-kill victory lock). `Lairs.spares(h, o)` reads the lair's `grudges`, which `Lairs.on_damage` (one line in `Match.on_damage`, beside the truce's) fills during the fight: a rival hunter sealed in with the target, hitting them directly. A hit from before the seal doesn't count (`lock_in` starts the list empty). Bot._choose skips spared rivals; the fight's boss is always in reach and outranks its adds. It also covers finishing a downed rival and the revive "danger" pick, and the bot's Boki (`KinTactics.spares`): it kept meleeing the player all fight.

## Consequences
`scripts/match/bot.gd`, `scripts/match/lairs.gd`, one line in `scripts/match/match.gd`, `scripts/combat/kin_tactics.gd`, `scripts/match/kin.gd`. No Net or save change. Check: `--boss-focus-check`.
