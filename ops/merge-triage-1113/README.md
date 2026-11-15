# merge-triage-1113 (ops payload from w2)

Made on w2, which has no merge-gap, branch-archive or ~/bin/merge-exclude.txt. Files:

- `MERGE_TRIAGE_1113.md`: the report. A copy is at /home/boki/coord/merge-triage-1113.md on w2; copy it to hetzner coord.
- `merge-triage-1113-archive.log`: the 166 archived branches, each with its restore command.
- `merge-exclude-add-1113.txt`: on hetzner, run `cat` on it and append the output to ~/bin/merge-exclude.txt. Those branches are already deleted, so this is optional.
- `pretagged_live.txt`: 230 (d) branches that already have `archive/<b>` at their head but are still live. Run `merge-gap --list | grep -Fxf` against it to see whether hetzner counts them.
- `classes.txt`: the class and reason for each of the 1614 branches.
- `bin/`: the scripts. They use /tmp/mt as their work dir. Run order: scan1, mt1, inmain1 (xargs -P), super, super2, final, deps, report, md, archive.
