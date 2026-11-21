# Egg rules (owner rule 11-16)

Eggs only ever hatch the first form of a Boki line, and some Boki never come from an egg.

- **First form.** `Evo.base_form(sp)` walks `content/rules/evolve.json` back to the first form of a line that the
  game has data for (a roster name with no data, like `barokit`, is skipped, so `sentrikat` is its own first form).
  `Data.egg_species(sp, rng)` is the one door: every egg is made through it (`Loot.rare_egg`, `Incubator.add`,
  `Heart`/`HeartRaid` eggs, the Black Market, nest eggs and the Locket in `NestItems.lay`) and every egg is hatched
  through it (`Care.hatch_rare`, `Care.breed`), so an old saved egg of a later form hatches the first form too.
  `Incubator.ensure` rewrites old saved eggs once on load, and the nest egg does the same when it is read.
- **Never from an egg.** `"no_egg": true` in `content/kin_home/<first form>.json` (data, not code) takes the whole line
  out: `Data.no_egg(sp)`. Today: `cairnback`, `zephyrak`, `hivara`, the three legendaries (also the only
  `"rare": true` kin). `Data.egg_species` rerolls such an egg from `Data.egg_pool()` (first forms that may hatch)
  by rarity tickets (`BokiModes.draw`). Content has no other unique, boss-only or charm-tier Boki.
- **Breeding.** Two `no_egg` parents get no egg: `NookRules.pair_why` says "...never come from an egg". With one
  legendary parent the egg takes the other parent's line.
- **Check.** `--egg-rules-check` (`tools/egg_rules_check.gd`).
