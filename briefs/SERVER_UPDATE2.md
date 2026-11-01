# Server update 2

Read `~/briefs/BRIEF_UPDATE2.md` and apply it now: tell your running hero agents about sync56, the new Net numbers in its table, health.py, the gen_wiki step and the off-limits Boki files. Use their numbers from that table instead of the 0.6.x ones in SERVER_HANDOFF.md.

## New queue item: ext/kits2-nor (Thief + Juggernaut, R removal)
kits2 is finished and is already in sync56, so this is a follow-up, not a port. Run it after the first hero pair finishes (keep the 2-pairs-at-a-time limit), on a Sonnet sub-agent.
- Wait for sync56 on origin/main, then branch `ext/kits2-nor` from it.
- Read `docs/heroes/HANDOFF_kits2.md` (on origin/kits2, also on main after sync56). Do its "What's next" item 1:
  - Fold Doomfall into Smash as its rank-3 upgrade (sweet-spot slam that also crashes and heals; keep the reset on knock).
  - Turn Jackpot into a Mark trigger: 5 Marks on a target release a short knife burst that refreshes Marks and gives one free Vault.
  - Remove R from both kits; update kit cards, next-rank text, bots and `--kit-combo-check` to assert the new triggers.
- Item 4 (sync the KMOVES move id over Net so remote players see full-body poses) is worth doing here too if it stays small; it benefits every hero. Use Net 0.8.10.
- Full suite once at the end, then report it as ready to merge.

Queue order on the server is now: (running pairs) → Kingpin+Felix → Tetra+Void → kits2-nor → Myth+Oath. Same usage rules as before.
