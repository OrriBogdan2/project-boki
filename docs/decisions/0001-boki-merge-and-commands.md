# 0001: Boki commands, the downed Boki and R = Merge

- **Status:** accepted (owner decisions of Nov 1 2026); the G commands and the shoulder default are superseded by [0002](0002-boki-follow-and-capture.md)
- **Date:** 2026-11-01
- **Area:** combat / networking / UI (Boki behaviour, the R slot, Net)

## Problem
The Boki is controlled by one overloaded key (G throws or recalls, C hops a Boki out and back), a hurt Boki faints for 8s and then teleports to your shoulder (no play around it), and R is each class's own ultimate with the Boki merge bolted on as an optional "bonded" rider. We want the Boki to be a second body you command and protect, and R to be one system for every class.

## Options
1. Keep the class ultimates and add Boki commands on top: least churn, but R stays 6 different things, merge stays optional, and the hero-port work would have to keep both.
2. R = Merge for every class (decided). Class R code stays in the repo behind a data flag (`content/rules/boki_system.json` `class_ults`) so the hero-port session can fold those ults into kits without breaking.
3. Make merge forms per hero x Boki pair: rejected, it multiplies content (6 x 9) and nobody can learn it.

## Decision
- **Commands** (`scripts/match/kin_command.gd`): G tap throws to the cursor (landing staggers what it lands on) or, when the Boki is out, recalls it (a leap back that hits everything on its path, only within a recall range). Hold G toggles "hold the spot" / "follow & fight" (Kin.hold_at). C casts the Boki's own ability from wherever the Boki is; on the shoulder it is cast through you (no hop-out). G, C, R, F stay reserved: no new keys (F is untouched, the rescue needs no key).
- **Downed Boki** (`scripts/match/kin_downed.gd`): replaces `fainted` / `faint_t` / the shoulder teleport. It stays where it fell, marked on screen and minimap. The owner rescues it by running into it (0.5s scoop) for a good chunk of HP, otherwise it recovers alone after 15-20s at low HP (faster with trust). Abyss falls: timer only. While down: no C, no Merge, no shoulder passives. It cannot be hurt, tamed or taken while its owner is in the map.
- **Merge** (`KinMerge`, `scripts/kin/merge_form.gd`, `scripts/match/merge_look.gd`): the bond meter (fed by Boki hits, your hits on targets it marked, combos) gates R. With the Boki out, R makes it leap back and merge mid-air. No Boki / downed / lost: a weak basic surge. The merged look, the activation burst and the changes to your abilities come from `content/rules/merge_forms.json`, keyed by the Boki's type (theme) and power tier (level + trust + forms), not by hero. Changes are kit-agnostic: ability cooldown speed (`cooldown` owner stat), a rider on every class-ability hit, a dodge rider, plus the existing per-species passives, shot riders and merged Boki abilities.
- **Net** (`scripts/match/kin_net.gd`, `Net.VERSION` 0.9.0): kin snapshot gains hold mode, down timer, rescue progress; hunter snapshot gains the merge form and time left; new `kcmd` events for throw, recall, scoop and merge so other games play the same moments. Rescue and recovery run in the owner's game and arrive as state.

## Consequences
- Files: new kin_command, kin_downed, kin_net, merge_look, merge_form, bot_kin, boki_hud; edits to kin.gd, kin_merge.gd, hunter.gd (small), match.gd and hud.gd (wiring only, budgets unchanged or lower), bond.gd, bot.gd, kit_card.gd, net.gd.
- Net.VERSION bump: yes (0.8.0 to 0.9.0). No save change (kin records are untouched; hold mode and down state are match-only).
- Removed: Kin.faint / faint_t / `_sim_fainted`, the C hop-out (`use_kin_hop`, `hop_back`), `Match._player_throw`. Class R code (ArchKit.use_r and the kits' `cast_r`) is kept reachable behind `class_ults` and listed in docs/DEBT.md.
- Checks: `--boki-system-check` (tools/boki_system_check.gd). `--teammate-check` and `--grammar-runtime-check` updated for the renamed state and the new throw entry point.
- Open: the R slot still unlocks at run level 6 (existing progression); the owner may want the merge available earlier.
- **Regen** (`scripts/kin/kin_regen.gd`, `boki_system.json` "regen"): a Boki mends on its own. On you by Return, settled: 6% of max health per second. Out beside you: 1.5%/s once it has gone 6s without losing health (a hit restarts the wait; Blight cuts it like other healing). A downed Boki never regenerates and waits again after it comes round. Every match starts at full health. A soft green pulse on its bar and a small mote show it.
