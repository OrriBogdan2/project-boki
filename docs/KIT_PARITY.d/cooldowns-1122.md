## Cooldowns 11-22: today vs source level 1 vs footage card (gap 10, owner call)

Audit only, no game number changed. One table: every Hunter x RMB / E / R / dash (plus Kael's air RMB and the two air dashes), read from `content/archetypes/*.json` on main by `python3 tools/cooldown_table.py --verify-ref 2be9877c2` (rewrite the table with `--write`).
- **Source L1** = source data at level 1 (sv/briefs `supervive_kits.md`, upgrade lines put back; the numbers ext/cooldown-parity-verify asserts in `tools/cooldown_parity_check.gd`). **Footage card** = the cooldown on the levelled footage hunter's card (briefs/hero-ref); "-" = not read, or charge/shield based (Kael dash 0.4 s between charges, Neve RMB 0.3 s, Albert RMB 0.15 s).
- **Verify changes it** = ext/cooldown-parity-verify (2be9877c2, 4 commits on d255acbee) sets this cell to Source L1; read from that commit's JSON, not assumed.
- The gap-10 row says "All 12, 0.48x to 0.85x". On main that is stale: **Lace, Tenzo and Motley already sit at 1.0x** (every cell), Albert and Cinder are 1.0x except R / RMB+E+R. Today/L1 runs 0.48 to 0.96 on the cells below L1 (Sable R 0.48 lowest, Vex E 0.96 highest).
- **Footage cards read lower than source L1 almost everywhere** (0.48 to 1.15 of L1): the footage hunter is levelled up, so a card is not a level-1 number. L1 is the fair target if the owner wants source; the card is a ceiling check, not a goal.
- ext/cooldown-parity-verify is not on origin any more (ls-remote empty); its commits exist locally at 2be9877c2. It conflicts with main in all 9 hero JSONs and their wiki pages (main moved the same lines to 0.8x), so a re-cut onto main is needed either way.

<!-- TABLE -->
| Hunter | Source | Slot | Today (main) | Source L1 | Footage card | Today / L1 | Card / L1 | Verify branch sets | Verify changes it |
|---|---|---|---|---|---|---|---|---|---|
| Vex | Ghost | RMB | 6.5 | 9 | 5.4 | 0.72 | 0.60 | 9 | **yes** |
| Vex | Ghost | E | 11.5 | 12 | 10 | 0.96 | 0.83 | 12 | **yes** |
| Vex | Ghost | R | 42 | 55 | 37.5 | 0.76 | 0.68 | 55 | **yes** |
| Vex | Ghost | dash | 8.5 | 11.5 | 7.5 | 0.74 | 0.65 | 11.5 | **yes** |
| Kael | Brall | RMB | 2 | 2.5 | 1.2 | 0.80 | 0.48 | 2.5 | **yes** |
| Kael | Brall | E | 12.8 | 16 | 9.4 | 0.80 | 0.59 | 16 | **yes** |
| Kael | Brall | R | 36 | 45 | 21.7 | 0.80 | 0.48 | 45 | **yes** |
| Kael | Brall | dash | 10.4 | 13 | - | 0.80 | - | 13 | **yes** |
| Kael | Brall | air RMB | 7.2 | 9 | 5 | 0.80 | 0.56 | 9 | **yes** |
| Lace | Myth | RMB | 16 | 16 | 9 | 1.00 | 0.56 | 16 | no |
| Lace | Myth | E | 15 | 15 | 8.3 | 1.00 | 0.55 | 15 | no |
| Lace | Myth | R | 60 | 60 | 33.3 | 1.00 | 0.55 | 60 | no |
| Lace | Myth | dash | 9.5 | 9.5 | - | 1.00 | - | 9.5 | no |
| Cinder | Felix | RMB | 7 | 9 | 5.8 | 0.78 | 0.64 | 9 | **yes** |
| Cinder | Felix | E | 10.5 | 13 | 8.3 | 0.81 | 0.64 | 13 | **yes** |
| Cinder | Felix | R | 36 | 45 | 25 | 0.80 | 0.56 | 45 | **yes** |
| Cinder | Felix | dash | 9 | 9 | - | 1.00 | - | 9 | no |
| Albert | Oath | RMB | 6 | 6 | - | 1.00 | - | 6 | no |
| Albert | Oath | E | 12 | 12 | 10 | 1.00 | 0.83 | 12 | no |
| Albert | Oath | R | 40 | 50 | 33.3 | 0.80 | 0.67 | 50 | **yes** |
| Albert | Oath | dash | 8 | 8 | 9.2 | 1.00 | 1.15 | 8 | no |
| Meeko | Elluna | RMB | 10.5 | 11.5 | 7.2 | 0.91 | 0.63 | 11.5 | **yes** |
| Meeko | Elluna | E | 11 | 12 | 10 | 0.92 | 0.83 | 12 | **yes** |
| Meeko | Elluna | R | 46 | 60 | 41.6 | 0.77 | 0.69 | 60 | **yes** |
| Meeko | Elluna | dash | 7 | 7 | - | 1.00 | - | 7 | no |
| Meeko | Elluna | air dash | 14 | 14 | - | 1.00 | - | 14 | no |
| Grimble | Kingpin | RMB | 12 | 18 | 11.7 | 0.67 | 0.65 | 18 | **yes** |
| Grimble | Kingpin | E | 7 | 12 | 6.7 | 0.58 | 0.56 | 12 | **yes** |
| Grimble | Kingpin | R | 21 | 36 | 20.8 | 0.58 | 0.58 | 36 | **yes** |
| Grimble | Kingpin | dash | 10 | 7 | - | 1.43 | - | 7 | **yes** |
| Grimble | Kingpin | air dash | 12.5 | 12.5 | - | 1.00 | - | 12.5 | no |
| Tenzo | Tetra | RMB | 11 | 11 | 9 | 1.00 | 0.82 | 11 | no |
| Tenzo | Tetra | E | 12.5 | 12.5 | 10 | 1.00 | 0.80 | 12.5 | no |
| Tenzo | Tetra | R | 45 | 45 | 35 | 1.00 | 0.78 | 45 | no |
| Tenzo | Tetra | dash | 12 | 12 | 9 | 1.00 | 0.75 | 12 | no |
| Neve | Celeste | RMB | 10.2 | 12 | - | 0.85 | - | 12 | **yes** |
| Neve | Celeste | E | 17 | 20 | 16.7 | 0.85 | 0.83 | 20 | **yes** |
| Neve | Celeste | R | 80 | 80 | 45.8 | 1.00 | 0.57 | 80 | no |
| Neve | Celeste | dash | 13 | 13 | 8.3 | 1.00 | 0.64 | 13 | no |
| Sparkle | Joule | RMB | 8 | 10 | 7 | 0.80 | 0.70 | 10 | **yes** |
| Sparkle | Joule | E | 10.5 | 12 | 9.2 | 0.88 | 0.77 | 12 | **yes** |
| Sparkle | Joule | R | 42 | 60 | 37.5 | 0.70 | 0.62 | 60 | **yes** |
| Sparkle | Joule | dash | 8 | 9 | - | 0.89 | - | 9 | **yes** |
| Sable | Shiv | RMB | 7 | 13 | 6.7 | 0.54 | 0.52 | 13 | **yes** |
| Sable | Shiv | E | 15 | 28 | 15 | 0.54 | 0.54 | 28 | **yes** |
| Sable | Shiv | R | 24 | 50 | 29.1 | 0.48 | 0.58 | 50 | **yes** |
| Sable | Shiv | dash | 4.5 | 5 | 4.2 | 0.90 | 0.84 | 5 | **yes** |
| Motley | Void | RMB | 10 | 10 | 5.8 | 1.00 | 0.58 | 10 | no |
| Motley | Void | E | 10 | 10 | - | 1.00 | - | 10 | no |
| Motley | Void | R | 70 | 70 | 58.3 | 1.00 | 0.83 | 70 | no |
| Motley | Void | dash | 9.5 | 9.5 | 7.5 | 1.00 | 0.79 | 9.5 | no |
<!-- /TABLE -->

**What the owner would see at 1.0x:** of 51 cells, 21 already equal source L1, 29 are below it and would rise, 1 is above it and would fall (Grimble dash 10 to 7 s): 30 cells change, in 9 kits (Vex, Kael, Cinder, Albert, Meeko, Grimble, Neve, Sparkle, Sable). 3 kits change nothing (Lace, Tenzo, Motley).

**Owner question (1.0x data or keep):**
1. Set every Hunter cooldown to the source's level-1 value (verify branch re-cut on main; Grimble's dash 10 s goes down to 7 s), or keep today's 0.8x-style numbers?
2. If keep: say so and gap 10 closes as "owner, kept" (Lace, Tenzo, Motley are already 1.0x either way).
