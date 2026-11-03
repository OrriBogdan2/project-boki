# Online hosting and launcher: options and recommendation (orchestrator research, 2026-11-03)
Asked by main (EXT_TO_MAIN 20:30 UTC item 2). For the owner to decide. No build yet.
Needs: Duel 1v1 (online search or bot), Arena 4v4, extraction in auto-filled trios with bots, plus a launcher with easy install and auto-update (DECISIONS / owner 20:15 UTC).
Our netcode today is host-authoritative (one peer runs the match). A headless export of that host is a dedicated server, so every option below fits without a rewrite.

## Recommendation
**Stage 1, now through outside playtests: our own dedicated servers on a small VPS, and the itch.io app as the launcher.**
- Run the Godot headless server build on one or two small Hetzner cloud servers (we already run agents on Hetzner). One process per match; a small matchmaker/lobby service on the same box (self-hosted Nakama, which is free and open source, or a tiny custom one).
- Distribute through the **itch.io app**: free; it installs the game, checks for updates on start and every 30 min, and downloads only a small patch for builds pushed with butler. That covers "online launcher + easy install" at no cost.
- Rough cost: about €5–€20/month for one or two small servers (Hetzner raised prices twice in 2026; check the live table). That's enough for testers and small player counts.

**Stage 2, public launch: Steam as the launcher, and keep authoritative servers.**
- Steam gives install, auto-update, friends, lobbies and invites. GodotSteam wraps it for Godot. The fee is $100 per app, paid back once the game makes $1,000.
- Keep match servers authoritative (our VPS fleet, or Edgegap if we need many regions on demand). Extraction PvPvE with bots, loot and deathboxes shouldn't run on a player's PC: host advantage, cheating, and the match dies if the host quits.

## Options compared (small scale)
| Option | What it is | Rough cost | Fit for Boki |
|---|---|---|---|
| Own dedicated servers on a VPS (Hetzner) | Headless Godot server + matchmaker on rented boxes | ~€4–€10/mo per small shared-vCPU server (2026 prices rose; dedicated-vCPU CCX from ~€43+/mo before the June hike) | **Best value now.** Full control, authoritative. We run the ops ourselves (restarts, updates). One region (EU) at first, so latency is higher for NA players. |
| Edgegap (on-demand game servers) | Spins up a server per match near the players, pay per use | ~$0.069 per vCPU-hour plus $0.10/GB egress; a free trial capped at 1 vCPU | Good when players are spread worldwide and usage is spiky. A 1-vCPU match server running 24/7 is ~$50/mo, so it's pricier than a VPS when busy. Docker-based, engine-agnostic. |
| Nakama (Heroic Labs) | Accounts, matchmaking, parties, leaderboards; not the match simulation itself | Self-hosted: free (Apache-2.0). Heroic Cloud: quote-based, reported from ~$600/mo | Self-host it beside our servers for matchmaking and parties. Skip the managed cloud at our size. |
| Steam networking (Steamworks / GodotSteam) | Lobbies, matchmaking, relay and NAT traversal through Valve | $100 per app (recoupable); networking included | Ideal launcher and lobby layer once we ship on Steam. The relay network suits listen servers; we'd still want our own authoritative servers for extraction. |
| Listen server + NAT punch-through | A player hosts; others connect peer-to-peer | ~free (a small relay/signalling box) | **Only for Duel** (1v1, low stakes). Not for extraction or Arena: host advantage, cheating, dead matches when the host leaves. |
| W4 Cloud (Godot-focused) | Godot-native multiplayer backend from W4 Games | No public pricing; open-source self-host option (AGPL) | Interesting but unproven at our size and the price is unknown. Watch, don't depend on it. |

## Owner decisions needed
1. **Stage 1 plan OK?** VPS servers + itch.io app for testers and early players.
2. **Steam at launch?** It would also be the long-term launcher.
3. **Regions:** EU only at first (cheapest), or EU + NA from day one (about double the server cost, or use Edgegap)?

Once decided, this becomes a build task: the headless server export, a matchmaker (queues for duel, arena 4v4 and trios with bot fill), a server deploy script, and the itch.io butler push in the build pipeline.

## Sources
- Hetzner 2026 price changes: tomshardware.com (April increase), privatedevops.com (June repricing), kimmo.suominen.com cloud price comparison 2026-08. The live table at hetzner.com/cloud is the source of truth.
- Edgegap pricing: edgegap.com/pricing; 2025 price change: edgegap.com/blog/announcement-offering-changes-for-2025
- Nakama/Heroic Cloud: heroiclabs.com/pricing; crux.supercraft.host Nakama self-hosted vs Heroic Cloud guide
- Steam Direct fee: partner.steamgames.com/doc/gettingstarted/appfee; SDR: partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay
- itch app updates: itch.io/docs/itch/integrating/updates.html; butler: itch.io/docs/butler
- W4 Cloud: w4games.com/w4cloud; gamefromscratch.com W4 Cloud launch coverage
