# Item 3: no natural death for Boki

Branch ext/no-natural-death-1108. No tuning numbers touched (no movement/feel numbers in this item; coord/PLAYTEST-1108.md and tuning.json are not on this tree). One new rule file: content/rules/neglect.json (`natural_death: false`).

**Rule.** Neglect (also offline catch-up, up to 14 days per launch, any number of launches) takes a Boki hungry, weak, too weak to go out, sick (30 h on the starve clock) and stops there. It never dies and recovers with a meal and rest (a meal takes 4 h off the clock; fed over 20 food undoes it 3x faster). Match losses to another squad (tier 2+) are unchanged.

**Dead Boki.** `Econ.revive_neglected` runs from `Econ.ensure()` on every home load, idempotent. Every grave with cause "starved" comes back on the roster as itself (level, memories, trust, looks), weak (6 h on the clock, food 30), with a one-time notice. Graves that hold the full record (all graves made by this game) come back whole; a very old grave without one comes back as a plain Boki of its name and kind, level kept (memories lost).

**The owner's save (on his PC).** It runs on his next launch of this build: yes, his Boki that died of neglect will come back, weak, if the graves are in his save (they are kept in `graves` with `rec`). A Boki "lost" to another squad stays lost. A Soul Shrine soul that was kept also comes back, without spending the ember.

| item | done/partial/blocked | what I tested |
|---|---|---|
| 3 natural_death flag | done | --neglect-check: flag false; fails (8) with true |
| 60 days offline never kills | done | 9 x 14-day catch-ups with no food and one 60-day tick: sick, alive, no grave; recovers with a meal |
| dead-by-neglect revives weak | done | grave with rec, bare old grave, a "lost" grave (stays); idempotent second run |
| economy-check, kinbox, economy-floor, work-check | done | all 0 failures (econ test updated: no death, sick instead) |
| fresh save / Training Area / GPU clip | n/a | check runs on a fresh save; no visible change except the "came back" notice, so no clip |
