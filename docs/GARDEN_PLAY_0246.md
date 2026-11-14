# Garden play, 0.24.6 (STACKED on ext/w0246-garden 73c831e62)

A garden-only player's first 30 minutes on a fresh save, driven through the real screens by
`--garden-play-shots --hatch-auto=0` (tools/garden_play_shots.gd): hatch, name, pet, feed, the four games, breed, a second zone.
Game time runs 6x; one `PLAY` line per step and a shot every 5 game minutes (GPU: `jobq submit --needs gpu`).
The shots sat in the GPU queue (about 60 jobs ahead) when this was written: the job ids are in the READY line.
Run headless, the whole 30 minutes goes through with no script error.

## Gaps, worst first for the raise-play-breed loop

1. **One Boki, no way to a second** (FIXED here): the Dash, Stump Shove, Seek and Spark Volley all refuse ("needs two
   rested Boki"), the nap pile and the Nook pair cannot happen, and the wild visitor (the only garden route to a
   second Boki) needed two residents of the zone's type group, which a starter never is. Three of the five first-day
   lines (race, nap, pair) were unreachable. Fix: `garden_visitor.json lone_residents: 0`, so a lone Boki's garden can
   draw a first visitor (a toy it likes still needed; it asks to stay after three favourite meals).
2. **Breeding is far past 30 minutes**: the starter is still level 1 after 10 minutes of petting and feeding; the Nook
   wants two Grown (level 8) friends. Even with a friend the loop has no breed in the first half hour. Not fixed (pace is a design call;
   `--garden-unlock-pace-check` and tools/garden_sim.py are the place).
3. **No second zone for a garden-only player**: Glasswater stays asleep (both keys false: Wayseed from a lair or the
   trader, plus a lean). Once woken, the hop and the arrival work. Not fixed.
4. **The first screens push combat**: after naming, "Head out together" (the big button) starts the combat tutorial;
   "Skip the tutorial" is a flat small button. A new save must then pick a combat Relic (archer, juggernaut or
   gunslinger) and sits through the put-on cinematic before the garden. The Relic step is skipped by the driver.
5. **Garden mode ships off**: `content/rules/farm_build.json base_mode` is false; the driver turns it on as the checks do.
   A player on the shipped rules gets the old farm. A release switch, not a bug.
6. **Feed has nothing to feed**: the bag holds one tonic; the kibble comes at the tutorial's feed step, after "say hello".
   The "Feed your Boki" line reads 0/1 with no food in the bag until then. Minor.
7. **Tumble with one Boki and no ring built** raised script errors in the driver (label shown, `ring` nil). Not reachable by a
   player until the ring is built; unverified beyond that, left.

Pet works (joy 70 to 75, trust up, once per 20 s). The first-day list shows its five lines from the first frame.

## The wave's four flaky checks (3 runs each, rpc5, loaded machine)

- `--chore-check`: 2 of 3 red ("Glom wrote one journal line per chore (2 lines)"). A journal-line count, not seen in play.
- `--carry-boki-check`: 3 of 3 red, 3.03 to 3.43 m behind against the 3 m bar. The carried Boki lags at walking pace; the bar is too tight under load.
- `--homecoming-check`: 0 of 3 red.
- `--home-hatch-check`: 1 of 3 red ("12 s out: the Boki are sent to watch (1)", one watcher). Timing-dependent.

None showed as a bug in the 30-minute play. Not root-caused here.

## Also fixed

`--garden-first-day-check` was red (nap, 2 FAIL) on the merged line: the Dash's results card holds its runners until it
closes, so the bot's two sleepers never ran. The check now lets the card close first (RESULT_STEPS).

Checks: `--garden-first-day-check` 0 fail, `--base-life-check` 0, `--garden-visitor-check` 0 (two new rows),
`--garden-play-shots` runs clean headless, `health --strict` OK, `gen_wiki --check` OK.
