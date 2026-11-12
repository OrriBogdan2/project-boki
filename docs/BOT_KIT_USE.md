# Bot kit use: what the bots really press

After the parity wave the Hunters got holds, recasts and movement moves the bots never learned. `--bot-kit-use` (tools/bot_kit_use_check.gd, registered in tools/check_registry.gd) plays one **bot-vs-bot duel per Hunter** in the duel room (both fighters play that Hunter, Duel difficulty "medium", `Match.duel_opts()` with `autoplay`) for **120 s on 3 seeds (3, 5, 9)** and counts, summed over both fighters and all seeds, what the bots do in each slot. It fails when a Hunter's slot below is never used, or Mossy's hold-only Aegis is mostly tapped.

Run: `godot --headless --path . -- --bot-kit-use[=<arch>] [--kit-use-t=120] [--kit-use-seeds=3,5,9]` (with a temp `XDG_DATA_HOME`). One Hunter takes about 10 s.

**Columns.** Press = the input went down (an RMB with a hold is counted on the hold's key edge, an instant RMB on its cast). Hold = RMB kept down past the kit's hold threshold. Hits = hit events by their tag (`shot`/`primary` is LMB, `utility` RMB, `k1` E); many kits tag their RMB or E hits with another word, so a 0 in a hit column only means "not tagged that way". R = the Hunter ultimate (level 6 gate). Dashes = Shift presses; glides = glider opened. Counts vary a little run to run (the bots roll the game's random numbers).

## Reading the specials

| Hunter | Slot | What counts |
|---|---|---|
| Kael | RMB hold | Lunge held only to wait out a foe's dash, let go in the perfect window (`lunge perfect`; rare by design) |
| Kael | E recast | Warchain pulled in once hooked (`chain reel`; RMB never pulls along it) |
| Mossy | RMB hold | Aegis raised (hold-only: a tap does nothing) |
| Mossy | LMB | Hammer thrown (`hammer throw`) and recalled (`hammer recall`) |
| Mossy | Shift behind the aegis | Shield Charge (`shield charge`), a Shield Slam at 50 Guard (`shield slam`, rare in a short duel) |
| Neve | Shift hold | Skate (`skate`) |
| Neve | E recast | Rink Wall frozen while it slides (`rink freeze`) |
| Tenzo | Shift recast | Rock Hop hops after the first of a chain (`hop recast`) |
| Cinder | E | Furnace Cloak drags foes in (`cloak pull`) |

## Before (origin/main d255acbee)

| Hunter | LMB hits | RMB presses | RMB holds | RMB hits | E casts | E hits | R casts | Dashes | Glides | Hold / recast specials |
|---|---|---|---|---|---|---|---|---|---|---|
| Vex (`gunslinger`) | 1399 | 52 | 0 | 11 | 29 | 24 | 7 | 9 | 79 |  |
| Kael (`juggernaut`) | 628 | 140 | 14 | 214 | 30 | 25 | 27 | 65 | 52 | lunge perfect 1, chain reel 1 |
| Lace (`archer`) | 192 | 46 | 43 | 34 | 35 | 98 | 0 | 33 | 108 |  |
| Cinder (`ashwick`) | 1 | 55 | 0 | 50 | 33 | 0 | 6 | 23 | 84 | cloak pull 34 |
| Meeko (`tender`) | 551 | 53 | 0 | 40 | 49 | 0 | 0 | 11 | 50 |  |
| Neve (`rimewright`) | 534 | 41 | 0 | 20 | 29 | 0 | 4 | 22 | 137 | skate 10 |
| Tenzo (`dolm`) | 150 | 17 | 16 | 0 | 5 | 0 | 1 | 51 | 173 | hop recast 21 |
| Motley (`ostra`) | 615 | 42 | 0 | 0 | 28 | 0 | 3 | 21 | 59 |  |
| Sparkle (`mage`) | 273 | 12 | 0 | 17 | 29 | 9 | 5 | 56 | 158 |  |
| Grimble (`dredge`) | 2346 | 43 | 0 | 33 | 62 | 42 | 14 | 26 | 62 |  |
| Sable (`thief`) | 321 | 68 | 0 | 45 | 33 | 18 | 7 | 63 | 126 |  |
| Mossy (`bulwark`) | 21 | 167 | 166 | 0 | 13 | 0 | 0 | 45 | 151 | shield charge 1, hammer throw 1, hammer recall 1, shield slam 0 |

Never used: Kael's perfect release (1 of 14 holds) and the Warchain pull (1 reel for 30 hooks); Mossy's hammer (1 throw, then it lay on the ground for good because nothing recalled it, and the ultimate); Neve's Rink Wall freeze; Lace's ultimate.

## After

| Hunter | LMB hits | RMB presses | RMB holds | RMB hits | E casts | E hits | R casts | Dashes | Glides | Hold / recast specials |
|---|---|---|---|---|---|---|---|---|---|---|
| Vex (`gunslinger`) | 1429 | 50 | 0 | 11 | 26 | 22 | 8 | 14 | 77 |  |
| Kael (`juggernaut`) | 506 | 106 | 6 | 160 | 20 | 10 | 14 | 45 | 66 | lunge perfect 5, chain reel 9 |
| Lace (`archer`) | 202 | 45 | 43 | 33 | 31 | 113 | 6 | 30 | 94 |  |
| Cinder (`ashwick`) | 1 | 55 | 0 | 50 | 33 | 0 | 6 | 23 | 84 | cloak pull 34 |
| Meeko (`tender`) | 551 | 53 | 0 | 40 | 49 | 0 | 0 | 11 | 50 |  |
| Neve (`rimewright`) | 712 | 52 | 0 | 32 | 35 | 0 | 6 | 42 | 104 | rink freeze 30, skate 20 |
| Tenzo (`dolm`) | 150 | 17 | 16 | 0 | 5 | 0 | 1 | 51 | 173 | hop recast 21 |
| Motley (`ostra`) | 615 | 42 | 0 | 0 | 28 | 0 | 3 | 21 | 59 |  |
| Sparkle (`mage`) | 273 | 12 | 0 | 17 | 29 | 9 | 5 | 56 | 158 |  |
| Grimble (`dredge`) | 2346 | 43 | 0 | 33 | 62 | 42 | 14 | 26 | 62 |  |
| Sable (`thief`) | 321 | 68 | 0 | 45 | 33 | 18 | 7 | 63 | 126 |  |
| Mossy (`bulwark`) | 48 | 207 | 204 | 1 | 21 | 4 | 2 | 85 | 76 | shield charge 11, hammer throw 9, hammer recall 4, shield slam 1 |

## What changed (bot code only; no kit numbers)

- **Kael** (`juggernaut_kit.gd`): the Lunge hold is `full_t + 0.07 s`, inside the 0.15 s perfect window, instead of a charge that never reached it (1 perfect of 14 holds became 5 of 6); a hooked Warchain is reeled in from 2 m (was 3.5 m, and only 80% of the time).
- **Mossy** (`bulwark_kit.gd`): the thrown hammer is recalled from the ground after 0.8 s (it used to stay out and block every other LMB); throws at a foe 3.6 m or more away; holds the Aegis 1.2 s up close so the Shift press is a Shield Charge (80% when the aegis is up); presses the ultimate at 4 to 13 m.
- **Neve** (`rimewright_kit.gd`): the bot schedules the freeze 0.15 to 0.45 s into the wall's slide (its decision tick, 0.9 to 2.2 s, never landed inside the slide of 1 s or less).
- **Lace** (`archer_kit.gd`): presses the ultimate at 4 to 14 m.
- Unchanged and already fine: Tenzo's Rock Hop recasts (21), Cinder's E pull (34), every Hunter's dash and glide. Meeko's ultimate heals a teammate, so the duel has none and the check skips it.

## Kael after his owner 11-11 kit

His RMB changed: the tap is a 4.3 x 0.72 m lane locked at the press and planted, the hold is the blade raised overhead with no lane (walking at 80%) and a plain Lunge along the aim on release, the Chain Lunge is gone (a hooked chain never pulls on RMB), and the Rampage is a movement dash first. The bot follows (`juggernaut_kit.gd` `bot_use`, tuning in the archetype's `bot` row of `content/archetypes/juggernaut.json`):

- **Tap** only when the foe stands in the lane as it would lock now (`AimMode.in_lane` along his current aim, the foe's body counted); a foe beside it gets no tap, and the aim is no longer snapped onto them for the press.
- **Hold** only while the foe is dashing (a locked lane would miss): full charge + `lunge_lead` (0.07 s, inside the 0.15 s perfect window), then the Lunge goes where they stopped.
- **Hooked chain:** E pulls in; no RMB hold expecting a pull, no Haul Slam timing.
- **Rampage** to close from `close` (2.5 to 6 m, `close_p` 25% a decision) or to escape: under `escape_hp` (30%) with the foe inside `escape_near` (3.5 m), straight away from them; never onto the void, never on the tick a Smash was pressed.

Checks: `--juggernaut-combo-check` rows "jug bot: ..." (tools/jug_bot_check.gd): a dummy in the lane gets the tap and the Slam lands; a dummy 1.5 m beside the aim gets no tap (fails on the old bot code, which snapped its aim onto the foe). `--bot-kit-use=juggernaut` on 11-11 (seeds 3, 5, 9): LMB hits 760, RMB presses 130, holds 1, RMB hits 118, E 26 (hits 23), R 16, dashes 33, glides 34, lunge perfect 1, chain reel 13; no failures.
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
