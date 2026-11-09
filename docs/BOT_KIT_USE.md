# What bots do with each kit

`scripts/match/bot.gd` calls the kit's `bot_use` (and the kit's own bot hooks) for every Hunter. This page counts what a bot really presses, holds and recasts per slot, so an unused or misused slot shows up as a number.

**Run it:** `godot --headless --path . -- --bot-kit-use=<archetype> [--seeds=3] [--secs=120] [--map=arena]` (`tools/bot_kit_use.gd`). It fights two bots of the same Hunter in the duel room, 120 s per seed, prints one `BOTKIT` line per counter and sums the seeds. The duel room is an empty island, so `--map=arena` (the Arena's pillars and walls, dummies removed) is used for the wall pin. Meeko gets a Vex squadmate per side, because Hearth Call needs one. Counts are per **3 seeds x 120 s x 2 bots = 12 Hunter-minutes** (Motley's swap row: 6 seeds). Same seeds before and after, but a changed fight reshuffles the dice, so small differences are noise.

## The table (part B: Sparkle, Grimble, Meeko, Sable, Lace, Motley)

| Hunter | Slot and move | Count | Before | After | Verdict |
|---|---|---|---|---|---|
| Sparkle | E Skycall: seconds E held to drag | s held | 0 | 10 | Fixed: a bot holds E 0.4 s and drags toward herself (pulls the foe in). It only ever tapped (throw out) |
| Sparkle | E Skycall casts | casts | 33 | 28 | Used |
| Sparkle | X Kitefall: hang ended by a press or attack (recast) vs the hover timer | recast / timer | 1 / 13 | 10 / 1 | Fixed: a bot strikes down once the crown is on a foe |
| Sparkle | X Kitefall: foes hit by the strikes | foes | 2 | 11 | Fixed (casts 15 / 14) |
| Grimble | Dash air pounce slot used (air dash presses) | uses (presses) | 5 (9) | 5 (9) | Left: a bot is rarely airborne in a fight (see Left) |
| Grimble | X Brass Broadside: casts / waves fired / stopped in the charge | casts / waves / stopped | 35 / 55 / 7 | same | Used: both waves fire on every cast that is not stunned, 164 slug hits (4.7 a cast) |
| Meeko | E Hearthlight thrown to a squadmate (the E recast) | throws | 0 | 41 | Fixed: a bot lights it for a hurt squadmate within 9 m and throws it to one outside the ring |
| Meeko | E Hearthlight casts | casts | 47 | 63 | Used |
| Meeko | X Hearth Call tether | casts | 10 | 10 | Used (on a downed or under-35% squadmate, as before) |
| Sable | E Shadow Knife: casts / recasts (blinks to it) | casts / blinks | 36 / 35 | same | Used: a bot steps to the knife when it sticks in a foe |
| Sable | Dash Vault: presses / chain resets / empowered bolts that hit | presses / resets / hits | 89 / 57 / 57 | same | Used |
| Sable | X Encore: casts / blades landed | casts / blades | 22 / 85 | same | Used |
| Lace | RMB Heavy Shot: holds / seconds held / wall pins | holds / s / pins | 54 / 61 / 0 | 47 / 51 / 0 | Held to full every time; pins are rare (Arena 2 -> 1), see Left |
| Lace | X Starpiercer: casts / arrows loosed | casts / arrows | 0 / 0 | 12 / 31 | Fixed: the bot never pressed X; now it casts at a Hunter in 16 m and looses the three shots |
| Motley | E Brimseed: pops (the E recast) / recast presses | pops / presses | 30 / 32 | 24 / 31 | Used (no early pops either way) |
| Motley | Dash Lantern Trade: swaps / foes swapped (6 seeds) | swaps / foes | 19 / 4 | 19 / 9 | Fixed: the lantern leads the target by the flight time and a stunned target is always chosen |
| Motley | X Nightwell: casts / Hunters caught | casts / caught | 10 / 9 | 8 / 7 | Used |

Fix sites (no kit numbers changed): `mage_sky.gd` (`_held`, `drag_dir`), `mage_ult.gd` (`_wants_down`), `tender_kit.gd` (`_bot_idle`), `archer_kit.gd` (`bot_use`), `ostra_kit.gd` (`bot_use`).

## Left

- **Grimble's air pounce:** the dash press is read before the kit ticks and every press flag is cleared at the end of the step, so a kit cannot jump-then-pounce on its own; a bot would need a per-step press from `bot.gd`. Used 5 times in 12 Hunter-minutes, only when a fall or a jump happens to meet the 3-6 m window.
- **Lace's wall pin:** a pin needs a wall within 3 m behind the foe along the shot. The bot already shoots a full Heavy Shot at every target in sight; waiting for a wall behind them cut the shots without raising the pins (2 -> 1), so it was dropped. Real gain needs the bot to position the foe against a wall.
- The counters in the tool come from the kits' own test counters (`pins`, `swaps`, `blinks`...) and from `CombatBus`, so they are not a hit-rate for every slot.
