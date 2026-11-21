# OWNER PRIORITIES 2026-11-09 (newest; wins over the older order below)
Goal for the next stretch: the game feels **playable**. Planner: at least 70% of new tasks must serve these areas, at least 3 per area, in this order.
1. **Game feel -> Supervive parity** (movement, dash, hit feedback, camera, input buffering, cancels)
2. **Farming / Chao-style Boki raising changes** (raising, bonding, farm loop)
3. **Combat changes** (kits, damage flow, TTK, readability)
4. **Animations** (every Warden and Boki state: idle, walk, run, attack, hit, death; blends and gaps)
5. **VFX** (abilities, hits, Boki types, readability)
6. **SFX** (every ability, hit, UI action, ambience)
7. **UI across the board** (HUD, menus, in-extraction UI, inventory)
8. **Tutorial** (new-player flow, farm tutorial, first match)
Also tracked, after those: better character customizer, better in-extraction UI, minigames for players who don't want extractions, clans (so people can do what they like and still play together), and many small polish items.
Rebase-only chores do not count toward these areas.

# Project Boki: priority order (owner-approved, 2026-11-03 23:40 UTC; replaces the 20:05 order)
**Vertical slice first:** one great match on the Hollow Crown with the starter Wardens and Boki. Work top-down.
**Finish what's in flight** (servers, the farm tutorial/Hob, the Vex model, the 2D portraits), but start NOTHING new from steps 6–8 until the slice feels great to the owner and outside testers.
Art and concepts run in parallel. Frozen: farm-builder depth, maps beyond tier 2.

1. **Ship the demo.** (Done: sync78–81.)
2a. **Final keys NOW (owner: high priority; main, branch keys82):** R = ultimate, X = Fuse, G = the single Boki button (C folded in; the Boki uses its abilities by itself), no reload key, C and T freed, settings migration. Kit agents: use Settings.key_cap and never key letters.
2. **(TOP, owner 2026-11-07: parity first, invent later; see DECISIONS) Warden mechanics parity (Opus where feel-critical):** abilities, cancels, buffering (as the source does it) and animations, LMB first, plus every owner hero note in DECISIONS. **Slice Wardens first: Vex, Zedran, Pin, Cinder** (what every new player touches) to full parity; then the other 8.
3. **Readability UI:** hitbox circles (done), the dash bar (done), Boki ownership rings and tags, the right-side Boki box with teammate Boki icons, a HUD clarity pass. (Main.)
4. **One great match + Boki as the star:** the 10-minute core-loop playtest on the Hollow Crown; the per-type Fusion spec (owner approves) and merge moments; Boki personality and reactions; Boki loss that hurts and can be recovered; playtest tools (F8 feedback, session stats, a tester guide); 2–3 outside testers on itch.
5. (Moved up to 2a: the final keys.)
6. **Economy:** loot and gem flow, then the Black Market (ext/market merged).
7. **Farm:** Hob and the farm tutorial (in flight), then islands and bridges.
8. **Modes and maps:** Duel online, Arena 4v4 with compact maps, the online launcher, the tier maps (apex threats, stealth), in-match shops.

Onboarding (new-game flow, tutorials, Mantle intro) follows once step 5 is final.
After the slice: the art upgrade roll-out (all Warden and Boki models, the creator, cutscenes).
**Done means played:** nothing counts as done until the owner or a tester has played it.
