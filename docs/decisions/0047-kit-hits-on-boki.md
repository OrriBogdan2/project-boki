# 0047: How kit hits land on a Boki (summoned and wild)

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** combat

## Problem
Every kit hits summoned and wild Boki, but nothing said how. Kit AoEs gathered targets through `Match.foes_of`, which skipped wild Boki (shots hit them, blasts didn't); a stunned Boki still bit and cast; a wild one walked through stun, root and slow; a Boki's knocks stacked (each shove added speed, a Hunter's sets it), so a light Boki flew out of a combo; Lace's last ult arrow executed Hunters only; Sable's ult skipped Boki; Tenzo's rocks rose under a Boki (only Hunters and monsters counted as bodies).

## Options
1. Per-kit special cases for Boki: many small rules, drift between kits.
2. One rule (`BokiHit`, `content/rules/boki_hit.json`) read by `Kin.hurt` and the Boki's walk, bite and cast; kits stay untouched.

## Decision
Option 2, from the source (PARITY FIRST): its creeps and summons take each card's number as written (no creep scaling: `dmg_k` 1.0 for summoned and wild), every listed crowd control lands on them (stun, root, slow, burn, Blight; DR as on Hunters), an execute finishes them at the card's threshold (Kael's slam "executes" the dummy; "kill a creep" counts as a knock on Kael's passive), and a knock moves them as it moves a Hunter (speed set along the shove, never stacked) divided by their mass (`Kin.mass`, giant scale squared; a Hunter is 1). A Boki out in the world is a body for placed rocks (`HeroZones.fits`). `foes_of(team, wilds := true)`: every hit counts wild Boki like the monsters; target picking and danger sensing pass `false`, so Boki and bots don't start fights with wild Boki. Damage never ends a summon early; the hit that empties it does (owner, 2026-11-09).

## Consequences
`scripts/combat/boki_hit.gd`, `content/rules/boki_hit.json`, a few lines in `kin.gd` (hurt, impulse, walk, bite, cast), `match.gd` (`foes_of`), `hero_zones.gd`, `pin_ult.gd`, `thief_ult.gd` and the AI callers of `foes_of`. No Net or save change. Check: `--boki-hit-table-check` (12 kits x 5 slots x Hunter/summoned/wild).
