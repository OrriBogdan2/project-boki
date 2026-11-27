# Open chests (no key): design

Status: DESIGN ONLY, no game code. Owner 11-26: add some of the key-free chests the reference
battle royale had, in various areas, AFTER map clarity and perf land. Build order is in section 9.

## 1. What the reference had (source: sv-refs source-notes, 11-25/26)

From `interactions-1125` (Boxes, items and loot) and `items-1125b` (Loot):
- **Searchable boxes** (Consumable Box, Armor Drop, Exotic Box, named boxes): press interact, the
  box is filled and its window opens. **Instant**, no channel (`GS_Search_Instant`). Medium-value and
  locked boxes are **blocked while in combat**. One press = one fill, then it is a normal container.
- **Loot plants and piles**: press, items drop from the loot table, XP is given, the object
  disappears. Berry bush: heals, 1.0 s warm-up, bush destroyed.
- **Loot tables** (`LT_*`): guaranteed items + a random pool, quantities and chances. Containers,
  breakables and trees each name a table.
- **Exotic loot**: server-side, rolled once per configured day from that day's table, handed out in order.
- Vault door: quick-time event (a locked, rare case; out of scope here).
- A press on another object cancels the running interaction and closes an open window.

Not in the notes (do not invent): spawn counts per area, respawn times, sound and map icon of a
box. `project-map-1126` is a tooling page and has nothing on chests. `docs/LOOT_FEEL.md` already
records that no footage capture covers chests. So the numbers below are OUR choices, tagged as such.

## 2. What we have now

- One chest type, **key-locked**: 1.1 s hold, costs one key; keys are carried by monsters
  (`content/rules/keys.json`, `scripts/match/key_run.gd`, `key_chest.gd`, `chest_loot.gd`).
  `keep` 0.6 thins the map's chests (owner 11-10).
- Chest loot: `gear.json` `"chest"` table (gear +1 tier 90%, gear 30%, tune 55%), gems 7-9,
  seed/valuable/tonic odds, tier by region bonus; creak sound by tier.
- Breakables (pots, crates, barrels, kegs): `breakables.json`, one hit; drop small loot.
- Deathbox: instant window on tap (`loot_full.gd`, `LootWindow`), see `docs/LOOT_FEEL.md`.
- Regions: `content/maps/hollowcrown.json` `regions` (9) and `tools/make_hollowcrown.py` islands with
  `chests=[...]` fixed spots and `fill=dict(chests=N, ...)`. NOTE: `content/maps/arena.json` is the
  216-tile training map and has no `areas`/chest key (it has `islands`, `stations`); the BR map is
  hollowcrown, so placements below use its regions.
- Hot drop zone: loot rarity one step better (`scripts/match/hot_zone.gd`).

Gap: every chest needs a key, so there is no "walk up, open, move on" loot beat between landing
and the key hunt.

## 3. Proposal: three key-free tiers (new type `open`, keys.json unchanged)

| Tier | Name | Open time | Contents | Look / sound tell |
|---|---|---|---|---|
| 1 | Supply Crate | **instant** press (window opens, as the deathbox) | consumables: tonic/heal 70%, ammo/seed 50%, 1 gem 40% | wooden, small, soft thud on open (reuse crate break sfx pitch down) |
| 2 | Cache Chest | **0.8 s** hold | 1 gear (tier by region bonus) 60%, tonic 60%, 2-4 gems | iron-banded, `chest_creak_plain` |
| 3 | Gilded Chest | **1.6 s** hold, blocked in combat | 1 gear +1 tier 85%, tune 40%, 5-7 gems, soul ember 20% | gold trim, faint hum + glint within 25 m, `chest_creak_rich` on open |

Reasons: tier 1 copies the reference's instant search; tier 3 copies its "valuable boxes blocked in
combat" rule; tier 2 is the middle. The locked key chest stays the best (gems 7-9, +1 tier, vault)
so keys keep their point. Open-chest odds sit below the locked table everywhere.

Rules (all tuned in one new file, `content/rules/open_chests.json`):
- **Interrupt**: a hold breaks on release (progress kept, matches the key chest), on a hit taken
  (progress reset; fixes the inconsistency listed in LOOT_FEEL), on knock/dash beyond 1.6 m.
  Opening another object cancels it. Tier 3 refuses to start if the hunter was hurt in the last 4 s
  (prompt says "Not now" in grey).
- **Opened chest**: lid stays open, empty window items stay as a normal container, no respawn in a
  match (BR; one-shot). Contents roll **server-side on open** from the match seed stream (new
  `seed_mul`/`seed_add`), so all clients agree.
- Bots: treat tiers 1-2 as loot targets in the same scoring as deathboxes; tier 3 only when no enemy within 20 m.
- Net: one reliable "chest open" event (id, opener), same path as `ChestLoot.open(..., from_net)`.

## 4. Placement per region (counts per match, our proposal)

Total ~34 open chests at default `keep` (about 1 per 4 existing chests worth, no extra keys).
Rule: not within 9 m of a camp, exit, drop spot or existing chest; never on hazard fields.

| Region | T1 | T2 | T3 | Spot logic |
|---|---|---|---|---|
| The Crown | 0 | 2 | 3 | bailey and keep rooms, walled; rich but fought over |
| Frostgate | 2 | 2 | 0 | Rimefield yard, shelf edge |
| Cinder Steps | 2 | 1 | 1 | one per cliff tier, T3 on the top tier |
| Stormbreak | 3 | 1 | 0 | bridge heads, shrine stair |
| Thornwood | 3 | 1 | 0 | groves, hidden (cover) |
| Larkhollow | 4 | 1 | 0 | open plain, many landings: lots of light loot |
| Highwatch | 1 | 1 | 1 | tower tops; T3 on the Lantern |
| Duskmoor | 1 | 2 | 1 | ruin maze rooms; T3 in Moor Chapel |
| Saltmere | 2 | 1 | 1 | rim and islet (T3 on the cache islet) |

Region loot leans (armor x1.6 Frostgate, gloves Cinder, boots Highwatch, relics Duskmoor) apply to
the gear slot roll, via the existing `loot.slots` in `hollowcrown.json`. Hot zone: +1 rarity as now.
Data: a new `open_chests` list per island in `tools/make_hollowcrown.py` (fixed spots, like
`chests=`), written into `hollowcrown.json`; `fill` gets `open=[t1,t2,t3]` for seeded extras.

## 5. Loot tables (our item system)

New group `open_chest` in `content/rules/gear.json` beside `"chest"`: `t1`, `t2`, `t3` lists of
`{kind, chance, bonus}` entries (same schema as `chest`). Gems and consumables go through
`ChestLoot.drop` with the tier's `gems`, `tonic_odds`, `seed_odds` fields from `open_chests.json`.
Tier = `ChestLoot.rarity_bonus` (region bonus + dangerous area + match tier) clamped per chest tier
so a T1 never gives top-rarity gear. Economy check: expected gems per match from open chests must stay
under 40% of the locked chests' (checked by a new `--open-chests-check`).

## 6. Map icon

Use the map-clarity icon set in `scripts/ui/icons.gd` / `map_key.gd` (I could not find a written
map-clarity doc yet; the build job must read that PR when it lands). Loot = **gold**.
- T1: small gold dot; T2: gold chest glyph; T3: gold chest glyph with a ring.
- Unopened only; an opened chest drops off the map. Not shown until within 60 m (fog of loot) or
  seen, so the minimap stays clear; the full map shows all T2/T3 you have seen.
- Locked key chests keep their existing icon (key glyph) so the two are told apart by shape, not just colour.
- Legend entry in `map_key.gd`.

## 7. Perf budget

- Max **40** open chests live per match; each is one mesh (~300 tris, shared material, instanced via
  MultiMesh per tier) and one `Area3D`-free proximity check done in the existing interact scan
  (`_update_interact`), no per-chest `_process`.
- Glint/hum: tier 3 only, one shared looping audio voice per hunter, picked from the nearest T3. No new particle systems.
- Budget: <= 0.1 ms per frame, 0 extra draw calls beyond 3 (one per tier MultiMesh). Verify with
  the match perf run (`docs/MATCH_PERF.md`) before/after; do not claim a number until measured.
- Match-start cost: placement with the existing spacing pass; < 2 ms.

## 8. Files a build job would touch

New: `content/rules/open_chests.json`, `scripts/match/open_chest.gd` (tier logic, interrupt, net),
`tools/open_chests_check.gd` (+ `.uid`), `art/props/open_chest_{1,2,3}.glb` (Meshy, owner picks first),
`content/sfx/open_chests.json` (reuse creak/crate files at first).
Edit: `tools/make_hollowcrown.py` + regenerated `content/maps/hollowcrown.json`;
`content/rules/gear.json` (open_chest group); `scripts/match/chest_loot.gd` (tier arg),
`scripts/match/key_chest.gd` (share the hold code), `scripts/match/match.gd` (interact case, kept
small: god-file budget, put logic in `open_chest.gd`), `scripts/match/world.gd` (spawn/spacing),
`scripts/match/bots` scoring file for loot targets, `scripts/ui/icons.gd`, `scripts/ui/map_key.gd`,
`scripts/ui/full_map.gd`, `scripts/core/net.gd` (one event), `docs/LOOT_FEEL.md`, `docs/SPAWNS.md`,
`docs/decisions/` (new note). No save change (chests are per-match, nothing persisted); confirm with `--save-compat-check`.

## 9. Order and checks

1. Wait for map clarity (icons) and perf PRs. 2. Rules + placement + check script (headless).
3. Interact/interrupt + net. 4. Bots. 5. Art (Meshy, owner pick), icon art. 6. Perf A/B, `--keys-check`,
`--hot-zone-check`, new `--open-chests-check`.

Open choices (alternative noted, decided): open chests do not respawn (alternative: T1 respawn 90 s;
rejected, BR is one life and it feeds camping). Tier 3 in-combat block copies the reference; alternative is
a longer hold only.
