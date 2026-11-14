# The downed loop: source numbers next to ours

Going down turns a Hunter into a Wisp (docs/decisions/0019). This table compares the downed loop's
numbers with the source. Under PARITY FIRST (briefs/DECISIONS.md, 2026-11-07), every number the
source settles is set to match it. Where the source is silent, our number stays.
Code: `Life.R` (scripts/match/life.gd), `Hunter` (move speed), `Match.revive_hunter`. Check: `--revive-check`.

Evidence tags: **[D]** game data (briefs/supervive-data/supervive_physics.md), **[F]** footage,
**wiki** the community wiki, **[patch]** patch notes (docs/SUPERVIVE_DATA.md §2), **gap** the source
publishes nothing, **owner** an owner rule that stays as it is.

| Row | Source | Tag | Ours | Status |
|---|---|---|---|---|
| Bleed-out time | 15 s (was 30 s before Dec 2024) | [patch] | 15 s (`bleed_out`) | match |
| Wisp speed | "slow-moving orb", no number | wiki / gap | 40% of run speed (Hunter move) | kept |
| Revive channel time | "a few seconds", no number | wiki / gap | 4 s (`revive_time`) | kept |
| Several on one wisp | Diminishing returns by count 1..4: 1.0 / 0.75 / 0.58 / 0.47, the same curve for allies reviving and enemies stomping | [D] | Speed = the curve summed per person: x1, x1.75, x2.33, x2.80 (`crowd`), for revivers and for the stomp drain | **set** (was +50% per extra reviver, stomp not scaled) |
| Interrupt: enemy on the wisp | Drains it fast and blocks revives | wiki | Blocks the revive, bar drains 0.5/s, wisp drains x2.5 (`stomp_mult`) | match (rates ours: gap) |
| Interrupt: reviver steps off | The revive bar and the wisp both drain again | wiki | Bar drains 0.5/s (`revive_decay`), wisp bleeds again | **set** (the bar used to hold) |
| HP on revive | "Revive HP per tick 2": unit and tick unknown | [D] (unreadable) | 25% of max HP (`revive_hp`) | kept |
| Armour on revive | Nothing published | gap | Armour 0 | kept |
| Finishing a downed foe | Hold E, about 3 s finisher, then the wisp dies | [F] + wiki | Hold 0.2 s to commit, then 2.8 s locked in, three stomps (`stomp_commit` + `stomp_time`, cycle 0.8 s) | **set** (was 0.2 + 2.4 s) |
| Last standing knocked | The whole team is eliminated, no wisp | [patch] Aug 2025 | Same | match |
| Second down | Nothing published (only XP: each repeat knock of the same person is worth 50% less) | gap | Every down starts a full 15 s wisp | kept |
| Carried by Soulpack | The Elluna-type kit carries ally Wisps | [D] kit text | Carried wisps don't bleed or get stomped (`CareUtil`) | kit, not audited here |
| Boki guardian | | owner | Your Boki guards your wisp and can pull you up in 8 s (`kin_revive_time`) | owner |
| Wisp stealing | | owner | Your Boki wisps break loose when you go down (DECISIONS 2026-11-09) | owner |
| Box revive, beacons | | owner | `content/rules/revive.json`, docs/decisions/0018 | owner |

## Readings and open points
- **The "count" in the [D] curve.** It is read as the number of people on one wisp at once, because
  the data says the same curve covers allies reviving and enemies stomping, and a wisp is stomped
  once. The box revive (`box_diminish`) reads the same curve as the Nth box revive of one Hunter in a
  match. That is an owner rule (101b) and stays.
- **Rates the source doesn't give** (bar drain when blocked or left, stomp drain x2.5, wisp speed,
  revive time, revive HP): ours until a number turns up in footage or data.
