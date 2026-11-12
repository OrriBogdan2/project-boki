# 0022: Sleepovers

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save format, social

## Problem
GARDEN_MODERN rank 10: send a Boki to a friend's garden for a day. It comes home with a memory line, a small
trait nudge toward their Boki and a gift from their patch. Species that "evolve by trade" (DECISIONS 2026-11-08)
need a way to evolve without giving a Boki away.

## Options
1. A new Net topic where the host's game accepts the guest live. Needs both players online and a Net.VERSION bump.
2. Trade a Boki for real. Loses a Boki, which the owner does not want.
3. Sender-side only. The Boki leaves for a day; when it is home, the game reads the friend's existing profile
   snapshot (`profiles/<id>`, the one visits already use) and applies the visit. Host needs no new code.

## Decision
Option 3. A sleepover lasts one real day (`Sleepover.DAY_SECS`). The Boki leaves the roster into
`Save.d["sleepovers"]` (`{rec, to, name, t}`), so it cannot be brought on a run or duplicated. You cannot send
your last or your active Boki, and at most 2 are away at once. On return `Sleepover.home` gives:
- a memory line and +2 trust;
- each trait moves 10% of the way toward the host's lead Boki (species traits from the cleaned snapshot);
- one seed of a crop growing on the host's plots (none if the plots are empty);
- trade evolution: if the species' `content/kin/<id>.json` has `"trade_to": "<species>"` the Boki becomes that
  species, logged as `evolved`. First pair: kilnbadger -> scaldamus.
No reply from the friend (empty snapshot): it still comes home, with only the memory line.

## Consequences
- Save v14 (`sleepovers: []`, migration 13 -> 14; v13 is main's garden zones). Old saves load.
- Net: no new topics or messages, so Net.VERSION stays. Only existing `Social.get_doc`.
- `scripts/core/sleepover.gd`, `scripts/home/sleepover_panel.gd`, a few wiring lines in `home.gd`.
- Check: `--sleepover-check`. The host is not told (alternative: a "pet"-style gift doc, later).
