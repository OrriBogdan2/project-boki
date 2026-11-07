# Checks

The game tests itself through command-line hooks in `scripts/main.gd`. Run them headless from the
project folder:

```
godot --headless --path . -- --check
godot --headless --path . -- --simtest --seed=5
```

Most print `PASS` / `FAIL` lines and a final `DONE` or `failures: N` line; `ship.sh` greps for
`FAIL`, `SCRIPT ERROR` and non-zero failure counts. Checks never touch your real save. A few need a
renderer (marked *window*): run them under `xvfb-run -a godot --path . --rendering-driver opengl3`
with a throwaway `XDG_DATA_HOME` so the shader cache starts cold.

Before a pull request, run at least `--check` and `--simtest`; if you touched Boki or abilities, also
`--grammar-check`. `ship.sh` runs `--check`, the checks you name, and always `--mantle-check`,
`--drop-check`, `--extract-check`, `--boss-check`, `--duel-check`, `--revive-check`, `--life-check`,
`--economy-check`, `--home-build-check` and `--simtest`.

## Every check

| Hook | What it asserts |
|---|---|
| `--check` | Every script under `scripts/` loads and compiles |
| `--grammar-check[=<folder>]` | Every Boki grammar file under `content/` (or the folder given) parses with no structural errors |
| `--grammar-runtime-check` | Each Boki's E and auto ability run from their parts; diminishing returns and stun immunity; no ability triggers itself; caps; slot locks and auto-cast; carry modes; owner bonuses; the merge unlocks, runs out and cools down |
| `--ability-check` | Gloves, weapon utilities, Boki abilities and dashes do what they say (drags, walls, reflects, parries, knock-ups, tethers, roots, swaps, pierces...), every ability runs without errors, and rank 3 is stronger and faster than rank 1 |
| `--archetype-check` | Every class kit in a flat arena: each dash, passive and resource, RMB variants, E, R (locked until level 6), the bonded R, controls, weapon locks, Boki infusion, feel |
| `--kit-combo-check` | The cross-ability interactions (E + RMB chains, resets, refunds); also runs inside `--archetype-check` |
| `--arena-check` | The Arena boots with its tools, dummies take and show damage, reset and swaps work, the kit card builds for every class, the training area works |
| `--hunter-unlock-check` (alias `--class-unlock-check`) | Hunter unlocks and mastery: Vex as the one starter and the second Relic (Kael, Meeko or Cinder) waiting by the farm portal after the first expedition, no Relic pick before the egg, challenge-only Hunters never offered, each Hunter's challenge (tier, target, measurable stat) making it ready and hold to unlock opening it (a partial hold cancels, the reveal plays), mastery goals counted per Hunter with cosmetic-only rewards (no stat or ability anywhere in the progression data), glider skins changing no handling, the feats HunterFeats records, save migration keeping every Hunter a save had unlocked or played, the viewer showing every ability as a clip of it working (keys from the bindings, one short line each, no story or gender text), the glider pick, locked Hunters playable in the Arena (its Training dummy) and practice picker |
| `--weapon-check[=<id>]` | Every weapon against a standing target at a few ranges (taps and charges), printing the DPS it really lands |
| `--weapon-clip-check` | No held weapon dips into the ground in any pose, on any class |
| `--pickup-check` | A picked-up weapon arrives with a full magazine and no reload running, from any source |
| `--balloon-check` | The hit marker is the real hitbox, for every class, below a lip, gliding and mid-hop |
| `--hold-check` | Hold animations keep their pose while refreshed, let go cleanly, and survive the network snapshot |
| `--move-feel-check` | Movement, jump, glide, feathering, drop and camera timings match `docs/MOVEMENT_FEEL.md` |
| `--mantle-check` | Ledges you mean to climb, you climb; ledges you don't, never grab you |
| `--wallhug-check` | Pressed against an island's side from the abyss, you're caught instead of sinking |
| `--abyss-check` | Islands are solid all the way down and the abyss is short: you catch ledges falling or knocked in |
| `--obstacle-check` | Walking past and round trees and rocks slides cleanly with no sticking or pull |
| `--airheal-check` | Heals and abilities work in the air; drinking in the drop folds the glider and is a risk |
| `--train-check` | Riding the sky train (moving with the car, its edges hold you) and being hit by its front |
| `--perch-check` | Each perch can be reached from its updraft chain |
| `--mapcheck` | Generated maps: every island reachable from every other (200 small, 40 big) |
| `--mapcheck-authored` | The authored map over 20 seeds: every island reachable, every point of interest on solid ground, nothing walled off |
| `--biome-check` | An expedition on the authored map: what each biome spawned, rarities and hazards, then a minute of play |
| `--drop-check` | The planning phase, pings, squad formation, passing the lead, separating, and randomised spawns |
| `--extract-check` | Every way out: skiff (waves, rival boarding), rift hatch (keys, losing and looting a key), uplink (stalls, completes, the lift) |
| `--boss-check` | Lair locks (dial, runes, ward stones), the ward, each boss's phases and enrage, the Rare Egg from the pack to the Incubator; bots can work a dial |
| `--boss-ttk` | Balance probe: a bot squad fights each boss for real and prints the time to kill |
| `--life-check` | The down, death and revive rules step by step, with hunters placed by hand |
| `--revive-check` | A bot squadmate reaches a downed player and finishes the revive in time, round walls and edges |
| `--base-check` | Basing to a teammate: a clean channel arrives weakened; a hit interrupts it |
| `--truce-check` | Truce offers and answers, no targeting during a truce, betrayal breaks and marks, shared uplink yards |
| `--duel-check` | The duel room: autopilot against the sparring bot through Hunter, behaviour, glove and difficulty changes |
| `--blight-check` | The Blight's strength curve, Warden posts, the landing grace period, noise drawing Skitters, a level-1 hunter can win early |
| `--raid-check` | Raid conditions roll fairly and repeatably, practice modes stay clear, sight shrinks, the armor kit key works |
| `--bot-sanity-check` | Over seeded matches, no bot spins, spams jump or dash, or hangs in the air |
| `--teammate-check` | Your Boki as a teammate: keeping close, callouts, caring, the tutorial guide |
| `--kinbox-check` | The farm cap and the Burrow: moving, sorting, releasing, overflow from old saves, mutation inheritance and odds |
| `--unique-check` | Every Boki is its own: deterministic rolls, the bell curve and tails, inheritance, ids, save migration, size effects |
| `--iv-check` | IV rolls, stable IVs for old saves, breeding passes 3 of 5, the Rare Egg floor, caps, save round trip |
| `--incubator-check` | Rare Eggs in the Incubator: cradles, buying more, warming (Ember Boki, coals), hatching |
| `--hatch-check` | Hatching is a quiet, personal moment: the Boki wakes, looks round and at you, no bursts or flashes; then the first Relic: Vex's Relic drifts to you, "Put on the Relic" (the interact key) makes you Vex, and her ability clips fit a 1280x720 screen |
| `--economy-check` | Full backpack swaps, smart loot, extracting fills the armory, feeders feed (also while away), starving to a grave, the Soul Shrine |
| `--work-check` | Boki at work: knacks, mutation bonuses, old saves, jobs from the farm's state, priorities and pins, real output |
| `--farm-start-check` | A new save's farm start: placing the essentials, chopping and mining, materials paying for buildings, assigned Boki working, old saves |
| `--home-build-check` | Build mode: placing, turning, moving, storing, refusing bad spots, save and reload, migration, expanding |
| `--pack-ui-check` | The backpack windows take real mouse clicks |
| `--title-check` | The title screen builds with the right menu, tagline, key art and frame budget |
| `--record-check` | Recording mode hides and restores the HUD and debug nodes correctly |
| `--hair-check` | Every race and hair style grows a mesh that shows outside the head and touches it (nothing hidden or floating) |
| `--speak-test` | Prints how Boki talk at each stage |
| `--simtest [--seed=N]` | A whole match on autopilot, printed; must end without script errors |
| `--hitch-check` *(window)* | A seeded expedition through loading, drop and landing; fails on a stalled frame or a late shader compile |
| `--load-check` *(window)* | The same, stopping at the reveal to judge the loading screen |

## Tooling flags

Not checks, but useful: `--loop-tour[=<class>]` (the core loop with a screenshot per step),
`--perf-probe`, `--meshtime`, `--gentime`, `--map-bake=<png>`, `--grammar-vocab` (prints the grammar
vocabulary as Markdown), the galleries (`--arch-lineup`, `--mob-gallery`, `--prop-gallery`,
`--flora-gallery`, `--pack-gallery`, `--hair-gallery`, `--map-overview`), and many `--*-demo` flags for
screenshots. Start-up shortcuts: `--match`, `--arena`, `--training`, `--duel`, `--tutorial`,
`--sandbox`, `--demo-match`, `--fresh`, `--skip-tutorial`.

## Adding a check

Put the logic in `tools/<name>_check.gd` (a `RefCounted` with `run(main)`), add a hook in
`scripts/main.gd` next to the others, print `PASS` / `FAIL` lines and a final summary, quit when done,
and never write the real save. Add it to this page and, if it should gate shipping, to `ship.sh`.
