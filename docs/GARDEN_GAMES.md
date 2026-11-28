# Garden games: Boki against Boki

DECISIONS 2026-11-09: Boki vs Boki minigames in the garden (races, contests, small duels) are a core
activity. What exists: The Dash (Speed), Stump Shove (Power, Guard: the strength push), Seek (Focus),
Spark Volley (Speed, Focus), Tumble, Echo Steps, the Relay Cup, the Show Ring and Kite Tow (see
`docs/GARDEN.md`, `content/rules/minigames.json`). The one contest missing is a fetch contest.

## Fetch Cup (our own design, `scripts/home/base_fetch.gd`, rules `content/rules/base_fetch.json`)

**Pitch.** You toss a seed, both Boki sprint after it, the first to bring it back scores. Twelve or so
tosses fill the 60 s round; the quicker, steadier Boki wins most of them, never all of them.

**Entry.** A toss mat stands beside the Training post (a card in "Play with your Boki"). Interact at it with
two rested Boki out on the base: your partner and the next one. With fewer it refuses. Costs 8 energy each.

**Round.** 60 s of game time, one explicit state machine: TOSS (0.8 s, the seed flies) -> CHASE (until the
quicker Boki has it) -> BRING (1.2 s, point) -> TOSS ... -> DONE at 60 s. Most points wins; a tie goes to
the Boki that scored last.

**Stats (raising stats decide the toss).** A Boki's trip takes `distance / pace`, with the distance 6 to
10 m a toss:
- Speed lifts pace (0.5% a point, like the match bonus).
- Focus cuts the chance to fumble the pick-up (2% a point; a fumble adds 1.5 s and starts at 50%).
- Joy (0.92 to 1.08) and trust (up to 1.05) nudge pace; each trip is rolled within +-25%, so the better
  Boki wins about 60 to 85% of the tosses, not every one.

**Your part.** One press on the Training bar calls a head start for the Boki you back: its next trip is
shortened (great 0.7, good 0.85, miss none).

**Reward.** The winner gains joy and trust, the loser sulks and remembers; you get 3 gems if your Boki won,
1 otherwise. No item prize and no XP, so the garden pace and `garden_sim` bands do not move.

**Checks.** `--fetch-check` (stat edges, machine, payout, on the base), the listing rows in
`--minigame-hub-check`, `--race-check` (shares the rested-entrants rule), `--garden-games-vfx-check` (the
landing ring), `--garden-sim-check` (unchanged bands).

## Getting to a game from the hub (2026-11-23)

A garden past its first day lands in the hub, but the Dash and the Fetch Cup stand in Bramblebank. Counted
from a fresh garden save (base mode, landing at the Waystone's south side, run speed 5.28 m/s; the hop is
`garden_zones.json` `hop_max_s` 2.0 s at most):

| Path | Presses | Moving + loading | Notes |
|---|---|---|---|
| Before, Dash | 3 (E at the Waystone, Go on the Bramblebank card, E at the race post) | 0.1 s to the ring + hop <= 2.0 s + 0.5 s to the post (2.7 m) = about 2.6 s | |
| Before, Fetch Cup | 3 (the same, E at the toss mat) | 0.1 + <= 2.0 + 0.95 s to the mat (5.0 m) = about 3.0 s | nothing in the hub names it: the board's Bramblebank row said only "The Dash" |
| After, either | 2 (E at the Games board, the game's button) | 1.0 s to the board (5.3 m) + hop <= 2.0 s = about 3.0 s | the game is running on arrival: no walk at the other end |

The Games board (an existing panel, no new HUD) now lists every game of every open zone as one button
(`ZoneCards.board`); a press is `MinigameHub.start`, which queues the game (`MinigameHub.queued`) and hops, and
`MinigameHub.open` runs it on arrival (with fewer than two rested Boki out it says what it needs, as at the
post). From the title, "Play with Your Boki" was already 2 presses and no walking. The board stands 7.5 m
from the landing against 2.6 m for the Waystone, so the seconds are level; the gain is one press less and
Fetch Cup (and Seek) now showing in the hub. `--minigame-hub-check` (step 7) proves it.

## Grand Dash (PROTOTYPE, 2026-11-28, `scripts/home/base_race_cup.gd`, rules `base_race.json` "cup")

The Dash (`base_race.gd`) with three laps and bots. Not polished: bots are coloured balls, no weekly twist or
showcase pin, no own card art.

**Entry.** Interact at the race post with exactly one rested Boki out (the case that used to refuse with "needs
two"). With two to four rested Boki the one-lap Dash runs as before.

**Round.** Your Boki and three bots (copies of it with stats x0.8, x1.0, x1.2) run the zone's own loop three
times, about 60 s (the loop's checkpoints are its stretch ends; pace is the Dash's: Speed, joy, knacks, wobble).

**Cheer button.** Interact boosts your Boki x1.12 for 1.5 s, then waits 4 s. The three timing-bar marks are the
one-lap Dash's only.

**Reward.** Gems by place 18 / 8 / 4 / 2, energy cost as the Dash, joy up for a win and down for last. The
Dash prize table, first-win item and weekly cup run through `GardenPrizes.settle("dash")`, the strongest bot being
the cup's rival. No bonds and no memories except a win.

**Checks.** `--race-cup-check` (bots fill four lanes, 45 to 100 s, boost and cooldown, boost helps, payout by place,
on the base it starts, finishes, pays and clears the lanes), `--garden-prizes-check`, `--garden-games-vfx-check`, `--race-check`.
