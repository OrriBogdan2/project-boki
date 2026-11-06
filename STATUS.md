2026-11-06T18:48:18Z

PHYSICS LANE (worktree /home/boki/lanes/physics-20261106-1607). S1 retired 17:20 UTC; its last STATUS is commit 5f165a95 on this branch.

| item | branch | sha | state |
|---|---|---|---|
| 185 + 162/162b + 149 | ext/phys-integrated | 38dde07c | READY (00:30 UTC candidate gate) |
| 151 training rocks + layout rules | ext/phys-151-layout | fca0115f | READY. Conflicts with integrated only in check_registry |
| 150 SV parity | ext/phys-150-parity | 4071fe66 | SV walking stop (braking 22.2, friction 2, shed to run speed); full suite running |
| 163 squad launch + SV glide | ext/phys-163-drop | cfc9b8d1 | stacked on integrated; checks + GPU shots done; suite after 150 |

- 151 root cause: the rock hop threw you over a clump of scattered rocks into a one-tile hole sealed by rocks on four sides. Fix: no rock hop; stray rocks placed then cleared (the map otherwise matches main); sealed pockets filled.
- 150: the game data is the reference (the footage is 5 fps). The dash carry stays as it is (0.5/0.6 pushed Breaker's step past 2 m).
