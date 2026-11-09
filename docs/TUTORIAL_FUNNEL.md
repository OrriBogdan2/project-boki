# Tutorial funnel

Where testers speed through, stall at, skip or quit the match tutorial and the farm tutorial.

- `scripts/core/tut_funnel.gd` (`TutFunnel`) keeps, per step: `[entered, finished, idle, hints, end]`.
  Times are whole seconds on the tutorial's own clock (it runs only while the tutorial does, across launches).
  `finished` is -1 until the step ends. `idle` is time with no key or mouse movement after 5 s of quiet.
  `hints` is extra help shown (the match's stall reminder; a later hint line on the farm). `end` is
  `done`, `skip`, or empty: entered and never ended, which is the quit.
- Hooks: `Tutorial` (enter, finish, stall reminder, tick), `FarmTutorial.mark/skip`, `FarmGuide` (current step and hint stage).
  The match tutorial has no skip on main; when one lands it calls `TutFunnel.skip("match")`.
- Stored in `user://feedback.json` (`Feedback.funnel`, this version only) and sent as `funnel` with the rate card's
  answer when the answer still fits the server's 2 KB (a long non-ASCII note leaves it off). The server (`mm/feedback.py`) validates it (numbers and `done`/`skip` only, no free text) and keeps it in `feedback.jsonl`.
  It reaches us only when a tester sends the card. No names, ids or dates are added.
- `python3 tools/tut_funnel.py <folder>` reads `*.json`/`*.jsonl` (feedback.jsonl, a tester's feedback.json) and prints, per step:
  reached, done, skip, quit, median seconds, median idle, average hints.
- Check: `--tut-funnel-check`.
