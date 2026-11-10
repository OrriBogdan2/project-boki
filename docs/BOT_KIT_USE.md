# Bot kit use: what the bots really press

After the parity wave the Hunters got holds, recasts and movement moves the bots never learned. `--bot-kit-use` (tools/bot_kit_use_check.gd, registered in tools/check_registry.gd) plays one **bot-vs-bot duel per Hunter** in the duel room (both fighters play that Hunter, Duel difficulty "medium", `Match.duel_opts()` with `autoplay`) for **120 s on 3 seeds (3, 5, 9)** and counts, summed over both fighters and all seeds, what the bots do in each slot. It fails when a Hunter's slot below is never used, or Mossy's hold-only Aegis is mostly tapped.

Run: `godot --headless --path . -- --bot-kit-use[=<arch>] [--kit-use-t=120] [--kit-use-seeds=3,5,9]` (with a temp `XDG_DATA_HOME`). One Hunter takes about 10 s.

**Columns.** Press = the input went down (an RMB with a hold is counted on the hold's key edge, an instant RMB on its cast). Hold = RMB kept down past the kit's hold threshold. Hits = hit events by their tag (`shot`/`primary` is LMB, `utility` RMB, `k1` E); many kits tag their RMB or E hits with another word, so a 0 in a hit column only means "not tagged that way". R = the Hunter ultimate (level 6 gate). Dashes = Shift presses; glides = glider opened. Counts vary a little run to run (the bots roll the game's random numbers).

## Reading the specials

| Hunter | Slot | What counts |
|---|---|---|
| Kael | RMB hold | Lunge held to full charge and let go in the perfect window (`lunge perfect`) |
| Kael | E recast | Warchain pulled in once hooked (`chain reel`) |
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
