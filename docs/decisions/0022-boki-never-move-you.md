# 0022: Boki never move you; a big Boki guards at your side

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement, combat (Boki)

## Problem
DECISIONS 2026-11-06 (OWNER_REVIEW 184b): Boki act on foes, the world and your stats, never on your body or
controls; only an obvious abyss rescue (Moonlift) may. The owner's 11-08 playtest found Lunowl still
teleporting him (Moon Swap). Also on 11-08: a Boki guarding its hunter must never be under or inside him.

## Options
1. Strip only Moon Swap. Leaves the carried dash/leap path (a carried Boki's Stinger Dash, Gale Lance and
   Gravity Slam moved the hunter) and the Return-order ride (the hunter stood on a big Boki).
2. Replace every offender and add a fence: the grammar refuses a Boki effect that moves the hunter, and a
   runtime check casts every ability next to an idle hunter.

## Decision
Option 2. Moon Swap becomes Moon Mark. A carried Boki jumps off to do its own dash, leap or blink. A Fusion
form is the player's own commanded form, so its moves stay. Your own Boki's body no longer shoves you. On the
Return order a Boki heavier than `follow.shoulder_max_mass` guards at your side: `guard_side_m` from you
on the flank it holds, and it takes the other flank when that one is blocked. It never comes closer than
`guard_min_m` and its feet are never below yours. While you glide or cross a gap it curls up on your back.
Only the giant Fusion form is still ridden.

## Consequences
- `scripts/kin/kin_fence.gd` (new), called from AbilitySpec and MergeSpec; `signature swap` and the dead
  `dodge_rider` parser are gone (unknown fields now fail the grammar check).
- `KinFollow.guard_tick/guard_spot/onto`, `Kin.big/beside/guard_side`; `Hunter.mounted()` means the giant
  form only; `KinFollow.on_jump` removed. Checks: `--boki-agency-check`, `--boki-follow-check` part 7.
- Net.VERSION: no bump. The guard spot is worked out on each game from the synced order and positions,
  and no synced field changed. Saves: untouched.
