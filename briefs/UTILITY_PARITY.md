# Utility parity audit (source vs Boki), Nov 9 2026

Owner ask (11-09): "in supervive there are 6 utility (i believe) and lots of utility items - lets copy
everything over and do our own artwork and 3d work for it". Source facts from docs/SOURCE_UTILITIES.md
(wiki + patch notes, read Nov 8); ours from `content/utility/*.json` on **ext/utility-parity**
(cut from ext/utilities-shops-rebased). Source HP is about 7.2x ours, so a source number divided by
7.2 is "the same" here. Prices and bring caps stay in our economy on purpose (gems, not gold).

## Slots

| | Source | Ours before | Ours now (ext/utility-parity) | Gap |
|---|---|---|---|---|
| Belt slots | 6: slot 1 only the brew, slot 2 only the armor repair, 4 open | 4 open | 6: slot 1 the Tonic's, slot 2 the Armor kit's (JSON `slot`), 3-6 open; keys 1-6 | closed |
| Home belt pick | n/a (bought in match) | 4 picks | picks fill the open slots; pinned items always present; old 4-item saves read back unchanged | closed |

## Items (28 ours; 24 source consumables mapped, 5 source items skipped)

| Item | Source behaviour (numbers) | Ours | Gap |
|---|---|---|---|
| Tonic (Vive Brew) | 1 s drink, 304 HP + mana, Vulnerable, a hit cancels, cleanses anti-heal, stack 8, fixed slot 1, 200 gold | 1.0 s, flat 42 HP, no slow, a hit spills, stack 8, slot 1, 30 gems | closed (no mana here; no cleanse) |
| Armor kit (Portable Armor Repair) | short cast, repairs 80% grey / 40% green / 30% blue of the bar, stack 8, fixed slot 2, 400 gold | 1.6 s at 45% speed, 80/40/30% by armor tier, stack 8, slot 2, 40 gems | closed |
| Deep Draught (Hypervive) | 60% slow + Vulnerable 5 s, then full HP + mana, a hit cancels, stack 1, 1000 gold | 40% speed 5 s, full HP, a hit spills, stack 1 | closed |
| Hawk Whistle (Pocket UAV) | marks every enemy hunter on the squad map, short time, stack 2 | whole-map reveal 4 s, stack 2 | ours shows bodies not map marks; keep |
| Spring pad (Jump Pad) | arms 2 s, lasts 30 s or 10 s after first use, stack 2 | same | closed (earlier branch) |
| Cloud Raft (Emergency Platform) | over air only, 30 s, refills gliders, vision | over air only, 30 s | glider refill not wired |
| Gust Fan (Deployable Fan) | launches on touch, 60 s, 2 charges, has HP | 60 s, stack 2 | no HP (can't be shot down) |
| Twin Gate (Two-Way Teleporter) | portal at aim + at feet, reactivate after 8 s to swap, stack 2 | swaps by itself at 8 s, stack 2 | second press not built; alternative noted |
| Warp Seed (Pocket Anomaly) | placed anomaly, channel, random teleport, timed, stack 3 | 1.5 s stand, random spot, 30 s, stack 3 | closed |
| Bounty Banner (Most Wanted) | 2 min reveal; survive = team revived + reward; knocked = straight to deathbox, knocker's team takes reward; one per team | 120 s, squad returns + 150 gems; **knocked = out at once, knocker pockets 150 gems**; one per squad | closed (kills don't shorten the timer) |
| Hearth Lamp (Mobile Respawn Beacon) | squad beacon, 6 s revive, 12 s sickness | revive beacon, any squad once | sickness not modelled |
| Skyfall Charge (Tactical Nuke) | 5 s fuse, 5000 dmg, fire 720/s for 3 s, hurts allies, kills beacons | **5 s fuse, 690 (lethal), fire 100/s for 3 s** | allies and beacons safe (no ally-hit path in Effects) |
| Pilfer Pouch (Mass Heist) | 1.5 s channel, steals 50% gold + vault loot | instant, destroys 50% of rivals' gems | channel and vault loot not built |
| Lostway Scroll (Anywhere But Here) | 4 s channel, random spot in the next circle, stack 1 | 4 s, random spot on the map, stack 1 | no storm circle here |
| Smoke bomb (Ethereal Smoke) | team stealth + speed 30 s, breaks near enemies | fixed cloud 8 s | design choice: keep ours |
| Shatter Charge (EMP) | 0.3 s after landing: 1600 armor + 30% slow 2 s | a beat after landing: strips most armor, slow 2 s | closed |
| Blight Flask (Death Circle Grenade) | storm pocket 40 s total, blocks all healing | **40 s patch, blights (heal cut), burns, slows**, stack 2 | closed (one size, no grow/shrink) |
| Lookout Lantern (Scan Grenade) | ward 60 s, reveals stealth, pick-up-able, stack 4 | 60 s reveal 14 tiles, stack 4 | cannot be picked back up |
| Thorn Wall (Spike Wall) | 2 s self-root to build, speed-based damage, stack 10 | 20 s wall, cut + slow on touch, **stack 10** | no self-root |
| Omen Draught (Prophet's Potion) | 1 s channel, team sees future storms 30 s | 1 s, squad sees Blight Wardens 30 s | closed (our storm = Blight) |
| Toss Satchel (Vive Packs) | pack lies 30 s, 140 HP/s for 5 s, air bounce, 2 charges | 30 s, 60% HP over 5 s, stack 2 | no air bounce |
| Chest Key (Gold Key) | nearest golden chest, opens vaults too | pings/opens locked chests | no vault open |
| Rift Key (Evil Key) | nearest evil chest | opens an extraction hatch | design choice: keep |
| Revive Ember (Orb of Revival) | boss reward, revives team at full HP | wakes fallen squadmates, boss/chest only | closed |
| Mending kit, Shield cell, Swift draught, Seeker flare | no final-version source item (Elixirs were cut) | ours | ours only; keep |
| Basecamp Recaller / Deployment Beacon | basecamp system | none | skip: no basecamps |
| Tome / Codex | in-match levels | none | skip: no levels |
| Little Cook, Snowball, Chonker Cannon, Present, Tree Costume, Money Tree | seasonal event items | none | skip for now (events) |

## Checks
`--equal-check` (slots, tonic, kit, home picks, deathbox), `--utility-parity-check` (banner knock,
skyfall, blight patch), `--equal-migrate-check`, `--shops-check`, `--raid-check`, `--backpack-check`,
`--airheal-check`, `--box-revive-check`; `health.py --strict`, `gen_wiki.py --check`. All green.

## Left for later (each noted in docs/SOURCE_UTILITIES.md "Built Nov 9")
Twin Gate second press, Pilfer channel + vault loot, Skyfall ally/beacon damage, fan HP, lantern
pickup, satchel air bounce, Thorn Wall self-root, revive sickness, Tonic anti-heal cleanse, Bounty
timer shortening on knocks. Art: briefs/boki-art/UTILITY_ITEMS.md (28 cards, 2D first, 3D after approval).
