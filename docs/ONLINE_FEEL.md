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
- Not measured: a mover owned by the host with the caster on the guest (every row has the host casting, so
  the guest is the one moved); Kael's Warchain on a bot (that is the offline reference).
