## Albert and Neve re-check on main 5a246f9696 (2026-11-23, branch ext/parity-recheck-albert-neve)

Every Albert (`bulwark`, source Oath) and Neve (`rimewright`, source Celeste) row was re-read on today's main against `docs/heroes/{bulwark,rimewright}.md` and the data/kit files (`content/archetypes/{bulwark,rimewright}.json`, `content/weapons/{tower_shield,hoar_fan}.json`, `content/rules/kit_parity.json`, `scripts/arch/kits/{bulwark,rimewright}_kit.gd`). The source numbers are the ones those docs quote from `sv/briefs/kits.md` and `briefs/hero-ref` (that file is not in this tree). The last full read was 11-12 (main 88b06b9e7). The current rows are in the Albert and Neve sections of `docs/KIT_PARITY.md`, which lost their stacks of superseded duplicate rows in this branch.

Owner rows left alone: all cooldown ratios (gap 10: Albert R 40 vs 50, Neve E 17 vs 20, Spear 10.2 vs 12), Albert's walk 55% while charging, lunge, perfect launch and boop, Neve's push-like spear, skate refund, Rimelock carry and radius, Faultline lane 5.5.

### Drift since 11-12, with the commit that moved it

| # | Item | Was | Now | Moved by | Reason | Action |
|---|---|---|---|---|---|---|
| 1 | Albert dash charges | 2 (heavy class) | 1 | `1ff0d92e81` (11-16) | Oath's Spin Dash has 1; a kit's `dash.charges` overrides the class | none (parity); Shield Charge spends none |
| 2 | Albert Guard meter, Shield Slam | cut 11-09, back through a stale merge | gone, `--kit-parity-check` pins it | `4ce1bd2953` (11-20) | owner 11-07 | none (parity) |
| 3 | Albert throw cadence | .48 | .45 | `1eecee8c3` (11-09), still .45 | source | none (parity) |
| 4 | Albert aegis | plated slab, amber | layered translucent `AegisWall`, pale gold; chord 4.2 m, arc 140 and 160 HP unchanged | `884cb80bc4`, `a359d3b5bd`, `03934aa2ed` (11-20), `42823939fb` (11-22) | look only; closes gap 8's "not pale gold" | none; geometry unchanged since 11-03 |
| 5 | Albert Shield Charge damage | 10 | 12 (198 vs throw 192) | `5f1a1e092d` (11-09) | source ratio | none; the doc row still said 10, fixed |
| 6 | Albert Crush stun | 0.5 | 1.0; Crushing Blow's own 0.4 stun removed | `61ecea1383` (11-09), `31ad6241c1` (11-12) | footage, source | none; `ext/parity-albert-blow-stun` is not needed |
| 7 | Albert Faultline lane | 4.5 m, no hop | 5.5 m, 1.2 m hop, lead 0.4 s | `dd5ea2c131` (11-09), `015f26780f` (11-12) | owner 11-09 feel brief, decision 0061 | owner row, left; docs said 4.5 |
| 8 | Albert passive text | "wall **or another foe**", "you heal" | walls only, no heal | text never followed the audit; asserted by `bjorn audit: a blow that knocks a foe into another foe (no wall) doesn't Crush` | source: "knocked into a wall" | **fixed**: `bulwark.json` card passive and passive desc, the kit comment, the wiki page |
| 9 | Neve skate speed, ramp | 11.5 m/s, 0.2 s | 10.5 m/s, 0.12 s | `62584033da` (11-12), `63e7ba08fc` (11-20) | footage mean 10 to 11; 5 fps pan fit | none (parity); docs still said 11.5 |
| 10 | Neve Rimelock hold | 3.5 s | 3.3 s | `fc548f3289` (11-12) | footage 3.2 to 3.4 | none; docs and desc said 3.5 |
| 11 | Neve Rimelock slow | 15% rising to 55% | flat 35%, no ramp | `384a462829` (11-12) | PARITY FIRST, the data has no ramp | none |
| 12 | Neve Rimelock radius | 8.3 | 7.47 | `3d4a2d1999` (11-11), `18b22ba946` (11-13) | owner 11-11, -10% on the +15% | owner row; KIT_PARITY said 8.3, fixed |
| 13 | Neve Rimelock crash | 40 | 18 (= 155/156 x spear 18) | `ext/parity-ttk-cinder-neve` (11-13) | source ratio, pinned in `kit_parity.json` | none; **the card line in `rimewright.json` still said 40: fixed to 18** |
| 14 | Neve Rink Wall HP | 70 | 200 (+40 at rank 3) | `793a547bc9` (11-12) | owner 11-08 (about 50 own darts) | none |
| 15 | Neve darts | straight while skating | home late (35 to 70% of the flight) while skating too; a hold = one burst, 3 large on let-go; a tap the burst cannot take yet is buffered | `5b008013f7` (11-12), `e5c73480c`, `ext/neve-dart-homing`, `b53f5b0328` (11-22) | source "semi-homing"; gap 16 closed | none |
| 16 | Neve Shatter | knock Shatter 30 | 37 in 3 m, 0.4 s later; 8 darts 60 in 2.4 m (3.0 x 0.8) | `ext/parity-ttk-cinder-neve` | source ratio | none; **passive desc said 3 m for the 60: fixed to 2.4 m, now the data field `passive.fan_r` (the kit computed 0.8 x 3.0 inline); wiki hand text said 30 and 1.6x: fixed to 37 and 2x** |
| 17 | Neve Spear detonation | 60 | 22 (= 190/156 x 18), +45% at rank 3 | `ext/parity-ttk-cinder-neve` (11-13) | source ratio | none |
| 18 | Neve body | size 1.014 / 1.15, hit_r .38 | size 1.11, hit_r .395, hit_h 1.66 | `a8b4449e37` (11-15), `3a50a38abb` (11-18) | height chart | owner row |

Not moved since 11-12 (re-read, same): Albert throw 12 / 12, range 9, Crushing Blow 36 to 66 over 1.25 s, E r 2.3 / 4 s / burst 18 / cd 12 and 8, Shield Charge cd 6, Whirl 24 / push 7 / cd 8, Faultline cd 40, aegis 160 HP; Neve dart 4 dmg / 0.18 s, Spear 18 / zone 2.2 / burst r 2.7 / 1.8 s / 2 charges, Wall slide 4.5 to 16.2 m, Skate 13 s / 1.6 s, Rimelock 80 s / stun 0.75 / late 0.75.

### Not drift (checked and left)

- Source gaps `[?]`: Albert hammer range (9 against 12.6 m or more seen), Neve Spear range clamp and Wall slide stop rule. Not determinable.
- `docs/KIT_PARITY.md` still carries the older merge-stack rows in its other sections (ranges, CC, knock, ranks tables). Read the Albert and Neve sections and this fragment as current.

### Checks (this branch)

| Check | Main 5a246f9696 | This branch |
|---|---|---|
| `--bulwark-combo-check` | 197 checks, 0 failures | 197, 0 failures |
| `--rimewright-combo-check` | 161 checks, 0 failures | 161, 0 failures |
| `--card-numbers-check` | 344, 0 failures | 344, 0 failures (a first try with "2.4m" in the card text and no data field failed: 1 failure, fixed by the `fan_r` field) |
| `--kit-parity-check` | 0 failures | 0 failures |
| `python3 tools/health.py --strict` | red: `tools/check_registry.gd` long_line 0 -> 1 (`66d289323f`); on d49f4f321d red again, `tools/camp_clear_check.gd` long_line | OK (both comments rewrapped) |
| `python3 tools/gen_wiki.py --check` | red: `docs/wiki/Rules.md` out of date (and `Boki-Growth.md` on d49f4f321d) | OK (regenerated) |
