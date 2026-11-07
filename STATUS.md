2026-11-07T08:21:10Z

PHYSICS LANE (worktree /home/boki/lanes/physics-20261106-1607). S1 retired 17:20 UTC; its last STATUS is commit 5f165a95 on this branch.

| item | branch | sha | state |
|---|---|---|---|
| 185 + 162/162b + 149 | ext/phys-integrated | ceab95f4 | READY (08:30 UTC candidate). 38dde07c plus a merge of kit-kael-113b (the 00:30 run skipped it on a conflict) |
| 185b mantle (owner) | ext/phys-185b-mantle | cc3212ae | READY on top of integrated. A dash keeps 0.6x over the lip; findings in briefs/supervive-data/MANTLE_185b.md; clips in /home/boki/clips/185b |
| 151 training rocks + layout rules | ext/phys-151-layout | fca0115f | READY. Conflicts with integrated only in check_registry |
| 150 SV parity | ext/phys-150-parity | 074453ec | READY with bot-sanity seed 9 red, explained (keys held in the window; nav jitter at a rim). Bot rim brake added. Coordinator decides |
| 163 squad launch + SV glide | ext/phys-163-drop | bb211b35 (local, ceab95f4 merged) | full suite running |

- 151 root cause: the rock hop threw you over a clump of scattered rocks into a one-tile hole sealed by rocks on four sides. Fix: no rock hop; stray rocks placed then cleared (the map otherwise matches main); sealed pockets filled.
- 150: the game data is the reference (the footage is 5 fps). The dash carry stays as it is (0.5/0.6 pushed Breaker's step past 2 m).
