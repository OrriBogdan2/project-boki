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
