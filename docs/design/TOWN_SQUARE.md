# The Waymeet: a town square beside the garden

**Owner summary** (answer to 11-11 "are we adding a townsquare type of place ... tied to the chao garden?")
1. Yes. A shared square, working name **the Waymeet**: a sixth card on your hub's Waystone. Hub and zones stay private.
2. You walk in with your partner Boki beside you: look at other people's Boki and Hunters, emote, visit their gardens, enter garden games against their Boki, read the board, use the vendors.
3. Offline it is full from day one (townsfolk). The web build fills the same spots with snapshots of real players. Live players arrive with the backend.
4. No new economy: the square gives a face to what decision 0013 already allows (stalls, auctions, Shelter, one-item gifts, the weekly Boki transfer). No free trade window.
5. Phase 1 is one week, offline, built from existing models and panels (no Meshy): the place, 8 residents, inspect card, emotes at home, board, vendors, a check, shots.
6. Risks: a bot square feeling fake (we label who is who), the frame cost of 12 people with Boki, moderation once chat is live. Nothing in the square gates the garden or expeditions.

Status: design only, nothing built. Builds on the 0.24.5 garden line (decision 0022, GARDEN.md 10, 0013 market).

## 1. What other games teach (feel references only; no names, text or assets taken)
- **The source game:** menus with your Hunter on screen, party and custom lobbies; we found no walkable hub. The square is where we go past it.
- **The Chao garden's lobby:** the room between gardens holds the services and contests, so a raised creature gets seen and tested there.
- **Splatoon's plaza:** filled with snapshots of real players, no live netcode. Async "echoes" make a full, honest square.
- **Monster Hunter's hub, Destiny's Tower, Animal Crossing:** every service on a 30-second loop, a board that starts things, capped gifts, wordless emotes before free chat. Small and dense beats big and empty.

## 2. What you do there
| Thing | How it works | Built on |
|---|---|---|
| **Show off** | You arrive as you are at home (your Unmasked, or the Hunter on the home pick row); your partner walks beside you. E on anyone opens their **card**: name, Hunter, partner Boki (form, lean, age, traits, wear, "raised by"), showcase wins. Hunter skins do not exist yet; they would be seen here. | Home's hero and partner, `BaseShowcase`, `Social.profile_doc` |
| **Emotes** | The match emote wheel works in the square. Benches to sit on. Boki greet each other with a heart or a huff. | `Truce.EMOTES`; the wheel moves out of `hud.gd` into its own file |
| **Garden visits** | "Visit garden" on a card takes you to that person's hub by the existing visit path: pet each Boki once a day, leave one gift. | `VisitZones`, `Social.send_gift` and its caps |
| **Square games** | The garden games with residents' Boki as rivals: the Dash laps the square's rim so everyone sees it, the Show Ring uses the stage. Same rules and payouts as at home. | `BaseRace`, `ShowRing`, `BaseShove` |
| **Notice board** | This week's twist, the judges' taste, today's strays, your Boki's wishes, guild projects; later short player notes from preset phrases. | games board, `GardenWishes`, `Shelter`, guilds |
| **Vendors** | Keepers on a market row open the panels the home stall already has (vendor and Exchange, Shelter, stalls search, auctions); the Drift Trader's cart on his days. Same stock; the home stall stays. | `HomeMarket`, `HomeTrade`, `BlackMarket` |
| **Trading, gifting** | Only what 0013 allows, face to face: one-item gifts, the weekly both-confirm Boki transfer. **No open trade window** (dupes, scams, gem mints). Alternative: a capped 1-for-1 item swap in phase 3. | `Transfer`, `Goods` |

## 3. Who is in the square (offline first, online later)
Every person there is one **profile doc** (the shape `Social.profile_doc` publishes: look, partner, showcase, garden). Only the doc's source changes, so one code path serves all three kinds:

| Kind | Source of the doc | Card label | When |
|---|---|---|---|
| **Townsfolk** | authored in `content/rules/square.json`: 4 keepers and 8 residents, each with a Boki and a line | "Lives here" | Phase 1 |
| **Echoes** | real players' snapshots (`Social.list_islands`, through `clean_island`); offline desktop has none | "Was here 2 days ago" | Phase 2, web first |
| **Live** | a player there now: position, facing, emote at about 10 Hz through `Net`, 16 a square, friends and guild first | name only | Phase 3 |

We never pass a bot off as a player. Residents walk, sit, watch the stage and cheer a race; their Boki run on `BaseLife`. Live presence trusts the client for position only; value moves through the backend. Phase 3 needs a decision note and a `Net.VERSION` bump. Squads later form here: walk into the portal together and the pre-match lobby (0019) opens.

## 4. Layout (about 34 m across; the hub is about 20 m)
```
                         N
            .-------- STAGE --------.        Show Ring, this week's winners' wall
         .-'  benches   o o o   benches '-.
  GARDEN GATE      . - ~ ~ ~ - .        MARKET ROW
  (visit a       /   THE GREEN   \      [vendor + Exchange]
   garden)  ==> |  pond    (*)    |     [Shelter keeper]
  arch, two     |     Meet Stone  |     [stalls + auction bell]
  lanterns       \   Boki play   /      [Drift Trader's cart, some days]
         '-.       ' - ~ ~ ~ - '       .-'
            '-. NOTICE      GAMES POST (Dash start, Shove stump)
               '-BOARD- [WAYSTONE] --'       you arrive here; expedition portal to the south
                         S
```
The Dash laps the rim path. Any service is under 10 s from the Waystone. Partners mingle on the Green, so Boki are the first thing you see.

## 5. Art needs
- **Reused (phase 1):** ground through `ZoneLayout` with a new cobble-and-grass theme, stall models, the Show Ring stage, the games board (as the notice board), race post, showcase wall, the hunter rig with Unmasked looks for townsfolk, Boki react clips.
- **New, small (phase 1, procedural):** Meet Stone (a larger Waystone), gate arch, bench, lantern and bunting scatter (`ZoneDress`), the sixth Waystone card, card and board panels.
- **Later (Meshy/Blender):** 4 keeper outfits, 4 hunter clips (wave, sit, cheer, lean), the Drift Trader's cart, a music loop, a crowd bed.

## 6. Build plan
- **Phase 0 (half a day).** Decision note `docs/decisions/NNNN-town-square.md` (lazy key `Save.d["square"]`, no migration, no Net change). Measure a scene with 12 people and 12 Boki first. Targets, not measured: 12 people with a Boki each, far people animated at a low rate, 450 draw calls or fewer.
- **Phase 1 (one week, offline, shippable).** Day 1: `SquareLayout` (a fixed island through Home's visit path, as the hub is) and the sixth Waystone card. Day 2: `SquareFolk` (townsfolk walk, sit, idle; partners on `BaseLife`). Day 3: inspect card, emote wheel at home. Day 4: notice board (existing data only), market row opening existing panels. Day 5: `--square-check` (you land, 8 residents, every card opens, the board lists the week's twist, an emote plays, the budget holds), GPU shots, text pass. New logic in `scripts/home/square_*.gd`; `home.gd` gets wiring only.
- **Phase 2 (one to two weeks).** Square games against residents' Boki; visits to residents' gardens (authored docs); pet and gift; echoes in the web build; preset-phrase notes; Drift Trader days; a weekly Show day.
- **Phase 3 (with the backend, ARCHITECTURE_PLAN phase 6).** Live presence, squads into the portal, face-to-face gift and transfer confirm, live races, text chat with mute and report.
- **Phase 4.** Clans (GARDEN.md 7): a banner corner, the league on the stage.

## 7. Risks
| Risk | Answer |
|---|---|
| A square of bots feels fake | Three honest labels (section 3); residents have their own Boki, lines and routines; echoes bring real players before live netcode. |
| Frame cost: people are heavier than Boki | Phase 0 measures first; cap of 12; the square is its own scene, like a zone. |
| Pulls focus from garden-first (DECISIONS 11-10) | Optional: new saves still land in their own garden; no reward or chore exists only in the square. |
| A second shop or games system (AGENTS 3) | Keepers open the existing panels; games are the existing modules with another rival source. |
| Abuse in chat, names, notes | Emotes and preset phrases until mute and report exist; every name and line through `Social.clean_*`. |
| Trade exploits, untrusted docs | 0013 rules unchanged; echoes go through `clean_island` and `VisitZones.clean_layout`. Phases 1 and 2 touch neither `Net` nor the save version. |

Defaults taken, change freely: a separate place instead of people in your hub (alternative: make the square the landing spot once live play exists); the name Waymeet (alternatives: Lantern Green, the Commons); 12 people offline, 16 live.
