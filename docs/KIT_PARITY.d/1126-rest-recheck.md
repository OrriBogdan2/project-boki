## Albert, Grimble, Neve, Meeko, Gil re-check on main cdbaa701ac (2026-11-26, branch ext/kit-parity-rest-1126)

Every slot row of Albert (`bulwark`, source Oath), Grimble (`dredge`, source Kingpin), Neve (`rimewright`, source Celeste), Meeko (`tender`, source Elluna) and Gil (`gil`, ours, no source) was re-read against `docs/heroes/<key>.md`, the data (`content/archetypes`, `content/weapons`, `content/dash_flow`, `content/rules/kit_parity.json`) and the kit scripts, by diffing everything that moved since the 11-23 re-checks (`1123-albert-neve-recheck.md`, `1123-grimble-meeko-recheck.md`, base `5a246f9696`). Damage is compared per cast (Grimble's gun is 7 slugs a volley, Neve's Shatter 8 darts, Meeko's ember one a shot).

Owner rows left alone: every cooldown ratio (gap 10), Albert's walk, lunge and Faultline lane, Neve's push-like spear and Rimelock carry, Grimble's tight 6 degree group and three Barge charges, Meeko's 6.75 m ember and Burrseed wind-up, Gil as a whole (no source).

### Drift since 11-23, with the commit that moved it

| # | Item | Was (doc) | Now (data) | Moved by | Reason | Action |
|---|---|---|---|---|---|---|
| 1 | Grimble pellet | 2 a slug, 14.0 a volley | 3.5, 24.5 (`shotgun.json` `dmg`) | `8495f5a6b8` (11-24) | owner playtest: hard to do damage | owner; **fixed** `dredge.md` (per-volley table, scaling bullets, Broadside ratio) and the KIT_PARITY Grimble LMB and R rows |
| 2 | Grimble gun against the source | 14 vs 193 footage volley | 24.5; 193 x 0.13 (hero HP 1531 vs our 193) = 25 | same | follows 1 | the gun now matches the source in absolute terms |
| 3 | Grimble Anchor and Broadside against the gun | Anchor 1.8x (source 1.8x), Broadside 3.4x (source 3.9x) | Anchor 25 = 1.0x, Broadside 48 = 2.0x | same | follows 1; neither was touched | **open for the owner** (below); docs say so |
| 4 | Meeko ember | 8, Kindle plateau +45% (footage +45.3%) | 6, flat Kindle +0.72 a stack = +60% at 5 | `8495f5a6b8` | owner 11-24 (the check was already moved to +60%) | owner; **fixed** `tender.md` (scaling, ramp row, burst ratio 4x -> 5.3x) and the KIT_PARITY Meeko LMB row |
| 5 | Neve dart homing | turn 12 rad/s onto the foe nearest the cursor, free acquire within 75 degrees | turn 7, foe within 2.4 m of the cursor point, else the cursor point; a foe away from the cursor pulls on nothing | `651e8bbb7a` (11-19) | owner (weaker homing) | **fixed** `rimewright.md` (LMB row, gap table row 2) and KIT_PARITY Neve LMB rows |
| 6 | Neve Shatter | 60 | 54 in 2.4 m | `8495f5a6b8` | owner 11-24 | docs already moved (`884ec75aaa`); re-read, same |
| 7 | Neve Shatter slow | 1.2 s / 30% | none | `f6c93c7a59` (11-19) | DECISIONS 11-07 | docs already say none |
| 8 | Ult ranks (Albert, Grimble, Neve, Meeko, Gil) | one step | `x.per_rank` data and rank text | `7b42b40816` (11-19) | owner 0022 option 2 | read against the "Ultimate ranks" table; match (Gil has no rank, kept) |
| 9 | Gil Super Zeep | name in card | "Geyser" | `20e367c793` (11-20) | wording | docs and wiki already say Geyser |
| 10 | Gil swordfish chain | 7 / 7 / 11 in `gil.md` and `gil_combo_check.gd` | 9.2 / 9.2 / 14.5 | `d90111aab5` (11-12, TTK roster median) | owner TTK bar | **fixed** `gil.md` and the stale pin in `tools/gil_combo_check.gd` (it failed on main: "numbers LMB: 7, 7, then 11") |
| 11 | Grimble: E during the reel, hook into Anchor lands on the hauled foe | n/a | an E on a foe waits and goes on arrival | `b3ff025f42`, `b671cff2c3` (11-19, 11-23) | tester 11-19 | docs already carry it (`dredge.md` reel row) |
| 12 | Dash-flow rows (all kits) | none | `into_cast` rows | `485c9006a3` (11-23) | cast-into-cast | not a kit number; Gil rows say "kept chainable" |
| 13 | Albert Faultline and 360 Smash look, Neve Rimelock veil, Grimble/Meeko sounds | n/a | look and sound only | `0e783023f7`, `eaf45ce798`, `7bf264030e`, `01b767b687` | polish | none (no number a kit row reads) |

Not moved since 11-23 (re-read, same): Albert throw 12 / range 9, Crushing Blow 36 to 66, Shield Charge 12 and cd 6, Whirl 24 / push 7, Faultline cd 40 and 160 HP aegis; Grimble Anchor 25 / stun 1.1 / cd 7, Broadside 4 a slug, 2 waves of 6, cd 21, Deep Reach 11.5 m / cd 12; Neve dart 4 / 0.18 s, Spear 18 and 22 detonation, Rink Wall 200 HP, Rimelock 18 / radius 7.47 / hold 3.3; Meeko seed 9, burst 32 / 2.2 m / root 1.1, Hearthlight 10 + 22, Hearth Call 5.3 a second / cd 46, dash 7 / 14.

### Still open

- **Grimble ratios after the 11-24 pellet change** (owner call; HARD 2/10, BLOCKS 1/10): Anchor (25) and Broadside (48) are 1.0x and 2.0x a gun volley, the source reads 1.8x and 3.9x. Source-ratio values would be Anchor about 44 and Broadside about 95; that is a large buff to a stun and an ultimate, so it was not made here.
- **Meeko Kindle +60% against the footage's +45%** is the consequence of keeping Kindle's flat step when the ember went 8 -> 6 (owner, `docs/TTK.md`).
- **`--gil-combo-check`, 3 failures on main, identical with and without this branch, not touched** (HARD 3/10, BLOCKS 2/10): "cancel X wave + E, RMB, LMB: nothing goes mid-ride" and "each waits and goes on landing" (RMB and LMB now fire mid-ride, E is refused: the 11-23 `into_cast`/Gil rows measure that, but `gil.md` and the check still say they wait), and "recast E: the window's total is its time left" (`GilKit.recast_window` passes the spin length as total and `auto` true). Either the doc and check follow the kit or the kit follows the doc; it is Gil's feel, so left for the owner.
- Source gaps `[?]` unchanged: Albert hammer range, Neve Spear clamp and Wall slide stop, Meeko Empowered effect, Meeko ally-pass refund.

### Checks (this branch)

| Check | Result |
|---|---|
| `--kit-parity-check` | 0 failures (83 rows ok) |
| `--card-numbers-check` | 344 numbers, 0 failures |
| `--bulwark-combo-check`, `--dredge-combo-check`, `--rimewright-combo-check`, `--tender-combo-check` | 0 failures |
| `--gil-combo-check` | before: 4 failures; after the pin fix: the 3 above |
