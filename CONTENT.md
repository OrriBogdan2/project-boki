# Adding content to Project Boki

Everything here is plain JSON under `content/`. The game reads it when it starts; no code changes.
Colours are hex strings, times are seconds, distances are tiles.

## A new kin: the kin grammar (`content/kin_v2`, `content/abilities_v2`, `content/merges_v2`)

Kin are built from a compositional grammar: a kin file (`content/kin_v2/<id>.json`) names its body,
looks, a 20-point stat profile, how it's carried (shoulder, perch or mount), its throw and dodge
rider, its E ability, an auto ability and its merge (R); abilities and merges are built from
deliveries, effects, modifiers and triggers. The full format, the vocabulary and the runtime rules
are in `docs/KIN_GRAMMAR.md`. Check your files with `--grammar-check`; the game skips any file with
errors. Kin files are data only: nothing in them is ever loaded or run.

`content/kin/<id>.json` now only holds a species' home and economy data:

- `work`: its work elements, the farm jobs it does on its own, each at a level 1-4, e.g. `{"bloom": 3, "forage": 2, "ranch": 1}`. Elements: ember, tide, bloom, spark, craft, forage, timber, stone, frost, haul, mend, ranch (see `scripts/core/work.gd`). Two or three per kin.
- `shiny`: its hand-picked shimmer palette, `{"color", "belly", "glow"}` (and `"wing"` for winged kin). Shimmers are 1 in 4096 (see `scripts/core/shiny.gd`).
- `rare` and `boss`: a rare kin only hatches from that lair boss's Rare Egg.

A kin with no `content/kin` file is fine: it's not rare, and its work elements are guessed from its theme.

IVs aren't set per species: every kin is born with its own (Health, Power, Speed, Work, Bond, 0-31 each; `Care.IVS` in `scripts/core/care.gd`), worth at most +10% (+5% Speed) at 31 through `Care.iv_mult`. Bred kin take 3 from their parents; Rare Eggs (which hatch on the Incubator by the Nesting Nook, `scripts/core/incubator.gd`) always have 3 at 26 or better. `--iv-check` and `--incubator-check` test them.

Open `tests/kin_gallery.tscn` and press F6 to see it next to the others.

## A new hunter ability: `content/hunter_abilities/<id>.json`

Weapon utilities (RMB) and class dodges. (Kin abilities are the grammar's, above.)

```json
{
	"id": "fireball", "name": "Fireball", "icon": "fireball", "color": "#ff7a3d",
	"desc": "A fireball that explodes and sets everything nearby burning.",
	"cooldown": 6, "charges": 1,
	"effects": [
		{"type": "projectile", "dmg": 18, "speed": 13, "range": 9, "size": 0.32, "color": "#ff7a3d", "burn": 5,
			"on_end": [{"type": "area", "at": "here", "radius": 1.9, "dmg": 8, "kb": 6, "burn": 5}]}
	]
}
```

- `effects`: steps run in order. Types (see `scripts/combat/effects.gd` for every field):
  projectile, area, cone, chain, pull, zone, telegraph, rush, leap, dash, blink, launch, heal, shield, haste,
  guard, cleanse, refill_dash, cool_glider, crit, burst. Any effect can have a `delay`. Buffs take a `target`
  (self, owner, both, allies); areas take an `at` (self, owner, aim, here).
- Crowd control from abilities has diminishing returns per target (`KinRules`, docs/KIN_GRAMMAR.md).

## Combos: `content/combos/<id>.json`

`setup_by` (kin, owner, any) applies one of `statuses`; within `window` seconds the next hit by `payoff_by`
(owner, kin, kin_ability) deals `bonus` times damage and adds `bond` to the meter.

## Tuning: `content/rules/`

- `bond.json`: how fast the bond meter fills from your hits, your kin's hits, combos and knockouts.
- `kin_ai.json`: how traits turn into chase range, leash, retreat health, and the recall and swap cooldowns.

## Weapons and classes

`content/weapons/<id>.json` (primary fire and an optional `utility` ability) and `content/classes/<id>.json`
(the class `dodge` ability).


## A hero's signature weapon: `"signature"` in `content/archetypes/<id>.json`

Every hunter carries ONE weapon for the whole run: the archetype's signature. Weapons are never found,
swapped or sold. They grow through upgrade perks (`"wup"` entries in `Data.PERKS`, see
`scripts/match/weapon_ups.gd`). A new hero names its weapon with one key and adds the weapon file:

```json
"signature": "longbow",
```

The weapon itself lives in `content/weapons/<id>.json`. An older archetype file with a `weapons` list still
loads (its first entry is the signature), so hero branches written before the gear model keep working.

## New gear: `content/gear/<id>.json`

Gear is found on the run (chests, crates, the Blight, bosses) and kept for the expedition (or brought home
by extracting). Five slots: `glove` (active, Q), `passive` (glove), `armor`, `boots`, `kit`. Pieces
without a `slot` key are gloves (a `cd` above 0 is the active one). Each piece has a rarity, Common to
Legendary, that scales its `stats` (Gear.mult). Picking one up replaces the piece in its slot. What drops
where is in `content/rules/gear.json` (tables of rolls: `gear` or `tune`, with chance, bonus, min_rar).

```json
{
 "id": "quake", "name": "Quake Glove", "cd": 18, "col": "ff9a5a", "icon": "quake",
 "stats": {"dmg": 0.04},
 "desc": "Punch the ground: after a short wind-up, everyone close is thrown into the air.",
 "effects": [
  {"type": "telegraph", "radius": 2.8, "time": 0.35, "at": "self", "color": "ff9a5a"},
  {"type": "area", "radius": 2.8, "dmg": 14, "lift": 9, "kb": 3, "at": "self", "delay": 0.35, "color": "ff9a5a"}
 ]
}
```

- `stats`: `speed`, `glide_speed`, `heat`, `armor`, `dmg`, `cdr`, `hp`, `reload`, `tonic`, `pack`, `dodge`, `gems`, `sight` (scaled up by rarity; Gear.stat_text names them).
- `effects`: the same building blocks abilities use (see `scripts/combat/effects.gd`). The older
  actives (jump pad, gust, platform, smoke, mending, seeker, shock) are coded in `Match.use_gear`.
- `icon`: any id from `scripts/ui/icons.gd`.
