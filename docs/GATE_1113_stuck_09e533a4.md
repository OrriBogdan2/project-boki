# Stuck-branch integration 09e533a4 (ext/stuck-integ-09e533a4)

Job 20261113-235517-a3 (rpc1, auto sys-audit): 590 READY branches merge-candidate kept skipping for conflicts.
Base: origin/main df5464db04 (PR #58). Not the newest `ext/mc-20261113-1750`: it conflicts with main in 9 files,
including two different Net 0.24.7 meanings ("stomp" vs "xp"), and it carries about 20 branches the merge-week
lanes own. Its merge with main belongs to the mc/lane jobs.

## Triage of the 590
- 194 are gone from origin (merged, archived or renamed since the list was made).
- `ext/agent-briefs` and `ext/agent-briefs-rebased`: the briefs channel, never merged into main.
- 191 have their tip inside a pending integration branch (141 in stuck-integ-11014837, 11 in stuck-integ-606e9a98,
  the rest in other stuck-integ, integ-1113 and mc branches).
- 101 are named in a batch of `ops/merge-triage-1113/MERGE_TRIAGE_1113.md` (ext/merge-triage-1113), and 93 more are
  carried by a branch named there. The merge-week lanes (A/C/D) and the archive pass own all of these; lane A
  (job 20261113-225148-a6) was still running.
- 11 had no owner. Of those, 4 have no READY note (dropped): art1-kael-2, kael-rmb-dash-turn,
  no-natural-death-1108, release-integ-0244-a4alt.
  - tenzo-playtest-1108 was dropped: its tip only re-merges main onto 770f73bc2, which stuck-integ-606e9a98
    carries, together with its Basalt Spine resolution.
  - parity-downed-numbers was dropped: its one own commit is in stuck-integ-606e9a98 and f6bd2b7c.

## Merged (newest READY sha)
- ext/heal-knock-source-rebased d9b716ba23: clean merge.
- ext/ui-death-recap ac3cea0861: clean merge.
- ext/input-latency-check b1204b3dba: the registry kept both lines. The 170 `docs/**/*.import` files the branch
  picked up were dropped, because docs/.gdignore stops Godot importing there and main tracks none of them.
- ext/step-smooth-rebased 2817c0ff0e: check_registry and MOVEMENT_FEEL.md kept both sides.
- ext/airdash-anims-1108 3ea315cfd7: `warden_clips.gd` keeps main's `owns_land` block ahead of the branch's
  `_move()` and air_clip dispatch. CLIPS.md has one `kmoves` line describing both.

These branches' older commits are partly in stuck-integ-606e9a98 too. Whichever lands second gets the same patches
twice; they should merge clean.
