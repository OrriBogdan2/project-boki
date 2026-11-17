# Hero brief update 1 (owner, Nov 1). Applies to all 10 heroes and to work already in progress.

## 1. No R ultimates
In Project Boki, R is the Boki Merge (your creature fuses with you; the creature defines the merged form, R effect and ability changes while merged). The main session builds Merge. Do NOT build an R for any hero, and remove any R you already built.

For each hero, decide whether its source ultimate is central to the kit's loop:
- Central (it resets on a knock, refreshes the passive, enables the combo): fold it into the kit as a rank-3 upgrade, a passive trigger, or an empowered version of another ability.
- Flavour: drop it.
Report the choice per hero with one line of reasoning. The kit must still feel complete without R.

## 2. Boki system (main session builds it; don't build it, don't conflict with it)
- G tap throws the Boki (landing staggers), G again recalls it (hits along the path), hold G toggles hold-spot/follow.
- C is the Boki's own ability, cast from where the Boki is. R is Merge.
- A downed Boki stays where it fell; the player rescues it by running into it (short scoop animation, no key), or it recovers on its own after ~15-20 s.
- Keep G, C, R and F free of hero abilities. Hero slots are LMB, RMB, Shift, Q, E and the passive.

## 3. Animations
Every ability gets its own readable animation on the hero in our procedural system (`scripts/match/hunter_anim.gd`, the KMOVES layer the main session added for Thief/Juggernaut): an anticipation pose, a strong impact pose timed to the hitbox, and follow-through. Design the poses fresh from the ability's function; don't copy any game's animations or character look. Save a frame strip per ability in your shots folder (one Godot run that captures several frames, e.g. --shot-times).

## 4. Research first
For each hero, cross-check several sources before building: wiki ability pages and upgrade tables, patch notes (later changes to timings, cooldowns, combos), and written guides or combo breakdowns. Build from the latest version of the kit. Gameplay facts only; write everything in your own words. Include a short research summary per hero in `docs/heroes/<id>.md`: sources (URLs), where they disagreed, which version you chose.

## 5. Kit interactions
List every cross-ability interaction from your research (one ability cast during another, dash cancels, resets on knock, passive triggers). Implement each one, add a check that scripts each combination and asserts the right variant fires (e.g. `--<id>-combo-check`), and include a combinations table in your report and in the hero doc.

## 6. Rules
Pull origin/main first. If `AGENTS.md` and `docs/GAMEDEV_CHECKLIST.md` exist, read and follow them (they may land on main shortly; re-check when you next merge main). Highlights:
- Kits go in `scripts/arch/kits/<id>_kit.gd` + `content/archetypes/<id>.json`.
- The big files (match.gd, home.gd, main.gd, hud.gd, hunter.gd, models.gd, world.gd) must not grow beyond a few wiring lines. If `tools/health.py` exists, run it; it enforces this.
- Run only targeted checks while iterating, then the full suite once on the final commit.
- Player-facing names, art and text are our own; never use the source heroes' names in the game.
