# 0181: The social store moves to our server; desktop is the only client

- **Status:** accepted
- **Date:** 2026-11-27
- **Area:** networking / social

## Problem
Clans, island visits, gifts, market stalls, the notice board, Boki transfers and town presence (`Social`) only worked in the web build, through the page's shared store (`tools/shell.html`, an old prototype). The owner plays the desktop builds and wants no web build, so all of it said "unavailable".

## Options
1. Nakama on the Hetzner box. Cons: a second stack (Go server + Postgres) and a client SDK, for features that only need documents.
2. A `/social` document store in the matchmaker we already run (stdlib Python + sqlite, same systemd unit). Same calls as the page store (get, set, del, add, query by `==`, claim), so no caller changes.

## Decision
Option 2: `server/matchmaker/mm/social.py`, routes `/social/hello|db|hub`. The server hands out player ids and tokens (`X-Boki-Player` header; kept in `user://social.cfg`, not the save). A doc keyed to a player (`<id>`, `<x>_<id>`) only that player writes; a doc naming people (to, from, by, seller) only they or its claim holder overwrite or delete; an added doc's sender fields must be the caller. Reads stay untrusted (`Social.clean_*`). Client: `SocialHttp` (scripts/core/social_http.gd), address from `--social=`, `BOKI_SOCIAL` or `SocialHttp.DEFAULT_URL` in exports. The Web preset and the page shell are gone.

## Consequences
- **Save format:** unchanged. **Net.VERSION:** unchanged (no match sync).
- **Checks:** `--social-net-check` runs the real service and two games; the clan/market checks keep `tools/mem_store.gd`.
- **Open:** shared docs (guilds, chat) are still writable by any player, as before; `DEFAULT_URL` is set when the service is deployed behind HTTPS (DEBT).
