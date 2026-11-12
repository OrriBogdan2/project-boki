# 0077: A kit move's clear and restart on the wire

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** networking

## Problem
The hunter snapshot carries the kit's full-body move as `[id, age]` (`ArchKit.net_move`, Net 0.16.0). Two
moves did not reach the other player (`--remote-anim-check` GAP rows). (1) A kit that clears its move
(`anim_id = ""`: Albert lowering his shield, Lace's cancelled draw, Kael's cancels) sent `""`, which is also
what an expired move sends after 3 s, so `apply_net_move` ignored it and the copy kept the hold pose
(`bul_guard`). (2) A move restarted within 0.3 s of its start (the Gunslinger's rapid `gunslinger_lmb`) looked
like the same play, because a restart was read only from the age jumping by over 0.3 s.

## Options
1. Send `""` for a clear and stop sending expired moves some other way. A guard held past 3 s then drops on
   the copy while the shooter still holds it.
2. A distinct clear value, and a play count beside the age. One more field in the row.

## Decision
Option 2. `net_move` sends `[id, age, n]`: `NET_MOVE_CLEAR` (`"-"`) when the kit has no move, `""` when the
move expired (the copy plays it out, as before), and `n` = `ArchKit.anim_n`, counted by `play()` (as
`MergeKit.anim_n` does for KinNet). The copy restarts when the id or the count changes; the age check stays for
kits that move a playing move's clock (a held draw, the Gunslinger's slide). The source decides: the copy
shows what the shooter's kit shows.

## Consequences
Net.VERSION 0.24.6 (main's 0.24.5 was taken by Limited Ways Out). `GripNet.AT` follows `NET_MOVE_SIZE` (3). match.gd unchanged. No save change.
`--remote-anim-check` asserts both casts.
