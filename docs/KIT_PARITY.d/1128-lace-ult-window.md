## Lace Starpiercer window and third shot (2026-11-28, branch ext/lace-ult-window)

The reference catalog (CATALOG-13-1127 section 1) read kit text and listed the ult as "no window or bonus". Main already has both, as data in `content/archetypes/archer.json` `x`; nothing in the kit changed.

| Item | Reference | Ours on main | Verdict |
|---|---|---|---|
| Arming | the next 3 LMB shots within 6 s, no draw | `x.shots` 3, `x.window` 6.0; the press is the first arrow, unused shots go when the window ends (`PinUlt.window`, asserted in `--archer-combo-check`: "unused shots go when the 6s window ends") | match (`e49bb4d12d`) |
| Third shot | hits harder | `x.final_dmg` 23.3 against `x.dmg` 18 (x1.29), also finishes a hunter left under 12%; rank numbers unchanged (`x.per_rank`). The third-beam damage is now asserted in `--archer-combo-check` | match |
| Range | longer | 18 m, 1.5x her Empowered range | match |
| Knockback | yes | `x.kb` 2.0, a nudge: the 11-10 owner cut (`ext/lace-knock-cut`, DECISIONS ours-only riders) | owner |
| Terrain pierce | pierces terrain and enemies | stopped by walls and terrain, a breakable prop ends it | `[?]`: the catalog row says "terrain", the footage notes say "destructibles" (docs/heroes/archer.md); the two readings differ and no clip shows a beam crossing a wall, so ours stands |
