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
  velocity; the owner sends 10 Hz (`send_t = 0.1`, scripts/core/net.gd:229), so the other game sees one or two
  snapshots of a 4.5 m fall, and `Ent.net_follow` (scripts/match/ent.gd:326) jumps when the gap is over 4 m
  (line 332). Raising that threshold with the owner's speed was tried and made it no better (the velocity is
  zero), so it was reverted. A fix needs the fall's velocity in the snapshot (the kit setting `h.vel` while the
  hunter step still does not integrate it: a double move on the own game if it does) or a cast event for the
  other game to play the dive locally (a Net shape change, so not done here).
- Not measured: a mover owned by the host with the caster on the guest (every row has the host casting, so
  the guest is the one moved); Kael's Warchain on a bot (that is the offline reference).

## Remote smoothing: the 0.24.4 gate's 5 reds (`--remote-smooth-check`)

docs/GATE_0244.md had `--remote-smooth-check` at 5 failures on both trees. Run on origin/main 88b06b9e7 on rpc7
(32 cores, load ~35): `--headless` 0 failures in 2 of 2 runs; xvfb 4 failures (25 snaps, 158 jerks, 22 backsteps,
0.97 m off the path). Not the 2x map, not a new move, not NetSmooth. Three causes, by weight:

- **The check under xvfb (the gate's reds).** It stepped the host's match once per frame. Drawn on llvmpipe, the
  host ran ~30 fps with frames over 0.1 s, so its match clock (the snapshots' time) ran at half the wall clock and
  fell up to 0.6 s behind. The guest's buffer then ran past the newest snapshot and started over at its 0.5 s
  resync. The game doesn't do this: `Match._process` steps on the wall clock. The check now steps both games the
  same way (an accumulator, frames clamped to 0.1 s), stamps each step with the wall moment it stands for, and
  stops the host drawing (`RenderingServer.render_loop_enabled = false`; only the headless guest is measured).
  `RSMOOTH load` prints what frames over 0.1 s still cost each game's clock in the run, so a stall can be told
  from a jerk. Moving the lag relay into its own process was tried and made no difference. After this: 0-2
  failures a run in both modes (1 backstep, or one 0.3-0.7 m overshoot).
- **The snapshot rate, in the game.** `Net.tick` sent a snapshot every 7th step (0.117 s, 8.6 a second), not
  every 0.1 s: `send_t = 0.1` minus six 1/60 s steps leaves 1e-17, so `<= 0` waited one step more. This dates
  from the first commit; host world snapshots went every 10th step (0.167 s) instead of 0.15 s. NetSmooth's
  0.15 s delay assumes a 0.1 s gap plus 40 ms of jitter. 0.117 s plus 40 ms overran it: the body ran on past a
  late snapshot and the next one pulled it back. Now a timer within 1 ms of 0 is due (`Net.SEND_DUE`): 10 and
  6.7 snapshots a second, 17% and 11% more snapshot traffic. No shape change, so Net.VERSION stays.
- **The lag relay's ordering (the check).** It gave every packet its own jitter and dropped a snapshot that a
  newer one overtook (ENet's ordered rule). Snapshots are 0.1 s apart and the jitter is +-20 ms, so only packets
  sent in the same step could swap: the host's hunter and world snapshots. With the 10 Hz fix they share a step
  every 0.3 s, and half of those swaps dropped the hunter's snapshot (28 lost in a run, not ~7). That sometimes
  turned the 5 m lift into a sweep under the 40 m/s snap speed. A real line queues packets in order, so the
  relay now keeps send order per peer and the overtake rule is gone.

Measured after all three: 4 runs at once at load ~35 (2 `--headless`, 2 xvfb), 0 failures each. 7 snapshots
lost (the 2%), 1 snap (the lift), 3-7 jerks, 0 backsteps, 0 overshoot (max 0.03 m off the path), drawn 200-205 ms
behind, 0 ms of either game's clock lost to stalls.
