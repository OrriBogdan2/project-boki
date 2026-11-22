# Boki -> player-character audit (item 186; covers 184, 184b, feeds 185)

Code paths are file:line on origin/main 7907d9af (Net.VERSION 0.24.1). Read-only audit, no code changed.
Rule applied: DECISIONS 2026-11-06 (no agency taken; default is cut or limit). "Owner" = the player's hunter.

Verdict key: **CUT** remove. **LIMIT** keep with the stated restriction. **KEEP** passes the bar (justification given).
Replacement ideas keep each Boki's theme and rough strength (per 184b); they act on foes, the world or stats only.

## A. Acts on the player's POSITION or MOTION (184b: all cut except the abyss rescue)

| # | Species | Effect on player | Trigger | Code path | Verdict | Reason |
|---|---|---|---|---|---|---|
| A1 | Lunowl (wisplet) | **Moon Blink**: every dash becomes a teleport (no travel, ghost + `teleport`). This is the bug-181 "instant blink" dash. | Any dash while bonded and Boki carried | content/kin_v2/wisplet.json `dodge_rider.as=blink`; scripts/match/hunter.gd:1174-1196 (`_dash_rider`, blink branch 1183-1196); arch_kit.gd:489-513 (`rider_points`); kin_spec.gd:216-233 | **CUT** | Owner already ordered all riders removed (item 129); still live in 0.24.x. Delete the field from the schema too. |
| A2 | Lunowl | **Moon Swap**: first foe hit trades places with you, 0.4 s stun; the Boki casts it by itself when a foe is within 8 m (the "random teleport" of 184). | AI auto-cast: cue foe_in_range 8 m (Boki out in the field) | content/abilities_v2/moon_swap.json; scripts/kin/kin_exec.gd:824-827 (`signature swap`), :829-846 (`_swap`: `teleport`, zeroes vel, ends glide); cast by scripts/combat/kin_tactics.gd:92-115 | **CUT** | Teleports and ends glide without consent. Replace with "Moon Mark": foe marked/revealed 4 s, +15% damage from you, or pulled 3 m to the Boki. Also drop `swap` from the signature enum (parts.gd:177). |
| A3 | Lunowl | **Moonlift**: column of light lifts you ~14 up and 3 forward, cools glider. | Auto, only when falling into the abyss (cue owner_falling) | content/abilities_v2/updraft.json; kin_tactics.gd:157-160; kin_exec.gd:909-918 (`lift` on owner sets `vel`); bot.gd:619 | **KEEP** | The one allowed emergency rescue (184b). Limit: keep cooldown 14 s, abyss-only cue, never usable as a travel tool. |
| A4 | Cindle (Vespyx) | **Stinger Dash**: Boki lunges 7 m. When the Boki is carried, the lunge is performed by the HUNTER (dash_with rush). | Auto cue foe_in_range 6 m; AI casts are skipped while carried (kin_tactics.gd:110) but the player's cast key goes through `cast_c`, so it can move you | content/abilities_v2/flare_dash.json; kin_exec.gd:581-609 (`_dash`, hunter branch 600-604); kin_command.gd:174-182 (`cast_c`) | **LIMIT** | Make the Boki always perform its own dash (never the hunter) so it only moves the Boki. If it cannot, cut. |
| A5 | Zephyrak | **Gale Lance**: same hunter-as-caster path, 8 m dash at speed 28. | Player cast with Boki on shoulder | content/abilities_v2/gale_lance.json; kin_exec.gd:581-609; kin_command.gd:174-182 | **LIMIT** | Same fix as A4: Boki-only dash. |
| A6 | Pebbit (Gravadillo) | **Gravity Slam**: 7 m leap (`launch_to` on the hunter when carried), then crater. | Player cast with Boki on shoulder | content/abilities_v2/slam.json; kin_exec.gd:611-640 (`_leap`, hunter branch 637-640) | **LIMIT** | Boki must leap, not you. Otherwise replace with a ground-target slam from the Boki's position. |
| A7 | Pebbit | **Gravity Wake**: dash end pulls foes within 3.5 m. Acts on foes but is the purple "explosion" owner found confusing. | Every dash | pebbit.json `dodge_rider`; hunter.gd:1174; arch_kit.gd:489 | **CUT** | Item 129 rider removal; still present in data. |
| A8 | Cindle | **Venom Trail** (damage + poison + mark on everything the dash passes). | Every dash | cindle.json `dodge_rider`; hunter.gd:1174, `_pass_along` (hunter.gd ~2245) | **CUT** | Dash rider (129). Hero kits own the dash. |
| A9 | Zapple (Echolop) | **Echo Step**: the dash repeats once (0.18 s later, 55%). | Every dash | zapple.json `dodge_rider.modifiers`; arch_kit.gd:489-513 | **CUT** | Dash rider (129); changes how the dash reads (relevant to 181). |
| A10 | Puddlet (Prismander) | **Prism Decoy**: a decoy of you for 1.8 s at dash start. | Every dash | puddlet.json `dodge_rider`; kin_exec.gd:923-927; hunter.gd:1174 | **CUT** | Dash rider (129). If a decoy is wanted later it is a Boki ability, not a dash change. |
| A11 | Burrlet (Mycroll) | **Spore Puff**: zone around you at dash start (2 dmg + slow to foes). | Every dash | burrlet.json `dodge_rider` | **CUT** | Dash rider (129). |
| A12 | Cairnback, Pebbit | **Mount**: "you ride it": ground speed x0.85-0.9, jump x0.9, turn x0.6-0.7, no glide while riding. | Carry style `mount`, Boki on you | cairnback.json / pebbit.json `carry.mount`; hunter.gd:398-400 (`mounted`), :819 (jump), :3087-3089 (`_mount_speed`), :3307 (ride height); kin_text.gd:232 | **LIMIT** | Slower, sluggish steering and no glide are a control tax with no player choice. Keep the look; set speed/jump/turn to 1.0 and allow glide. The defense passives (C1) are the benefit. Confirm `_mount_speed` and turn are actually consumed (grep found only the definition). |
| A13 | Tempest fusion (Lunowl / Zephyrak line) | Fusion `tempest`: +30% move speed, +1 air jump, +0.5 glide for 7 s, plus a pull pulse on foes. | Player presses X (Fuse) | content/merges_v2/tempest.json; kin_merge.gd:176-190 (`passives`), hunter.gd:825 (`extra_jumps`), :3081 (`glide`) | **LIMIT** | Player-commanded and timed, so acceptable, but drop the extra jump and glide (movement identity belongs to the hero); keep a small speed bonus. |
| A14 | Fusions with kit (stormwing, titan, tidal_shell) | Replace the hunter's kit for 10 s with the form's; move speed +3..30% by weight class. | X (Fuse) | content/merge_forms/*.json `baseline`; kin_merge.gd:106-137; merge_kit.gd; merge_form.gd | **LIMIT** | It is the commanded signature move ("Fusion") and the owner kept it; but cap the movement bonus to the class-agnostic 15% (rules/merge_forms.json `afterglow` is already 15%) and verify the form dash does not alter the hero dash outside the window. |
| A15 | Any (fusion end) | **Afterglow**: +15% move speed and 8% shield for 3 s after release. | Release | content/rules/merge_forms.json `afterglow`; merge_release.gd:19-30 | **KEEP** | Small, short, reward for releasing; no control change. |
| A16 | Any (rescue) | Carrying a downed Boki slows you to 90%. | Rescue | content/rules/boki_system.json:49 `carry_speed_k`; kin_downed.gd:173; hunter.gd:2237 | **KEEP** | Intentional cost of a rescue the player chooses. |

## B. Stat riders on the player (movement stats, dash, defense, offense)

| # | Species | Effect | Trigger | Code path | Verdict | Reason |
|---|---|---|---|---|---|---|
| B1 | Lunowl | +1 dodge charge (`dodge_charges`) | Passive while Boki carried | wisplet.json `carry.passives`; hunter.gd:372 (`max_dashes`) | **CUT** | Changes the dash count/UI of every hero (also muddies item 147). Replace with a non-dash stat (e.g. +regen). |
| B2 | Lunowl | +20% glide speed/time (`glide`) | Passive | wisplet.json; hunter.gd:3081 (`heat`,`glide_speed`) | **CUT** | Alters movement feel; glide is a hero/game system. |
| B3 | Lunowl, Cindle, Zapple | `owner_move_speed` (+3%, +3%, +4.5% at defaults) | Owner points from stats | wisplet/cindle/zapple.json `stats`; hunter.gd:3080 (`kin_pt`), parts.gd:327 | **CUT** | Tiny, invisible, and part of why speeds differ between runs. Swap for hp/shield points. |
| B4 | Zapple, Zephyrak | +20% fire rate, +20% faster reload (`fire_rate`, `reload`) | Passive | zapple/zephyrak.json; hunter.gd:1507, :1729 | **LIMIT** | Weapon DPS shifts hero balance; keep one (fire rate), cap at +10%. Gun kits have no reload anyway (DECISIONS: no reload). Drop `reload`. |
| B5 | Cairnback, Pebbit | -15% damage taken, 50% knockback resist | Passive while mounted | cairnback/pebbit.json; hunter.gd:517, :766; parts.gd:351-352 | **LIMIT** | Defense is a legit Boki role, but knockback resist changes how you react to hits: drop it, keep damage reduction. |
| B6 | Burrlet, Cindle, Pebbit, Puddlet | Owner max HP (+12, +8), armor (+x), shield (+12, +16), regen (+0.75) | Owner points | kin_v2/*.json `stats`; hunter.gd:546 (armor), :2034-2039 (regen/shield) | **KEEP** | Pure stats, the model case the owner allows ("heal, shield, buff"). Keep within current caps (parts.gd:323-327). |
| B7 | Puddlet | +regen passive | Passive | puddlet.json `carry.passives`; hunter.gd:2034 | **KEEP** | Same as B6. |
| B8 | Burrlet, Cindle, Hivara | `carry.on_shot`: slow/poison on your shots | Every shot | kin_v2/*.json; hunter.gd:1914-1925 | **LIMIT** | Acts on foes, fine; but it changes what your weapon does. Keep poison/mark, cut slow (stacks with Boki CC, muddles weapon feel). |
| B9 | Mutations (Crystal / Glowing Boki) | +armor / +sight to the hunter | Boki mutation | scripts/core/mutations.gd:164; hunter.gd:3077 | **KEEP** | Passive stat from a rare mutation; no control change. |
| B10 | Any fusion | `damage` +15-20% (capped), `dodge_regen` 1.0 (instant dash refill) in Stormcoat, `knockback_resist` 0.5-0.75 | Fusion window | merges_v2/stormcoat.json, blaze_mantle, hive_crown, thornwake, cairn_colossus; kin_merge.gd:176-190, :152 (`dodge_regen`) | **LIMIT** | Damage fine (capped). Cut `dodge_regen` (changes dash economy in violation of 185) and knockback_resist. |

## C. Buffs/shields/info on the player from Boki abilities

| # | Species | Effect | Trigger | Code path | Verdict | Reason |
|---|---|---|---|---|---|---|
| C1 | Zapple | **Echolocate**: reveal rivals 18 m for 3 s + your next shots crit for 1.5 s. | Auto, in a fight | echolocate.json; kin_exec.gd:940-952 (`_buff`) | **KEEP** | Info plus a short damage buff on the player's stats. |
| C2 | Puddlet | **Refraction**: 1 s mirror + 20 shield when hurt below 55%. | Auto | refraction.json; kin_exec.gd:905-908 | **KEEP** | Shield, no movement; emergency use, 12 s cooldown. |
| C3 | Pebbit | **Mass Guard**: wall in front of you for 3 s. | Auto when shot at | rock_guard.json; kin_tactics.gd:150-156 | **LIMIT** | A wall placed on top of your position can block your own movement; place it 1.2 m ahead only if clear, no body collision with the owner. |
| C4 | Puddlet | **Prism Wall** on command. | G cast | prism_wall.json | **KEEP** | World object, not on the player. |

## D. Acts on foes only (listed for completeness, no change)

Burrlet Puffcap Mines / Spore Patch, Cindle Stinger Hook (drags the FOE to the Boki; fine), Cairnback Boulder Heave, Hivara Hive Swarm / Spore, Zapple Echo Chain, Zephyrak Storm Arc and the merge pulses (tempest pull, thornwake root, cairn_colossus launch) all target foes. **KEEP.**

## E. Control channel

| # | What | Code path | Verdict | Reason |
|---|---|---|---|---|
| E1 | AI casts happen while the Boki is out; none can take input. Verified nothing in kin_tactics or kin_command locks the player's input. | kin_tactics.gd:92-115 | KEEP | n/a |
| E2 | Fuse (X) takes over the kit and shell for the window | kin_merge.gd:106-137 | LIMIT | Player-commanded and signature; no auto fuse may ever exist. |

## Findings that need owner attention

1. **Dash riders are NOT removed on main** (item 129): 6 of 9 species still carry one and the whole pipeline (`_dash_rider`, `rider_points`, KinSpec `dodge_rider`, KinText.rider, home.gd:2943 tooltip) is live. Cutting A1, A7-A11 (data + code) closes bug 181.
2. **Hunter-as-caster:** `kin_exec._dash` / `_leap` run on the hunter when the Boki is carried (A4-A6). That is a movement path 184b did not list.
3. **Schema-level fence suggestion:** forbid `target: owner` for `lift`, `pull`, `push`, `signature swap` outside the `owner_falling` cue, and forbid `dodge_rider`, `dodge_charges`, `glide`, `extra_jumps`, `air_dashes`, `dodge_regen` and `owner_move_speed` in kin data. Add a grammar test so new Boki cannot reintroduce them (satisfies the 185 "check that fails").
4. Unverified: A12 mount turn rate and `_mount_speed` consumers (grep shows only the definition at hunter.gd:3087), and whether `stormwing`/`titan`/`tidal_shell` form dashes leak outside the fusion window.

Default stance: everything in A except A3/A15/A16, plus B1-B3, is a CUT; the rest is LIMIT or KEEP as above. Nothing is cut until the owner reviews this list.
