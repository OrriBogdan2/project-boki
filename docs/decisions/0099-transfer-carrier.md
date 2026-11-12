# 0099: Carrying Boki transfers through the shared store

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** save / farm

## Problem
`Transfer.send` / `accept` (0013) had no transport: a sent Boki sat in the outbox until called back. Until the exchange server exists, the web build's shared store (`Social`, where visit profiles live) can carry it. A Boki must never end up on both farms or on neither.

## Options
1. Post the packet and remove the Boki from the sender at once. Cons: lost if nobody answers; recall becomes a store race.
2. Keep the Boki in the sender's outbox (it already is, inside the save) until the receiver's answer is in. Packets at `transfers/<sender id>_<outbox id>` go to the profile with the typed name. The receiver claims the packet, writes a yes/no answer (`transfer_answers`), then deletes the packet. The sender settles an answer only once the packet is gone, the same rule as market payouts. Recall works only while the packet is still on the store.

## Decision
Option 2, in one file: `TransferPost` (scripts/core/transfer_post.gd). It runs `sync` (from `Social.collect_gifts` on coming home, and right after a send), `answer` and `recall`. Transfer keeps the rules. The server swaps TransferPost and leaves Transfer alone.

## Consequences
- **Save format:** unchanged, so no migration. Whether a packet is posted is read from the store (gone and no answer: post it again). The inbox lives in memory, not in the save.
- **Trust:** like the rest of the store, a packet is the sender's word. `clean_kin` bounds it and Boki never pay gems, so a forged packet can't mint gems. A name can belong to more than one profile, and the first one found gets the packet. The server ends both (DEBT).
- **UI:** the Shelter tab gets "Handed to you" (Accept / Refuse) and shows up at any stall level while a Boki waits.
- **Checks:** `--market-check` adds a refuse-then-accept round trip through `tools/mem_store.gd` (`Social.fake_store`). Net.VERSION is not bumped.
