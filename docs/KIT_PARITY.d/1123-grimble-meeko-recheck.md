## Grimble and Meeko parity re-check (ext/parity-recheck-grimble-meeko, 2026-11-23)

Every Grimble (`dredge`, source ref-dredge) and Meeko (`tender`, source Elluna) row of this doc and of docs/heroes/{dredge,tender}.md read against `content/archetypes/{dredge,tender}.json`, the weapons, `dash_flow` and the kits on main 5a246f9696 (after the 11-15..11-22 merges; 36 later main commits touch none of these files). Source facts are unchanged: no row's source column moved. Code and data did not drift from the source without a reason: every difference below is an owner call or a gap-10 cooldown (owner). What had drifted was the docs, which still described numbers that later commits moved, and each slot's row sat 3 to 4 times after the merges. Checks on this tree: `--dredge-combo-check` 148/0, `--tender-combo-check` 158/0, `--card-numbers-check` 344 numbers 0 failures, `--kit-parity-check` 0 failures.

| Hero | What the doc said | Now (data) | Moved by | Reason |
|---|---|---|---|---|
| Grimble | LMB fan 20 rested, 30 firing, bloom, 8.8 m reach | one 6 degree group, no bloom, stop 6.3 m, reach 6.8 in game | `0dede72323` 11-17, `7402731f4d` 11-17, `23282bb8a4` 11-18 | owner 11-17 (one aim line, tight group) |
| Grimble | E Grounds the foe (ours) | no Ground; "slammed to the ground" in the card is the animation | `7b130d5c7` 11-09 (in main) | rider cut, DECISIONS 11-07 |
| Grimble | reel 11 m/s | reel 9 m/s, arm 17 m/s after a 0.2 s coil | `pull_speed` 9 since the first cut, 17 m/s owner 11-10 | the old per-slot row was never retired |
| Grimble | barge: a press in a shove is lost | held to the gap's end | `8ba7ea217a` 11-21 | feel fix, no parity row |
| Grimble | `dredge.glb` 40 clips | 45 clips | v95 and anim merges 11-16..11-18 (`9f30565ec9`, `57d96c1f7c`) | art, no parity row |
| Grimble | dredge.md rank paragraph "-10% steps, +15%" and "Abyssal Hand" | `rank_cd` .86/.72 sec, .82/.64 dash, .79/.58 E, E damage +20/+40% | `aa3a0919df` 11-10, rename `2f7336fb84` 11-14 | doc only |
| Meeko | LMB 13.5 m flat, or "Empowered +40% range" | 6.75 m; Empowered 8.4 m (x1.25) and x1.5 size | `5ce4816037` 11-17 | owner 11-17 |
| Meeko | E `self_k` .33, "open" | none, she heals like any teammate | `0d6177875b` 11-09 (in main) | rider cut |
| Meeko | Hearth Call 7/s | 5.3/s (44/s x 154/1285), pinned in `kit_parity.json` | `2ef3ba1486` 11-19 | parity, Meeko heals section below |
| Meeko | dash 3.6 m/.2 s and 13.3 m/.95 s (felt table, status table) | 3.15 m/.23 s and 10.5 m/.95 s, off the dash feel | `2f8b11c58c` 11-11 | owner playtest 11-11 |
| Meeko | RMB "hop form, windup 1.0", seed 30 m/s | wind-up 0.6 s, seed 24 m/s, root after 2 s in 15 m | `dc29370ad4` 11-11 | owner 11-10, 11-11 |
| Meeko | hit shape LMB reach 13.1 / 16.1 | 8.6 in game | `5ce4816037` | owner 11-17 |
| Meeko | pip.glb 45 clips | 47 clips | `9f30565ec9`, `183ab833c3` 11-16 | art |
| Meeko | R on X, passive "Bearer", drops on a root or hex | R is the ult (X = Fuse), passive Carrier, drops on any damage or a stun | key move 11-17 (`key_migrate.gd`), carry rows asserted | doc only |

**Left alone (owner rows):** cooldowns 12 / 7 / 21 and 10.5 / 11 / 46 against the source's 18 / 12 / 36 and 11.5 / 12 / 60 (gap 10); Grimble's 3 dash charges and cd 10 (owner 23:40); Meeko's RMB motion `[?]`, the ally-pass refund `[?]`, the 6 `[?]` hold rows; Grimble's 16% knock heal (dredge.md lists it as source, this doc as ours: unresolved, owner's "remove or keep"); Grimble E angle 110 `[?]`.

**Not looked at before, now settled:** `docs/HITBOX_SIZE.md` flags "Grimble RMB reads 20.5 m in the fine run against 11.5". It is a probe artefact: a foe 15 m out on the aim line is not grabbed (the arm's tip stops at 11.9 m, `--dredge-combo-check` "miss" row asserts 11.5 m).

**Docs retired in place** (rows each, before to after): this doc Grimble table 25 to 7, Meeko table 19 to 7; dredge.md per-slot 16 to 7; tender.md "Our kit" 22 to 7 and parity pass 9 to 7. Two 11-11 snapshot rows (status table, felt-dash table) and the two "branch ready" rows for `0d6177875` and `7b130d5c7` now say what is in main.
