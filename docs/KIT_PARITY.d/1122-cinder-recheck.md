## Cinder (`ashwick`) re-check on main c303669761 (2026-11-22)

Every Cinder row re-read against ref-ashwick (the data in `sv/briefs/kits.md` "Felix", the footage notes `hero-ref/linwick.md`, the
owner notes) and against `content/archetypes/ashwick.json`, `content/dash_flow/ashwick.json`, `content/rules/kit_parity.json` and
`scripts/arch/kits/ashwick_*.gd`. Last full read was 11-12 (0.24.4 / 0.24.5 marks above). Our numbers are the source's x 154/1285
(mean Hunter health, docs/TTK.md); cooldowns sit at the line's 0.8x (owner question, row 1 of the open table).

**Result: no data row moved since 11-12 except the two owner changes below.** `git log -S` on each number: the damage, Ignite and
cooldown values were last set by 36a1aca46d (11-11) and f2478ab453 (11-03); the RMB, E and dash cooldowns by 6dce74161a (11-01), the rank steps by 003a3cfeb1 (11-08).
Two text values had drifted from the data and are fixed here; the hero doc and the Cinder rows above carried stale duplicates, now removed.

| Row | Source (ref-ashwick) | Ours today | Last moved by | Verdict |
|---|---|---|---|---|
| LMB damage | Flamethrower 258/s = 30.9/s | `lmb.dps` 31 (pinned, ratio 2.38 to the bolt vs 2.43 +-0.29) | 36a1aca46d (11-11) | match |
| LMB reach, width | ~4 bh (7.2 m) past any cursor; 0.3 to 1-1.5 bh wide | 6.1 m, 0.65 to 2.85 m | 632de4b224 (11-10, owner playtest) | **owner** (-15% to source) |
| LMB relight, slow | 0.35 s between uses, 0.35 s slow after release | `relight` 0.35, `slow_after` 0.35, no fuel | f2478ab453 | match |
| Passive Ignite | 2 levels, 3 s, 31 stacks, refresh, knock heal, knock +1 dash charge | Char 31, 3 s, 0.5% / 1% a second, `heal_knock` 0.16 (wiki only) | 36a1aca46d | match; heal size `[?]` |
| Passive bonus | bonus on stream and bolt vs Ignited (no number) | x1.06 / x1.10, chip 0.4% / 0.6% (`--ttk-check` sizing) | 36a1aca46d | ours, sized to the ~0.9 TTK bar |
| RMB damage | Embry Bolt 106 = 12.7 | `rmb.dmg` 13 (pinned 12.7 +-0.5) | 36a1aca46d | match |
| RMB cooldown, charges | 9 s; tier IV +1 charge | 7 s (0.78x); `rank3_charges` 2, rank steps x0.833 / x0.667 | 6dce74161a, 003a3cfeb1 | match; scale **owner** |
| RMB range, slow | no range number; Slow (no number) | 14 m always; 30% for 1.5 s | owner item 19 | `[?]` **owner** |
| Dash damage | Pyro Pounce 150.4 = 18.0 | `dash.dmg` 18 (ratio 1.385 vs 1.419 +-0.17) | 36a1aca46d | match |
| Dash charges, cooldown | 2 charges, 9 s | 2, 9 s (1.0x) | 6dce74161a | match; the only slot not at 0.8x |
| Dash move | ~3.4 m in 0.33 s, stops on first foe | 3.4 m / 0.33 s ground; air poof **3.4 m / 0.28 s** (was 6.8 m) | 720fde43ea (11-17, owner playtest) | **owner** (poof now matches the ram) |
| Dash knock | "knockback", no number | `kb` 7 (2.01 m), self `recoil` 3.5 | 90c71388b7 | `[?]` |
| Dash rank 3 | +40 base = +4.8, +75 speed = 16%, 150 shield = 11.6% | +5, +16% for 2 s, 11.6% for 2 s | 36a1aca46d, 90c71388b7 | match |
| E damage, radius | Heat Shield 76.8 = 9.2; ring 2.5 bh = 4.5 m | 9; 4.5 m | 36a1aca46d | match |
| E cooldown, ranks | 13 s; -2 s x2, +25% dmg and shield x2, +30% shield | 10.5 s (0.81x); 8.9 / 7.3 s; dmg +25% / +50%; shield +25% / +80% | 6dce74161a, 003a3cfeb1 | match; scale **owner** |
| E timing | ~0.2 s arms-out fling then the blast | instant on the press, 0.24 s flare clip, 0.18 s ring | bd27d2c178 (11-03, owner item 11) | **owner** |
| R carpet | 239.2/s = 28.7/s | 4.5/s | db19aeb64e | **owner** (burst cap) |
| R flight | forward, steers, recast ends, ~7 bh/s for 1.3-1.4 s | 12.6 m/s x 1.8 s = 22.7 m, steers 90 deg/s, hang 0.15 s | 2b4ea5c2f2 (11-12) | **owner** (item 20: longer) |
| R cooldown | 45 s | 36 s (0.8x) | f2478ab453 | match; scale **owner** |
| R ranks | -15 s, +25% dmg | **superseded, see `1128-ult-rank-rows-reconcile.md`**: ~~none built (ADR 0022 is a spec, no code)~~; built: Flue Flight cd 36 -> 24 -> 24 s, trail 4.5 -> 4.5 -> 5.625/s (`555debe7d2`, 11-19) | `555debe7d2` | **done** (read on a tree without it) |
| CC | Slow, Anti-Heal, pull (no numbers) | bolt slow 30% 1.5 s; carpet slow 30% 0.5 s refreshed; Anti-Heal 3 s; pull 14 m/s to 1.3 m | none | `[?]` numbers ours |
| Dash flow | footage silent on presses inside a bash | 5 ground, 5 air, 5 into-dash rows, `hold.rmb` x3 and `dash.ground.lmb` unsourced | none since 11-12 | `[?]` **owner** (rows unchanged) |
| Cancels | none shown; DECISIONS 11-07 chainable | 15 rows, 30 `ult 66` asserts | 3053ddcef9 (11-17) only removed merge locks | match |

**DECISIONS: during Flue Flight only E works** (owner item 66, DECISIONS Nov 5). LMB is ignored with a soft tick (not buffered; the
lance lights the step the flight ends), RMB, Shift (no poof, no dash spent), the gloves, items, the Merge key and G are dropped, not
buffered. Steering and a jump stay (movement); R again lands. This holds on today's main (`ult 66` rows, PASS).

### Drift found and fixed

| What | Where | Was | Now | Moved by |
|---|---|---|---|---|
| Kit card chip for Cinder Shot | `content/archetypes/ashwick.json` `card.chips.rmb` | 14 dmg | 13 dmg (data 13) | 36a1aca46d (11-11) cut the bolt to 13, chip stayed (`--card-numbers-check` does not read chips) |
| How-to combo line | `howto[1]` | "25% more damage" | "6% more damage" (`ignite_bonus.dmg_k[0]` 1.06) | 36a1aca46d cut the Ignite bonus from +25% to +6%; howto text (d45c24c5de, 11-10) kept the old number |
| Hero doc per-slot table | `docs/heroes/ashwick.md` | 24 rows, 17 stale (7 m reach, +25%/+40%, 14 / 16 / 7 damage, 120 deg/s, 32 s, "X" key) | 7 rows, the current kit | merge duplicates since 11-11 |
| Hero doc ult text | same file, "Ultimate on R", Combinations, cancels | 32 s cooldown, 120 deg/s, an RMB-in-flight row that contradicts item 66, X key | 36 s, 90 deg/s, no RMB row, R key (moved 31649d400e, 11-03) | 2b4ea5c2f2, 31649d400e |
| Rank paragraph | same file | "shared steps -10% / +15%" (gone) | points to the Upgrade parity table | 36a1aca46d |
| KIT_PARITY Cinder table | `docs/KIT_PARITY.md` | LMB range 7 row, air poof 6.8 m, duplicate RMB/LMB rows | range 6.1, poof 3.4 m, one row each | 632de4b224, 720fde43ea |

### Not changed (owner or no reason to move)

LMB reach 6.1 (owner 11-10), air poof 3.4 m (owner 11-17), Furnace Cloak instant (item 11), flight length and carpet cap (item 20, burst
cap), RMB range 14 (item 19), cooldown scale 0.8x (owner question), unsourced dash-flow rows, R ranks (built; this line was stale, see `1128-ult-rank-rows-reconcile.md`).

Checks on this tree: `--ashwick-combo-check` 157 checks, 0 failures (125 on 11-12); `--card-numbers-check` 343 numbers, 0 failures;
`--kit-parity-check` 0 failures; `--ttk-check` Cinder LMB 0.92 / 0.91, combo 0.91 / 0.88 (docs/TTK.md: the same).
