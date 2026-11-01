# Handoff: kits2 (Thief and Juggernaut)

- **Branch:** `kits2`.
- **State:** complete and checked. It has also been merged into `integ36`, which ships to main as sync56.
- **This note:** what's in the branch and what comes next.

## Ids and names (ours, original)

| Archetype id | Hero/class name | Weight class |
|---|---|---|
| `thief` | Thief | Light |
| `juggernaut` | Juggernaut | Heavy |

| Hero | Ability names |
|---|---|
| Thief | Marks (passive), Vault (dash), Bola (RMB), Shadow Knife (E), Jackpot (R) |
| Juggernaut | Rage (passive), Greatsword (LMB, hold for Searing Wave), Smash (RMB), Rampage (dash), Warchain (E), Doomfall (R) |

Player-facing names and text are our own. Inspirations are recorded only in docs/wiki/Inspirations.md and docs/ARCHETYPES.md.

## Done, per slot

### Thief
| Slot | Behaviour |
|---|---|
| Passive (Marks) | Each weapon hit adds a Mark, shown as gold diamonds. Max 5, each lasts 4s, +8% weapon damage per Mark. A knock or assist heals 25%. |
| LMB | Twin Blades or SMG. Every hit stacks a Mark. |
| Dash (Vault) | A 3.4m flip with +30% speed. The next hit within 3s is Primed: +10 damage, 2 Marks and Shred (+15% damage taken for 3s). The Primed hit resets Vault, which is the core loop. |
| RMB (Bola) | Range 10m. The first foe hit is Grounded for 1.5s (no dash, jump or glide). If the Bola catches a second foe, both are stunned for 0.9s and take +13. |
| E (Shadow Knife) | A sticky dagger that slows on hit. Recast to step to it; it auto-steps after 5s. |
| R (Jackpot) | A 0.45s fuse you can shoot through, then 2s of knives at every foe within 8.5m. Knives refresh Marks and grant 2 free quick Vaults. |

### Juggernaut
| Slot | Behaviour |
|---|---|
| Passive (Rage) | Fills from damage dealt; the Searing Wave fills it 3x faster. When full, you're Enraged for 6s: +15% damage and faster cooldowns and dash. A knock heals 20% of the target's max HP. |
| LMB (Greatsword) | Alternating 8-damage slashes every 0.34s, double damage at the tip. Hold to charge the Searing Wave (6→10m, 12→28 damage). |
| RMB (Smash) | Tap: a wound-up slam for 26, +50% below 35% HP. Its sweet spot resets Doomfall. Hold: a charged lunge; a miss doubles the cooldown. Air: Meteor Drop, which slows and stuns the centre. During the chain: Scorching Spin. Chain states: a lunge along the chain, or a slam on arrival. |
| Dash (Rampage) | 2 charges, a 4.4m dash attack with double damage at the tip. A knock refunds a charge. |
| E (Warchain) | Hooks a foe or a wall; recast to pull yourself in. A stun breaks it, and it can't be thrown while rooted or Grounded. |
| R (Doomfall) | 0.6s invulnerable rise, then a 48-damage crash that heals 60% of the damage dealt. A knock within 2s resets it. |

### Shared work
- **`--kit-combo-check`:** 21 combinations asserted.
- **HunterAnim.KMOVES:** a keyed full-body animation layer, with a move for every ability.
- **kit_status.gd:** Grounded, blight and Shred, synced through the Net event `["kst", nid, kind, seconds, k]`.
- **New sounds:** `pay_cashin`, `pay_rage`.
- **Docs:** the "Kits2" section of docs/ARCHETYPES.md, with sources, disagreements and gaps.

## What's next (owner decisions, Nov 1)

1. **R becomes the Boki Merge.** The main session builds Merge. For these two kits:
   - Fold Doomfall into Smash as its rank-3 upgrade: a sweet-spot slam that also crashes and heals. Keep the reset-on-knock rule.
   - Move Jackpot to a Mark trigger: hitting 5 Marks on a target releases a short knife burst that refreshes Marks and gives one free Vault.
   - Remove R from both kits. Update the kit cards, next-rank text and bots, and update `--kit-combo-check` so it asserts the new triggers.
2. **Rescuing a downed Boki needs no key:** the player just runs into it. Keys G, C, R and F are reserved for the Boki system, so no hero ability may use them.
3. **Gaps the engine couldn't reproduce:**
   - mana
   - Brall's double-height wall climb
   - dodges building Rage
   - a Doomfall knock sending the target straight to the deathbox
   - a turn lock after RMB into the dash
   - Shiv's dagger sticking to moving props
   - the Bola hitting destructibles

   Revisit these once the other heroes land.
4. **Animations only play locally and on bots.** Remote players see effects and weapon swings but not the full-body poses. Sync the move id through Net if needed (a version bump).

## Net version

- kits2 introduced 0.7.0 (the `kst` event).
- After merging with the handcrafted map, main is 0.8.0.
- Any further sync change bumps to the next version above main when you merge.

## Checks

Run on the final kits2 commit, all 0 failures and no SCRIPT ERROR: `--check`, `--archetype-check` (195), `--kit-combo-check` (21), `--ability-check`, `--arena-check` (68), `--duel-check`, `--revive-check`, `--bot-sanity-check`, `--grammar-runtime-check`, `--boss-check`, and `--simtest --seed=5` (extracts at 198s).

## Screenshots

`/home/claude/shots/kits2/` on the main session's machine. They aren't in the repo, so regenerate them with the `--arena-demo` hooks.
