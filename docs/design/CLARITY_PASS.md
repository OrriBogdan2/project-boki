# Clarity pass (Nov 12): fixed spawns, less visual noise

Owner rule (briefs/DECISIONS.md, "CORE SERIES PRINCIPLES" #1): Supervive-level readability. No random
enemies; every enemy/camp/boss spawns at a fixed, learnable place on a predictable timer, telegraphed
before it appears; VFX that carry no gameplay info get cut. Line numbers below are `origin/main` (0.24.4)
before this pass; the 0.24.5 rows are ext/release-integ-0245 2723685892.

## 1. Spawn audit (Expeditions; the farm and its tutorial spawn no hostiles)

| Spawn | Where (before) | Random before | Now |
|---|---|---|---|
| Camp monsters (type mix) | match.gd:971-990 | type by `rng` per camp | `SpawnTable.camp_comp`: camp k always holds list[k % n] |
| Camp monsters (place) | match.gd:1000 | +-1.8 tile jitter | ring slots round the camp spot |
| Biome camp mix | biome_run.gd:90 `_pick` | weighted `rng` | weighted, by a fixed fraction per camp slot |
| Camp return (rolling) | rolling.gd:290, 615 | jitter, who is pre-cleared | same ring; pre-cleared camps by camp number; **8 s ring before it returns** |
| Wild Boki live subset | match.gd:1534 | 25% by match seed | every 4th spot, same in every match |
| Wild Boki species/level | match.gd:1544 | `rng` | species and level by spot number |
| Rare Boki, vaults, caches, boss lair live | spawn_plan.gd:170-186 | shuffle by seed | `SpawnTable.spread`: evenly through the authored list |
| Rare Boki species/level | spawn_plan.gd:217 | `r.randi` | by candidate number |
| Wardens (count, post) | blight_dir.gd:116, 135 | `rng` by match seed and raid | `rng` seeded by the map and island |
| Skitters out of the ground | blight_dir.gd:303-370 | noise "heat", random spot 13-20 tiles from you, random pack | **burrow nests**: one per island, fixed spot, first time and interval by danger tier, 6 s ring + minimap countdown |
| Warden shriek pack | blight_dir.gd:244 | random angle/radius | fixed ring round the Warden (the shriek is its telegraph) |
| Lair guards | lairs.gd:476-480 | angle, radius, kind | ring, kind walks the pool |
| Brood Mother adds | boss.gd:604, 619 | angle, kind (egg ring and timer already telegraphed) | ring, kind by egg number |
| Dock/uplink waves | exits.gd:727, 748 | kind, spot (timer and toast already existed) | golden-angle slots, kind by wave |
| Hazards (generated maps) | biome_run.gd:380, 399, 492-560 | spot, first strike, interval | map-seeded spot, fixed 6.5 s round; hand maps already authored |
| Lightning strike target | biome_run.gd:475 | +-3 tiles | fixed round of six marks (ring already shown 1.2 s) |
| Tutorial camp (0.24.5) | tutorial_camps.gd:80 | angle round the player | `CAMP_ANGLE` |
| Sealed Lair quest seat (0.24.5) | quest_seats.gd:42 | which lair, by match seed | by the map (`SpawnTable.map_key`) |
| Glimmerkin | match.gd:4866 | island and cell | `SpawnTable.glimmer_spot` (map-fixed), **8 s ring + countdown** first |
| The Watcher (centre island) | match.gd:4772 | (fixed spot and time) | **8 s ring + countdown** before it wakes |

Not spawns, left alone: Mob/Blight wander and cooldown jitter (mob.gd:43-197, blight.gd:50-277), boss
attack picks (telegraphed), lair puzzle needle (lairs.gd:90, 381), rarity/mutation/loot dice (the
COMMON/RARE/VERY RARE tiers; they change what a spawn drops or carries, not where or when), the match
weather (RaidLook.pick; chosen per match and shown in the lobby, it only scales sight and Blight level),
meteor strikes (each lands near a random hunter after a 1.5 s ring), the Heart's site on generated maps
and its Gate angle (match seed; heart.gd belongs to the Heart Raid lane, docs/DEBT.md).

**Spawn table.** `content/rules/spawn_tables.json` (camp lists, wild stride, burrow timing by danger tier)
and `scripts/match/spawn_table.gd`. `SpawnTable.rows` is the per-map table: `{id, what, pos, n, first,
every}`, built from the map's islands with a map-only seed (same map, same rows, any match seed); the
schedule is a pure function of the session clock (`due_at`, `schedule`). A row inside its last 6 s shows
a ring on the ground and a counting ring on minimap and full map (`SpawnMarks`). A nest with no hunter
within 70 tiles skips its turn; a nest that is overdue (a late join to a rolling session) fires only the
turn due now, never the backlog. Skyreach has 7 nests (first turn 80-146 s, every 90-150 s by danger
tier): 56 turns in 15 min (a nest with nobody near skips its turn; the old heat trickle was never counted,
so density is judged by the timings above, not measured against it).
Noise no longer spawns anything; it only sends the Blight already out to look (so the Heart's
`tide_heat`, which fed that heat, is gone; the tide still raises the Blight's strength).

**No scouting.** The spots never move, so the full map shows every candidate as it is from the start
(live, empty cross, taken tick) for everyone; SpawnPlan's reveal-by-sight, the "?" marker and the
"spotted" toast are gone. The minimap shows live spawns while the map key is held (MapDetail).

**Heart Raid wave director must follow the same rule**: waves are rows (`first`, `every`, place,
what), the next wave's ring and countdown shows on the minimap before it appears, composition is a list
walked in order (no `randf`/`randi`), positions are authored points or `SpawnTable.ring_spot`. Reuse
`SpawnTable.mark/unmark/warning` for the telegraph. Any rarity dice stay seed-independent for *where* and
*when*.

Check: `--spawn-table-check` (two seeds, same monsters/Boki/live spawns/schedule/Glimmerkin spot; a nest's
ring and countdown, then its pack on time at its place; the Glimmerkin's and Watcher's lead-in rings; a
rolling camp's ring before it returns).

## 2. Visual noise around characters, worst first

Reference: Supervive. Clean silhouettes, team-colour outline, almost no ambient FX, VFX that say
something (a telegraph, a CC, a hit, a pickup). Ranked from code; before/after of a busy fight (`--blight-demo=all`, a Warden, Skitters, squad Boki) are
`docs/shots/clarity-1112/busy_fight_{before,after}.png`.

1. **Boki species specks** (`models.gd:2024`: 7-10 particles on every Boki, always on). Flavour only,
   and they sit on every Boki outline in a crowd. **Cut**: only a rare Boki shows them (`kin.gd:1086`).
2. **Ash-storm streaks** (`raid_look.gd:271`: 340 particles streaming over the whole view). The sight
   penalty already carries the info. **Toned**: 150 (70 in lite).
3. **Biome air** (`biome_run.gd:592`: 20-70 snow/spark/ember/spore specks per island, in a box up to
   2.5 m over the ground, so round every body). Region already reads from the ground tint and banner.
   **Toned**: 10-35 per island (`AIR_PER_TILE`).
4. Kin species aura shell and team rings: kept (team colour, squad Boki through walls = info).
5. Hit sparks, telegraphs, CC reads, shiny sparkle: kept (info).

(Boki wisp trails are only in the gallery prototype, not in matches.) Left (not cut here, see
`docs/DEBT.md`): glider trails, hero-kit hold motes (`hero_vfx.gd`
~383-650), ground clutter and sky deco.
