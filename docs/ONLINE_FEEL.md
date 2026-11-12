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
use it. `--online-displace-check=0` goes straight to the relay for a no-delay baseline.

## Measured (100 ms each way, 10 Hz snapshots, 60 fps)

Columns: the largest step in one frame on the mover's own game (offline in brackets) and on the other game; the
largest step per snapshot on the server (it only sees 10 Hz, so a fast mover shows long steps there); the end
position error against the offline end, between the other game and the mover's own game, and between the server's
last snapshot and the mover's own game (m); the net distance moved against the offline run.

| Move | Mover | Step/frame own (offline) | Step/frame other | Step/snapshot server | End: own vs offline | End: other vs own | End: server vs own | Moved vs offline | Note |
|---|---|---|---|---|---|---|---|---|---|
| Kael Warchain self-pull | caster | 0.37 (0.37) | 0.38 | 2.56 | 0.22 | 0.00 | 0.00 | 5.0 vs 5.2 m (x0.96) |  |
| Kael Warchain sling | caster | 0.43 (0.43) | 0.57 | 2.99 | 0.48 | 0.00 | 0.00 | 4.8 vs 5.3 m (x0.91) | speed away 4.6 m/s |
| Grimble Abyssal Hand reel | moved Hunter | 0.18 (0.18) | 0.30 | 1.18 | 0.00 | 0.00 | 0.00 | 4.5 vs 4.5 m (x1.00) |  |
| Motley swap dash | moved Hunter | 8.00 (8.00) | 8.00 | 8.00 | 0.00 | 0.00 | 0.00 | 8.0 vs 8.0 m (x1.00) | a teleport |
| Motley swap dash | caster | 8.00 (8.00) | 8.00 | 8.00 | 0.00 | 0.00 | 0.00 | 8.0 vs 8.0 m (x1.00) | a teleport |
| Meeko Hearth Call pull | moved Hunter | 8.05 (8.05) | 8.05 | 8.05 | 0.00 | 0.00 | 0.00 | 8.1 vs 8.1 m (x1.00) | a teleport |
| Sparkle Kitefall launch and crash | caster | 1.08 (1.06) | 0.76 | 3.61 | 0.00 | 0.00 | 0.00 | 4.5 vs 4.5 m (x1.00) |  |
| Sparkle Kitefall launch and crash | moved Hunter | 0.13 (0.13) | 0.19 | 0.81 | 0.00 | 0.00 | 0.00 | 2.3 vs 2.3 m (x1.00) |  |
| Knock into a wall | moved Hunter | 0.26 (0.26) | 0.38 | 1.75 | 0.00 | 0.00 | 0.00 | 3.9 vs 3.7 m (x1.07) |  |

The no-delay baseline (`=0`) ends within 0.52 m of offline everywhere and shows the same Sparkle crash step
(4.98 m), so that step is not the delay's doing; with delay it was 0.76 to 5.71 m from run to run (see below).

## Dash sweep: every Hunter's dash on the other game

The same check also plays each Hunter's ground dash and air dash (Shift with the move keys held, the air one from
8 m up, 7 m back from the strip's middle so the gliders have room) and Kael's Lunge on the host, and reads the
host's Hunter on the guest's game, frame by frame. Neve's skate push-off, Motley's Trade, Grimble's Barge, Tenzo's
Rock Hop and Sable's Cartwheel are those Hunters' dash rows. A row is **flagged** (`DISPNET FLAG`, not failed) when
the guest's copy moves over 0.5 m in one frame and over 0.15 m more than the dasher's own game does (Kael's and
Sparkle's dashes are 0.55-0.7 m a frame on both games: that is the dash, not a jump), or ends over 0.3 m from
where the dasher's own game ends. A frame that took 50 ms or more on the box is left out of the jump (a loaded box
stalls a game; that is not the net). Motley's Trade is a swap, so its rows are exempt from the jump.

Result at 100 ms each way: **no flag, every end within 0.01 m.** The guest's copy follows a dash frame by frame at
the dasher's own step. Step per frame (m) own / other, end off (m), net distance moved (m):

| Hunter | Ground: step own / other | End off | Moved (m) | Air: step own / other | End off | Moved (m) |
|---|---|---|---|---|---|---|
| Vex | 0.32 / 0.32 | 0.00 | 4.8 | 0.24 / 0.25 | 0.00 | 8.8 |
| Lace | 0.24 / 0.21 | 0.00 | 3.0 | 0.24 / 0.22 | 0.00 | 6.5 |
| Cinder | 0.24 / 0.24 | 0.00 | 3.6 | 0.41 / 0.41 | 0.00 | 14.7 |
| Meeko | 0.30 / 0.32 | 0.00 | 3.7 | 0.29 / 0.35 | 0.00 | 19.2 |
| Albert | 0.42 / 0.44 | 0.00 | 4.9 | 0.42 / 0.44 | 0.00 | 12.0 |
| Sable | 0.24 / 0.23 | 0.00 | 4.8 | 0.24 / 0.36 | 0.00 | 9.7 |
| Kael | 0.56 / 0.57 | 0.00 | 4.2 | 0.56 / 0.55 | 0.00 | 9.8 |
| Grimble | 0.25 / 0.25 | 0.00 | 2.7 | 0.33 / 0.33 | 0.00 | 14.3 |
| Tenzo | 0.15 / 0.15 | 0.01 | 3.1 | 0.23 / 0.23 | 0.00 | 9.0 |
| Sparkle | 0.58 / 0.63 | 0.00 | 5.6 | 0.58 / 0.71 | 0.00 | 10.2 |
| Neve | 0.19 / 0.18 | 0.00 | 1.8 | 0.22 / 0.22 | 0.00 | 9.5 |
| Motley | 5.97 / 5.97 | 0.00 | 6.0 | 6.45 / 6.44 | 0.00 | 8.1 |
| Gil | 0.25 / 0.33 | 0.00 | 6.2 | 0.42 / 0.45 | 0.00 | 17.3 |

Seen once and gone on the next runs (before the stall filter), left unexplained: Tenzo's ground hop 0.75 m a frame
on the guest (own 0.15) and Meeko's ground dash 4.8 m (the copy stood over 4 m behind, `Ent.net_follow`'s
teleport). Neither came back in three further runs, and both fit a stalled guest frame on a box with a load
average near 80. If they come back on a quiet box they are real: queue a task on the dash fx event (as Kitefall's
`fall`, `ext/feel-online-kitefall`) for them.

## Findings

- **No double move anywhere.** A Hunter moved by someone else's ability is moved once, by its own game
  (`Displace`, docs/decisions/0016-displace.md); the other game and the server only follow its snapshots. The
  distances match offline (x0.90 to x1.07).
- **Ends agree.** The other game and the server end exactly where the mover's own game ends (0.00 m). Against
  offline: Kael's pull ends 0.2 to 0.5 m short of the offline run in some runs (the hooked player's body is
  nudged by the arrival differently than the bot's; not traced), everything else 0.00 m.
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
- Not measured: a mover owned by the host with the caster on the guest (every row has the host casting, so
  the guest is the one moved); Kael's Warchain on a bot (that is the offline reference).
