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
