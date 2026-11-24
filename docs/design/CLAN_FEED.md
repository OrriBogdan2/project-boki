# Clan feed: see what your clanmates did, without playing together

Status: spec only, owner approves before building. Builds on decision 0022 (clans, slice 3b `ClanInfo.last_deed`),
0087 (clan board) and the clan chat (`ClanChat`, `ClanChatPanel`). Owner list: "clans so people can do what they
like and still play together (some extract, some raise)".

## Owner summary
1. A clan member sees a short feed of what the others did: the latest Boki they **bred**, their **race wins**
   (garden cups) and their **expedition extracts**. A raiser and an extractor each see the other's work.
2. It shows in **one place only**: the clan block of the Nook side panel, under the clan chat (`ClanChatPanel`).
   Nothing in the match HUD, no toasts, no pop-ups, no badges. Outside a clan the block is absent.
3. It is **not live**. Each member's last deeds ride the profile doc they already publish; others read them when
   the panel opens (and on the existing 20 s publish throttle). No match Net traffic, no `Net.VERSION` bump.
4. Cost: one `Save.d` field is **not** needed for the feed itself; one small optional save counter is (below).
   About 120 net lines, one new check.

## What a member sees (max 5 lines)
Newest first, one line per deed, own name tagged like chat (`[WREN] Ivy`):
- `Ivy bred a Cindle, 3 h ago`
- `Moss won a garden cup, yesterday`
- `Ivy made it out of a match, 2 d ago`
Reads from the clan's roster only (muted names, `MuteList`, are dropped for you). Tapping a line opens that
member's island visit (existing `visit` flow). No reactions or replies; chat is the place to talk.

## What exists (extend, do not duplicate)
| Piece | Today | Change |
|---|---|---|
| `ClanInfo.last_deed(events)` | newest of extracted / raised / bred, one deed per member | `ClanInfo.deeds(events, 3)`: newest per kind (bred, cup, extracted), plus raised kept as is |
| `profiles/<me>.last` | one deed `{did, t, sp}` | add `deeds` (array, max 3 items, same item shape). `last` stays for older clients (read as 1 deed) |
| `Social.clean_deed` | cleans one deed | `clean_deeds(v)`: max 3, known kinds, time clamped to now, species known or "" |
| `ClanBoard` | counts cups per week | untouched; the feed is the story, the board is the goal |
| `ClanChatPanel.side_rows` | chat block | calls `ClanFeedPanel.side_rows(dv)` just above chat (one line of wiring in `home.gd`, which is frozen) |
| Event log | logs `extracted`, `evolved`, `hatched`+`bred` | add `Save.log_event("raced", ...)` in `BaseRace.settle` where `ClanBoard.add("cup")` is called (backed pick won). One line |

New file: `scripts/social/clan_feed.gd` (pure: merge each member's deeds into one list, newest first, 5 max, text via
`ClanInfo.deed_text`) and `scripts/home/clan_feed_panel.gd` (draw). Add `"cup"` to `ClanInfo.DEEDS` and its text
(`won a garden cup`).

## Net and store (small, no live sync)
- **Match Net: nothing.** No topic, no event, no `Net.VERSION` bump. Per AGENTS.md anything synced goes through
  Net; this is the page store (like roster, board, chat), the same channel decision 0022 and 0087 chose.
- **Store: no new doc.** It rides `profiles/<me>`, which `Social.publish_profile` already writes (throttled 20 s).
  Added bytes: at most 3 deeds x about 40 bytes = about 120 B per profile.
- **Read:** the roster read already fetches each member's profile for the member roll; the feed is built from the
  same rows (no extra query). 24 members max (`Social.CLAN_CAP`) so at most 24 x 3 = 72 deeds sorted, 5 shown.
- **Trust:** everything is cleaned on read (`clean_deeds`); non-members and other clans' rows are dropped; a forged
  deed shows a line, nothing more (no reward, no points, unlike the board). Offline: the block shows your own
  deeds only, or hides.
- Refresh: when the panel opens, no polling timer. Stale up to one publish interval (20 s) plus the member's next
  publish, so "a few minutes late" is accepted and not a bug.

## Save fields
Save.d change: **none required** for the three deeds, since they come from the existing `log` event list.
One field is optional and recommended, because the log is trimmed:
- `Save.d["clan_feed_seen"]` (int, unix seconds): the time the panel was last opened; the panel puts a dot on lines
  newer than it. Skipped if the owner wants no "new" marker: then no save change, no migration at all.
If added: `Save.VERSION` 22 to 23, a migration `data.setdefault("clan_feed_seen", 0)`, a golden file
(`docs/SAVES.md`, `--save-compat-check`). Old saves load unchanged. **Default in this spec: do not add it.**
Check the log trim length (`Save.log_event`) before building: the feed needs the newest bred, raced and extracted
event of each kind to still be in the log; if the trim drops them, keep a tiny `last_deeds` dict on save instead.

## Rules that keep it small
- Only the clan's own members; no friends feed, no global feed, no leaderboard text.
- No new currency or reward; no gating of content by clan.
- Shown in the social panel only. Not in lobby, nameplates, island top bar or match.
- A member with no deeds shows nothing (no placeholder spam). All text is our own words.

## Check (when built)
`--clan-feed-check` (registered in `tools/checks/misc.gd`): `deeds` picks newest per kind; `clean_deeds` drops
unknown kind, future time, 4th item; the merge sorts newest first, caps 5, drops muted and non-members; old
profile with only `last` still shows one line; save-compat golden loads.

## Open choices (my pick in bold; owner can flip)
1. Race wins: **only the garden cup you backed (as the board counts)** vs every race you ran in. Alternative: all
   placings, more noise.
2. Extract line shows **no loot** (just "made it out"), to avoid envy and Net-size growth. Alternative: best item name.
3. "New" dot via `clan_feed_seen`: **off** (no save change). Alternative: on, costs one migration.
4. Raised (a Boki taking a form) stays in the feed as the fourth kind, because raisers are the other half of the
   owner's "some extract, some raise". Alternative: drop it to keep to the three asked for.

## Cost
About +120 lines, -0, 2 new files, 1 new check, 1 line each in `home.gd` (wiring) and `base_race.gd`. No assets.
