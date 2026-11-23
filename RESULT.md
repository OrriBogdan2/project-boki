# RESULT: integration lane bundle (ext/merge-lane-integ-1115)

Job 20261115-113307-a3 (rpc4), continued from wip/cj-20261115-093450-a3 / ext/merge-lane-integ-1115.
- 22 integration-lane READY branches bundled on one branch from origin/main (88c671a67a), 8 of the original stuck-integ list skipped, details in gh-outbox/new-pr.md.
- The first bundle (22 branches) was re-fitted after main moved by ~4400 and then ~600 commits: dropped hunks restored, ~25 fix commits, each explaining itself.
- suite-fast x4 on this tree vs main, every red re-run alone on both trees; export dry-run 5 presets rc 0, 453 MB.
- Open: tutorial-dead-air (Boki falls in Kael's gap step), wisp-hit-rules 3 rows, cast-predict flaky under load.
- gh is not installed on rpc4, so the PR is described in gh-outbox/new-pr.md for the coordinator to open; nothing merged to main.
