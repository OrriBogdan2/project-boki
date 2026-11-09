# 0019: Pre-match lobby

## Problem
Owner (Nov 7): before every match a lobby (90 s, since 11-08 30 s): pick your Hunter, meet your squad, plan by text and voice, then load. An admin setting skips it for a plain loading screen, which gets better too.

## Options
1. Gate inside `Main.show_screen("match")`: grows a god file and every test path would hit it.
2. Gate in `Game.start_match` (the one door home, the title and the online lobby use): a new `prematch` screen runs first, then goes to `match`. Tests and `--shot` flows call `show_screen` directly and never see it.

## Choice
Option 2. `Prematch` (scripts/match/prematch.gd) holds the rules (countdown, lock, picks, squad, options); `PrematchView` is the screen. Only real expeditions (teams > 1, not tutorial, training, arena, duel, demo, autoplay) get a lobby. `Settings.lobby_enabled` (default on, in the admin settings group) skips it.
- Squad: online it is your roster team (the online lobby now sends each hunter's `arch`); offline duos and trios deal bot mates (`Prematch.deal_mates`) into `opts["mates"]`, which `Match.make_bot` uses, so the lobby, the loading screen and the match agree.
- Picks lock at 0; the locked pick is saved (`HeroGrid.save_pick`) and passed as `opts["arch"]` and, online, into the roster.
- Chat and picks go over the lobby channel (`Net.lobby_emit` topics `chat` and `pick`), filtered to teammates. Voice is a stub: `VoiceChat.transport` is the plug-in point, none ships.
- Loading screen: map name, mode, squad portraits, a lore line under the tip, the staged progress bar.

## Affects
Net.VERSION 0.25.0 (new topics, roster field), `Game.start_match`, `Match.make_bot`, the online lobby's `_go`, loading.gd. No save-format change. Online countdowns are local per client from the moment each receives Start.
