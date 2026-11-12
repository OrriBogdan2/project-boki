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
  velocity; the owner sends 10 Hz (`send_t = 0.1`, scripts/core/net.gd:228), so the other game sees one or two
  snapshots of a 4.5 m fall, and `Ent.net_follow` (scripts/match/ent.gd:326) jumps when the gap is over 4 m
  (line 332). Raising that threshold with the owner's speed was tried and made it no better (the velocity is
  zero), so it was reverted. A fix needs the fall's velocity in the snapshot (the kit setting `h.vel` while the
  hunter step still does not integrate it: a double move on the own game if it does) or a cast event for the
  other game to play the dive locally (a Net shape change, so not done here).
- Not measured: a mover owned by the host with the caster on the guest (every row has the host casting, so
  the guest is the one moved); Kael's Warchain on a bot (that is the offline reference).

## The squad rocket drop (`--online-rocket-check[=<ms>]`)

`tools/online_rocket_check.gd` (the same three processes and 100 ms delay proxy) plays the drop with a host and a
guest in one squad: the host leads and steers the rocket for the nearest island, the guest rides, jumps out 1.6 s
after the launch, free-falls steering with the keys, pulls the glider with a fresh press 1.4 s later and glides to
the island; the rocket lands on its own. The games run on real time (a step per 1/60 s of wall clock, caught up
after a slow frame, as a real match does) so the two clocks do not drift apart on a loaded box; the guest's ship
is 0.2 s ahead of the host's (two games never start together). Every frame each game records every remote body
it knows and the largest step per 1/60 s (a catch-up frame is scaled back to one step) is flagged over 0.5 m.

Largest step in one frame of a remote body (m, quiet-box run, 100 ms each way; "own body" is the real one on
its own game, for reference; rival bots are the host's, seen on the guest):

| Game | Body | Phase | Frames | Largest step per 1/60 s (m) | Frames over 0.5 m | Catch-up frames | Worst at (s after launch) |
|---|---|---|---|---|---|---|---|
| host | squadmate (the other player) | ride | 104 | 0.45 | 0 | 0 | 3.3 |
| host | squadmate (the other player) | fall | 85 | 0.44 | 0 | 0 | 3.5 |
| host | squadmate (the other player) | glide | 833 | 0.34 | 0 | 0 | 6.6 |
| host | squadmate (the other player) | landing | 86 | 0.25 | 0 | 0 | 34.6 |
| host | own body (this game) | ride | 104 | 0.46 | 0 | 0 | 2.4 |
| host | own body (this game) | fall | 85 | 0.43 | 0 | 0 | 4.7 |
| host | own body (this game) | glide | 833 | 0.60 | 1 | 0 | 9.3 |
| host | own body (this game) | landing | 86 | 0.00 | 0 | 0 | 0.0 |
| guest | squadmate (the other player) | ride | 104 | 0.45 | 0 | 1 | 2.8 |
| guest | squadmate (the other player) | fall | 85 | 0.43 | 0 | 0 | 5.2 |
| guest | squadmate (the other player) | glide | 92 | 0.40 | 0 | 0 | 6.3 |
| guest | squadmate (the other player) | landing | 51 | 0.40 | 0 | 0 | 9.2 |
| guest | rocket (follower copy) | ride | 95 | 0.45 | 0 | 1 | 2.8 |
| guest | rocket (follower copy) | fall | 85 | 0.43 | 0 | 0 | 5.2 |
| guest | rocket (follower copy) | glide | 92 | 0.40 | 0 | 0 | 6.3 |
| guest | rocket (follower copy) | landing | 16 | 0.40 | 0 | 0 | 9.2 |
| guest | own body (this game) | ride | 104 | 0.80 | 1 | 1 | 0.3 |
| guest | own body (this game) | fall | 85 | 0.40 | 0 | 0 | 3.5 |
| guest | own body (this game) | glide | 92 | 0.23 | 0 | 0 | 6.3 |
| guest | own body (this game) | landing | 51 | 0.15 | 0 | 0 | 9.3 |
| guest | rival bots | ride | 208 | 0.43 | 0 | 2 | 1.8 |
| guest | rival bots | fall | 170 | 0.60 | 2 | 0 | 4.5 |
| guest | rival bots | glide | 184 | 0.12 | 0 | 0 | 9.3 |
| guest | rival bots | landing | 102 | 0.12 | 0 | 0 | 9.3 |

What it showed:

- **The follower's rocket snapped the rider.** A squadmate's rocket is made where their own ship is, then followed
  the leader's synced position in one jump (`pos = l.pos`). With the ships 0.2 s apart (a ship moves ~30 m/s) the
  guest's own body jumped 2.2 m in one frame at the launch (3.3 m with a 0.1 s clock error); the other game saw it
  smeared over several frames. `DropRocket.tick` now closes the gap at the rocket's speed plus 8 m/s (`CATCH`),
  and only jumps past 40 m (`FOLLOW_SNAP`): the guest's own launch step is 0.8 m (the 0.8 m seat drop from the ship
  to the rocket, by design) with the skew, 0.45 to 0.8 across runs. Checked: the guest's own body on the rocket
  stays under 1.0 m. No Net shape change (the "rkt" event is as in 0.24.6), so `Net.VERSION` stays.
- **Free fall and glide are clean.** The other game sees the jumper at 0.25 to 0.45 m a frame all the way down
  (the free fall steers with `Loco.air_step`, the glider opens on the fresh press); the follower copy of the
  rocket (the leader) 0.40 to 0.45 at its 24 m/s top speed, the nominal 0.4.
- **Both ends agree** to 0.01 m (the guest where it landed, the leader where the rocket set it down).
- **Gap, not fixed: on a loaded box the host sees the guest's rider in the first second after the launch with
  1 to 4 m steps** (about half the runs; the guest's own path is smooth, 0.45 to 0.8 m). The host's copy had snapshot
  gaps (0.12 s, then 0.47 s) at 100 ms delay and none at 0 ms. Not traced: the guest builds the rocket's meshes
  that frame (a hitch holds its 10 Hz snapshots), or the unreliable "st" packets over the 1392-byte MTU (Godot warns
  at 1503 bytes on the host's) are lost. Those runs print `ODROCKET FLAG` lines and the check does not fail on them.
- **Harness caveat found on the way:** one sim step a frame at less than 60 fps drifted the two games' clocks
  apart by 0.2 s, which NetSmooth reads as lag and shows as a 1.3 m step every snapshot; the check steps on real
  time for that reason (`--online-displace-check` still steps one a frame).
