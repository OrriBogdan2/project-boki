# merge-archive-1113 (ops payload from rpc4, job 20261113-173508-a3)

Archive pass on the low-impact batches the top-10 merge job does not touch. Ops only: do not merge to main.

- `merge-archive-1113.md`: the report (copy to hetzner `/home/boki/coord/merge-archive-1113.md`).
- `merge-exclude-add-archive-1113.txt`: on hetzner, append to `~/bin/merge-exclude.txt` (rpc4 has no copy of that file).
- `merge-archive-1113.log`: one line per archived branch: sha, reason, tag, why, restore.
- `tagplan.txt` / `archive_list.txt`: reason code (a0 residual 0, at trivial residual, ar READY successor, b on main), branch, sha, tag.
- `bin/`: the scripts (work dir /tmp/ma, inputs from `ext/merge-triage-1113`). Order: parse, anc, lines, files, cover, resid, rl2/pair (hand checks), report, md.
