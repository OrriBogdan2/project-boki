# What bots do with each kit

Extraction is always 10 trios with bots backfilling, so most of a new player's fights are against bots. `scripts/match/bot.gd` calls each kit's `bot_use` (and the kit's own bot hooks); this page counts what a bot really presses, holds and recasts per slot, so an unused or misused slot shows up as a number.

**Run it:** `godot --headless --path . -- --bot-kit-check[=<archetype>] [--bot-kit-t=90] [--bot-kit-seed=7]` (`tools/bot_kit_check.gd`, with a temp `XDG_DATA_HOME`). For each of the 12 Hunters it plays one bot-vs-bot fight of **90 s** on the flat duel island: both fighters play that Hunter, every slot open at level 12, and the bond meter refilled every 30 s so Fuse is on offer. Meeko gets a hurt Vex squadmate 8 m away per side (Hearthlight is thrown to a squadmate, Hearth Call needs one). All 12 take about 50 s. Counts are both fighters summed and move a little from run to run (the bots roll the game's dice, and a fight that goes differently reshuffles them).

**What fails the check.** A Hunter fails when its bots never use a slot (LMB fired and hit, an RMB press, E, R, dash, glide, Fuse, any hit at all), when a kit with an RMB hold presses RMB but never holds it past the hold threshold, and for these kit moves that need the bot to do something specific:

| Hunter | Must happen in 90 s | Counter |
|---|---|---|
| Kael | Lunge let go in the perfect window; Warchain reeled in | `lunge perfect`, `chain reel` |
| Lace | Heavy Shot drawn to full and released | `full draw` |
| Cinder | Furnace Cloak drags a foe in | `cloak pull` |
| Meeko | Hearthlight thrown to a squadmate (the E recast) | `hearth toss` |
| Neve | Skate; Rink Wall frozen while it slides | `skate`, `rink freeze` |
| Tenzo | a Rock Hop after the first of a chain | `hop recast` |
| Motley | Brimseed popped (E recast); Lantern Trade swap | `brimseed pop`, `lantern swap` |
| Sparkle | Kitefall strike lands on a foe | `kitefall foes` |
| Sable | Shadow Knife blinked to (E recast) | `knife blink` |
| Mossy | hammer thrown and recalled; Shield Charge from behind the aegis | `hammer throw`, `hammer recall`, `shield charge` |

Meeko's R (Hearth Call) is exempt: it needs a downed or under-35% squadmate, which the test does not stage.

**Reading the columns.** LMB `s` = seconds the bot held fire. RMB press = the key went down; held = released after the kit's hold threshold. Hits by tag: `primary`/`shot` (and Cinder's `flame`) are LMB, `utility` RMB, `k1` E; many kits tag other hits with another word, so a 0 in one hit column only means "not tagged that way"; the last line of each table is every hit. R = the Hunter ultimate (`ultimate` casts). Fuse = a merge started.

## What the bots were fixed to do (bot side only, no kit numbers)

- **Kael** (`juggernaut_kit.gd`): Lunge held to full charge + 0.07 s so it lets go inside the 0.15 s perfect window (60% of the time at 3.2 to 7 m); a hooked Warchain is reeled in from 2 m.
- **Mossy** (`bulwark_kit.gd`): a thrown hammer is recalled from the ground after 0.8 s; throws at 3.6 m or more; holds the Aegis up close so the dash is a Shield Charge; raises it against only half the shots, since the hammer needs the aegis down; ultimate at 4 to 13 m.
- **Neve** (`rimewright_kit.gd`): schedules the freeze 0.15 to 0.45 s into the Rink Wall's slide; holds the Ice Spear past its 0.2 s tap so the landing ring shows.
- **Tenzo** (`dolm_kit.gd`): Stone Row only when `row_spots` finds room (the bot used to press it over the island's edge, where it is denied), from 3 m out; the Basalt Spine every time a foe is inside its range (a 10% roll never fired it).
- **Cinder** (`ashwick_kit.gd`): holds Cinder Shot 0.3 s past its hold threshold, then lets go (it only tapped).
- **Sparkle** (`mage_kit.gd`, `mage_sky.gd`, `mage_ult.gd`): holds the Storm Rod a full 1 s (was 0.6 to 1.1 s, mostly short of the threshold); holds E to drag with Skycall; strikes Kitefall once the crown is on a foe.
- **Lace** (`archer_kit.gd`): presses the Starpiercer at a Hunter inside its range (30% of looks); the Heavy Shot is always held to full + 0.1 s.
- **Meeko** (`tender_kit.gd`): lights Hearthlight for a hurt squadmate and throws it to one outside the ring.
- **Motley** (`ostra_kit.gd`): the lantern leads the target by the flight time and a stunned target is always chosen.
- The two earlier branches (`ext/bot-kit-use-a`, `-b`) carried the Kael, Mossy, Neve, Lace, Sparkle, Meeko and Motley fixes and each their own check; this page and `--bot-kit-check` replace both checks.

## Left

- **Grimble's air pounce:** the dash press is read before the kit ticks and every press flag is cleared at the end of the step, so a kit cannot jump-then-pounce on its own; a bot would need a per-step press from `bot.gd`. Rare in a fight (it only happens when a fall meets the 3 to 6 m window).
- **Lace's wall pin:** needs a wall within 3 m behind the foe along the shot; the flat island has none. Waiting for a wall behind the foe cut the shots without raising the pins, so it was dropped.
- Hit tags: the check asserts LMB hits and the all-hits count; RMB, E and R hits are shown but not asserted, because kits tag them with their own words.

- **Kael** (`juggernaut_kit.gd`): the Lunge hold is `full_t + 0.07 s`, inside the 0.15 s perfect window, instead of a charge that never reached it (1 perfect of 14 holds became 5 of 6); a hooked Warchain is reeled in from 2 m (was 3.5 m, and only 80% of the time).
- **Mossy** (`bulwark_kit.gd`): the thrown hammer is recalled from the ground after 0.8 s (it used to stay out and block every other LMB); throws at a foe 3.6 m or more away; holds the Aegis 1.2 s up close so the Shift press is a Shield Charge (80% when the aegis is up); presses the ultimate at 4 to 13 m.
- **Neve** (`rimewright_kit.gd`): the bot schedules the freeze 0.15 to 0.45 s into the wall's slide (its decision tick, 0.9 to 2.2 s, never landed inside the slide of 1 s or less).
- **Lace** (`archer_kit.gd`): presses the ultimate at 4 to 14 m.
- Unchanged and already fine: Tenzo's Rock Hop recasts (21), Cinder's E pull (34), every Hunter's dash and glide. Meeko's ultimate heals a teammate, so the duel has none and the check skips it.

## Ultimate and Boki in a match

The duels above count presses; they don't say whether a bot fires its ultimate when it matters or brings its Boki to a fight. `--bot-kit-use --kit-use-match` (tools/bot_ult_use.gd) plays **one seeded 10-trio match per seed (3 and 5, 300 s each, bot difficulty "medium", every Hunter a bot)** with every Hunter raised to level 6 at the start, so the ultimate is open from the first fight. It takes about 3.5 minutes a seed.

Run: `godot --headless --path . -- --bot-kit-use --kit-use-match [--kit-use-t=300] [--kit-use-seeds=3,5] [--kit-use-diff=medium]` (with a temp `XDG_DATA_HOME`).

**What counts.** A *fight* is a bot targeting a rival Hunter within 12 m; it ends 3 s after that stops, and it is *real* once the two traded 2 hits. The ult is *ready and useful* while it is off cooldown, the rival is in sight and inside the ult's own reach (its data's range, reach, length or radius, 4 to 10 m). A *wait* is one stretch of ready-and-useful time; it is *on time* when it ends in a cast within 3 s, *late* when it runs past 3 s (cast or not); a wait the fight closes sooner is neither. A cast in a fight *lands* when the caster hits a rival Hunter while the ult runs or 3 s after (a trail or a well keeps hurting; any hit in that span: a long ult such as Lace's arrows counts its own shots). A cast *into nothing* has no foe or rival Hunter within 15 m. *Boki sends* are throws off the shoulder (`kin_thrown`); the Boki is *out* in a fight when it is ever off the shoulder in it (beside the bot, flying in, or merged), counted over the fights where it could be (not downed, reviving, resting, benched or dead).

**Targets** (the check fails a Hunter that misses one; Hunters with under 20 s of ready time are listed, not judged):

| Target | Value |
|---|---|
| Ready useful ult cast within 3 s | 60% or more of on-time + late waits |
| Casts in a fight that land | 50% or more (from 4 casts) |
| Casts into nothing | none |
| Real fights with the Boki out | 80% or more (from 5 fights) |

Meeko's Hearth Call heals a teammate below 35% (or downed), so its ready time against a rival is not judged; its row is shown.

Columns: fights (real), casts, casts in a fight, casts per minute of ready-and-useful time, landed (share of casts in a fight), into nothing, mean wait (s), on time, fights the ult sat ready 3 s or more with no cast, Boki sends, fights with the Boki out / fights it could be.

### Before (origin/main 53e2fe7f3)

| Hunter | Fights | Casts | In a fight | Per ready min | Landed | Into nothing | Mean wait s | On time | Ult left | Boki sends | Boki out |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Lace (`archer`) | 5 | 5 | 2 | 7.3 | 1 (50%) | 0 | 4.1 | 50% | 0 | 0 | 5/5 (100%) |
| Kael (`juggernaut`) | 12 | 15 | 9 | 38.0 | 5 (55%) | 0 | 0.6 | 100% | 0 | 8 | 10/10 (100%) |
| Vex (`gunslinger`) | 11 | 5 | 4 | 6.8 | 4 (100%) | 0 | 2.4 | 57% | 4 | 2 | 10/11 (90%) |
| Albert (`bulwark`) | 24 | 17 | 8 | 3.6 | 7 (87%) | 0 | 2.6 | 23% | 6 | 13 | 22/22 (100%) |
| Cinder (`ashwick`) | 8 | 11 | 5 | 50.4 | 3 (60%) | 0 | 0.7 | 100% | 0 | 7 | 7/7 (100%) |
| Meeko (`tender`) | 8 | 1 | 1 | 0.7 | 0 (0%) | 0 | 1.9 | 8% | 5 | 2 | 7/7 (100%) |
| Tenzo (`dolm`) | 9 | 2 | 2 | 1.4 | 2 (100%) | 0 | 2.4 | 10% | 6 | 5 | 8/8 (100%) |
| Grimble (`dredge`) | 10 | 14 | 6 | 9.2 | 5 (83%) | 0 | 1.3 | 60% | 2 | 5 | 9/10 (90%) |
| Neve (`rimewright`) | 3 | 2 | 2 | 18.4 | 1 (50%) | 0 | 1.1 | 100% | 1 | 3 | 3/3 (100%) |
| Sparkle (`mage`) | 6 | 4 | 3 | 12.5 | 2 (66%) | 0 | 2.4 | 66% | 0 | 1 | 5/5 (100%) |
| Sable (`thief`) | 5 | 6 | 5 | 18.3 | 5 (100%) | 0 | 0.8 | 80% | 0 | 6 | 5/5 (100%) |
| Motley (`ostra`) | 14 | 5 | 4 | 1.9 | 3 (75%) | 0 | 2.8 | 23% | 5 | 12 | 11/11 (100%) |
| Gil (`gil`) | 10 | 5 | 2 | 19.1 | 1 (50%) | 0 | 0.9 | 50% | 0 | 1 | 8/9 (88%) |

Misses: below gunslinger: 57% of ready ults cast within 3 s (target 60%); FAIL bulwark: 23% of ready ults cast within 3 s; FAIL dolm: 10% of ready ults cast within 3 s; FAIL ostra: 23% of ready ults cast within 3 s. Tenzo cast 2 ults in 9 fights and left a ready one unused in 6; Motley and Albert sat on a ready ult for 2.6 to 2.8 s on average. The Boki was already out in nearly every real fight (90 to 100%), so the Boki brain is unchanged.

### After

| Hunter | Fights | Casts | In a fight | Per ready min | Landed | Into nothing | Mean wait s | On time | Ult left | Boki sends | Boki out |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Lace (`archer`) | 6 | 2 | 1 | 10.3 | 1 (100%) | 0 | 1.0 | 50% | 1 | 1 | 5/5 (100%) |
| Kael (`juggernaut`) | 10 | 10 | 8 | 75.0 | 7 (87%) | 0 | 0.5 | 100% | 0 | 2 | 8/8 (100%) |
| Vex (`gunslinger`) | 14 | 12 | 12 | 26.8 | 10 (83%) | 0 | 1.2 | 83% | 1 | 8 | 12/12 (100%) |
| Albert (`bulwark`) | 24 | 32 | 19 | 40.3 | 14 (73%) | 0 | 0.9 | 94% | 1 | 21 | 23/23 (100%) |
| Cinder (`ashwick`) | 9 | 10 | 6 | 37.6 | 5 (83%) | 0 | 1.0 | 100% | 0 | 4 | 8/8 (100%) |
| Meeko (`tender`) | 7 | 1 | 1 | 1.2 | 0 (0%) | 0 | 2.1 | 0% | 5 | 5 | 6/6 (100%) |
| Tenzo (`dolm`) | 25 | 18 | 14 | 33.8 | 14 (100%) | 0 | 0.7 | 100% | 0 | 5 | 18/18 (100%) |
| Grimble (`dredge`) | 10 | 9 | 7 | 22.1 | 4 (57%) | 0 | 0.7 | 100% | 0 | 1 | 9/9 (100%) |
| Neve (`rimewright`) | 3 | 2 | 2 | 19.5 | 2 (100%) | 0 | 0.7 | 100% | 0 | 3 | 2/2 (100%) |
| Sparkle (`mage`) | 7 | 4 | 4 | 36.0 | 2 (50%) | 0 | 1.1 | 100% | 0 | 5 | 6/6 (100%) |
| Sable (`thief`) | 6 | 6 | 4 | 15.2 | 4 (100%) | 0 | 0.8 | 80% | 0 | 6 | 5/5 (100%) |
| Motley (`ostra`) | 16 | 13 | 4 | 58.8 | 4 (100%) | 0 | 0.7 | 100% | 0 | 7 | 14/14 (100%) |
| Gil (`gil`) | 5 | 4 | 1 | 67.9 | 1 (100%) | 0 | 0.9 | 100% | 0 | 1 | 5/5 (100%) |

No failures. Runs differ (the bots roll unseeded random numbers), so a row can move 20 points between runs; across five runs while tuning, every Hunter stayed above the floors except one 42% landed row (Neve, 3 of 7) and one 66% Boki row (Kael, 6 of 9), which is why the check fails only under the floor (on time 50%, landed 35%, Boki 70%) and marks "below" between floor and target.

### What changed (bot code only; no kit numbers, no Net or save change)

- **Every bot** (`bot.gd`): after an ability look, a bot whose ult is ready while it fights a Hunter looks again in 0.3 s instead of 0.4 to 2.8 s. Only bots with `abil` 0.5 or more (medium and up): **easy bots, the tutorial's, keep their pace**, and `Data.BOT_DIFF` is untouched.
- **Tenzo** (`dolm_kit.gd`) and **Motley** (`ostra_kit.gd`): no 10% dice on top of the conditions (a ready ult waited about 10 looks); Motley aims the Nightwell half a tell ahead of where the rival walks.
- **Vex** (`gunslinger_kit.gd`) and **Sparkle** (`mage_kit.gd`): no 35% dice on top of the conditions.
- **Gil** (`gil_kit.gd`): aims the Tidal Wave at the rival (it rolled along whatever the bot was facing).
- **Albert** (`bulwark_kit.gd`): the Faultline before the E and from 1.5 m (its lane starts at his feet; a rival closer than 4 m never got one).
- **Grimble** (`dredge_kit.gd`): the Broadside from 0.8 of its range (4.7 m) instead of 3.5 m.
- Meeko's Hearth Call is unchanged (it waits for a hurt teammate); Lace, Kael, Cinder, Neve, Sable were already on time.
