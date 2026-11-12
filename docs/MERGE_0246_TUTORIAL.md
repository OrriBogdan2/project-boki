# 0.24.6 wave 6 (tutorial): merge notes

Branch ext/w0246-tutorial on ext/release-integ-0245 (92df78ce4). Plan: docs/MERGE_PLAN_0246.md (ext/merge-plan-0246).
Net.VERSION untouched (no sync change in the merged set). Save stays v13: tut-move-drills (drills), tut-resume
(TutorialResume.migrate) and tut-xp-hint (XpHints.migrate) each wanted their own v12; their additions ride 0245's
12 -> 13 step, which only adds what is missing. A save already at v13 skips that step, so all three read their
fields with defaults.

Counts (44 rows): 17 merged, 23 held, 4 superseded.

Merged: tut-armour-hint, tut-first-capture, tut-context-tips-rebased, tut-controls-card, tut-first-echo,
tut-first-evolve (brings ext/anim-evolve-moment), tut-first-tumble, tut-hunter-howto-rebased, tut-move-drills,
tut-pick-in-action, tut-resume, tut-skip-check (tip f617c7e8e, which also merges origin/main 88b06b9e7),
tut-try-relic, tut-words-page-rebased, tut-xp-hint, tut-signature-drills, feel-first-cast-warm-rebased (only its
own commits, 70f3b1989; its ext/mc-20261110-0630 merge and the registry fix that merge needed are left out).

## Held / superseded
- SUPERSEDED ext/prologue-canon-2: 0245 already carries the owner's later prologue lines (HOLLOWING/RELICS asserted by prologue_check)
- HELD ext/tut-first-race-rebased: ported onto 0244c's BaseRace (race.json, TimingDrill); 0245 replaced it with the garden BaseRace (base_race.json, TimingBar, solo lap, weekly twists): the practice-lap offer needs a third port
- HELD ext/tut-first-shop: stacked on ext/utilities-shops-rebased f8af39fa2, merged by the ui wave (92739c9a6); merge its one commit after the ui+tutorial combine so the 8-file shops conflict is not resolved twice
- SUPERSEDED ext/tut-glide-double-press: 0245 already teaches 'jump, press %J again' (tutorial banner, Training drill, match tips with the live key); loading tips are tips.json {jump}/{glide} tokens after tut-context-tips; the press-only glider is the feel wave's glide_press_only
- HELD ext/tut-hot-zone-line: built on the old one-island HotZone (contains/bonus_at/paint); 0245 rewrote it on map regions (rarity_bonus, minimap rings, region rows in hot_zone_check): the once-per-save line under the drop map needs a port
- HELD ext/tut-start-here-rebased: 0245 decluttered the Hunter pick (name + role word only, stats on hover; prematch_check asserts two labels per card, prematch_shots rewritten for safe margins); the 'Start here' line and chip tag need a port/owner call against the simplified cards
- SUPERSEDED ext/tutorial-any-starter: 0245 has ext/tut-fight-per-starter (shoot_draw/shoot_melee lines per starter, driver draws/taps blades, per-starter fight foes) on the run-levels tutorial
- SUPERSEDED ext/tutorial-idle-check: the same commit is in 0245 as 5eb5d26dc (same author time and message)
- HELD ext/tut-duel-ring (and ext/duel-ring-online it carries, garden-wave row): built on main d255acbee's Arena/Training Area; against 0245's Training Grounds it conflicts in 12 files incl. main.gd, match.gd, hud.gd, home.gd, arena.gd, export_presets.cfg: an online duel queue port is well over 30 min
- HELD ext/tut-first-games: stacked on ext/tut-first-race (held) and the pre-0245 garden games; 11 conflicts in base_race/seek/shove/volley and boki_rig against 0245's garden games
- HELD ext/tut-dodge-dummy-rebased: built on the old Training Area line (train-moving-dummies-rebased, mc-20261109-2230) that 0245's Training Grounds replaced; 12 conflicts incl. home.gd and vv_fx.gdshader; merge after wave 2 brings that line, or port the Dodge Pen
- HELD ext/tut-summon-station: stacked on ext/tut-dodge-dummy (held) + wisp-summon; 19 conflicts incl. main.gd, net.gd, hud.gd, home.gd, arena.gd
- HELD ext/tutorial-prologue-rebased-rebased: its own work (8105bbed5 prologue panels v3, 4347c61b8 Pell guide) is on 11-06 main and conflicts in 15 files: 0245 has the owner's later prologue lines (prologue_check asserts them), the run-levels tutorial, and Pell is now the Black Market keeper (the guide's name needs a canon call); the rest of the branch is the stale ext/mc-20261108-0830 line
- HELD ext/tut-beat-retry: built on main's old tutorial; 0245's run-levels tutorial already revives a downed player after 3 s and brings the Boki round, and restarting a beat there must also reset TutorialCamps' XP ledger (else a retried camp pays twice) and re-key the retry tips to the camp steps: a port, not a merge
- HELD (owner pick) the short-tutorial / first-hints line, 12 branches: ext/tutorial-beats-7-8-rebased, ext/tutorial-beats-5-6-rebased-rebased, ext/first-hints-check-rebased, ext/hunter-first-hints, ext/tut-first-fuse, ext/tut-dive-hint, ext/tut-wall-kick-hint, ext/tut-first-heartspark-rebased, ext/tut-first-proc, ext/tut-ways-out, ext/tut-belt-hint, ext/tut-hints-blight-camp-box. They all stand on ext/tutorials-cut 37dc18d84 (owner 11-08, decision 0023: match tutorial 22 -> 10 beats, cut steps become FirstTimeHint/MatchHints one-time hints), rebuilt on the rejected ext/mc-20261109-2230 / -0630 / -1030 candidates. 0245 ships the other design: the 23-step run-levels tutorial (owner 11-10, rated 4/10: one ability per level, every ability forced and explained, 1915516a1) plus tut-fight-per-starter. Merging the line replaces that tutorial. Follow-up if the owner keeps 0245's tutorial: port FirstTimeHint + MatchHints + hints.json (no tutorial cut) onto 0.24.6 as one change, then cherry-pick the 9 hint children's own commits.
- ext/tut-text-budget: merged, then reverted. Its --tutorial-text-check rejects 0245's run-levels tutorial lines
  (19 problems), and its farm rewrites drop facts --farm-tutorial-check asserts. The budget needs an owner call.

## Resolutions that pick one side
- Loading tips live in content/rules/tips.json (tut-context-tips), reworded to 0245's double-press glide text.
- Home evolution plays EvolveMoment and EvolveCard (tut-first-evolve) instead of 0245's tween and body glow.
- The Tumble keeps 0245's rush/brace/dodge rig clips; the teach adds its icons and the util1-3 keys.
- The Hob pick keeps 0245's shared first/second Relic offer and role lines. The reel loops attack, the talk
  rules' signature (else preview_slot) and dash. Try only shows on the second pick.
- The Hunter how-to shows on Hob's pick only. 0245's decluttered pre-match cards stay name + role word.
- The farm tutorial is skippable as tut-skip-check ships it (decision 0023). --farm-tutorial-check's
  base_mode-off row now follows that setting.
- The tutorial resumes through 0245's _skip_to (last stop and run-level picks). The outpost run restarts at
  wayout. A scripted run (tut_test) neither resumes nor saves a beat.
- The signature-drill tech emits go next to 0245's ComboMark payoffs. Gunslinger keeps 0245's DashReset (no
  dash refill).

## Suite (headless, one Godot at a time, LP_NUM_THREADS=2, against ext/release-integ-0245 92df78ce4)
`--check` passes, as do the 10 new checks (armour-hint, evolve-moment, move-drills, tips, tut-first-capture,
tut-first-evolve, tutorial-resume, tutorial-skip, words, xp-hint; kit-drill also runs the signature drills) and the
touched ones: tutorial-hud/fight/idle, farm-tutorial, prematch, hob, tumble, echo-steps, keys and hero-title.
Red here and on 0245: `--title-check` (the same 8 rows: headless title scene) and `--hob-check`'s script
error at hob_check.gd:193 (guide.tracker is null). `--tutorial-fight-check` is flaky on the kick row (0245:
juggernaut red once; here gunslinger once, then green). NEW-RED: 0.

## Starter check: the first hour with Lace, Kael and Vex (ext/verify-tut-starters-0246, 2026-11-12)
STACKED on ext/w0246-tutorial e4741341c, plus ext/tut-three-starters 4c79672df (the `--starter=` flag, per-starter
kit drill rows; w0246 lacked it). Both checks take `-- --seed=N` now (`--new-player-flow-check`: the global RNG and
the first expedition's map; `--tutorial-fight-check`: its RNG, default 11). Seeds 1, 2, 3, headless, one Godot at a time.

| `--new-player-flow-check` | seed 1 | seed 2 | seed 3 |
|---|---|---|---|
| Lace (archer) | 0 fail | 0 fail | 0 fail |
| Kael (juggernaut) | 0 fail | 0 fail | 0 fail |
| Vex (gunslinger) | 0 fail | 0 fail | 0 fail |

Each run: prologue, hatch, starter pick, tutorial course, results, farm, Hob's second Relic and the first expedition
to the uplink lift. All 9 teach all 23 steps the kit has, none missed, slowest step 14-20 s.

| `--tutorial-fight-check` (first hit, then reruns) | seed 1 | seed 2 | seed 3 |
|---|---|---|---|
| Lace | 0 fail | 0 fail | 0 fail |
| Kael | 0 fail | 0 fail | 0 fail (1 slow-beats red once: kin step 71 s) / 1 red `kick` once |
| Vex | `kick` row red once, then green | 0 fail | `kick` row red twice, green once; glove stall once (before the fix below) |

Seeds 4, 5 and the default 11 also ran: green, except Lace seed 4 once (glove stall, did not repeat in 10 reruns).

### What stalled, what was fixed
- **Stale check, all 9 flow runs (fixed):** the first-expedition stage looked for a skiff; docks are gone (Ways Out), so
  every starter failed "there is a skiff to take". It takes the uplink now: wait until it can start, hold the console,
  hold the yard, ride the lift. Rivals are set idle and the hit-timer reset there: a rival in the yard stalls the charge
  and a hit breaks the start, both real rules and not what the check is about.
- **Glove step stalled for Kael and Vex (fixed, tutorial data + driver):** after the Boki camp fight the bot walked
  straight at the pickup on the Range isle: into the lookout cliff on the north side, or off the lip of the Lookout
  isle at the bridge head. Seen: Vex seeds 2 and 3, Kael seed 2 (850 s stall). Three waypoints in
  `content/maps/tutorial.json` `course.pickup` (via1..via3: round the cliff, onto the bridge, off it) and the driver
  follows them. A player is not affected (they see the bridge); the stall was the bot's straight line.
- **kit-drill-check after the merge (fixed):** the walk finished the tech step with Lace's own id as "another Hunter's
  tech", and asked every Hunter's dummy to be rigged weak (Vex's rig only). Now it uses another Hunter's id and rigs the
  row for Vex only.
- **Nothing found of another Hunter's key or text:** the flow check teaches every step the kit has with that Hunter's keys;
  the fight check's first line names each starter's own move (draw / step in / shoot); kit-drill-check text rows pass.
  This is not a full text audit of the 23 course lines per Hunter.

### Listed, not fixed
- `--tutorial-fight-check` "every ability used (missing kick)": the wall-kick step ends when the Hunter stands on the
  lookout (`tutorial.gd` wallkick), so the bot can get up without a kick. Seen for all three starters, about 1 run in 4.
  Same flake as noted above for 0245. Fix is a design pick (require the kick, or drop the row): left to the owner.
- Kael seed 3 once: the Boki-camp step took 71 s (usually 15 s), over the check's 30-70 s window for the fight beats.
- Lace seed 4 once: glove stall; not reproduced (10 reruns, seeds 4-9), no position seen.
