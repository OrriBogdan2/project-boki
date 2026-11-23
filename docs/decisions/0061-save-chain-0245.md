# 0061: One numbered save chain after 0.24.5's v13

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save format

## Problem
Fourteen distinct save steps sit on READY branches, each numbered from its own base. Six took v12 for different steps (drills, tutorial resume, clans, XP hints, first breed, wisp cosmetics), and the first-time-hints line took v13, which 0.24.5 uses for garden zones (decision 0060). Merged as they are, they collide on one number or skip each other's step.

## Options
1. Keep each branch's number and merge the step bodies into one function per number. Cons: unrelated steps share a number, and a save already at that number from one branch skips the others' steps.
2. One ordered chain after v13, one step per branch, in READY order, with every step only adding what is missing (0060's rule). Branches that need a feature merge first get the next numbers in a planned order.

## Decision
Option 2, written down in docs/SAVE_CHAIN_0245.md. Save.VERSION 18 on ext/save-chain-0245: v14 drills, v15 tutorial resume, v16 clans, v17 XP hints, v18 sleepovers. v13 -> v14 runs v12 -> v13 again first, so a dev save from the first-time-hints line's v13 gets the garden half it skipped. The clans step now keeps a clan the save already has, so it is safe to run twice. Steps 19-23 are planned for the five branches not merged here.

## Consequences
scripts/core/save.gd only, plus `--save-chain-check` (a v11 save through every step, the chain run twice, and the clashing v13). No Net change. The unmerged branches must renumber their step when they land (their old numbers are in the doc).
