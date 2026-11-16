# stuck-integ-be6ffab8: why 205 of the 697 stuck READY branches cannot be merged, only replayed

Pass 1 (job 20261116-195528-a5) merged ext/vfx-last-hit-colour and recorded 7 branches whose work is on main
(see the READY line of 6db102ca67). Pass 2 (this job) found the systemic cause behind most of the "conflict" skips.

## Finding: the batch-26 drop

`ext/merge-batch-26-1113` stacked many READY branches (gil-train-1112 with 19 branches, feel-input-batch,
feel-cast-lock-buffer, stuck-integ-f6bd2b7c and -606e9a98 members, ...). On 11-15 the train was reset:

- 622a26fed8 "Batch 26 (PR #69): current main plus ext/zone1-batch1 only; the stacked stuck-integ members are dropped"
- 03b4f45235 "Batch 26 (PR #69): every member dropped; the tree is origin/main"

PR #69 then merged into main (88c671a67a). Result: **266 non-merge commits are ancestors of main while none of
their changes are in main's tree** (999 files, 10186 insertions and 20496 deletions went away in the drop).
For every branch built on them, `git merge` is a no-op for that part (git sees it as already merged) and the
branch's later commits conflict against a tree that lacks their base. merge-candidate reports "conflict", and
`git merge-base --is-ancestor` / "IN-MAIN" triage reports "already in main". Both are wrong about the content.

Numbers (this job, main e2bc08e889): 205 of 697 stuck branches have commits in that dropped set
(`dropped_members.tsv`: branch, own commits main lacks, commits lost in the drop, the earlier triage class).
43 of them have 3 or fewer own commits beyond the drop: the cheapest to replay.

## How to replay one (done here for ext/feel-cast-lock-buffer)

1. Base = the main commit the branch last merged (`git merge-base --all origin/main <branch>`: the one that is
   not the branch's own commit).
2. `git diff <base> <branch> -- . ':!docs/wiki' | git apply -3`; resolve keeping both intents; then grep main's
   newer code for the names the branch removed (here DashFlow.BUFFER_S, ArchKit.RECAST_BUFFER, Hunter.DASH_BUFFER
   had 20 new uses in kits and tools) and switch them too; regenerate the wiki; run the checks the READY line names.
3. Never `git merge` such a branch: the merge records it as done while its code stays out.

## This pass

- ext/feel-cast-lock-buffer 35f58a6496: replayed (one press window `Loco.press_buffer` from tuning.json,
  FireTap low-fps tap latch, `ArchKit.disabled()/lock_refuses()`, DashFlow `_route_lock` for RMB/E during a kit's
  own cast lock, kept beside main's newer `LOCK_SLOTS`/`lock_left` routing for Shift/LMB/jump; checks
  --cast-lock-buffer-check and --low-fps-input-check registered). Supersedes ext/feel-one-buffer and
  ext/feel-low-fps-input as its READY line says.
- ext/tut-creator-first 5adaa832aa: superseded. Main's creator is now `CreatorPanel` (OWNER_REVIEW item 45,
  sliders in Body/Face/Colours tabs); the branch's "first rows + More" on the old Unmasked.ROWS card has no
  target left. Its name-card change (one name box) assumed the creator card asks the player's name, which
  CreatorPanel does not; main's name card keeps both boxes. Nothing to port.
- ext/split-exits, ext/split-lairs, ext/split-rimewright-spear: pure file splits made on 11-12 files; main has
  since changed exits.gd 26 times, lairs.gd 55 times, rimewright_kit.gd 88 times. A replay would re-split
  old code; the split has to be redone on the current file (health --strict passes on main, so no budget forces it now).
- The rest of the list keeps the pass-1 triage (`triage_cd1e658f.tsv`): 176 INFLIGHT (open PRs), 487 PORT.
  Read PORT rows against `dropped_members.tsv` first: a PORT row that is also a dropped member is a replay, not a merge.
