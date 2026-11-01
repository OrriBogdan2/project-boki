# Handoff: work moved from the main session

The main session now keeps only two jobs:
- owning `main` (merging and integration);
- building the Boki system (Merge on R, plus the G, C and downed-Boki commands).

Everything below moves to the other session.

**Rules for all of it** are in `AGENTS.md` and `docs/GAMEDEV_CHECKLIST.md`, both on main after sync56:
- god-file budgets enforced by `tools/health.py`;
- a design note in `docs/decisions/` before touching core systems;
- targeted checks while iterating, then the full suite once;
- our own names and text throughout.

**Delivery:** push a branch, say it's ready, and the main session merges it.

**Reserved for the main session's Boki work:**
- Keys G, C, R and F: no other ability may bind them.
- Files: `scripts/match/kin.gd` command and recall paths, `kin_merge.gd`, `kin_companion.gd`, `scripts/kin/*`, and the Hunter R/ult input.

---

## 1. Owner notes batch: branch `feelfix` (9 of 10 done, item 7 partial)

**Goal:** the owner's playtest notes from Nov 1 afternoon. `docs/HANDOFF_feelfix.md` on the branch has the per-item detail.

**Done:**
- no web/Claude mentions
- new dash pips
- walk off ledges
- characters lean back 20° to face the camera
- abyss tint matched to the reference footage (off while rising)
- Orchid Isle bridge from real edges (`--farm-start-check`, 50 seeds)
- class switch on the farm (Hero button, J key)
- secondary keybinds (ult R / X, drop-separate Z, Arena reset Backspace)
- a safe Demo-match landing for the first minute

**Partial (item 7, water):**
- Built so far: animated ponds, wade and swim, Boki paddling, `--swim-check` 7/7.
- Left to do:
  - re-run `--farm-start-check` and `--home-build-check` now that ponds are walkable;
  - check the match map (The Hollow Crown) for flat blue areas;
  - polish the water's look.

**Before merging:**
1. Merge `main` (sync56) into `feelfix`.
2. Run the full suite once. `--arena-check` and `--record-check` may still expect the old X reset key, so update them to Backspace.
3. Look into a single random `--farm-start-check` failure on a new-save seed.

**Done means:**
- all checks pass, including `--swim-check`, `--keybind-check` and `--hero-check`;
- before/after screenshots exist for the dash pips, character lean, abyss tint, water and the bridge.

## 2. Weapons and gear (SUPERVIVE model): not started, suggested branch `ext/gear`

**Owner decision:** one signature weapon per hero, with no weapon pickup or swapping in matches. Rarity (Common to Legendary) moves to gear slots: armor, boots (movement perks), gloves (the existing 23 actives) and a utility kit. Instead of replacement weapons, you get in-run weapon upgrades: power pickups and level-up perks.

**Loot:**
- Chests, the Blight and bosses drop gear and upgrades.
- Bosses drop fewer items, all high value.
- Extracted loot becomes farm materials, plus gear for the next run.

**Files:**
- `scripts/core/data.gd` (weapons, RARITY)
- `content/weapons`, `content/gloves`
- the loot tables (chests, lairs, Blight drops)
- `scripts/match/hunter.gd` (weapon state)
- `scripts/ui/hud.gd` (weapon panel)
- bots, the economy, kit cards (`content/archetypes/*.json` `weapons` lists)

**Net:** bump the version.

**Done means:**
- a new `--gear-check`;
- the full suite passes;
- screenshots of the gear UI and of loot drops.

## 3. Class unlocks and the "class" rename: not started, suggested branch `ext/classes`

**Owner decisions:**
- Every player-facing "archetype" becomes "class".
- A new save picks 1 starting class from a starter set of 3. Suggested: Thief (light), Gunslinger (medium), Juggernaut (heavy); confirm with the owner.
- The rest unlock through play: account XP plus a clear goal per class on a Classes screen (e.g. extract twice, reach level 6, beat a boss), with a reveal moment.
- Locked classes stay playable in the Arena and Training Grounds.
- Existing saves keep everything unlocked.
- The farm class picker from `feelfix` already greys out locked classes, so hook into it.

**Done means:**
- a `--class-unlock-check`;
- the full suite passes;
- screenshots.

## 4. Farm building pass: not started, suggested branch `ext/farmbuild`

**Owner decisions:**
- A new farm starts with only a house, a crop patch and a cooking pot. Every other building, station, decoration and incubator slot unlocks through farm level, materials from runs and milestones (first extraction, first boss, tame 3 Boki). The build menu shows locked entries with their requirement.
- Upgrade tiers L1 to L3, each with a visible model change.
- **A real build mode:**
  - category tabs;
  - costs shown with material icons;
  - snapping grid with a footprint outline;
  - rotate, and move or pick up placed buildings;
  - place pop with dust and sound;
  - reasons shown when a spot is invalid.
- **Construction takes Boki labour and materials** (wood, stone, coals, fibre) plus a small gem cost. Placing a building creates a site with scaffolding and a progress bar. Assigned Boki walk over and build it, faster with a better building skill. Upgrades work the same way.
- Richer original building models, paths, fences and decor.
- Old saves keep what they've placed.

**Files:** `scripts/home/home_build.gd`, `home_work.gd`, `home_econ.gd`, `HomeLayout`, `scripts/core/save.gd` (migration).

**Done means:**
- a `--build-unlock-check`;
- `--farm-start-check`, `--home-build-check` and `--economy-check` pass;
- before/after screenshots.

## 5. Cleanup and refactor pass: not started, suggested branch `ext/cleanup`

**Goal:** pay down the debt listed in `docs/DEBT.md` so new features stop adding to it.

**Steps:**
1. Move the ~50 checks out of `main.gd` into `tools/<name>_check.gd` behind one registry. Fix the `--airheal-check` fall-through on the way.
2. Merge `content/abilities` and `content/abilities_v2`, and `content/kin` and `content/kin_v2`, into one version each, then delete the old ones.
3. Fix the stale text the wiki found:
   - the README facts
   - "Archetype" in Settings
   - evolved Boki names built from old internal roots (`evo.gd` ROOTS, and the 3 missing rare species)
   - retired abilities still mentioned in data
   - unused `Data.MATCH`/BUILDINGS/ISLES
   - stale comments and doc paths
4. Start splitting the god files by system (match, home, hud, main), then lower the budgets in `tools/health.py`.
5. Apply the systems and performance parts of `docs/GAMEDEV_CHECKLIST.md`: pool projectiles and FX, use a spatial grid for target queries, and time-slice bot thinking.

**Avoid conflicts:** do this after `feelfix` merges, and coordinate with the main session so it doesn't touch the Boki files listed above.

**Done means:**
- `tools/health.py` reports lower budgets;
- the wiki `--check` is green;
- the full suite passes;
- there are no behaviour changes, confirmed by the same check results before and after.

## 6. Hero roster ports (10 heroes): already with the other session

These are the inspiration-based kits on branches `ext/heroes-*`. They follow the latest update: R is the Boki Merge, so fold loop-critical original ults into the kit, and the downed-Boki rescue is just running into it. For the Thief/Juggernaut follow-up, see `docs/heroes/HANDOFF_kits2.md` on branch `kits2`.

## 7. Second-account branches already in flight

`polish`, `rolling`, `ext/fixes`, `ext/economy`, and the heroes. Merge `main` (sync56) into each before reporting it ready. sync56 changes the default map (The Hollow Crown) and sets Net.VERSION to 0.8.0.
