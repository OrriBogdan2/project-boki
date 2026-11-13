# Downed Hunters (Wisps) and abilities: source rules vs ours

Parity first (briefs/DECISIONS.md 2026-11-07). A downed Hunter is a Wisp (docs/decisions/0019, presentation only). Our
`Match.foes_of` skips downed Hunters and `Hunter.hurt` returns 0 for them, so every ability that finds targets through
those two ignores Wisps. Evidence tags: [D] hero card / `briefs/supervive-data/supervive_kits.md`, [W] wiki row quoted in
docs/heroes, [F] footage frames in `briefs/hero-ref/*.md` (5 fps, 0.2 s a frame). Magnitudes marked "unknown" are not
in the refs: nobody has measured them.

## Rules

| # | Rule (source) | Evidence | Ours now | Proposed | Net impact |
|---|---|---|---|---|---|
| 1 | Sparkle's Lightning Strike launches Wisps like any body in its circle | [W] Joule; mage.md row 114 | **Built here**: rival Wisps in the circle get the same slide tow (no Static, no Grounded: a Wisp can't be shot or grounded) | done | none: `Displace.tow` already mirrors to the owner's game |
| 2 | Lace's Hail Wall affects Wisps | [W] Myth; archer.md row 112 | no (foes_of skips downed) | **waits on rule 2 decision**: proposal below (bleed x2 and slow 35% inside the wall, no hit on the pool), draft docs/decisions/0098 | none: `down_hp` is owner-side and already in the `"st"` row |
| 3 | Grimble's Abyssal Grasp scoops Wisps on its path and reels them in | [D] kits:57, [F] dredge.md f-9 | **Built** (dredge_kit `scoop`, dredge.md rows 101/162) | none | tow `haul`, already Net-safe |
| 4 | Elluna's Soulpack: walk over an ally Wisp to carry (2), carried Wisps don't bleed, can't be stomped; damage or stun drops them, 4 s lockout | [D] kits:7, [F] mooshmoosh.md | **Built** (tender_kit, `CareUtil`); "which hits drop" not traced | trace the drop list against footage | none |
| 5 | Elluna's Divine Intervention heals an ally Wisp, resurrects it and teleports it to her at the end; continues if the ally is knocked | [D] kits:13, [F] mooshmoosh.md 244-257 | **Built** (tender.md rows 48/75, `_call_home`) | none | `Displace.teleport` plus the `"rev"` event, already used |
| 6 | Bjorn's Regen Field burst: allied Wisps hit begin to resurrect | [D] kits:92 | **Built** (+0.35 of the revive bar; bulwark.md 87/118) | none | none |
| 7 | Ostra Level 4: allies and Wisps entering the outgoing zone get a shield | [W] ostra.md 145 | allies only | **waits on rule 2 decision**: a shielded ally Wisp ignores ability drain for the shield's 3 s (proposal below) | none |
| 8 | Juggernaut: R no longer resets on Wisp execution (patch 22.01.25) | [W] | n/a, hunters only | none | none |
| 9 | Stomp: standing on an enemy Wisp drains it, blocks revive; the committed stomp locks both in place and only a stun or hard CC breaks it | [W] SUPERVIVE_DATA.md 56-57, owner 2026-11-11 | **Built** (life.gd `stomp_mult`, `stomp_slow`; stomp.gd, decision 0061) | none | none |
| 10 | Knocked-down mate pulled by a knock/launch while an enemy stomps: unknown | none in refs | A Wisp under a committed stomp is pinned (owner 2026-11-11): a knock or launch can't move it; only a stun or hard CC on the stomper frees it | owner rule replaces the guess | none |

## Open questions (owner, not built)
- Does Lightning Strike launch **allied** Wisps too? The wiki row says "Wisps" without a team. We launch rivals only, like the rest of the strike (alternative: both teams, one condition).
- Rule 2: the proposal below (both: a faster bleed and a slow), decision draft docs/decisions/0098.
- Whether other displacement (Dolm chain, knockback arrows, Pin pushes) moves Wisps: no source row found, so nothing proposed.

## Rule 2 proposal: ability effects on Wisps

Every kit row that mentions downed Hunters, in our names. "Source" is the effect on a Wisp in our words.

| Hero | Ability | Source effect on Wisps | Ours | Rule 2 status |
|---|---|---|---|---|
| Lace | Hail Wall (E) | the rain zone "affects" Wisps; no number, no clip | nothing | waits on rule 2 decision |
| Motley | Lantern Trade, rank 3 shield | allies and Wisps entering the zone get a shield | allies only | waits on rule 2 decision |
| Sparkle | Skycall | launches Wisps in the circle | rival Wisps slide (rule 1) | not affected: a move, no drain |
| Grimble | Abyssal Hand (RMB) | scoops Wisps on its path, reels them in | built | not affected |
| Meeko | Bearer (passive) | carries ally Wisps; carried ones don't bleed, can't be stomped | built | carried Wisps take no ability drain either |
| Meeko | Hearthlight / Hearth Call | heals ally Wisps (x5), the ult revives and pulls one home | built | not affected |
| Albert | Mending Ground burst | ally Wisps hit start to revive | built (+0.35 bar) | not affected |
| Kael | Gilded Riposte (X) | no reset on a Wisp finish (so the ult could hit one) | hunters only | not affected: no ability hits a Wisp |
| everyone | the stomp | the only finisher; stun or knock on the stomper breaks it | built (DECISIONS 2026-11-11) | unchanged |

Base numbers (life.gd): the pool is 100 and bleeds in 15 s (6.7 a second); a stander drains x2.5 (16.7/s);
the stomp is 2.4 s, three feet of 12 each, then the finish.

**Recommendation.**
1. Wisps still take no ability damage (attacks pass through the source Wisp). There is no downed branch in
   `Hunter.hurt`; no ability hits the pool and none finishes a Wisp. The finish stays the stomp, or the bleed.
2. Rule 2 is an **ability drain** for abilities whose source row names Wisps and that hold an area: today only
   Hail Wall. A rival Wisp inside the wall bleeds **x2.0** (13.3/s: the wall adds 6.7/s, 3.3 a 0.5 s tick) and drifts
   at **x0.65** (the wall's 35% slow). A full wall (4.4 s) takes 29 of the pool on top of the base 29: it can't finish
   a fresh Wisp alone (58 of 100), only one already low.
3. It never stacks with standing on the Wisp or the stomp: the higher drain counts (x2.5 beats x2.0) and the lower
   speed counts (x0.4 beats x0.65). The wall never speeds a stomp up.
4. During a revive the base bleed pauses as today, but the wall's share keeps running (6.7/s), so reviving in the wall
   is a race the 4 s revive still wins from 27+ pool. That is the wall's job: deny the revive, not take the kill.
5. Allies' Wisps and carried Wisps are untouched by their own team's walls and by every wall.
6. Motley's rank 3 shield on an ally Wisp: the Wisp ignores ability drain for the shield's 3 s. It does not stop
   the base bleed, a stander or the stomp (only a stun or knock on the stomper ends a stomp).

**How it reads.** Each wall tick, a small blue burn flicker on the Wisp's plume (the wall's burn colour, scaled to
the soul) and the plate's pool bar steps down 3 with a short blue edge. No damage numbers (the pool is not health) and
no red: red bursts stay the stomp's, so a stomp and a wall never look alike. The plume keeps the viewer-relation colour.
A shielded Wisp shows the same shield shell as a Hunter, scaled to the soul, and no blue flicker while it lasts.

**Against the earlier build.** The w0246-combat-a wave drains tick damage x2.5 (12.5 a tick, 25/s): a fresh Wisp
dies in 4 s inside the wall with no commit and no stun that saves it, faster than a stomp. If that build lands first,
this proposal is its multiplier at 0.67 (5 x 0.67 = 3.3 a tick) plus items 3-6.

**Alternatives (not chosen).** Slow only (x0.65, no drain): safest, but the wall then does nearly nothing to a Wisp.
Real damage to the pool through `Hunter.hurt` with a floor at 15: lets every kit hit Wisps and needs a list of
exceptions; rejected for the stomp's sake.

**Net and checks when built.** No Net change: the drain runs in the Wisp owner's game and `down_hp` already rides the
`"st"` row. The build extends `--wisp-check` (wall drain rate, no stack with a stander, revive race, ally and carried
Wisps untouched, shielded Wisp ignores it).
