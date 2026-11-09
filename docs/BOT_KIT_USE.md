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

## Counts per Hunter (default seed 7)

### Vex (`gunslinger`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 36 s | 202 |
| RMB | 7 presses, 0 held to the kit's hold threshold | 1 |
| E | 6 casts | 5 |
| R | 2 casts | |
| Dash | 1 presses | |
| Glide | 33 opened | |
| Fuse | 5 merges | |

All hits landed: 221.

### Kael (`juggernaut`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 81 s | 163 |
| RMB | 55 presses, 4 held to the kit's hold threshold | 55 |
| E | 9 casts | 7 |
| R | 9 casts | |
| Dash | 19 presses | |
| Glide | 14 opened | |
| Fuse | 8 merges | |
| Special | lunge perfect 4, chain reel 3 | |

All hits landed: 274.

### Lace (`archer`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 51 s | 46 |
| RMB | 11 presses, 7 held to the kit's hold threshold | 4 |
| E | 8 casts | 28 |
| R | 3 casts | |
| Dash | 10 presses | |
| Glide | 34 opened | |
| Fuse | 8 merges | |
| Special | full draw 6 | |

All hits landed: 87.

### Cinder (`ashwick`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 89 s | 166 |
| RMB | 21 presses, 11 held to the kit's hold threshold | 10 |
| E | 9 casts | 0 |
| R | 6 casts | |
| Dash | 3 presses | |
| Glide | 10 opened | |
| Fuse | 7 merges | |
| Special | cloak pull 11 | |

All hits landed: 195.

### Meeko (`tender`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 75 s | 130 |
| RMB | 22 presses, 0 held to the kit's hold threshold | 11 |
| E | 12 casts | 0 |
| R | 1 casts | |
| Dash | 4 presses | |
| Glide | 17 opened | |
| Fuse | 6 merges | |
| Special | hearth toss 3 | |

All hits landed: 155.

### Neve (`rimewright`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 67 s | 254 |
| RMB | 21 presses, 11 held to the kit's hold threshold | 9 |
| E | 8 casts | 0 |
| R | 2 casts | |
| Dash | 8 presses | |
| Glide | 16 opened | |
| Fuse | 12 merges | |
| Special | skate 5, rink freeze 3 | |

All hits landed: 312.

### Tenzo (`dolm`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 59 s | 55 |
| RMB | 12 presses, 3 held to the kit's hold threshold | 0 |
| E | 3 casts | 0 |
| R | 4 casts | |
| Dash | 15 presses | |
| Glide | 28 opened | |
| Fuse | 6 merges | |
| Special | hop recast 4 | |

All hits landed: 124.

### Motley (`ostra`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 101 s | 180 |
| RMB | 16 presses, 0 held to the kit's hold threshold | 0 |
| E | 10 casts | 0 |
| R | 1 casts | |
| Dash | 8 presses | |
| Glide | 7 opened | |
| Fuse | 8 merges | |
| Special | brimseed pop 9, lantern swap 2 | |

All hits landed: 234.

### Sparkle (`mage`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 75 s | 104 |
| RMB | 13 presses, 2 held to the kit's hold threshold | 9 |
| E | 11 casts | 2 |
| R | 4 casts | |
| Dash | 22 presses | |
| Glide | 27 opened | |
| Fuse | 8 merges | |
| Special | kitefall foes 5 | |

All hits landed: 155.

### Grimble (`dredge`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 45 s | 371 |
| RMB | 7 presses, 0 held to the kit's hold threshold | 6 |
| E | 8 casts | 3 |
| R | 3 casts | |
| Dash | 4 presses | |
| Glide | 35 opened | |
| Fuse | 5 merges | |

All hits landed: 400.

### Sable (`thief`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 61 s | 78 |
| RMB | 19 presses, 0 held to the kit's hold threshold | 6 |
| E | 7 casts | 3 |
| R | 4 casts | |
| Dash | 23 presses | |
| Glide | 28 opened | |
| Fuse | 8 merges | |
| Special | knife blink 6 | |

All hits landed: 108.

### Mossy (`bulwark`)

| Slot | Bot did (90 s, two bots) | Hits |
|---|---|---|
| LMB | fired 53 s | 16 |
| RMB | 46 presses, 42 held to the kit's hold threshold | 0 |
| E | 7 casts | 0 |
| R | 4 casts | |
| Dash | 23 presses | |
| Glide | 35 opened | |
| Fuse | 6 merges | |
| Special | hammer throw 8, hammer recall 3, shield charge 5, shield slam 0 | |

All hits landed: 26.
