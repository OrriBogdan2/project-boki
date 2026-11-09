# Clans: spec (shape, first slice, data, Net, limits)

Status: proposal, no code. Source: PRIORITIES 2026-11-09 ("clans, so people can do what they like and still play together"), briefs/design/GARDEN.md section 7, the "playable without extraction" line in briefs/DECISIONS.md. Player text uses **Clan**; code keeps `guild` ids and `Social` guild functions (extend them, do not build a second system). All names below are our own.

## 1. The player loop

A clan is a small group (up to 12) with one shared base and a roster. Nobody has to play the same way.

- **Raisers** feed, play with and train Boki. They tend the shared base toys and run the weekly Dash league (the race minigame).
- **Breeders** lend a Boki to the Nest; a pair from two members' Boki lays a clan egg both parents' owners share.
- **Extractors** run expeditions and bring back Inks and Rare Eggs, dropped into the clan Cache for anyone to claim.

Nobody picks a role. Roles are labels the base shows from what each member does most (races entered, pairs bred, runs returned), so a member can drift.

**The base.** Each member owns a **corner** (own toys, own Boki on display). The **middle** is shared: the race loop, the Nest, the Showcase Wall (each member pins one Boki or trophy). Visiting is the existing island visit, pointed at a clan base snapshot.

**A week.** Members play their own way. Races, bred eggs and returned runs each add Clan Marks to the clan. The league table ranks clans by Marks that week. Weekly reward: a **clan egg** (one species the clan can hatch together; the whole roster gets a share of the hatch trait).

## 2. First slice (smallest useful)

1. **Create** a clan (name, banner colour, 3-line motto) for a small gem fee.
2. **Invite** by player name or an invite code; the invitee accepts. Leave and kick work.
3. **Shared base visit**: the clan base is a snapshot (member corners plus the Showcase Wall) any member can walk into, read-only to others' corners.
4. **One league table**: weekly Marks per clan, top 20, from race wins only (slice 1 has one minigame).

Not in slice 1: Nest and clan egg, Cache, roles, kick votes, clan chat, wars. Order after: Showcase Wall pins, Cache, Nest, clan egg.

## 3. Data model

**Save (`Save.d`, per player).** Reuse `guild_id` and `guild_name`. Add `clan = {role_hint, marks_week, marks_total, week}` and `clan_corner = {toys, boki_shown}`. Migration: absent keys default to empty; old saves with no clan load as "no clan". Bump the save version once.

**Server store.** The relay (`scripts/server/relay.gd`) is a stateless forwarder: only `clients`, `pres` and rooms, nothing persisted. Clans need persistence, so pick one (see Q1): the existing document store behind `Social` (`guilds/<id>`, `profiles`, `contrib`), or a small file or SQLite store in the dedicated server. Records:

| Record | Fields |
|---|---|
| `clans/<id>` | name, banner, motto, owner uid, created, `members[]` (uid, name, joined, role_hint), `invites[]` (code, uid or open, expires), `rev` |
| `clanbase/<id>` | the shared snapshot: corner list (uid to cleaned toys and shown Boki), wall pins, `rev`, `updated` |
| `league/<week>/<id>` | marks, members counted, updated |
| `marks` (per member, per week) | uid, clan, source, amount (capped, see section 5) |

The relay's part: it only needs to **authenticate the uid** (it already does via Discord) and route clan topics to the store. It must keep `uid` on each `clients` entry (it does) and enforce section 5 limits before anything is written. Clan presence (who in my clan is online) rides the existing `pres`.

Every snapshot read from the store is untrusted; run it through the same cleaning as `Social` island snapshots (safe shapes, string and count caps).

## 4. Net messages

All go through `Net` and the relay. New topics only; existing `st`, `hit`, `ev` and the `--relay`, `--server=`, `--token=` args stay. Adding them bumps `Net.VERSION` (minor).

| Topic | From | Body | Effect |
|---|---|---|---|
| `clan_make` | client | name, banner, motto | server validates, replies `clan_ok` with id or `clan_no` with a reason |
| `clan_invite` | member | target uid or "code" | server stores an invite, pushes `clan_inv` to the target if online |
| `clan_join` / `clan_leave` / `clan_kick` | client | clan id, code or uid | membership change, replies with the new `rev` |
| `clan_get` | client | clan id | returns the clan record and base snapshot |
| `clan_corner` | member | cleaned corner (toys, Boki) | server stores into `clanbase`, bumps `rev` |
| `clan_mark` | client | source, race id | the server credits Marks, not the client (the client only reports; the host validates a finished race) |
| `league_get` | client | week | top 20 plus the caller's clan rank |

Replies use the existing request-and-reply pattern, with a `rev` so a stale client refetches.

## 5. Abuse limits

- One clan per player; 7 days before joining another after leaving (stops marks hopping).
- Name 3 to 20 characters, our word filter and uniqueness; one rename a month. Motto 60 chars.
- 12 members; 20 open invites per clan; invites expire in 3 days; 10 invites per player per hour.
- Marks are credited by the server only for finished matches or races with at least two real players; a member counts for at most 5 Marks per day to a clan, so one account cannot carry the table. Same-pair repeat races count once per day.
- Corner uploads: 1 per 10 s, at most 40 KB, at most 24 toys and 8 Boki shown per member.
- Only the owner kicks or deletes; if the owner leaves, the longest member inherits. Deleting a clan clears its table row.
- New accounts (under 24 hours played) can join but not create.
- Report button on a clan name and motto; the owner of the Discord server can remove one.

## 6. Owner questions (default if no answer)

1. Where do clans live: the existing document store, or a store inside the dedicated server? **Default:** the document store the guilds already use; the relay stays stateless.
2. Are old guild projects (the Social `PROJECTS` perks) kept? **Default:** keep them as clan perks; the clan is the guild renamed in player text.
3. Clan size? **Default:** 12.
4. Does the league reset weekly? **Default:** yes, Monday 00:00 UTC, top 3 get a banner cosmetic.
5. Gem fee to create? **Default:** 100 gems, refunded never.
6. Can a member belong to a clan and still enter a match with a non-clan squad? **Default:** yes; clans never gate matches.
7. Is the clan egg shared ownership? **Default:** the egg hatches in the base; each parent's owner gets one copy of the hatched Boki, the clan keeps the egg's trait on the wall.
8. Should the base be reachable while offline members are away? **Default:** yes, from the stored snapshot.
