# Ground pickup reach

Picking things up should feel as quick as the source. This is what the source does for each kind of thing on the ground, what we do, and where the numbers live: `content/rules/pickup.json`, read by `scripts/match/pickup_reach.gd` (PickupReach), wired into `Match._update_pickups`, `_update_wpicks` and `_update_interact`. The check is `--pickup-reach-check` (`tools/pickup_reach_check.gd`).

## Sources

Tags as in docs/SUPERVIVE_FEEL.md. `[kits]` = `ext/agent-briefs:briefs/supervive-data/supervive_kits.md`, `[physics]` = `supervive_physics.md`, `[hero-ref]` = `briefs/hero-ref/*.md` (footage notes), `[est]` = my estimate from footage memory, nothing in the briefs says it.

- `[kits]` "Interact prompts seen: F Buy Stuff (shop), Hold F Brew Vive (healing station)": stations and shops take the interact key, a press or a hold. The same key on chests and deathboxes (README "hold F").
- `[kits]` Soulpack: "can pick up and carry allied Wisps"; `[hero-ref]` mooshmoosh: "Passive, Backpack, walk over: Walk over ally wisps to pick up and carry them"; dredge: "the arm also picks up wisps it passes". Wisps are taken by walking over them, no key.
- `[physics]` The hero nav agent is radius 43 uu (0.43 m); nothing in the movement data names a loot radius, so the walk-over radius below is an estimate.
- `[est]` Gold, power and consumables fly to you as you pass (a loot magnet about a hunter's height out, ~2 m); gear on the ground gets the F prompt on the piece under the cursor; nothing in the footage shows loot taken through a rock, and a dash across a drop still collects it.

## What the source does, what we do

| Kind | Source: key | Source: reach | Ours: key | Ours: radius / height (m) | Ours: when several | Fixed here |
|---|---|---|---|---|---|---|
| Consumables (tonic, belt items) | walk over `[est]` | ~2 m magnet `[est]` | walk over | `walk` 2.2 / 2.0, pulled in at 6 + 6x(2.2 - d) m/s, taken within 0.6 of the chest, 0.5 s after landing | every one in reach flies in, no order | numbers moved to rules; no pull through a wall |
| Armour shards | walk over `[est]` | same | walk over | same `walk` rule | same | same |
| Gems, seeds | walk over `[est]` (gold) | same | walk over | same `walk` rule | same | same |
| Rift key, chest key | n/a in the source | | walk over (a full stack leaves it glinting) | same `walk` rule (keys.json `pickup_pull` was a dead copy of it: removed) | same | same |
| Weapon tuning | n/a (SUPERVIVE has no tunings) | | walk over | `tune` 1.1 / 1.0 | first in list | numbers moved to rules; wall blocks |
| Gear (gloves, armour, boots, passives) | interact key `[est]` (an upgrade may auto-equip; not settled, see Open) | the piece under the cursor `[est]` | interact key (press) | `interact` 1.5 / 1.2 | **nearest the cursor** (was nearest the hunter) | cursor order; wall blocks |
| Treasure (valuables) | n/a | | interact key, player only | `interact` 1.5 / 1.2 | nearest the cursor | same |
| Bots: gear better than theirs, tunings | | | walk over | `bot` 1.4 / 1.0 | first in list | numbers moved to rules; wall blocks |
| Wisps (downed teammates) | walk over `[kits]` `[hero-ref]` | touch | walk over (Linnet Carrier, `pick_r` 1.1 + body; Dredge hook scoop) | `content/archetypes/tender.json` | up to 2 | unchanged, matches |
| Deathbox, chest, shrine, capture | hold F `[kits]` | | hold F | 1.5 / 1.4, 1.6, 1.8, capture 3.5 (Life, Match, capture.json) | first in list | unchanged |

Dashing: the source collects loot mid-dash `[est]`; ours has no state gate on walk-over pickups (a roll takes them, checked). Gliding: the source is a few metres up while gliding and takes nothing `[est]`; ours is the `height` of each rule (2.0 m for walk-over), so a low skim takes, a glide well above doesn't (checked).

Through a wall: `PickupReach.clear` runs `World.los` at chest height (1.0 m) from the hunter to the thing: a rock, ground more than a terrace higher, or a kit wall blocks it. A thing lying inside a rock's own cell is reached from any side so loot that bounced into one is never stranded.

## Open

- Whether the source auto-equips a gear upgrade walked over. Kept on the interact key: the briefs and footage notes say nothing, and the belt hint and tutorial pickup step both rest on the prompt.
- The walk-over radius is `[est]`; 2.2 m kept (within the estimate's error). Read it from the game data if the loot component is ever dumped.
