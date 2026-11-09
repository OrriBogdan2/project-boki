# Online feel at 100 ms

How an online game feels when one player's line has 100 ms added each way (200 ms round trip, what
`tc netem delay 100ms` on loopback gives). Measured by `--online-feel-check` (`tools/online_feel_check.gd`).
Local input latency is a separate job; this is only what the net adds.

## How it was measured
- Two real headless games over the relay (as `--displace-net-check`): the host runs the relay in-process and
  watches; the actor connects through `tools/online_feel_proxy.py`, a userspace UDP proxy that holds every
  packet 100 ms each way (no root here, so no netem; the proxy is the stand-in and removes nothing from the box).
- The actor presses as Vex (gunslinger), Kael (juggernaut) and Neve (rimewright), 5 times per case. All clocks are
  this machine's wall clock, so one press is followed on both games and at the relay.
- **Architecture note:** the relay only forwards. Each game owns its own hunter, so there is no server-confirmed
  position: "confirmed" below is the relay receiving a snapshot or event that shows the press. Nothing is ever
  sent back to correct the owner.
- Columns, ms from the press, median: **local** = the actor's own first reaction (move, kit animation or cooldown);
  **moved** = first local motion (dash, recast); **relay** = the relay gets the first packet that shows the press;
  **seen** = the other player's copy of the actor starts to move (dash only).

## Numbers (median ms)
| Hero / press | local | moved | relay, before | relay, after | seen, before | seen, after |
|---|---|---|---|---|---|---|
| Vex dash | 2 | 2 | 172 | 115 | 173 | 124 |
| Vex LMB | 2 | | 139 | 115 | | |
| Vex E | 1 | | 174 | 115 | | |
| Vex recast | n/a: Vex's E has nothing to recast | | | | | |
| Kael dash | 1 | 68 | 145 | 118 | 263 | 186 |
| Kael LMB | 154 | | 278 | 268 | | |
| Kael E | 3 | | 183 | 109 | | |
| Kael recast (pull on a hooked foe) | 2 | 2 | 137 | 118 | | |
| Neve dash | 1 | 1 | 127 | 110 | 128 | 128 |
| Neve LMB | 1 | | 208 | 110 | | |
| Neve E | 1 | | 166 | 110 | | |
| Neve recast (freeze the wall) | 1 | | 216 | 110 | | |

Reading it: every local reaction is immediate (1-3 ms; the sim step is the floor). Kael's dash moves at 68 ms
because the dash has a 0.07 s windup (`content/archetypes/juggernaut.json:22`); his LMB at 154 ms is the release of the
0.15 s hold the harness gives it (a hold-scaled attack), neither is a net cost. Before the fix the relay heard a
press 24-115 ms later than its local reaction plus the line (100 ms); after, 6-17 ms later.

## Remote Hunter in a dash (the other client's view)
Worst of 5 dashes, per frame at 60 fps. The dash is 19 m/s for 0.19 s, 3.6 m.

| Hunter | biggest step per frame | the actor's own step | trails the real path by | runs past its end by |
|---|---|---|---|---|
| Vex | 0.17 m | 0.18 | 1.55 m | 0.05 m |
| Kael | 0.34 m | 0.34 | 2.88 m | 0.07 m |
| Neve | 0.17 m | 0.19 | 1.50 m | 0.07 m |

There is no snap: the biggest step a frame is the dash's own step, and the 4 m teleport threshold in `Ent.net_follow`
is never hit. (Before the fix: Kael 0.54 m step, 3.73 m trail, 0.50 m overshoot.) The copy trails by about the line delay times the dash speed, which is
expected at 100 ms; the avoidable part was the wait for the next snapshot.

## The 3 biggest gaps
1. **Snapshots and events left on a 10 Hz tick** (fixed here). `Net.tick` sent the player's snapshot, hits and
   events only when `send_t` ran out (`scripts/core/net.gd:222-232` on main, `send_t = 0.1`), so every dash, cast and
   hit waited 0-100 ms (mean 50) on top of the line. Fix: `flush()` runs every frame and a dash or kit move that
   starts sends its snapshot at once (`net.gd:228-247`, at most one early snapshot per 30 ms). No wire change.
2. **A remote dash is dead-reckoned from one or two snapshots.** `Ent.net_follow` (`scripts/match/ent.gd:326-337`)
   follows `net_pos + net_vel * age` with the age capped at 0.25 s and a 14/s lerp; a 0.19 s dash fits between two
   snapshots, so the copy trails the real path by 1.5-2.9 m and Kael appears 118 ms after his own 68 ms windup
   (`seen` 186). *Proposal (Net shape change, needs a `Net.VERSION` bump):* send the dash's end point and duration in
   the kit-move fields (`ArchKit.net_move`, `scripts/arch/arch_kit.gd:731`) so the other game draws the whole dash
   from the first snapshot.
3. **The attacker judges hits against a trailing copy, and nothing corrects anyone.** The relay forwards only
   (`scripts/server/relay.gd:123-134`); `Match.net_send_hit` (`scripts/match/match.gd:5537`) sends the attacker's verdict
   and the target's game applies it as is (`match.gd:5757`). With the gap above, someone 100 ms away sees a dashing
   target 2-3 m behind where it is. *Proposal:* let the target's game accept a hit only if the target was near the
   claimed spot a line-delay ago (a position history of ~0.3 s per hunter), or move hit authority to the dedicated
   server. Not measured here: the press-to-damage path (a first attempt at it was unreliable and was dropped).

## Re-running
`godot --headless -- --online-feel-check` (about 6 minutes; needs `python3` for the proxy). It fails if the game adds
more than 60 ms to the line's delay for any press (`NET_SLACK_MS`). Before the fix 6 of the 11 measured rows failed that budget.
