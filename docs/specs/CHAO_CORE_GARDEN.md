# The garden core: raise Boki, everything else is extra

Design lead spec for release 0.24.4 (owner order 11-10). Build list: [CHAO_CORE_GARDEN_TASKS.jsonl](CHAO_CORE_GARDEN_TASKS.jsonl).
The file name keeps the owner's working title. Nothing in the game uses names, looks, layouts or characters from any other game; every name below is ours.

## Owner summary (10 lines)

1. Home is a garden where your Boki live on their own: they wander, nap, play, make friends. You pet them, feed them, play with them.
2. How you raise a Boki shapes it: food changes its colour and element, play grows its stats, your company builds its trust.
3. Boki compete against other Boki in small games (a race first, three more after), and two grown friends can have an egg.
4. You take up to three Boki on an expedition. A well-raised Boki hits harder, lasts longer and has stronger skills there.
5. Expeditions send things home: seeds that open new garden zones, rare eggs, inks, snacks, and stories your Boki remember.
6. You never have to go on an expedition. A garden-only player still levels Boki and can still open every zone, just slower.
7. The garden is a small hub island with a stone ring in the middle. One zone is open at the start; the others show what opens them.
8. Crops, chopping, work stations, haul jobs and the Exchange are no longer part of the main game. They live in Hob's Workyard, which you can open or ignore.
9. The Workyard only adds: custom toys and decorations, treats, gems, and chores your Boki can choose to help with. Nothing in the garden needs it.
10. Old saves keep everything. Anyone who already built a farm has the Workyard open from the first load.

## Owner calls (my default is what gets built unless you say otherwise)

| # | Call | My default | The alternative |
|---|---|---|---|
| 1 | How many zones ship in 0.24.4 | Hub plus three zones: Bramblebank open, Glasswater Shallows and Cinderstep openable. Hushwood and Kitewind Ridge show as "still growing in" and open in the next release | Hold 0.24.4 until all five are built and benched (about one more day, two more zones to gate) |
| 2 | What happens to farms players already built | They keep working exactly where they are, and the Workyard counts as open for those saves | Fold old farms away and refund them in gems (clean, but takes things from players) |
| 3 | What the Workyard costs a new player | Free. Hob offers it once the first-day list is done; "Not now" is always fine and he never nags | Charge gems or an expedition find for it (makes an optional thing feel like a goal) |

---

## 1. The one design

The garden is the game's home loop and it is always on. There is no `base_mode` switch any more: the garden systems run for every save, and the farm-sim systems run only for a save that has opened the Workyard. Two layers, one rule between them: **the Workyard may add, it may never be needed.**

| Layer | What is in it | Who has it |
|---|---|---|
| **Garden core** | Boki living on their own, petting, feeding, carrying, toys, the four games, breeding, the egg, the Elder, the journal and away card, the hub, the zones, the Drift Trader's stall, the expedition portal | Every save, from the first second |
| **Hob's Workyard** | Crops and fields, chopping and mining, work stations, haul jobs and the Job Board, the Exchange and the Sell tab, blueprint building with wood and stone | A save that said yes to Hob, or an older save that already had a farm |

What this replaces: today the garden only exists behind a rules flag that is off in the shipped game (`content/rules/farm_build.json` `base_mode: false`), and the shipped home is the farm-sim.

## 2. The first 10 minutes (new player)

A new save lands in Bramblebank, not the hub: the first thing on screen is a Boki, not a menu. Every step is led by the Boki walking there and waiting (the Lead state), every step can be skipped, and nothing has a fail state.

| Time | Beat | The player does | The player sees and learns |
|---|---|---|---|
| 0:00 | Arrive | Nothing | The starter Boki runs over and hops. It was waiting for you |
| 0:30 | Pet | Hold E on it | Hearts, a happy sound, a trust tick. "It will remember that" |
| 1:00 | Feed | Follows it to the snack patch, picks a snack, hands it over | It eats; its colour starts to shift. The card says which element it is leaning toward. Food shapes it |
| 2:30 | Play | Follows it to the ball, throws it | It fetches. "Speed +1, from fetch". Play grows stats, and the game says why |
| 4:00 | Hatch | Holds the welcome egg in the Incubator to warm it | A second Boki hatches and gets a name. The baby trails the starter around |
| 5:30 | Watch | Nothing (the list says "let them be for a moment") | The two play, then nap in a pile. They live on their own |
| 6:30 | Race | Walks to the flag, enters the starter in The Dash against a visiting Boki | Cheering at the marks helps. Win or lose it gets joy and a ribbon line in its journal |
| 8:30 | Hub | Follows the Boki to the return pad | The hub: the Waystone with four dark stones. Each stone's card says what wakes it |
| 9:30 | Portal | Looks at the expedition portal | One line: what this Boki's care gives it out there. "Take it along" or stay; both are fine |

At 10:00 the player has two Boki, one stat point, one race run, a visible colour shift, and three open hooks: wake a zone, grow the baby, go on an expedition. The first-day list in the Goals tracker carries the rest (pair two grown friends in the Nesting Nook, +15 gems) into the next sessions. After the list, Hob waves from his gate with the Workyard offer.

The welcome egg is new: today a new save has one Boki, so the nap pile and the Nook step have nothing to work with. One egg of the starter's own species, in the Incubator from the start, ready at the fourth minute.

## 3. The core loop

```
   raise (pet, feed, play, keep company)
     -> the Boki grows (colour and element lean, four stats, personality, trust, level)
     -> compete (The Dash, Stump Shove, Seek, Spark Volley) and breed (Nesting Nook)
     -> take up to three on an expedition (they ride as wisps)
     -> bring things home (Wayseeds, Rare Eggs, Inks, snacks, soul echoes, stories)
     -> the garden grows (new zone, new egg, new look) -> raise
```

The four levers stay as in the garden brief, one sentence each:

- **Food shapes element and look.** Each of the 18 types has a snack. About two meals of one type shows a tint; 12 of 24 lean points is the key for that type's zone.
- **Play grows stats.** Ball: Speed. Post: Power. Tub: Focus. Games and drills cover Guard. Each stat tops out at 100, all four together at 240, so every Boki ends up a shape, not a maximum.
- **Company grows personality and trust.** Who it plays with, who it naps beside, how often you are around. Friends and rivals form on their own.
- **Expedition finds make the big jumps.** A Wayseed opens a zone, a Rare Egg starts a line, an Ink changes a coat, a soul echo teaches an Elder's trick.

Rules that keep it kind: a Boki never dies or leaves from neglect (sulky at worst), stats never go down, and time away shows up as a short away card, not a bill.

Breeding is a main path, not an end-game one: two Grown Boki that are friends and rested, one egg, hatching after one expedition or ten minutes at home. The baby takes its species from one parent, its lean from what the parents ate, and a head start in the stats its parents were trained in.

## 4. Garden and expedition: one loop, two halves

**What a Boki takes out with it** (all already read by `Care.match_mods`; the numbers are today's):

| Raised in the garden | Shows up on the expedition as |
|---|---|
| Power, Guard, Speed, Focus (first 25 points of each count) | Up to +10% damage, +12.5% health, +6% move speed, 7.5% faster skills |
| Trust: Close (50), Soulbound (90) | Skills +5%; then +10% health and damage |
| Condition (fed, rested, happy) | 0.82x to 1.1x on damage and health. A happy Boki fights better |
| Element lean (next release) | A 5% edge on skills of its leaned type |

Only the first 25 points of a stat count out there, on purpose: a week of care gives the full expedition edge, and the other 75 points are for garden games, looks and pride. Raising matters in a match without deciding it.

**What comes home** (win, lose or leave early):

| From the expedition | Feeds the garden as |
|---|---|
| Wayseed (lair drop, by the lair's biome) | The first key to a locked zone |
| Rare Egg (Sealed Lair drop; the Heart's final seat) | An egg in the Incubator |
| Inks, wild snacks | Coat changes; lean points in types the snack patch does not grow |
| Soul echo (from a Boki you took) | A trick an Elder can pass on at the Soul Shrine |
| Level XP, trust (+6 early Heart seat, +20 final seat) | Growth stage and trust rank |
| The trip itself | A journal line and a homecoming: the ones who went run over and "tell" the ones who stayed |

**The rules that tie them:**

- Your own Boki always come home. Limited Way Outs changes who leaves with loot, never who keeps their Boki (owner 11-09 and 11-10).
- A lost expedition still pays the garden something: XP, a journal line, and tired Boki that want care. Losing sends you home to do the fun thing, not to grind.
- The garden pays the expedition back the same day: a fed, rested, played-with Boki is at 1.1x.
- Garden-only play is real: care and games give level XP (`content/rules/garden_xp.json`), held to at most 2x slower than expedition play by `--garden-pace-check`, and the Drift Trader sells a Wayseed every three days.
- Expedition-only play is real too: Boki at home look after themselves, and the away card catches them up.

## 5. What "garden on by default" means, system by system

| System | Status | Where it lives | Note |
|---|---|---|---|
| Boki life (roam, eat, nap, play, watch, react) | Core | Every zone | Always on. Today it only runs under the flag |
| Pet, feed by hand, carry, name | Core | Every zone | |
| Toys (ball, post, splash tub; zone toys) | Core | Zones (none in the hub) | Placed from the Base tab in build mode. Today they only work under the flag |
| Snack patch | Core | Bramblebank | Free food forever; never sold |
| The four games, games board, weekly race | Core | Zones; board in the hub | |
| Nesting Nook, Incubator, Soul Shrine, Burrow | Core | Hub nest corner | |
| Journal, away card, first-day list | Core | HUD | |
| Hub, Waystone, zones, Wayseeds | Core | | |
| Drift Trader's stall | Core | Hub | Buys nothing. Sells snacks, toys, an egg now and then, a weekly Wayseed |
| Expedition portal and glider rack | Core | Hub | |
| Placing toys, nests and decorations | Core | Any open zone | Build mode keeps the Garden, Base and Island tabs. Costs gems or expedition finds only |
| Chores by knack (a Boki tidies, waters the snack patch, minds an egg) | Core | Zones | A Boki's own choice, never an order |
| Crops and fields | **Optional** | Workyard | Upside: treats (a cooked snack, about twice the lean of a raw one) |
| Chopping and mining, tools | **Optional** | Workyard | Upside: wood and stone for custom pieces |
| Work stations | **Optional** | Workyard | Upside: craft custom toys, decorations, zone furniture |
| Haul jobs, the Job Board | **Optional** | Workyard | Upside: gems |
| The Exchange, the Sell tab | **Optional** | Workyard | Upside: gems for surplus |
| Blueprint building with wood and stone | **Optional** | Workyard | Upside: a house and garden that look like yours |
| Boki helping at stations | **Optional** | Workyard | Upside: one more way to earn trust and a stat point a day. Offered, never assigned; a Boki with low joy refuses and that costs nothing |

Three promises, each one a check (`--garden-core-check`):

1. A new save with the Workyard closed can get every toy, play every game, hatch and breed, open every zone and reach every stat cap.
2. No core item costs a Workyard-only material.
3. Nothing the Workyard makes beats a cap or is Workyard-only power: treats are also on the Drift Trader's weekly shelf.

## 6. Where things live: the hub and the zones

- **The hub** is a small round island (about 20 m): the Waystone in the middle, the nest corner, the house, the expedition portal and glider rack, the Drift Trader's stall with the games board, the Burrow door, and **Hob's gate** on the landward side. No toys, no Boki living here; it is the crossroads.
- **Five garden zones** hang off the Waystone, one stone each. Boki live in zones, six out per zone, the rest in the shared Burrow. Only the zone you are standing in is simulated; the others catch up when you step in.
- **Hob's Workyard** is a sixth place, reached through Hob's gate, not the Waystone: it is not an element zone and no Boki lives there. Boki can come along to help.

| Zone | Open at start | Types that thrive | Trait | Signature toy and game |
|---|---|---|---|---|
| Bramblebank | Yes | Normal, Grass, Bug, Spore | Loyalty | Ball, dig patch, snack patch; The Dash |
| Glasswater Shallows | No | Water, Ice, Crystal | Calm | Splash tub; Spark Volley |
| Cinderstep | No | Fire, Rock, Steel, Dragon | Fiery | Warm stone, post; Stump Shove |
| Hushwood | No (next release) | Dark, Psychic, Poison | Curiosity | Lantern hollow; Seek |
| Kitewind Ridge | No (next release) | Flying, Electric, Fairy, Sound | Bravery | Updraft vent; the ridge Dash |

**How a locked zone opens: two keys, one from each half of the game.**

1. A **Wayseed** of that zone. From an expedition: a lair of the matching biome (frost for Glasswater, ember for Cinderstep), about 1 run in 20. From the garden: the Drift Trader, 110 gems, restocked every three days.
2. A **Boki that leans** toward one of the zone's types: 12 of 24 lean points, about two meals of the right snack.

Bring both to the zone's stone and the Boki plants the seed. It becomes the zone's founder (a line in its journal, its name on the stone's card). The dark stone's card always shows both keys and how close you are to each. Order is free; no zone needs another.

Why open one: a Boki in the zone that suits it loses joy half as fast, its zone toys train 25% faster, and each zone has a toy and a game the others do not.

**0.24.4 ships** the hub, Bramblebank, Glasswater and Cinderstep. The Hushwood and Kitewind stones stay dark with the card "Still growing in. It opens in a later update", and their Wayseeds do not drop or sell until the zones ship, so nobody holds a key to a door that is not there.

**The Workyard in 0.24.4** is a per-save switch, not yet its own island: saying yes to Hob turns the farm layer on where it stands today (Bramblebank's plot and its side isles, whose bridges come back). Its move to its own island behind Hob's gate is the first task after the release and carries the save step that moves the pieces. Old farms and new Workyards are in the same state, so one move covers both.

## 7. What must change from today's code

Today: origin/main (0.24.3) ships the farm-sim with no garden. The release candidate (`ext/release-integ-0244-fix` ec3c9dafb) carries a slice of the garden (toys, Nook, the flag, a duplicate Dash). The full garden is READY but unmerged on `ext/garden-zone-budget` 410c9524e (the whole `ext/garden-integrated` line plus the hub, Waystone, Glasswater and Cinderstep).

1. **Merge the full garden into the release line.** 27 files conflict. Keep the garden line's `BaseRace` and `Fsm`; the candidate's copy from `ext/garden-race-main` is the duplicate and goes.
2. **Remove the `base_mode` flag.** `FarmUnlocks.base_mode()` has about 25 call sites with two meanings. The sites that switch the garden ON (Boki life in `home.gd`, toys, snack patch, no starving in `care.gd`, lean, mentor card, the garden tutorial, hub landing) lose the condition. The sites that switch the farm-sim OFF (`home_gather.gd`, `home_work.gd`, `home_market.gd`, the build tabs in `home_build.gd`) read a per-save `Workyard.open()` instead (new `scripts/home/workyard.gd`). The key leaves `farm_build.json`.
3. **Boki life and Workyard jobs must coexist.** Today a save runs either Boki life or the old job AI. With the Workyard open, station and haul jobs become extra chores a Boki may pick in its Chore state, under the same joy rule as any chore.
4. **One save chain from the shipped format.** Only v11 is in players' hands. The candidate's v12 (evolution data) and the garden line's v12 (bonds) merge into one v11 to v12 step; v13 is zones and each Boki's home zone; v14 is the Workyard switch (on when the save shows farm progress: any field, station, tool upgrade or Exchange sale). Every step only adds keys that are missing. Decision note in `docs/decisions/`.
5. **Unlock path.** Wayseed (`ext/garden-wayseed`), its pacing (`ext/garden-unlock-pace`) and the thrive bonus (`ext/garden-thrive`) on top of the merge; dark-stone cards for the two unbuilt zones.
6. **The first 10 minutes.** The Boki-led tutorial, the first-day list, the hub hints, the welcome egg, the retired side-isle bridges.
7. **Expedition ties.** Garden XP, the 25-point clamp in `Care.match_mods`, the homecoming.
8. **Checks that assert the old default** (`farm_tutorial_check`, `race_check`, `snack_patch_check`, `toy_check`, `base_demo_check`) are rewritten to assert the new one. That is a changed rule, not a weakened check.
9. **Performance.** On the M5 at Medium the hub draws 689 against a 200 budget, Bramblebank 740 against 350, and Cinderstep runs 18.3 ms against 16.7. The gate is frame time: 16.7 ms in the hub and all three zones.
10. **No Net change.** The garden is not synced; `Net.VERSION` stays whatever Limited Way Outs sets.

## 8. What to cut

- The `base_mode` rules flag and every "off" path behind it.
- The duplicate Dash on the release candidate (`ext/garden-race-main`), and the superseded branches: `ext/garden-unlock` (Wayseed won), `ext/garden-zone-cinderstep` and `ext/garden-cinderstep` (rebuilt as `ext/garden-cinderstep-zone`), the second zone-look class on `ext/garden-lantern-zone-hub`.
- `ext/farm-optional-1108` (the Auto-farm toggle): it automates a layer that is now optional. Not merged.
- Starving, sickness from hunger and any stat loss in the garden. A hungry Boki sulks.
- The side isles as part of the garden (they become Workyard land).
- Farm level as a gate on anything in the core. It stays as the Workyard's own progress.
- Selling as a core money loop. Gems come from expeditions, games, the first-day list and wishes; the Exchange is Workyard-only.
- From the genre, on purpose never built: good and evil alignment, coloured stat orbs, letter grades, a lifespan that resets the creature, fixed preset gardens, a creature school, a shady-market shop name.

## 9. Saves

Old saves load and lose nothing: every Boki starts in Bramblebank, every placed piece stays where it is, a save with farm progress has the Workyard open, a save without it gets Hob's offer like a new player. The garden tutorial does not replay for a save that finished the old one; it gets the first-day list only. `--garden-save-check` loads a real shipped v11 fixture (one with a farm, one without) and proves all of this.

## 10. Scope

**In 0.24.4** (tasks labelled `[garden-0244]`, sized for about 12 hours of parallel work): the merge, the flag removal and Workyard switch, the unlock path with three zones, the first 10 minutes, the expedition ties, the save gate, the frame-time pass, Hob's offer, one feel pass, one final gate.

**After** (`[garden]`): the Workyard as its own island; Hushwood and Kitewind Ridge; stats that show on the body (Power broadens it, Guard thickens it, Speed lengthens the stride, Focus brightens the marks); the lean edge on expeditions; the results card and journal lines for each way out; Workyard treats and crafting; the care-depth, games, cups, wishes, family tree, sound and animation packs that are READY today.

## 11. Risks

| Risk | Guard |
|---|---|
| The merge (27 conflicts, two Dash copies, two save lines) eats the 12 hours | It is the first task and a deep one; everything else stacks on its branch and can start the moment it posts READY |
| Old farms break when Boki life and jobs run together | The v11 fixture with a farm in `--garden-save-check`; `--garden-core-check` runs both Workyard states |
| A new player cannot reach a zone without luck | `--garden-unlock-pace-check`: the Trader path opens a first zone inside a week of garden-only play |
| The hub misses its frame budget | Frame time is the gate; draw counts are reported, not gated |
| Limited Way Outs and the garden touch the same lair loot | The Wayseed drop goes in the lair's loot table only; `heart.gd`, `exits.gd` and the lair flow belong to the Way Outs tasks |
