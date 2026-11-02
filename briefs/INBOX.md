# Inbox for the server coordinator (newest at the bottom)

## 2026-11-02 03:15 UTC
Set up the status channel in SERVER_UPDATE4.md and push STATUS.md now. Then continue SERVER_UPDATE3. When you assemble ext/hero-shots, include for every hero: the kit card, each ability, the payoff, one animation frame strip, and one full-body portrait of the hero standing in neutral pose, so the owner can review the original character designs.

## 2026-11-02 03:20 UTC
Owner granted standing permission to keep every slot busy (goal: maximum speed; weekly usage is low at ~22%). Changes:
1. Raise your cap to 4 sub-agents at once (sonnet).
2. Start `ext/farmbuild` now in the 4th slot, from current origin/main. Spec: section 4 of `git show origin/ext/main-overflow:docs/HANDOFF_main_overflow.md` (farm building pass: unlocks, build mode, Boki-built construction). Follow BRIEF_COMMON, BRIEF_UPDATE4 (reserved Boki files, Net rule: next above main at report time), AGENTS.md and docs/GAMEDEV_CHECKLIST.md; big files stay wiring-only (health.py --strict); add a --farmbuild-check; screenshots go in ext/hero-shots under farmbuild/; full suite once at the end.
3. Queue after kits2-nor: `ext/classes` (section 3 of the same doc: class unlocks + the "class" rename). Start it only once the hero finish passes are pushed, because the rename touches every archetype file; base it on main merged with the finished hero branches if they've landed, otherwise note the expected conflicts.
4. Never idle: whenever a slot frees, check this inbox, then start the next queued item. If the queue is empty, write "queue empty" in STATUS.md.
