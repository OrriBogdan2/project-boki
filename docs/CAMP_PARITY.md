# Camp parity: our monster camps against the source

Tags: **[D]** the source data (briefs/supervive-data: supervive_kits.md, supervive_physics.md),
**[F]** footage and the hero sheets (briefs/hero-ref, ext/hero-ref-footage), **[O]** an owner note in
briefs/DECISIONS.md (wins over the source), **—** the source says nothing.

**What the sources give (2026-11-09):** almost nothing on camps. The data files cover kits, movement
and the practice range, not camps. The footage is training-range kit footage against dummies, with no
camp in any frame or OCR line. The only camp facts:
- [F] camps exist and kills heal some kits: "Heal when you knock an enemy or kill a creep" (juggernaut.md:17).
- [F] XP floats over the plate as a small purple "+17 XP" (HUD.md:112). It shows the size of a single
  grant, not its source.
- [O] Inks drop from a boss of their type, plus rare wild drops (DECISIONS.md:369). Each lair boss drops a
  Rare Egg of its own kin.

So no number below has a source value to match, and **no camp number was changed**. The one fix is the
leash *behaviour*, below. The task treats "chases past the leash" and "resets without healing" as
defects in their own right.

## The table

| What | Ours (where) | Source | Verdict |
|---|---|---|---|
| Aggro radius (idle) | 7.5 m, same height ±2.5 m, Hunters in grass skipped beyond 2.6 m (`Mob.AGGRO_M`) | — | keep |
| Target switch radius (fighting) | 11 m around the monster (`Mob.CHASE_M`) | — | keep |
| Leash distance | 13 m from its camp spot (`Mob.LEASH_M`) | — | keep the number |
| Leash: hard stop | **was** a re-target only: past 13 m it looked for anyone within 11 m *of itself* and kept chasing, so a backing Hunter could pull it without limit. **Now** it drops the fight at 13 m (14 m at most, with one lunge: `--camp-check`) | — | **fixed** |
| Leash reset | **was** one frame of walking home, then an idle stroll at 0.3x speed that could pick a fight again on the way, with no heal. **Now** it walks straight home at full speed, ignores hits and Hunters on the way, and heals to full on arrival (`HOME_M` 1 m; after `HOME_T` 6 s it heals where it stands) | — | **fixed** |
| Respawn | Normal expedition: cleared camps stay cleared. Rolling session: back after 240 s with nobody near (`Rolling.CAMP_RESPAWN`) | — | keep |
| HP per tier | base x1.0 / 1.45 / 2.0 (Meadow / Dusk / Hollow, `Data.TIERS[].mob`) | — | keep |
| Damage per tier | x1.0 / 1.27 / 1.6 (`Mob.dmg_mult` = 1 + (tier - 1) x 0.6) | — | keep |
| Base HP / damage | Skitter 34 / 9, Spitter 44 / 11, Puffbomb 26 / 16, Sentinel 70 / 8, Brute 170 / 24, Watcher 820 / 30, bosses 1250-1500 / 18-26 (`Data.MOBS`) | — (source damage runs ~10x ours, e.g. 169 per boulder in breah.md; it has no creep numbers) | keep |
| XP | 0.35 XP per point of damage dealt to a monster (Hunters: 0.6), and a boss pays 260 to its killers' squad (50% / 20% to other squads in the lair) (`Match` damage hook, `Lairs`) | [F] grants are small floaters ("+17 XP") | keep |
| Loot | gems = `gems` x 3 x tier loot (1 / 1.75 / 2.75); elites 60% for 25 armor; seeds 12% (Brute 35%); Brute 25% valuable; Watcher a treasure, 50% for a Soul Ember and always a Rift Key; elites 6% for a Rift Key; Brute 50% / Watcher 100% for a perk orb; gear tables in content/rules/gear.json | [O] Inks from a boss of their type, Rare Egg per lair boss | keep (Inks: see below) |
| Stagger windows | elites and bosses (purple ring; `Mob.STAGGER_DMG` 2.5x) | — (the code comment calls it the source's; not in briefs) | keep |

## Left open
- When the source data gains camp numbers (a camp capture or a wiki pull), fill the Source column and
  tune `Data.MOBS`, `Data.TIERS` and `Rolling.CAMP_RESPAWN` against it. Today that would be guessing.
- Ink drops ([O] 369) belong to the Boki-item work, not this table.
- Lair bosses (`boss.gd`) fight inside a sealed lair and have no leash. The rule above covers camp monsters only.
  Blight monsters hunt by sound and have no camp.
