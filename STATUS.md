2026-11-06T18:48:18Z

PHYSICS LANE (worktree /home/boki/lanes/physics-20261106-1607). S1 retired 17:20 UTC; its last STATUS is commit 5f165a95 on this branch.

| item | branch | sha | state |
|---|---|---|---|
| 185 + 162/162b + 149 | ext/phys-integrated | e99c49e5 | one branch to merge; full suite vs main running (185 alone: 0 NEW-RED, 0 WORSE) |
| 185 Boki never change a dash | ext/phys-185-boki-dash | ebc9c16d | in integrated (check flake fixed) |
| 162/162b air limits | ext/phys-162-air-limits | ea1952f0 | in integrated |
| 149 wall hop | ext/phys-149-wall-bounce | 89879b96 | in integrated; adds fx "whop" (no Net.VERSION bump) |
| 151 training rocks + layout rules | ext/phys-151-layout | c9a4bcd5 | targeted checks green; full suite running. Conflicts with integrated only in check_registry |
| 150 SV parity | ext/phys-150-parity | (local) | step 3: braking 22.2 + friction 2, dash carry 0.5/0.6; checks running |
| 163 squad launch + SV glide | - | - | next |

- 151 root cause: the rock hop threw you over a clump of scattered rocks into a one-tile hole sealed by rocks on four sides. Fix: no rock hop, the generator fills sealed pockets, no stray rocks in training. briefs/supervive-data/LAYOUT_RULES.md.
- 150 step 2: the footage is 5 fps, too coarse for a 0.2 s stop or a dash decel; the game data is the reference.
