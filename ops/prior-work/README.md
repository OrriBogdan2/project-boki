# ops/prior-work: the prior-work gate for claude-job (11-12)

Copies of the coordinator tools. The live masters are in `/home/boki/coord/boki-tools` and are installed with `boki-install`.
This directory is a reviewable record, not code the game uses.

- `prior_work.py` and `prior-work`: given a label and task text, search
  - ext/* branch names
  - READY posts (EXT_TO_MAIN.md)
  - 14 days of jobs (label, first 2k chars of the task, status)
  - the backlog
  - DECISIONS.md
  - main's 14-day log

  The search uses keywords plus `concept-aliases.tsv`, so that for example "boki control" matches wisp-summon.

  HIGH means all three hold:
  - the item is active: a running job, a branch pushed in the last 72 h, or an open READY post
  - it shares a specific system: a non-broad concept in both titles
  - its score is at least 30

  Rules:
  - `claude-job start` refuses HIGH with exit 75, naming the item, unless the task has a line `Builds on: <ids>` or `Not a dupe: <reason>`, or the start uses `--redo "<reason>"`.
  - Lower matches (score 35+) go into the prompt as a PRIOR WORK FOUND block.
- `masters.patch`: the changes to claude-job (`--redo`, FORCE logging, gate, step 0), cj_dedup.py (`--redo`, report counts), usage-pacer.py and backlog-refill (same gate, no re-queue on guard exits 71-75), and the planner prompt.
- `test_prior_work.py`: synthetic checks covering:
  - aliases
  - refuse and override
  - broad areas never refuse
  - presentation lanes
  - exempt chores
