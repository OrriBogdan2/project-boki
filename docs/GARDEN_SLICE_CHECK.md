# Garden first slice: played on 0.24.5 (2026-11-11)

briefs/design/GARDEN.md section 9 asks for raise, pet, feed, play, race and breed, with Boki living on their own.
Tree: `ext/release-integ-0245` 272368589 (origin/main is 0.24.4 and has none of the garden code). Each beat was
played on a fresh save (`Save.new_kin`, throwaway `XDG_DATA_HOME`, `base_mode` on) through the garden checks;
times are in-game seconds printed by the checks. Headless wall time per check was 3-30 s (hatch 30 s, new-player-flow 67 s).

Fresh save with the shipped rules: `farm_build.json` `base_mode` is `false` (`--toy-check` asserts it), so none of this
shows until it is switched on. That is the owner's switch, not a bug (row 0).

| # | beat | result | time | shot | fix line (ready to queue) |
|---|---|---|---|---|---|
| 0 | base_mode on a fresh save | gap | n/a | - | Owner call: flip `base_mode` to true in `content/rules/farm_build.json` for the garden build, with a migration or old-save check in the same branch. |
| 1 | Raise: element snack, tint and mark | works | tint and mark on the meal (1 snack: lean 9, a mark; 3 Fire snacks: 88% Fire, 3 marks) | `shots/garden-slice/lean.png`: fresh, 1, 3 snacks: the tint goes pink to orange and one, two, three ember orbs appear | - |
| 1b | Raise: part at the next form | gap | n/a | `shots/garden-slice/lean.png` frame 4: bigger, no horns | `--lean-check` fails "its next form grows the Fire part": no launch species level-evolves (DEBT.md "Evolution vs GARDEN pace"). Owner picks the form levels in `content/rules/evolve.json`, then re-run `--lean-check`. |
| 2 | Pet | works | instant (pat, heart, voice); trust once per farm day (+2.5, then 0, next day +1.5) | `shots/garden-slice/base_demo_away_card.png` (the card hides the base, row 13) | Low: a second pat the same day shows no hint that trust is capped; add a `_toast` line in `_pet_kin` (`home.gd`, god file: wire only) or leave it. |
| 3 | Pet, arrival rank | gap (known red) | n/a | - | `--raising-check` "the rank it arrives with is where it starts: no moment (Friendly)": on arrival the rank moment is not played; fix in `Care` rank moments or relax the row (GATE_0245 / DEBT). |
| 4 | Feed | works | instant: food 5 -> 35, tint moves, journal line; start pack is 3 Emberberries | `shots/garden-slice/base_demo_away_card.png` hides them (row 13); no Boki frame yet | Take the frames after row 13 is fixed. |
| 5 | Away card | works | one card, once; lists the snacks and the lean change, never "lost" or "starved" | - | - |
| 6 | Play: toys | works | first use 5.6-12.6 s (limit 60), a second Boki joins at 42.7 s; play trains a stat (+13); dig turns up a snack | `shots/garden-slice/base_demo_away_card.png` hides them (row 13); no Boki frame yet | Take the frames after row 13 is fixed. |
| 7 | Boki on their own | works | friends and rivals form in 10 simulated min; nobody holds a state over 90 s except Nap; a new arrival draws the others over; night naps and the nocturnal Zapple stay up | `shots/garden-slice/base_demo_away_card.png` hides them (row 13); no Boki frame yet | Take the frames after row 13 is fixed. |
| 8 | Race (the Dash) | works | tick after a finished race at 20 s; all formats under 120 s; favourite wins 18 of 20; winner joy+trust, loser sulks, +6 gems, bond -0.15, memory line | `shots/garden-slice/base_demo_away_card.png` hides them (row 13); no Boki frame yet | Take the frames after row 13 is fixed. |
| 9 | Hatch | works | egg hatches in 10.5 s; hop-look-face beat 2.06 s; named 4.8 s after it looks at you | `clip4.png` (`--gameplay-media`) | - |
| 10 | Breed: Nook gates | works | 20 of 20 babies take the stronger parent's lean; rest 1200 s; one egg at a time | - | - |
| 11 | Breed: reaching the gate on a fresh save | gap | Lv 8 (Grown) on day 8 at 30 min/day, day 29 at 5 min/day, garden only (`tools/garden_sim.py`) | - | The first-day line "Pair two Boki in the Nook" (`farm_tutorial.json` `first_day`) cannot tick on day one, and a fresh save has one Boki. Apply `garden_sim.json` `proposal` (home only, 5 min: Lv 8 on day 14) and move the "pair" row out of the first-day list into the Goals after Grown. |
| 12 | Whistle | works | a trusting partner arrives in 4.25 s; a sulky or new one only looks over | `whistle_run.png`, `whistle_here.png` (`--garden-whistle-shots`) | - |
| 13 | Demo seed (`--base-demo`) | gap | check: ready in 1.1 s (limit 10), something at 0.5 s | `shots/garden-slice/base_demo_away_card.png` (frames at 3 s and 6 s are identical) | On the real screen a blurred "While you were away: A Rare Spore Egg is ready to hatch" card covers the whole base and no Boki shows; the demo film needs it gone. In `BaseDemo.stage` (`scripts/home/base_demo.gd`) skip the first-arrival card (`ZoneAway.card`, `home.gd` arrival hook) or close it, and have `--base-demo-check` assert no card is open at 5 s. |
| 14 | First-day list | works | five rows tick in the bot run, +15 gems once, list gone | - | - |
| 15 | new-player-flow | known red | n/a | - | Its driver still looks for the removed skiff (GATE_0245, DEBT.md); needs a Ways Out driver. Expedition side, not the garden. |

No dead end found in feed, pet, play, race or hatch. Every prompt tested (meet, feed, place a toy, head out or stay,
"Start a Dash, ... (back <name>)", the E key doing what the Boki wants and otherwise petting) reads clearly in the code
and in the check text.

## Checks run (all `godot --headless -- --<name>-check`, throwaway XDG, tree 272368589)
Pass (0 failures): lean-snacks, feed, toy, base-life, race, nook, iv, journal, hatch, base-demo, garden-first-day,
garden-daily, garden-trust, garden-whistle, garden-visitor, farm-tutorial, garden-items, garden-nav, garden-prizes,
garden-recipes, garden-zones, garden-unlock-pace (zones open on day 3, all five by day 10-14).
Red: lean (1: row 1b), raising (1: row 3), new-player-flow (1: row 15). All three are in GATE_0245 and DEBT.md already.
Also `python3 tools/garden_sim.py` (row 11), `python3 tools/health.py --strict` OK, `python3 tools/gen_wiki.py --check` OK.

## GPU shots (jobq, `--needs gpu`)
Jobs: lean-shots 20261111-172033-26485, base-demo frames (`--base-demo --shot=shots/base.png --shot-every=3`)
20261111-172053-15170, garden-whistle-shots 20261111-172104-24643, gameplay-media clip 4 (hatch) 20261111-172118-20385.
All four finished rc 0 (67, 50, 34, 217 s on rp1-1). Outputs are in `/home/boki/jobq/done/<id>/out` (not kept in the repo except the two stills above): `lean*.png`, `base.png` and `base_1.png`, `whistle_run.png` and `whistle_here.png`, `clip4.avi` and `clip4.png`. The pet, feed, play, nap and race rows have no usable frame yet because of row 13.
