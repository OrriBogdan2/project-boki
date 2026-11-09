# Wisp combat tutorial (spec)

Decision: briefs/DECISIONS.md 2026-11-09 "Soul-linked Boki". Spec only; no game code changed. Builds on `ext/tutorials-cut`
(8 banner steps, `content/rules/tutorial.json`, `Tutorial`, `TutorialDrive`, `TutorialHud`) and the wisp prototype
(`ext/boki-wisp-proto`: `KinWisp`, `BokiWispLook`). Open questions are `boki-art/WISP_DESIGN_OPEN.md` Q1-Q9.

## Rules for every beat
- One banner line (the `steps` array in `tutorial.json`, tokens `%T` Boki key, `%s` Boki name, `%F` interact). The cut tutorial's
  `Tutorial._stall` already pulses the pill after `NAG_T` (15 s) with no progress; that stays the only nag.
- Nothing blocks over a few seconds. Every beat has a **fallback**: a timer after which it counts as done and the next
  banner shows. Cooldowns in the tutorial run at `cds` 0.25 (and are refreshed on step start), so waits are short.
- `applies(sid)` skips a beat if the hunter has no Boki (as `throw` does today).
- The old moves (dash, glide, E ability, chest) stay one-time hints (`hints.json`); this spec replaces `shoot`, `sig`, `throw`, `fight`.

## Beats (8)
| # | id | Banner | Completes when | Fallback |
|---|---|---|---|---|
| 1 | move | Land and walk to the glowing beam | as today (`moved > 3` and near stop) | none (walking cannot stall) |
| 2 | wisp | %s rides with you as a wisp | wisp is shown on the shoulder for 2 s (`Kin.wisp`) | auto-done at 4 s |
| 3 | carry | While it rides, its power is yours | player takes one hit from a weak tutorial monster (monster `dmg` 0.1) or 6 s pass; the carried stat shows once in the banner pill | auto-done at 6 s |
| 4 | summon | Tap %T to summon %s | summoned Boki is out (`Kin.wisp` false while `Kin.state` is active; the summon itself is not built yet) | 15 s nag, then Boki self-summons at 25 s |
| 5 | timer | Summoned %s fights for a few seconds, then rests | Boki hit a monster while out, then timer ends (or recall) and the Boki ring shows the cooldown | auto-done at the end of the summon window |
| 6 | outline | Round outline is a Hunter, critter outline is a Boki | player has had a decoy enemy Hunter and its summoned Boki in view 1.5 s | auto-done at 4 s |
| 7 | steal | Its Boki wisps scatter: hold %F to grab one, then summon it | decoy downed; a loose wisp is grabbed (hold interact 0.6 s), then summoned or fallback | grab: wisp floats to the player at 8 s; summon half waits (see below) |
| 8 | extract | Step into the light at the outpost | as today (match ends) | as today |

Beats 4-5: monsters are the cut `skitter`/`spitter` (`_keep_foe`), so the Boki has something to hit; `Tutorial._foes` supplies them.
Beat 6 uses a non-hostile decoy Hunter (round) beside a decoy critter-form Boki, both as outlines; no new art, only the existing outlines
(`ext/hunter-wisp-outline`, `BokiWispLook`).
Beat 7 uses a scripted downed decoy (`Hunter` downed, 0019 Hunter Wisp) that scatters its Boki wisps (`ext/downed-wisp`); nothing is
actually lost: tutorial wisps go home when the match ends.

## Headless TutorialDrive steps (extend `TutorialDrive.drive`, `match sid`)
- `move`: `goto(dest)` as today.
- `wisp`, `carry`, `outline`: no input; wait for the completion test (the fallback timer also exercises the auto path).
- `summon`: `KinCommand.tap(p)` once (as `throw` does), aim at the nearest monster.
- `timer`: `_fight` (fire at nearest monster) until the summon ends; assert the summon cooldown is running (field arrives with the summon code; `Kin.wisp` and `Kin.state` exist today).
- `steal`: walk to the loose wisp (`goto`), hold `p.inp["interact"]` for 0.7 s, then `KinCommand.tap(p)` to summon it.
- `extract`: `_outpost` as today.
A check (`--tutorial --tut-test`) must reach `extract` with `last_step` printing each id once; also run with `--tut-from=` each beat.

## Waits for open wisp questions
- **Q1 summon duration and cooldown**: beat 5's wording gives no numbers ("a few seconds"); after Q1 it may read "out for %d s, rests %d s" from species data.
- **Q3 one Boki out at a time**: beat 4/7 assume one summon lane; stolen summon in beat 7 conflicts if the own Boki is still out, so beat 7 starts only after beat 5 ended.
- **Q6 stolen wisps (summon once for half duration vs. no stolen summon)** and **Q8 passive at 50 %**: beat 7's "then summon it" half waits.
  If Q6's alternative wins (no stolen summon), beat 7 is grab only and ends when the wisp is carried ("Carry it home, it works for you now").
- **Q5 killed summon**: nothing in the tutorial; tutorial Boki cannot die (`kin.down_t` is capped already).
- **Q4 summon while downed**: not taught; downed is shown on the decoy only.
- **Q9 PvE vs PvP**: the tutorial is PvE; the decoy is scripted, so it follows the PvE exceptions whatever they are.

## Code that must change later (not here)
- `KinWisp.mode` returns false when `tut` is set ("never in the tutorial"); beats 2-7 need it true and the wisp shown in tutorial.
- `Tutorial` needs the decoy and the new ids in `_is_done`, `applies`, `_enter` (as the cut steps do); `TutorialText` gets `%s`-style tokens it already has.
- Net-neutral wiring only; the god files may not grow (AGENTS.md section 2). New logic goes in a `scripts/match/tutorial_wisp.gd`.
