# Camp and lair-boss parity: ours against the source

Tags: **[D]** source data (briefs/supervive-data), **[F]** footage and hero sheets (briefs/hero-ref), **[O]** owner note in
briefs/DECISIONS.md (wins over the source), **[?]** the source gives no value; ours is kept and unconfirmed.
Camp (non-boss) rows live on ext/camp-parity and ext/combat-pve-mult, which also create this file; this one holds the
lair-boss section, so merging them is an add/add conflict on this file: keep every section.

**Source read (2026-11-11):** supervive_kits.md, supervive_physics.md, PHYSICS_PARITY.md, LAYOUT_RULES.md and the 14 hero-ref
sheets. They cover kits, movement and the practice range. No boss HP, phase, enrage, leash, respawn or reward value appears
in any of them (the footage is training-range dummies; the one monster line is a kit heal on a creep kill, juggernaut.md:17).
So no boss number was changed; every source cell is [?] except the owner's reward rule. The [?] numbers are named in one
place each (`Data.MOBS` hp and enrage, `Boss.PHASE_HP`, `Boss.LEASH_T`), so a sourced value is a one-line change.

## Lair bosses (colossus, serpent, brood: `Data.MOBS`, `boss.gd`, `lairs.gd`)

| Function | Source | Ours (where) | Verdict |
|---|---|---|---|
| HP | [?] | 1500 / 1250 / 1350 (`Data.MOBS`), tier x1.0 / 1.45 / 2.0 | keep |
| HP per squad size | [?] | none: one pool whatever the squad | keep, [?] |
| Phase triggers | [?] | 66% and 33% health (`Boss.PHASE_HP`): each adds or sharpens an attack; damage +10%, cooldown -12%, wind-up -10% per phase (`Boss.dmg`, `cd_k`, `_wind`) | keep, [?]; `--boss-parity-check` |
| Enrage | [?] | 75 s awake (`md.enrage`): damage x1.5, cooldown x0.6, wind-up x0.8, speed x1.25 | keep, [?] |
| Leash distance | [?] | the sealed lair itself: it cannot leave it (`Boss.clamp_in`) | keep, [?] |
| Leash reset | [?] | nobody inside for 12 s (`Boss.LEASH_T`), the sealed party wiped, or the 90 s seal fails (`Lairs.LOCK_T`): asleep in the middle, full health, phase 0, no enrage, adds removed, 8 s calm (`Lairs.reset_boss`) | keep, [?]; `--boss-parity-check` |
| Respawn | [?] | none: a cleared lair stays cleared, also in rolling sessions | keep, [?] |
| Kill XP | [O] 11-10: the last-hit squad takes the XP and the kill bonus; no XP for damage | **was** 260 to everyone in the lair (killer's squad 100%, others 50% / 20% by damage) plus 0.35 XP per point of damage. **Now** 260 (`KillXp.BOSS_XP`) to the last hitter and squadmates within 30 m (`KillXp.SHARE_R`), nothing for damage: ext/combat-xp-last-hit, merged in here | **changed**; `--boss-parity-check`, `--xp-share-check` |
| Kill bonus | [O] same | rolled for the last hitter and dropped where the boss fell: the gear pile (with a Brand for their weapon), treasure, sometimes a key, the perk-orb fan (perks open to them). The kill stat and the lair's "cleared by" are theirs. The Rare Egg lies on the floor for anyone | keep; `--boss-parity-check` |

## Ideas of ours (not built)
- HP that scales with the squads inside; a visible low-HP tell for last-hit steals (counterplay named in DECISIONS 11-10).
