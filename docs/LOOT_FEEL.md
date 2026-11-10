# Loot feel: chest, deathbox, take/swap tempo

Measured on `main` (read from code and rules, 2026-11-09). Tags: **[D]** = SUPERVIVE data in
`briefs/supervive-data`, **[F]** = footage / `briefs/hero-ref`, **[-]** = no source.

**Source search result:** `supervive_kits.md`, `supervive_physics.md`, `PHYSICS_PARITY.md`, every
`briefs/hero-ref/*.md` sheet and the `ext/hero-ref-footage` READMEs/OCR contain nothing on chests,
deathboxes, loot windows or loot interrupts (the footage is per-hero ability capture only). So no number
below can be called wrong against the source, and none was changed. A loot-specific capture is needed
for the [-] rows; no owner note in `briefs/DECISIONS.md` sets a loot time either (it only fixes the
swap rule, kept as is).

| What | Ours now | Where | Source |
|---|---|---|---|
| Chest open | hold interact **1.1 s** (needs a chest key); lid and burst at the end | `content/rules/keys.json` chest.hold_s | [-] |
| Chest hold broken by release | progress is **kept** (never decays); hold again to finish | `match.gd` "chest" case | [-] |
| Chest hold broken by a hit | **no**, hits do not touch it | same | [-] |
| Chest hold broken by dash / knock | leaving 1.6 m drops the prompt; progress is kept | `match.gd` `_update_interact` | [-] |
| Deathbox open (you) | **tap interact = instant** loot window; tap again = smart loot | `match.gd` "loot" case (player) | [-] |
| Deathbox hold (bots, remote) | hold **1.0 s** takes everything; a hit restarts it | `life.gd` loot_time, `match.gd` | [-] |
| Take one item | click = **instant**, no timer | `hud.gd` `_build_loot`, `LootFull.click` | [-] |
| Swap (gear / full pack) | **instant** click | `loot_full.gd` | [-] |
| Item that doesn't fit | nothing moves; your pack opens beside the box to swap (owner rule, kept) | `LootHold`, `LootFull.swap_held` | owner |
| Damage while panel open | panel stays open | `hud.gd` `_loot_tick` | [-] |
| Close conditions | walk beyond 2.4 m, go down, box emptied, or the X button | `hud.gd` `_loot_tick` | [-] |
| Move / look with panel open | **yes**, both stay live (only a pause zeroes them); the mouse over the panel just doesn't fire | `match.gd` input poll | [-] |
| Box revive hold | hit breaks it until you let go and hold again | `box_revive.gd` | [-] |

## Inconsistencies found (not changed: no source to say which side is right)
1. Chest progress survives release and hits, while the box revive and bot box loot break on a hit.
2. A chest has a real channel (1.1 s), a deathbox for the player has none (instant window).
If a loot capture shows interrupted channels reset, the fix is one reset in the chest case plus
`h.hurt_at` (about 4 lines in `match.gd`/`key_chest.gd`).
