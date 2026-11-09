# Clans (spec)

Owner goal (PRIORITIES, "also tracked", 2026-11-09): clans, so people can do what they like and still play together. Shape from `briefs/design/GARDEN.md` section 7 (on `origin/ext/agent-briefs`): a shared base plus a roster; Raisers, Breeders, Extractors; each member's own corner; a league and a clan egg. Docs only: no game code here.

## 0. What exists today (read first)

Clans are **not** a new system. They are guilds grown up. Everything below extends:
- `scripts/core/social.gd` (autoload `Social`): the store wrappers `get_doc/set_doc/query` (page shared store, web only; desktop says "unavailable"), `publish_profile()` / `profile_doc()` (the island snapshot, throttled 20 s), `clean_island()` / `clean_guild()` (every read from the store is untrusted and cleaned), and the guild calls `create_guild`, `join_guild`, `leave_guild`, `list_guilds`, `guild_members`, `contribute`, `load_progress`, with `PROJECTS` (hall, forge, shrine, lighthouse) as the shared gem sinks.
- `scripts/social/town.gd`: `mode == "guild"` builds a guild isle (`_build_guild`), places one `member` spot per member (visit their island), shows the project plots, and joins a live room `kf-guild-<gid>` through `js.hubJoin`. The guild registry is `_open_guilds`.
- Visiting: `Game.goto("home", {"visit": snapshot, "visit_id": id})` (`scripts/main.gd`), received by `scripts/home/home.gd` (`visit`, `visit_id`, `_d()` returns the visited snapshot instead of `Save.d`; most mutation is gated on `visit.is_empty()`). `--visit-test` in `scripts/main.gd` exercises it.
- Save: `Save.d["guild_id"]`, `["guild_name"]`, `["guild_perks"]`, `["guild_built"]` (`scripts/core/save.gd`).
- Docs for store rules: `docs/EXCHANGE_SERVER.md`. Net rules: `docs/decisions/` (core systems need a note; the clan base sync below is a networking and save-format change, so slice job 1 starts with `docs/decisions/NNNN-clans.md`).

## 1. Data model: what lives where

Rule (same as guilds today): **your save is the truth for what you own; the store only describes it.** Nothing in the store adds gems or Boki to a save on its own word.

### In the save (`Save.d`, one new dict, old saves load without it)
`clan = {id, role, corner_seed, joined}`; `guild_id` stays and equals `clan.id` (so existing guild code and perks keep working; a clan is a guild with `roles` and a base). Per-Boki: `rec["clan_loan"]` (set while a Boki is lent to a breeding pair, see section 4). League points are not stored locally (derived from the store).

### On the server (store docs; all cleaned on read)
| Doc | Holds | Written by |
|---|---|---|
| `guilds/<id>` (exists) | name, motto, color, founder, built, **+ `base`: shared-base state, `league_season`, `egg`** | founder/officers only for settings; any member for `base` fields they own |
| `profiles/<me>` (exists) | island snapshot, `guild` | the member |
| `contrib/<me>` (exists) | per-member gem totals per project | the member |
| `clanroster/<gid>_<me>` (new) | `{role, joined, corner: {decor, toys, kin slots}, last_seen}` | the member; role changes by an officer writing `role_set` that the member's client applies |
| `clanbase/<gid>` (new) | shared middle: race-loop times, nest egg progress, showcase wall slots (each entry `{owner, uid, species, form snapshot}`) | any member, one slot per member per field (no shared-field overwrite, same trick as `contrib`) |
| `clanleague/<gid>_<season>` (new) | each member's score doc `{me, pts}` | the member (own doc) |

Why per-member docs: the store has no transactions; `contribute` already solves this by one doc per member plus a summed read. Keep that.

Limits: roster 24 (matches `guild_members` limit 24), showcase wall 12 slots, scores capped per season.

## 2. Join, leave, roles

- **Join:** `Social.join_guild` already sets `guild_id`, republishes, resets `contrib` for a new guild. Add: write `clanroster/<gid>_<me>` with role `member`, assign `corner_seed` (hash of me+gid, picks the corner plot). Invite is by clan id from the registry (`scripts/social/town.gd _open_guilds`) or a link `goto:visit`-style; a clan can be `open` or `invite` (default open, section 6).
- **Leave:** `leave_guild` already clears the id and perks. Add: delete own `clanroster` doc, take lent Boki back (loan cleared locally; the pair partner keeps their own offspring), the showcase slots you owned empty. Founder leaving hands founder to the longest-standing officer, else oldest member; last member leaving deletes nothing (the doc just goes idle).
- **Roles:** `founder`, `officer`, `member`, plus a **focus** each member picks freely: `raiser`, `breeder`, `extractor` (or none). Focus is taste, not permission: it only changes which base chores and league tracks pay out to you. Permissions: founder and officers can set name, motto, open/invite, kick; only the founder promotes officers and disbands. A kicked member's own client notices a missing roster doc on `refresh_guild` and clears `guild_id` (we cannot write to their save).

## 3. What the shared base syncs

Visitors already see a cleaned island snapshot; a clan base is the same mechanism pointed at the clan's doc, so it reuses `clean_island` style cleaning (a new `clean_clanbase`).

- **Synced (read by all members, written one-slot-per-member):** member corners (each corner = the member's own decor, toys and up to 3 Boki, from their `profile_doc`, so it costs no new writes), showcase wall, nest/egg progress, race-loop best times, league table.
- **Not synced:** inventories, gems, Boki care state, anything in `Save.d` beyond the snapshot. The shared middle is **display plus counters**, not shared items.
- **Cadence:** reads on entering the clan base and every 30 s while inside; writes throttled like `publish_profile` (20 s). Live presence (who is standing there) rides the existing `js.hubJoin("kf-clan-<gid>")` room, as `scripts/social/town.gd` does for guild isles, no new channel.
- **Conflicts:** never two writers on one field. Egg progress is the sum of per-member `egg_pts` capped per member per day. Corner edits are local-first and republished.
- **Trust:** every number from the store is clamped on read (`clampi` as in `clean_island`); a forged score can at worst move the league table, never a save.

## 4. Roles in play (what each focus does)

- Raisers: feed and play in the shared base; base chores (feeding the nest) add `egg_pts`; they run the minigame league (race loop, see GARDEN "The Dash").
- Breeders: pair a Boki with another member's Boki. Implemented as **a loan, not a transfer**: owner A offers a Boki, member B picks it for a pairing at the Nest; both get an egg of their own (rebuilt fresh by the receiver, like `Social.clean_kin`, which already says "anything else is rebuilt fresh for the new owner"). The loaned Boki never leaves A's save.
- Extractors: run expeditions; each extract adds league points and, past a threshold, ink/rare-egg tokens the **clan** earns (a counter), which any member can claim once per season from their own save. Existing guild perks (`PROJECTS`) stay the gem sink.

## 5. Minimal first slice (3 jobs, each under 2 hours)

1. **Clan identity and roster (about 1.5 h).** Files: `scripts/core/social.gd` (`clanroster` write on join, delete on leave, `clean_roster`, `Save.d["clan"]`), `scripts/core/save.gd` (default, old saves load), `scripts/social/town.gd` (roster list in the guild isle panel), plus `docs/decisions/NNNN-clans.md`. Check: new `--clan-check` in `tools/clan_check.gd`, registered in `tools/check_registry.gd` (see `--air-limits-check`): clean_roster drops bad roles and clamps; join/leave on a fake store round-trips; an old save without `clan` loads; `--visit-test` still passes.
2. **Shared base and corners (about 2 h).** Files: new `scripts/home/clan_base.gd` (loads `clanbase/<gid>`, draws member corners from `profile_doc` snapshots and the showcase wall), `scripts/social/town.gd` (ferry spot opens it, reusing the `visit` path in `scripts/home/home.gd`), `Social.clean_clanbase`. Check: `--clan-check` additions: a fake store with 3 members yields 3 corners, a 13th showcase entry is dropped, forged huge numbers are clamped; headless open of the base prints no errors.
3. **League and clan egg counters (about 1.5 h).** Files: `scripts/core/social.gd` (`clanleague` score doc, `egg_pts`, season key), `scripts/social/town.gd` (table and egg bar), the extract-result hook in the existing expedition end path calls one `Social.clan_score(kind, n)` (a few wiring lines, `scripts/match/match.gd` is frozen). Check: `--clan-check`: capped per-member per-day points; the table sums only current roster members (like `load_progress`); claiming the egg twice in a season gives one egg.

Out of slice: breeding loans, officer tools, kick, invite links, clan chat. Note these in `docs/DEBT.md` when the slice lands.

## 6. Open taste questions (default each, nothing waits)

| Question | Default |
|---|---|
| Clan size cap | 24 (store query limit today) |
| Open or invite-only | Open; founder can switch to invite |
| Can you be in a clan and still visit/play alone | Yes; the clan is never required for any content |
| Are roles locked or just a focus | Just a focus, changeable any time |
| Breeding: loan vs transfer | Loan; a Boki never leaves its owner |
| League season length | 7 days, resets Monday, points cap 200/member/day |
| Clan egg reward | One shared-species egg per member per season, claimed in own save |
| Does a clan replace guild projects | No; hall/forge/shrine/lighthouse stay as the gem sink |
| Desktop builds (no store) | Clan screens say "needs the web version", as `Social` does today |
| Kicked or left member's showcase slots | Empty at once; league points stop counting |
| Name moderation | Same `say_of` cleaning as guilds; report/removal by founder only |
| Cross-clan visits | Allowed via the existing visit path, read-only |
