# A fresh player's first hour in the Boki base

DECISIONS 11-09/11-10: a player can enjoy the game only raising, breeding and competing with Boki, and the garden
core is the default for everyone. This is the review of that hour on the 0.24.5 garden line (`ext/integ-garden-0245`).

## How it was run

`--garden-day-check` (`tools/garden_day_check.gd`) starts a new save as the hatch leaves it (one starter Boki, the
match tutorial skipped, `base_mode` on) and plays one hour at home: feed, pet, play with a toy, adopt a second Boki,
run The Dash, pair two Boki, hatch the egg. Each step uses the button or prompt the screen shows (the Boki card's
Feed, the build bar, the market's Adopt, the Dash prompt, the Nook's Pick and Pair, the nest prompt). Where the
screen cannot do it the step logs `GAP` or `LISTED` (known, in the list below) and takes a shortcut so the hour
goes on. Farm time runs in 0.25 s steps like `--garden-soak`; the egg's unix-time clock is aged to match.
`--shots-dir=<dir>` saves one image per step: `jobq submit --needs gpu --tree <tree> --out shots -- --garden-day-check
--shots-dir=shots --size=1280x720`. Four such jobs were lost (workers rp1-2 and rp2-2 restarted, three attempts each), so
there are no shots yet. Never touches the real save.

Time to the first egg: **never from the screen in an hour**: with the level and friendship shortcuts the egg is laid
at 3 minutes and hatches 10 minutes later. The real wall is levels (below).

## Fixed on this branch (two blockers; the third below, the wood gate, is as bad and waits on an economy call)

1. **A Boki raised at home could never level, so the Nook never opened.** Since written, main fixed it its own way:
   `scripts/home/garden_xp.gd` pays XP for feed, pet, fetch and the training drill (farm-garden-xp-live). The branch's
   own XP (games 8/15/45, first care of a kind 3, journal line, "+N XP" on the result card) was dropped in the merge
   with main as redundant for care and unpaced for games; the alternative is `GardenXp.played` called from
   `GardenPrizes.settle`, after `tools/garden_pace_check.gd` is re-run with it. The Dash pays no XP today.
2. **No way to a second Boki from the base.** The Shelter (the only place to adopt a stray) opens at market stall
   level 2, and the stall says "Upgrade the stall (build mode, Upgrades)", but the base's build bar has no Upgrades
   tab. The Dash and the Nook both need two Boki. Fix: `Shelter.open()` (level 2, or base_mode), used by the market
   tabs and by adopt / give up. Check row: "a stray adopted at the Shelter by the stall".

## Listed, not fixed (ranked)

1. **The Nesting Nook and the Training post (the Dash's post) cannot be built in the base: worst of the rest.**
   A fresh island has neither. The Nook costs 60 gems and 8 wood; the post 35 gems and 6 wood (the site cost shows
   10 gems, 8 wood, 2 stone). `base_mode` has no axe or pickaxe and no wood on sale, so wood is 0 for ever: no Dash and
   no egg, whatever the XP. The run placed both with a test helper. Suggested fix (an owner call on the economy):
   in `base_mode` price wood and stone in gems at one rate in `farm_build.json`, or give both as starters.
2. **Feed has nothing to feed (first minute).** The tutorial hands out food into the bag but the Feed panel reads
   the crop shelf: "Nothing to feed it. Harvest crops, or buy kibble and buns at the market stall." Fixed on
   `ext/tut-garden-fresh` (8f3c0180a, `FarmTutorial.give_food`); not on this line.
3. **Level pace.** Grown is 2800 XP. At the design numbers an active day is about 150 XP, so the first egg is about
   19 days away; the first Boki and the second must both be Grown. The balance pass (garden_sim.json `proposal`:
   per-level 50, flat from 20) is the owner's call. Suggestion: a "Grown in about N days" line on the Nook intro.
4. **The Nook says "LV 5 NEEDED"** on a tile while the rule is level 8 (`home.gd` `_pair_short`): a stale number.
5. **Friends gate with no hint.** After the Dash the Nook says the pair "need to be friends"; nothing on screen says
   how bonds form (play and nap together) or shows the bond. Suggestion: a bond line on the Boki card.
6. **Old-farm text at arrival**: "Hob will show you around", "F Talk to Hob" (fixed on `ext/tut-garden-fresh`).
7. **The egg's prompt** says "It hatches after your next expedition" with no word of the 10 minutes at home.
8. **`farm_build.json` `base_mode` is still `false` on this line.** A fresh player gets the old farm unless
   `ext/farm-garden-default` (eb8588e64) is merged; the run switches it on itself.
9. **Jargon** on the first Boki card: nature, farmhand, Boki Burrow, Partner, Work elements (see the first-minute
   findings on `ext/tut-garden-fresh`, docs/ONBOARDING_GARDEN.md).

## Journal

Every cause the run used shows on the Boki card after the fixes: meal, petting (first care of the day), the toy
(fetches), the Dash (win or loss), XP and levels. Not in the journal: a bond forming between two Boki.

## Notes from merging onto main (2026-11-12)

On main the day check lists, rather than fails on: the Hob prompt wins over the Boki's own beside the start spot (pet
step); feed, pet and Dash lines are not in the journal (main's XP grants write none; the branch's did); the Nook is
out of reach in an hour (level 1 with 2 XP after the hour; the check's own "first egg" row is its test helper).
The Shelter fix and `Shelter.open()` are unchanged. XP for games stays the open design question above.
