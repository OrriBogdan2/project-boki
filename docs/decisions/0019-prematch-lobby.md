# 0019: Pre-match lobby

## Problem
Owner (Nov 7): before every match a lobby: pick your Hunter, meet your squad, plan by text and voice, then load. An admin setting skips it for a plain loading screen, which gets better too.
Owner (Nov 9): no two players on a squad may play the same Hunter (the enemy may mirror), and the flat timer becomes a pick order: picking starts once everyone in the lobby has loaded, then players pick in turn, 10 s each, a run-out turn gets a random untaken Hunter.

## Options
1. Gate inside `Main.show_screen("match")`: grows a god file and every test path would hit it.
2. Gate in `Game.start_match` (the one door home, the title and the online lobby use): a new `prematch` screen runs first, then goes to `match`. Tests and `--shot` flows call `show_screen` directly and never see it.
Turn order: alternate teams (A1, B1, A2, B2...) or each squad in its own order, all squads at once. Uniqueness is only within a squad, so squads never wait on each other: per-squad order, all at once (a trio's picks take 3 x 10 s, not 12 x 10 s).

## Choice
Option 2. `Prematch` (scripts/match/prematch.gd) holds the rules (load wait, turns, picks, squad, options); `PrematchView` is the screen. Only real expeditions (teams > 1, not tutorial, training, arena, duel, demo, autoplay) get a lobby. `Settings.lobby_enabled` (default on, in the admin settings group) skips it.
- Loading: online each client sends `loaded` when its lobby opens and answers anyone new with its own, so late loaders hear the early ones. Picking starts when the whole roster (all squads) has loaded or left, or after `LOAD_WAIT` (60 s) so one stuck client can't hold everyone. The screen shows "Waiting for players to load (n/N)".
- Turns: each squad in pick order, `TURN` (10 s) per Hunter; a turn always runs its full 10 s and you may change your pick until it ends (so a trio takes ~30 s). Offline you pick first; online the order is shuffled by the match seed, the same on every client. Bot mates pick the moment their turn comes (their dealt Hunter unless taken). The picker's own client ends its turn and sends `pick` with `final`; teammates accept a pick only on that player's turn and only an untaken Hunter. A teammate who left is picked for at once, one whose final pick never arrives after `GRACE` (3 s); auto-picks come from a stream seeded by the match seed, so every client deals the same one.
- Taken Hunters show greyed with the teammate's name; the picker's squad row is lit with the turn countdown on top. Bots never double a squadmate: `deal_mates` deals unique Hunters, `Arch.pick_for` skips the squad's (online fill-in bots too).
- Server side: the matchmaker (server/matchmaker/mm/picks.py, `POST /queue/<ticket>/pick`) holds the same rules for the matches it starts (load = the slot joined its game server). No client calls it yet: online play still runs over the relay, where each client checks its squad's picks as above.
- Squad: online it is your roster team; offline duos and trios deal bot mates (`Prematch.deal_mates`) into `opts["mates"]`, which `Match.make_bot` uses, so the lobby, the loading screen and the match agree.
- The locked pick is saved (`HeroGrid.save_pick`) and passed as `opts["arch"]` and, online, into the roster.
- Chat goes over the lobby channel (`chat`), filtered to teammates. Voice is a stub: `VoiceChat.transport` is the plug-in point, none ships.
- Screen (UI declutter, owner 11-08): one title line under the turn banner (whose turn, its big countdown, ticking and pulsing red in the last seconds of your own turn); a squad strip on top; cards are portrait + name + role word (`card.role_word` in the archetype JSON), stats and the unlock quest on hover, shut Hunters dim with a padlock; until the save's first match the three starters wear a "Start here" stamp in the card corner (DECISIONS 11-10, rules `start_here_matches`), no third line and no pick made for you; chat is one "Enter to chat" line that opens the log on the first message; hold-to-talk shows only with a voice transport and a human squadmate.
- Loading screen: map name, mode, squad portraits, a lore line under the tip, the staged progress bar.

## Affects
Net.VERSION 0.24.4 (`loaded` topic, `pick` carries `final`), `Game.start_match`, `Match.make_bot`/`make_hunter` (bot Hunters unique per squad), the online lobby's `_go`, loading.gd, the matchmaker API. No save-format change. Rare edge: a final pick that arrives after the grace can leave clients disagreeing on that one pick (first one heard wins).
