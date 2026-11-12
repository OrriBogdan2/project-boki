# Camp parity: Hunter damage vs monsters

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). Question: does the source's kit damage change against camp monsters (bonus vs monsters, reduced vs bosses, DoT or pet rules)?

**Finding.** `briefs/supervive-data` (supervive_kits.md, supervive_physics.md, kit_comparison.md, PHYSICS_PARITY.md) lists **no** PvE damage modifier and no creature hp or damage. Every number there is a hit on "enemies"; the only monster mentions are kill hooks (a minion kill heals, a minion kill while Chilled shatters), not damage scaling. The footage briefs (briefs/hero-ref/*.md, text read, frames not re-watched) list none either; their one monster line is Juggernaut's heal on a creep kill (juggernaut.md), already in. So nothing is sourced, and **no modifier was applied**: no content changed, clear times are unchanged (`--camp-clear-check` prints them; a 2026-11-11 run matched 66 of the 72 cells in EXPEDITION_SPEC "Camp clear pacing" exactly and all six spread lines; only archer's six cells differ (by 0.1-1.2 s; cause not traced, the other 11 Hunters repeat exactly)). Tags: `[?]` unsourced, left at x1.0; `[D]` data says so; `[ours]` our own rule.

**Ours today.** Hunter kits hit `Mob` through the same path as a Hunter (`Ent.hurt`), same damage, no PvE multiplier. `scripts/match/mob.gd` `hurt` adds two rules of ours: x`STAGGER_DMG` while staggered, and a stagger-window ability hit adds max-hp % (`stag_k`) and staggers `[ours]`. Boss and lair-ward rules are in `scripts/match/lairs.gd`, also ours. Kill hooks that already match the source: Juggernaut heals on a monster kill (`juggernaut_kit.gd`), Rimewright shatters on a kill while Chilled (`rimewright_kit.gd`) `[D]`.

**If a modifier is found later**, add one `pve_mult` entry per kit in `content/archetypes/<id>.json` and apply it in `Mob.hurt` by the hit's `ab` slot; do not build it before a source exists.

| Hunter | Slot | Ability (ours) | Source modifier vs monsters | Ours vs monsters | Tag |
|---|---|---|---|---|---|
| archer | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| archer | RMB | Heavy Shot | none listed | same as vs Hunters, x1.0 | [?] |
| archer | E | Hail Wall | none listed | same as vs Hunters, x1.0 | [?] |
| archer | R | Starpiercer | none listed | same as vs Hunters, x1.0 | [?] |
| ashwick | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| ashwick | RMB | Cinder Shot | none listed | same as vs Hunters, x1.0 | [?] |
| ashwick | E | Furnace Cloak | none listed | same as vs Hunters, x1.0 | [?] |
| ashwick | R | Flue Flight | none listed | same as vs Hunters, x1.0 | [?] |
| bulwark | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| bulwark | RMB | Aegis | none listed | same as vs Hunters, x1.0 | [?] |
| bulwark | E | Mending Ground | none listed | same as vs Hunters, x1.0 | [?] |
| bulwark | R | Faultline | none listed | same as vs Hunters, x1.0 | [?] |
| dolm | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| dolm | RMB | Quakefall | none listed | same as vs Hunters, x1.0 | [?] |
| dolm | E | Stone Row | none listed | same as vs Hunters, x1.0 | [?] |
| dolm | R | Basalt Spine | none listed | same as vs Hunters, x1.0 | [?] |
| dredge | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| dredge | RMB | Abyssal Hand | none listed | same as vs Hunters, x1.0 | [?] |
| dredge | E | Anchor Drop | none listed | same as vs Hunters, x1.0 | [?] |
| dredge | R | Brass Broadside | none listed | same as vs Hunters, x1.0 | [?] |
| gunslinger | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| gunslinger | RMB | Burr Charge | none listed | same as vs Hunters, x1.0 | [?] |
| gunslinger | E | Longneedle | none listed | same as vs Hunters, x1.0 | [?] |
| gunslinger | R | Cinderfall | none listed | same as vs Hunters, x1.0 | [?] |
| juggernaut | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| juggernaut | RMB | Smash | none listed | same as vs Hunters, x1.0 | [?] |
| juggernaut | E | Warchain | none listed | same as vs Hunters, x1.0 | [?] |
| juggernaut | R | Gilded Riposte | none listed | same as vs Hunters, x1.0 | [?] |
| mage | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| mage | RMB | Storm Rod | none listed | same as vs Hunters, x1.0 | [?] |
| mage | E | Skycall | none listed | same as vs Hunters, x1.0 | [?] |
| mage | R | Kitefall | none listed | same as vs Hunters, x1.0 | [?] |
| ostra | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| ostra | RMB | Shard Snap | none listed | same as vs Hunters, x1.0 | [?] |
| ostra | E | Brimseed | none listed | same as vs Hunters, x1.0 | [?] |
| ostra | R | Nightwell | none listed | same as vs Hunters, x1.0 | [?] |
| rimewright | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| rimewright | RMB | Ice Spear | none listed | same as vs Hunters, x1.0 | [?] |
| rimewright | E | Rink Wall | none listed | same as vs Hunters, x1.0 | [?] |
| rimewright | R | Rimelock | none listed | same as vs Hunters, x1.0 | [?] |
| tender | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| tender | RMB | Burrseed | none listed | same as vs Hunters, x1.0 | [?] |
| tender | E | Hearthlight | none listed | same as vs Hunters, x1.0 | [?] |
| tender | R | Hearth Call | none listed | same as vs Hunters, x1.0 | [?] |
| thief | LMB | weapon | none listed | same as vs Hunters, x1.0 | [?] |
| thief | RMB | Bola | none listed | same as vs Hunters, x1.0 | [?] |
| thief | E | Shadow Knife | none listed | same as vs Hunters, x1.0 | [?] |
| thief | R | Encore | none listed | same as vs Hunters, x1.0 | [?] |

**Ideas of ours (not built):** a slow-kit damage bonus vs monsters to narrow the 4-12x clear spread; see EXPEDITION_SPEC "Camp clear pacing".
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
| Leash distance | [?] | the lair's walls: it cannot leave (`Boss.clamp_in`) and targets only foes inside; woken with someone inside, the gate seals them in with it (`Lairs.lock_in`, `_hold_seal`) | keep, [?] |
| Leash reset | [?] | sealed fight: at once when the sealed party is all down or out, or when the 90 s seal runs out (`Lairs.LOCK_T`). Woken from outside (no seal): nobody inside for 12 s (`Boss.LEASH_T`). Either way: asleep in the middle, full health, phase 0, no enrage, adds removed, 8 s calm (`Lairs.reset_boss`). **Fixed:** the reset kept a phase roar's armour (x0.15 damage for up to 1.6 s into the next fight) and the empty-lair clock (woken from outside again, it slept on the first frame) | keep, [?]; **fixed**; `--boss-parity-check` |
| Respawn | [?] | none: a cleared lair stays cleared, also in rolling sessions | keep, [?] |
| Kill XP | [O] 11-10: the last-hit squad takes the XP and the kill bonus; no XP for damage | **was** 260 to everyone in the lair (killer's squad 100%, others 50% / 20% by damage) plus 0.35 XP per point of damage. **Now** 260 (`KillXp.BOSS_XP`) to the last hitter and squadmates within 30 m (`KillXp.SHARE_R`), nothing for damage: ext/combat-xp-last-hit, merged in here | **changed**; `--boss-parity-check`, `--xp-share-check` |
| Kill bonus | [O] same | rolled for the last hitter and dropped where the boss fell: the gear pile (with a Brand for their weapon), treasure, sometimes a key, the perk-orb fan (perks open to them). The kill stat and the lair's "cleared by" are theirs. The Rare Egg lies on the floor for anyone | keep; `--boss-parity-check` |

## Ideas of ours (not built)
- HP that scales with the squads inside; a visible low-HP tell for last-hit steals (counterplay named in DECISIONS 11-10).
