# Boki agency audit (OWNER_REVIEW 184b, DECISIONS 2026-11-06, owner 11-08)

The rule: a Boki never moves, steers, stops, swaps, teleports, launches or roots its own hunter, and never
takes over the controls. Boki act on foes, the world and the hunter's stats (heal, shield, buff). The one
exception is the obvious abyss rescue (Moonlift). Owner 11-08: "make sure the boki changes to not interfere
with ur gameplay (only buff/aid it)". Decision note: [0022](decisions/0022-boki-never-move-you.md).

Re-audited on main d255acbee: every kin_v2 species (50), abilities_v2 (16), merges_v2 (9), merge_forms (3),
evolution_v2 (10), the throw, carry styles and passives, and the Boki body itself. The starting point was the
item 186 audit (briefs/BOKI_PLAYER_AUDIT.md, main 7907d9af).

## What moved or held the hunter, and its replacement

| Ability / system | Who | Offending effect | Replacement |
|---|---|---|---|
| **Moon Swap** (E) | Lunowl, Moonloris, Caecilith, Opalisk, Lodestick, Duskapi | The first foe hit traded places with YOU (teleport, velocity zeroed, glide ended). The owner's 11-08 "lunowl teleported me again". | **Moon Mark** (`moon_mark`, same icon slot, range, cooldown, disc): 4 damage, stun 0.4 s, then the foe is revealed (seen through walls and grass) and takes +15% damage for 4 s. `signature swap` is deleted from the grammar. |
| **Stinger Dash** (auto) | Cindle, Nettlynx, Kindlewren, Cindowary | Cast while the Boki was on you, the hunter did the 7 m lunge. | The Boki jumps off onto your side spot and lunges itself (`Kin.use_ability` → `KinFollow.drop_beside`). Same damage and reach. |
| **Gale Lance** (E) | Zephyrak, Kindlewren, Hoarheron, Cindowary, Squalltross | Same path, an 8 m dash at 28 m/s by the hunter. | Same fix: the Boki does the dash. |
| **Gravity Slam** (E) | Pebbit, Glaciyak, Scaldamus, Umbrathere, Casquebill, Kilnbadger | Same path: a 7 m leap (`launch_to`) by the hunter. | Same fix: the Boki leaps and slams. |
| **Return order, big Boki** (carry style `mount`) | the 16 large species | "You ride it": the hunter stood on the Boki, slower ground speed and jump, and the Boki threw you off when you jumped. Owner 11-08: never under or in the hunter. | It guards at your side instead (see below). Its carried bonuses (-15% damage taken, half knockback) stay. `KinFollow.on_jump` is deleted. Only the giant Fusion form is still ridden. |
| **Your Boki's body** | all | The body push between bodies shoved the hunter whenever his Boki walked into him (a big Boki pushed hardest). | Your own Boki steps aside and takes the whole push (`Match._separate`). |
| **Dash riders** (Moon Blink, Gravity Wake, Venom Trail, Echo Step, Prism Decoy, Spore Puff) | 6 species | Data already removed (item 129); the parser and tooltip text were still live. | `dodge_rider` parser and `KinText.rider` deleted: the field is now an unknown-field grammar error. |

## Kept, with the reason

| Ability / system | Why it passes |
|---|---|
| **Moonlift** (`updraft`, auto) | The whitelisted abyss rescue: only on the `owner_falling` cue, 14 s cooldown, lifts you out of the abyss and cools the glider. |
| Mass Guard (`rock_guard`), Prism Wall | World objects (a wall between you and the shooter); nothing is done to your body. |
| Echolocate, Refraction | A reveal on foes, plus a crit window, a mirror and a shield on you: stats and aid. |
| Boulder Heave, Echo Chain, Storm Arc, Hive Swarm, Puffcap Mines, Thorn Patch, Stinger Hook | They act on foes only. Stinger Hook drags the foe to the Boki, or to you when the Boki is on you. |
| Fusions (`merges_v2`): start bursts and pulses | Their lift, pull, push, root and stun all land on foes. KinFence checks this with the hunter as the caster. |
| Fusion passives (move speed, extra jump, glide, dash refill, knockback resist) and carry passives (glide, regen, damage reduction, fire rate) | Stat buffs that only add to what you do; they never move you or take input. |
| Fusion form kits (stormwing, titan, tidal_shell) and a merged Boki's E | The player chose to Fuse and presses the key, so the move is your own form's move (like a hero ability). |
| Giant Fusion form (stat merges on a big Boki) | Ridden for its timed window by the player's own command. Open for the owner: it still puts you on the Boki (mount speed and jump apply only here). Alternative: a giant that guards at your side. |
| Throws | The grammar already forces `target: foes`. |
| Evolutions | Sidegrades and stat shifts on the Boki's own numbers; none adds movement. |

## The big Boki guard spot (owner 11-08)

On the Return order a Boki heavier than `follow.shoulder_max_mass` (1.2: the large species, 1.4-2.0)
guards at your side. Smaller ones still ride your shoulder or pack.
- The spot is `guard_side_m` (1.7 m) out, square to your facing. It keeps that flank as you move, and takes
  the other one when that flank is void, a block, or a step off your level.
- It is never closer than `guard_min_m` (1.2 m), and its feet are never below yours: it hops with your jumps.
- When you glide or cross a gap it can't walk, or both flanks are blocked, it curls up on your back. It goes
  back to its flank when you land.
- Code: `KinFollow.guard_tick` / `guard_spot` / `onto`, `Kin.big()`. Tuning: `content/rules/boki_system.json` "follow".

## The fence

- **Grammar** (`scripts/kin/kin_fence.gd`, run by `--grammar-check`). An ability or Fusion fails if:
  - a dash, leap or blink starts from the hunter (`origin: owner`, or any mover in a from:owner ability or a
    Fusion stage), or
  - a lift, pull, push, slow, root or stun targets the hunter (`target: owner`, or `self` when the hunter
    casts it).

  The only exception is a lift in an ability cued by `owner_falling`. `tests/grammar_fixtures/broken/abilities_v2/bad_agency.json`
  shows both errors.
- **Runtime** (`--boki-agency-check`). Every Boki ability (one species each) is cast 20 times next to an idle
  hunter, with the Boki on him and with it out beside him. Then every Fusion runs its start and pulses. His
  position and velocity must not change.
- **Guard spot** (`--boki-follow-check`, part 7). While you run, jump, turn, find a flank blocked and glide,
  the Boki is never under or in you.
