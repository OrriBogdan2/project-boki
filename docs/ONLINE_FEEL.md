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
# Online feel: moves that carry a Hunter

Abilities that move a Hunter (a pull, a swap, a launch, a knock into a wall) must look the same online as offline.
`--online-displace-check[=<ms>]` (`tools/online_displace_check.gd`) measures it with three real processes on one
machine: a headless relay server (`scripts/server/relay.gd`, which logs every position snapshot it forwards) and
two games, the host and the guest. Run it with a scratch `XDG_DATA_HOME`:

```
XDG_DATA_HOME=<scratch> godot --headless -- --online-displace-check=100
```

Each move is played twice from the same spot: on a bot (the offline reference), then on the guest's Hunter. The
moved Hunter's path is recorded every frame on its own game and on the other game, and at every snapshot on the
server. The check asserts, per mover: it moved, no step of 4 m or more in one frame on its own game (a teleport
is exempt), the ends agree (0.75 m) with the offline end and across games, no double move (under x1.5).

## Delay

`tc netem` needs root and is blocked on the worker, so `tools/udp_delay.py` sits between the games and the relay
and holds every datagram 100 ms each way, as netem on loopback would (200 ms of round trip). Only these processes
use it. `--online-displace-check=0` goes straight to the relay for a no-delay baseline. `--od-jitter=<ms>` adds a
uniform plus-or-minus that many ms to each datagram (netem's `delay D J`; datagrams can overtake each other).

## Measured (100 ms each way, 10 Hz snapshots, 60 fps)

Columns: the largest step in one frame on the mover's own game (offline in brackets) and on the other game; the
largest step per snapshot on the server (it only sees 10 Hz, so a fast mover shows long steps there); the end
position error against the offline end, between the other game and the mover's own game, and between the server's
last snapshot and the mover's own game (m); the net distance moved against the offline run.

| Move | Mover | Step/frame own (offline) | Step/frame other | Step/snapshot server | End: own vs offline | End: other vs own | End: server vs own | Moved vs offline | Note |
|---|---|---|---|---|---|---|---|---|---|
| Kael Warchain self-pull | caster | 0.37 (0.37) | 0.38 | 2.57 | 0.14 | 0.00 | 0.00 | 5.3 vs 5.4 m (x0.97) |  |
| Kael Warchain sling | caster | 0.43 (0.43) | 0.43 | 2.99 | 0.01 | 0.00 | 0.00 | 5.6 vs 5.6 m (x1.00) | speed away 4.6 m/s |
| Grimble Abyssal Hand reel | moved Hunter | 0.18 (0.18) | 0.26 | 1.22 | 0.00 | 0.00 | 0.00 | 4.5 vs 4.5 m (x1.00) |  |
| Motley swap dash | moved Hunter | 8.00 (8.00) | 8.00 | 8.00 | 0.00 | 0.00 | 0.00 | 8.0 vs 8.0 m (x1.00) | a teleport |
| Motley swap dash | caster | 8.00 (8.00) | 8.00 | 8.00 | 0.00 | 0.00 | 0.00 | 8.0 vs 8.0 m (x1.00) | a teleport |
| Meeko Hearth Call pull | moved Hunter | 8.05 (8.05) | 8.05 | 8.05 | 0.00 | 0.00 | 0.00 | 8.1 vs 8.1 m (x1.00) | a teleport |
| Sparkle Kitefall launch and crash | caster | 1.08 (1.09) | 4.97 | 4.97 | 0.00 | 0.00 | 0.00 | 4.5 vs 4.5 m (x1.00) |  |
| Sparkle Kitefall launch and crash | moved Hunter | 0.13 (0.13) | 0.13 | 0.88 | 0.00 | 0.00 | 0.00 | 2.5 vs 2.5 m (x1.00) |  |
| Knock into a wall | moved Hunter | 0.26 (0.26) | 0.34 | 1.82 | 0.00 | 0.00 | 0.00 | 3.9 vs 3.7 m (x1.07) |  |

The no-delay baseline (`=0`) ends within 0.52 m of offline everywhere and shows the same Sparkle crash step
(4.98 m), so that step is not the delay's doing; with delay it was 0.76 to 5.71 m from run to run (see below).

## Findings

- **No double move anywhere.** A Hunter moved by someone else's ability is moved once, by its own game
  (`Displace`, docs/decisions/0016-displace.md); the other game and the server only follow its snapshots. The
  distances match offline (x0.90 to x1.07).
- **Ends agree.** The other game and the server end exactly where the mover's own game ends (0.00 m). Against
  offline: Kael's pull ends 0.0 to 0.3 m short, everything else 0.00 m. Kael's rows were red on main (0.77 to
  0.84 m, 3 of 3 runs; the 0.24.4 gate triage put the 2 reds on Meeko's Hearth Call, which passes at 0.00 m) and
  it was the check, not the game: the offline run leaves the bot right where the guest is placed next (Kael's
  arrival shoves it to 48.75 m), and the guest's game still draws the bot's copy there for ~0.5 s (delay plus the
  snapshot buffer), so the two bodies separate and the guest starts 0.55 m nearer Kael, who then stops 0.8 m
  short. The check now waits SETTLE_VIEW after moving the bot away before placing the guest.
- **Teleports are teleports, on every game.** Motley's swap and Meeko's Hearth Call pull are one 8 m jump by
  design (`Displace.teleport`, scripts/combat/displace.gd:44) and look the same on the other game and the server.
- **Gap, not fixed: Sparkle's Kitefall crash steps 4 to 5.7 m in one frame on the other game** (4 of 5 runs,
  with and without delay; the own game's largest step is 1.06 m). Cause: the crash is a scripted 0.15 s lerp
  (`MageUlt._fall_tick`, scripts/arch/kits/mage_ult.gd:280, sets `h.vel = ZERO`), so the snapshot reports no
  velocity; the owner sends 10 Hz (`send_t = 0.1`, scripts/core/net.gd:228), so the other game sees one or two
  snapshots of a 4.5 m fall, and `Ent.net_follow` (scripts/match/ent.gd:326) jumps when the gap is over 4 m
  (line 332). Raising that threshold with the owner's speed was tried and made it no better (the velocity is
  zero), so it was reverted. A fix needs the fall's velocity in the snapshot (the kit setting `h.vel` while the
  hunter step still does not integrate it: a double move on the own game if it does) or a cast event for the
  other game to play the dive locally (a Net shape change, so not done here).
- **Fixed: a guessed run-on shoved the other player.** `--displace-net-check` failed under xvfb (0 headless):
  Kael's Warchain left a 3.4 to 4.7 m gap instead of 0.9, and the burn row read 3.3 s of 4. Logged per step on
  both games: the host's hook (+0.30 s) and pull (+0.48 s) land at the same sim times headless and under xvfb,
  and the guest sees the pull start on time (`NetSmooth.DELAY` behind). The pull's end reaches the guest late.
  Its copy of Kael runs on at 22 m/s past the arrival (`NetSmooth.RUN_ON`, up to 0.25 s), and `Match._separate`
  shoved the guest's own hunter 4.2 m with that guess. Then the next snapshot put Kael back. Now a remote body
  drawn past its last snapshot with a real run-on (`NetSmooth.guessing`) shoves no one. Its owner's game
  decides where it is. No Net shape change. With the fix alone and the old pacing, the gap is 0.8 m.
- **The check's pacing.** The check stepped the match once a frame. A host drawing ~35 fps under xvfb ran its
  clock at ~0.6x the headless guest's, so the guest ran Kael on all the time, which two real games never do.
  `_run` now steps by the wall clock as `Match._process` does (as many steps a frame as real time asks, at most
  0.1 s behind). No tolerance changed. 37/0 in 3 runs headless and 3 under xvfb.
- `--online-displace-check` Kael self-pull and sling "ends agree" (1 or 2 rows a run, 0.78 to 0.85 m against
  the offline bot run, the bar is 0.75) stay red with this fix alone, as on main. That is the check's setup
  (the bot's stale copy shoves the guest before the pull), fixed by ext/feel-online-hearth-call: with both,
  40/0 in 3 runs at 100 ms and Kael's ends 0.03 to 0.27 m from offline.
- Under xvfb run the check with `--rendering-driver opengl3`, as the suite does. On Vulkan (llvmpipe) on a
  loaded box the guest's answers never reached the host (every row red from the first, the same in 3 runs).
- **Sparkle's Kitefall crash is a drop on the other game too** (ext/feel-kitefall-net; it stepped 4 to 5.7 m
  in one frame there in 4 of 5 runs before, while the own game's largest step is 1.06 m). The crash is a
  scripted 0.2 s lerp (`MageUlt._fall_tick` holds `h.vel` at zero so the hunter step does not move her twice),
  and the owner sends about 10 snapshots a second, so the other game saw one or two snapshots of the fall with
  no velocity and drew it as a teleport. Now the snapshot's velocity field carries the fall's own velocity
  (`ArchKit.net_vel` -> `MageUlt.move_vel`, the derivative of the lerp; no new field, so no `Net.VERSION`
  bump), and `NetSmooth` only takes a move faster than `SNAP_SPEED` for a teleport when the two snapshots'
  velocities along the move don't account for it (up to twice the faster of them). A teleport reports the
  speed it goes on with, not one along the jump, so it still snaps. `--remote-smooth-check`'s "fall" row casts
  Kitefall on the host 12 m out and asserts the guest's biggest step in a frame stays under 4 m (1.6 to 1.8 m
  measured). Left: the cubic between the last snapshot of the fall (full speed) and the first after the
  landing (still) can carry the drawn body up to about 0.15 of the fall past the landing for a few frames
  when that snapshot falls in the fall's last 0.03 s (not seen in the check's runs).
- Not measured: a mover owned by the host with the caster on the guest (every row has the host casting, so
  the guest is the one moved); Kael's Warchain on a bot (that is the offline reference).

## Cross-region: 150 ms each way, 20 ms jitter (2026-11-11)

`XDG_DATA_HOME=<scratch> godot --headless -- --online-displace-check=150 --od-jitter=20`, for EU against US servers
(DECISIONS Hosting: 75-90 ms each way plus jitter, so this is the bad end). Every game reaches the other through the
relay, so a host-to-guest message crosses the proxy twice: 300 ms plus up to 40 ms of jitter. Added moves: Kael's
Rampage and Grimble's Barge (dashes) and Neve's Skate (held 0.5 s; at 0.8 s she skates off the ledge 12 m west of
home and falls). Added columns: **Rubber band**, the farthest the other game's copy strays off the path the mover's
own game drew, whenever it drew it (lag along the path does not count), and **Late start**, how many ms after
offline the move gets going (0.3 m) on the mover's own game and on the other game.

Snapshot gaps at the relay were 110-150 ms with about 1 in 10 over 200 ms (three games on one worker hitch), so
NetSmooth's fixed 0.15 s buffer (one 0.1 s gap plus 40 ms) ran dry and the body ran on along its last velocity
(RUN_ON). The worst error was Kael's Rampage dash on the other game: it ran 1.33 m past the dash's end at dash
speed, then snapped back 1.53 m in one frame. **Fixed:** NetSmooth's margin over one gap is now a jitter buffer, how
late recent snapshots came against the quickest (peak held, 3% off per snapshot, 50 to 120 ms;
scripts/match/net_smooth.gd). A steady line still draws 0.15 s behind. No sync shape change, so Net.VERSION stays.

| Move | Mover | Step/frame other: before / after | Rubber band other (m): before / after | Late start own / other (ms), after | Moved vs offline, after |
|---|---|---|---|---|---|
| Kael Warchain self-pull | caster | 0.37 / 0.49 | 0.09 / 0.05 | -1 / 454 | x1.00 |
| Kael Warchain sling | caster | 1.60 / 2.86 | 0.14 / 0.42 | 1 / 440 | x1.00 |
| Grimble Abyssal Hand reel | moved Hunter | 0.40 / 0.26 | 0.00 / 0.00 | 355 / 816 | x1.00 |
| Motley swap dash | moved Hunter | 8.00 / 0.90 | 0.00 / 0.00 | 401 / 768 | x1.00, a teleport |
| Motley swap dash | caster | 8.00 / 8.00 | 0.00 / 0.00 | 0 / 411 | x1.00, a teleport |
| Meeko Hearth Call pull | moved Hunter | 8.05 / 8.05 | 0.00 / 0.00 | 532 / 895 | x1.00, a teleport |
| Sparkle Kitefall launch and crash | caster | 5.65 / 5.55 | 0.00 / 0.01 | 0 / 412 | x1.00 |
| Sparkle Kitefall launch and crash | moved Hunter | 0.13 / 0.14 | 0.00 / 0.05 | 461 / 924 | x1.00 |
| Knock into a wall | moved Hunter | 0.29 / 0.29 | 0.23 / 0.00 | 344 / 766 | x1.07 |
| Kael Rampage dash | caster | 1.53 / 0.52 | **1.33 / 0.44** | 6 / 427 | x1.00 |
| Grimble Barge dash | caster | 0.25 / 0.26 | 0.25 / 0.25 | 1 / 433 | x1.00 |
| Neve Skate (held 0.5 s) | caster | - / 0.19 | - / 0.10 | -60 / 395 | x1.00 |

Before is the fixed 0.15 s buffer (Neve's row was the 0.8 s skate off the ledge); after is the jitter buffer. One run
each, so a few tenths of a metre is run-to-run noise. Ends agree everywhere (other vs own 0.00 m, own vs offline at
most 0.29 m) and nothing moves twice (x0.95 to x1.07): the 52 checks pass. The self-dash late start on the other
game went from about 418 to 427 ms with the bigger margin.

### Follow-ups, worst first (not done here)

1. **A hit on another Hunter shows on the caster's screen 0.77 to 0.92 s late** (Grimble's reel, Meeko's pull,
   Sparkle's launch, a knock). The hit goes caster to relay to owner (300 ms), the owner moves its Hunter
   (Displace, decision 0016), and the snapshots come back (300 ms) plus the buffer. The owner's own game starts
   0.34 to 0.53 s late. Only prediction on the caster's copy (draw the pull at once, hand back to the owner's
   snapshots) would cut it. That changes decision 0016 and needs a parity look at the source first.
2. **Kael's Warchain sling steps 1.6 to 2.9 m in one frame on the other game** (0.57 at 100 ms, 0.43 on its own
   game). Not traced. A lost or overtaken snapshot at the sling's speed probably clears the buffer.
3. **Sparkle's Kitefall crash steps about 5.6 m on the other game**: the known gap above. The model is hidden from
   30% of the fall (`MageUlt._fall_tick`), so it reads as the streak. The fix is still a cast event or the fall's
   velocity in the snapshot (a Net shape change).
4. **A teleport can be drawn as a glide** (Motley's 8 m swap, the moved Hunter on the host, 0.90 m a frame in the
   second run). If the snapshot before it is lost or overtaken, 8 m over 0.2 s of owner time is right at
   `NetSmooth.SNAP_SPEED` (40 m/s), so the buffer sweeps it. A teleport flag on the hunter snapshot would make
   it exact (a Net shape change and a VERSION bump).
5. **Dashes still run on 0.25 to 0.44 m** (Rampage, Barge) when a gap is over the 120 ms margin cap (owner
   hitches). A higher cap trades that for more lag on every Hunter.
