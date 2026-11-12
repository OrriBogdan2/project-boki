# Vision: does the source hide Hunters, and what do we do?

Research spec, no game code. Tags: **[game data]** read from game files, **[wiki]** wiki page, **[footage]** seen in
play notes, **[gap]** not published, **[ours]** read from our code on main. Source notes live on `ext/agent-briefs`
(`briefs/supervive-data/*.md`) and in `docs/SUPERVIVE_DATA.md` section 11. I did not re-watch footage; the footage
facts below come from the written play notes in `supervive_kits.md`.

## 1. Source rules

1. **Yes, the source runs fog of war.** Myth's (our Lace's) passive Spectral Hunter gives "vision of injured hunters
   through fog of war" [game data, supervive_kits.md:72]. That only makes sense if uninjured hunters out of vision are hidden.
2. **Vision radius is a number we do not have.** The wiki gives no vision radius, fog or ping rules [gap, SUPERVIVE_DATA.md:270].
   One data point: the aim-down-sights camera sits at 12700 uu "Fog-of-war radius x1.25, 30 deg cone" [game data,
   supervive_physics.md:16]. So normal fog radius is about 10160 uu (about 100 m at 100 uu/m, scale-dependent) and ADS
   widens it 25% inside a 30 degree cone.
3. **Sneak (Ctrl) gives more vision** and doubles as ADS [wiki, SUPERVIVE_DATA.md:267]. Same lever as the ADS cone.
4. **Terrain hides.** Bushes and stealth items hide you from base-camp vision [wiki]. Hiding behind walls and
   elevation follows from fog of war; exact occlusion rules (height tiers, ledges) are not published [gap].
5. **What reveals** [wiki/game data]:
   - Myth's passive: injured hunters through fog [game data].
   - Tenzo's (our Dolm) Stonesight: sneak to detect enemies in front "even out of vision" [game data, kits.md:104].
   - Oracle scanners (world objects) show enemy positions roughly; the storm shift "Global Oracles" scans the whole map every 10 s [wiki].
   - Carrying a Soul/objective reveals you for 120 s [wiki, SUPERVIVE_DATA.md:255]; base camps and Oath's hammer give team vision [wiki].
   - Damage, sounds and minimap rules: not published [gap]. Nothing found on whether hits or footsteps reveal.
6. **Tiers and abyss:** tiers are ledges (single high is mantled, double high needs Myth's climb or a launch)
   [footage, kits.md:121,125]. How vision treats height or the open abyss is not published [gap]. Fog is likely a 2D
   radius, which would make the abyss see-through. Unverified.
7. **Minimap:** the full map shows team pings, Oracle scans and Soul carriers; whether it shows other fogged hunters
   is not published [gap]. Assume it only shows what the team sees.

## 2. Ours on main [ours]

- **Yes, we hide Hunters.** `Match.sees()` (match.gd ~2917) is the one rule: a team shares sight; each member sees
  everything inside a 3.2 m circle (1.6 m crouched), plus a forward cone (dot > 0.6, about 106 degrees) out to
  `VIEW_RANGE` 24 m (14 m crouched), x1.25 while crouching, x gear `sight`, x raid `sight_k`.
  Needs `world.los()`: rocks and higher ground block it; dynamic sight-blocking walls too.
- **Grass and smoke** hide a target from anyone outside (`in_bush`, `in_smoke`) unless revealed.
- **Reveal** is one field, `Hunter.reveal_t`: while above 0 the target ignores cone, grass and crouch (range
  `VIEW_RANGE`+2). Writers: Hawk Sense (archer_kit.gd:134, hp under 50%, 22 m, re-armed 0.4 s), Seeker/scan belt item
  (utility_use.gd:71, `SCAN_TIME`), using any utility (0.6 s), kin `reveal` effect, Tripwire (verbs.gd:499),
  Rimelock (rimewright_kit.gd:238), Oath hammer vision (bulwark_kit.gd:591), truce betrayer (truce.gd:201, 15 s) and the
  captor of a Boki (match.gd:2839). `muzzle_t` (firing) also gives you away. Replicated as flag 4096 (match.gd:5559).
- **Output:** `_update_vision()` runs every 0.05 s and sets `Hunter.unseen` for the local player's view only; unseen
  hunters are not drawn, get no plate, nameplate, cast tells, or map dot (hud.gd, full_map.gd:506 "the map is no wallhack").
  A shader dims ground outside your cone (`vis_*` globals, up to 3 allies).
- **Blight** (blight.gd:80) uses the same `reveal_t`/`muzzle_t` as "lit" for its senses.
- **Tiers and abyss:** `los()` samples every 0.4 m and blocks on `ground_at > y + 0.2`, so higher tiers block sight
  from below and the abyss does not block (not verified for void cells).
- **Dolm's Tremor Sense** (dolm_kit.gd) reveals in its sneak cone through walls, like the source.

## 3. The gap

We already hide and reveal Hunters, and Hawk Sense has meaning. Differences from the source: (a) our range and cone
are invented numbers, the source's fog is a radius with an ADS cone, [gap] so there is nothing to match; (b) we have
no visible hint that someone nearby but unseen is acting (a sound or ping direction); (c) bots use `sees`/`can_see` the
same as players, so no cheating, but Hawk Sense is the only passive writing hp-based reveals; (d) the rules live only
in code comments, not a doc, and remote clients derive `unseen` from replicated flags only.

## 4. Recommendation

**Keep the current model; document it and change nothing in code.** Source data is too thin (no radius, occlusion,
damage or minimap rules) to justify a rework, and our model already supports Lace's passive and the equal-footing rule.
Optional follow-ups, each small and separate:

| Option | Cost | Perf for 30 Hunters |
|---|---|---|
| A. Keep as is (recommended) | 0 | `sees()` is O(hunters x team) with `los()` every 0.05 s per hunter: 30 x ~6 team members x ~60 samples, fine today |
| B. Hit/shot reveal for the victim's attacker (0.5 s) | ~15 lines in damage path, one flag already exists | none |
| C. Edge-of-vision directional sound for unseen attackers | ~40 lines + one sound | negligible |
| D. Cache `unseen` per team instead of per local viewer | ~60 lines | needed only if spectating or 30-player bots all see; saves repeat `los()` |

Perf risk to watch at 30 Hunters: bots calling `can_see` against every hunter each AI tick. Measure with a jobq GPU
perf run before B-D; no change until a profile shows it.

## 5. Needs a decision note

Draft: `docs/decisions/0022-vision-model.md` (proposed). It records "our fog is ours, documented, owner-tunable",
so later Lace and Tenzo changes do not copy invented source numbers.
