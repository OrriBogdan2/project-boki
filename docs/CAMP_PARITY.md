# Camp and lair-boss parity: ours against the source

Tags: **[D]** source data (briefs/supervive-data), **[F]** footage and hero sheets (briefs/hero-ref), **[O]** owner note in
briefs/DECISIONS.md (wins over the source), **[?]** the source gives no value; ours is kept and unconfirmed.
Camp (non-boss) rows live on ext/camp-parity and ext/combat-camp-clear; this file holds the lair-boss section, so those
branches will conflict on this file's name: keep both sections.

**Source read (2026-11-11):** supervive_kits.md, supervive_physics.md, PHYSICS_PARITY.md, LAYOUT_RULES.md and the 14 hero-ref
sheets. They cover kits, movement and the practice range. No boss HP, phase, enrage, leash, respawn or reward value appears
in any of them (the footage is training-range dummies). So no boss number was changed; every source cell is [?].

## Lair bosses (colossus, serpent, brood: `Data.MOBS`, `boss.gd`, `lairs.gd`)

| Function | Source | Ours (where) | Verdict |
|---|---|---|---|
| HP | [?] | 1500 / 1250 / 1350 (`Data.MOBS`), tier x1.0 / 1.45 / 2.0 | keep |
| HP per squad size | [?] | none: one pool whatever the squad | keep, [?] |
| Phase triggers | [?] | 66% and 33% health: each adds or sharpens an attack, damage +10%/phase, cooldown -12%/phase (`Boss.sim`, `_phase_up`) | keep, [?] |
| Enrage | [?] | 75 s awake: damage x1.5, cooldown x0.6, speed x1.25 (`md.enrage`) | keep, [?] |
| Leash distance | [?] | the sealed lair itself: it cannot leave it (`Boss.clamp_in`) | keep, [?] |
| Leash reset | [?] | nobody inside for 12 s: asleep in the middle, full health, phase 0, no enrage, adds removed, 8 s calm (`Lairs.reset_boss`) | keep; `--boss-parity-check` |
| Respawn | [?] | none: a cleared lair stays cleared | keep, [?] |
| Kill XP | [O] 11-10: the last-hit squad takes the XP and the kill bonus | **was** 260 to everyone in the lair (killer squad 100%, others 50% / 20% by damage). **Now** 260 (`Lairs.BOSS_XP`) to the last-hit squad's members within 30 m of the boss (`BOSS_XP_SHARE_R`); other squads get none | **changed** |
| Kill bonus | [O] same | gear pile (Brand for the killer's weapon), treasure, key, perk-orb fan, kill stat all go to the last hitter (`_boss_dead`); the Rare Egg lies on the floor for anyone | keep |

The per-damage XP (0.35 per point dealt to a monster) is a separate rule that decision 11-10 asks to remove; it is not touched here.

## Ideas of ours (not built)
- HP that scales with the squads inside; a visible low-HP tell for last-hit steals (counterplay named in DECISIONS 11-10).
