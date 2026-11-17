# The town square hub (design, no code yet)

Owner ask, Nov 7 (LORE_MASKS.md round 5, low priority, keep near the end of the queue): a skyboat
from the farm to a big shared multiplayer town square full of shops and stalls and other players;
the tutorial requires one visit; not MMO scale. This doc covers the net model, the player cap, what
is sold and the tutorial beat. Nothing here is built. Defaults are picked, with the alternative noted
next to each one, so the work never waits on an answer.

## What exists today (grow this, don't build a second one)

- **`scripts/social/town.gd` (726 lines):** the hub scene (`mode "hub"`) and guild isles. It's a 50x44
  island with a fountain, 3 market stalls, a notice board, the guild registry, the expedition portal,
  a "Ferry home" post, the island-visit signpost and 5 wild Boki. You reach it from the hub bar
  (`home.gd:3884`, `Game.goto("town", …)`).
- **Presence (web only):** `town.gd` calls `kinBridge.hubJoin/hubPresence` directly (that breaks the
  "only through Net" rule; this work fixes it). Snapshots go out every 0.2 s while you move and every
  1 s while you stand, and at most 30 others are drawn. Desktop has no town presence.
- **Relay (`scripts/server/relay.gd`):** ENet, Discord-gated, `--max=120` clients, rooms (`join`,
  `memit`). Presence (`pres`) goes to every client, with no room scoping.
- **Shops:** `HomeMarket` (Vendor tabs Boki/Hunter/Seeds/Farm/Home/Sell, plus the Exchange, Shelter,
  My stall, Search and Auctions, gated by the farm stall's level), `HomeBlackMarket`, and `Stalls`
  with its NPC stalls. They're all local now and become backend calls later (docs/EXCHANGE_SERVER.md).
- **Tutorial:** `FarmTutorial` steps run axe … hob, then expedition. After the first expedition,
  `MaskOffer` offers the second Mask at the farm portal.

## Place and travel

- **Name (proposed): The Moorings**, a town that grew where skyboats tie up, built from salvaged
  Solmere stone with red banners gone pale. Alternative: just "the town" until the lore pass names it.
- **The skyboat replaces the ferry.** The farm-start island's ferry spot (`home_layout.gd`, the
  portal/rack/ferry/landing heart) becomes a dock with a small moored skyboat (`Models.ferry_post`
  re-skinned, same footprint, no layout change). In player text, "Ferry" becomes "Skyboat".
- **The ride is the loading screen:** about 8 s. The boat lifts off, clouds pass and the town rises
  into view. It covers the connect and the instance lookup. The first ride can't be skipped; later
  ones skip on a press. The way home is the same in reverse, from the town docks.
- **Size:** about 2.5x today's hub (around 80x70 tiles, plaza radius about 14). Dock to the farthest
  shop is ≤ 20 s at `SPEED` 5, so there's no fast travel. The districts open off the fountain plaza:
  the docks to the west (where you arrive), the Mask Hall to the north, Market Row to the east, the
  Stall Row lane, and the Expedition Gate to the south. The Black Market sits down a side alley.

## Net model

- **Shape:** each client owns its own walker. There's no host and nothing to simulate, because the
  square has no combat and no physics between players. Every purchase and sale goes through the same
  `Stalls`/`Exchange`/… calls as the farm (local now, backend later), so nothing in town grants
  gems or items on a peer's word. Presence is cosmetic.
- **Desktop (relay):** one new relay message, `town {with?: uid}`. The relay answers with
  `{room: "town:N"}` and counts walkers per town room. The client then uses the existing `join`.
  Walker snapshots use a new fast topic, **`tst`** {x, z, face, anim}. The client sends it at 5 Hz
  while moving and at 1 Hz while still (the web rates). The relay keeps only each sender's latest
  `tst` per room and flushes one batched packet to each receiver at 10 Hz. Each client receives about
  31 x 40 B x 10 = ~12 KB/s, and the relay sends about 320 packets/s per full room instead of ~5k.
  A profile (name, Mask, worn look, active Boki species, guild tag) goes reliable on join and on
  change, under topic **`tpro`**. Chat is reliable, under topic **`tsay`**: at most 120 characters,
  shown as a bubble over the speaker's head and in the message lane, and a local mute per player.
  `st`/`hit`/`ev` and every Net function name stay unchanged. **Net.VERSION bumps** (new relay
  message and topics).
- **Web:** keep the `kinBridge` room. Move its calls into `Net` (`Net.town_join/town_send/town_peers`)
  so `town.gd` only talks to Net. Its cap is the same as desktop's.
- **Others on screen:** a 150 ms interpolation buffer (the match's remote hunters work the same way).
  Name labels fade beyond 18 m, others' Boki are culled beyond 20 m, and far walkers animate at
  half rate.
- **Offline or no server:** the same square, with the shops working. Townsfolk NPCs (beast-folk and
  the Empty, drawn as blobs with a few marks per DECISIONS.md) fill it. The tutorial beat never needs
  a connection.
- **Core-system note:** this changes networking, so the build starts with
  `docs/decisions/NNNN-town-square.md` (AGENTS §1).

## Player cap

- **Hard cap 32 per square instance; soft fill 24.** A new arrival joins the fullest instance under 24,
  which leaves 8 places for friends or guildmates who follow (`town {with: uid}` fills up to 32).
  When every instance is at 24, a new one opens. Empty instances close after 60 s.
- **Why 32:** it's enough that the square feels busy. 32 rigged Hunters plus their Boki is the render
  budget to prove, and the relay already caps at 120 clients across matches and town together.
  Alternatives: 24 (cheaper GPU), or 48 if the perf render passes with room to spare.
- **NPC townsfolk scale down** as players arrive (about 30 bodies total), so an empty instance doesn't
  look dead and a full one doesn't look crowded.
- **Perf gate:** a `--town-bots=32` fake-peer mode, rendered through `jobq submit --needs gpu`.
  The target is 60 fps on the min-spec preset with 32 walkers, 32 Boki and the townsfolk on screen.

## What's sold (every counter opens an existing panel)

| Place | Sells | Opens |
|---|---|---|
| Mask Hall | Masks you've already unlocked by challenge, at the economy pass's prices (LORE_MASKS: "unlock, then buy"); a look at Masks you haven't unlocked yet | the Hunters screen's buy path (**town-only**) |
| Outfitter | gear (armory pieces), belt utility (healing, armor) | `HomeMarket` Vendor: Hunter |
| Boki Goods | food and treats, Boki wear, dyes | Vendor: Boki (+ dyes from Goods) |
| Seed and Tool shed | seeds, farm items, tools | Vendor: Seeds, Farm |
| Furnisher | furniture | Vendor: Home |
| Buyer's counter | sell crops and finds | Vendor: Sell |
| Tradewind Exchange office | wood, stone, scrap, crops, kibble, tonics | Exchange tab |
| Shelter | adopt strays and given-up Boki (Boki are never sold) | Shelter tab |
| Auction House | lots, bids, friends-only lots | Auctions tab |
| Stall Row | one stall per player in this instance who has listings (up to 12 stalls, newest first), filled with NPC stalls before the backend exists | Search, filtered to that seller |
| Black Market (alley) | buy-backs, the rare daily rotation, the Rare Egg | `HomeBlackMarket` |
| Notice board, Guild registry, Island signpost | as today | as today |
| Expedition Gate | online expeditions with others; leads into the pre-match lobby | the lobby, as today |

- **In town, every tab is open at stall level L3.** The reason to make the trip is that the whole
  market and the Mask Hall are here and the people are here. Upgrading the farm stall brings tabs
  home. Alternative: town tabs follow your stall level (then the Mask Hall is the only pull).
- There are no town-only goods apart from Masks, and no second shop system. In-match shops stay
  separate (map work, DECISIONS.md).

## Tutorial beat (required once)

- **When:** after the second Mask is taken (`MaskOffer` stays at the farm portal; it's built and works).
  Then Pell, the tutorial guide, says that the town is where Masks are bought and other Hunters gather,
  and the dock's marker lights up.
- **Steps** (data, appended to `farm_tutorial.json` as a `town` phase so `FarmTutorial`/`FarmGuide` run it,
  with no new tutorial system): 1. board the skyboat; 2. land at the docks, where Pell greets you;
  3. buy one thing on Market Row (the gems are topped up to the cheapest item, like the `market_gems`
  option); 4. walk to the Expedition Gate, where Pell explains playing with others. Done: one reward
  (`end_gems` pattern, 20 gems by default). After that you're free, and the skyboat goes home any time.
  It can't be skipped, like the farm tutorial. It works offline.
- **Save:** a new `tutorial.ft` phase key. The migration marks it done for any save that already has
  its second Mask, so old players aren't sent back. Save version bump plus migration (AGENTS §4).
- **Alternative:** move the second-Mask pick into the Mask Hall as the beat itself. It has a stronger
  pull, but it re-anchors a working feature, so it isn't the default.

## Build order (when it comes off the queue)

1. **Offline square** with no Net change: the layout, counters wired to the existing panels, the
   skyboat dock and ride, townsfolk, the tutorial phase and its migration, and `--town-check`
   (counters open the right tabs, the tutorial completes offline, the migration works).
2. **Presence:** the relay `town` message, `tst`/`tpro`/`tsay`, batching, instances, and the web path
   moved into Net. Net.VERSION bump, the GPU perf gate, and a relay check (a 33rd join goes to a new room).
3. **Stall Row from real listings,** once the backend's Stalls API exists (EXCHANGE_SERVER.md Phase 6).

`town.gd` is already 726 lines. Before the square grows, split it into
`town_layout.gd`/`town_presence.gd`/`town_counters.gd`, with guild isles staying in their own file.

**Out of scope (not asked for):** direct player-to-player trade windows, emotes, housing in town,
voice chat in the square, MMO features (zones, a persistent world state).
