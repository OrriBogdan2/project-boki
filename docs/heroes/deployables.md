# Placed objects: HP or lifetime, what damages them, what happens when they break

Parity first (briefs/DECISIONS.md 2026-11-07). Companion to the barrier table (what placed walls *block*, on
`ext/barrier-block-parity`); this one is how they *die*. Pinned by `--deployable-hp-check`
(`tools/deployable_hp_check.gd`: one break case per object, through the real path).
Sources: `briefs/supervive-data/supervive_kits.md` (kit cards, "KITS" below), `briefs/hero-ref/breah.md` (Tetra footage),
`tamsin.md` (Celeste), `bjorn.md` (Oath), `dancer.md` (Shiv), each hero doc's source rows.

## What the source says (all of it)
- KITS Celeste E: Frozen Barricade "wall that pushes enemies and blocks projectiles; recast to freeze it in place"; rank IV "+1000 wall HP" (so it has HP; base not given).
- KITS Tetra: Rockwave "punch them with Quake Punch to launch them"; passive: hitting your Rocks gives a Shield; Tetraform "+2.5s terrain lifetime" per rank. breah.md: rock lifetime "5 s or more on screen, expiry not shown".
- KITS Oath: Brightshield "blocks all damage from the front (shield energy that regens/repairs)"; Regen Field "healing zone around your hammer"; bjorn.md: hammer planted 3.6 s+ then recalled, "does it return by itself?" unanswered.
- KITS Void: Anomaly "plant a bomb that grows over time; reactivate to detonate" (no expiry given). Elluna: zone 2.5 s, "attaches to any ally it passes through". Shiv: dagger "after 6s MUST teleport back". Brall: chain "attaches to enemies or walls", wiki 5 s, "a stun breaks it".
- No source row gives an HP number for any rock, wall or seed. HPs below are ours, scaled to our hunter HP (rocks 45 = a third of a 145 hunter).

## Table (ours now)
| Object (hero, file) | HP / lifetime | Damaged by | When it breaks | Source row | Verdict |
|---|---|---|---|---|---|
| Stone Row rock x3 (Tenzo, `dolm.json` rock) | 45 hp, 9 s | a foe's shots (any LMB or ability that is a projectile; the shot is spent); not melee, zones or cones; own team's shots pass; his punch/slam launches it (no hp loss) | crumbles (RockLook.crumble), whoever stood on it falls; launched = flies as a boulder instead | lifetime "5 s or more, expiry not shown"; launch by punch (KITS) | same where the source speaks; hp and 9 s are ours |
| Basalt Spine rock x9 (Tenzo ult, `dolm.json` x) | 45 hp each, 7 s, one cast deals a foe at most `rock_cap` 40 | as above | crumbles; over the abyss the ground goes with it | "terrain lifetime" per rank (KITS); not shown | lifetime ok (>= 5 s); the rank rows are not built (our X has no ranks) |
| Rock Hop rock (Tenzo dash, `hop_rock_hp`) | 30 hp, 1.2 s | as above | crumbles | none | ours (a skid rail) |
| Rink Wall (Neve, `rimewright.json` e) | 70 hp (x rank power, +40 at rank 3), 4.5 s; frozen by a second E: 6 s | a foe's shots; touching foes are pushed, not damaged by it | 0 hp or timer: shatters; a frozen wall stands the full 6 s | "has HP, +1000 HP at IV, freeze by recast" (KITS) | same shape; base hp ours |
| Aegis (Albert RMB, `bulwark.json` rmb.shield) | 160 hp (+25% / +50% by rank), regen 20/s after 2 s, no timer | a foe's shots and every hit from the front 140 degrees, melee and abilities (not damage over time) | 0 hp: "SHIELD BROKEN", 3 s lockout (2 s rank 3), up again at the regen | "blocks all damage from the front", regens/repairs (KITS) | same |
| Mending Ground zone (Albert E, `bulwark.json` e) | no hp, 1 s fill + 4 s | nothing (it is a zone, not a wall) | timer: ends with a burst of healing; heals the aegis only while it stands, never a broken one | Regen Field "zone around your hammer" | same; duration ours |
| Hammer planted (Albert LMB) | no hp, no timer (`lie_t` 0) | nothing | recalled by a second press | bjorn.md: stays planted; return-by-itself unknown | same |
| Brimseed (Motley E, `ostra.json` e) | no hp; grows 6.5 s, fizzles unpopped at grow + `hold_full` 10 s | nothing (a foe's shots pass through) | recast = pops (damage); her being downed or the fizzle = it ends with no damage | "reactivate to detonate", no expiry in the source | **ours-only: the 16.5 s fizzle** (below) |
| Hearthlight (Meeko E, `tender.json` e) | no hp, 2.5 s | nothing | timer: heals once more in a burst; a thrown one latches on a teammate | zone 2.5 s with a burst at the end (KITS) | same |
| Shadow Knife (Sable E, `thief.json` e) | no hp, 6 s | nothing | 6 s: she is brought to it | "after 6s MUST teleport back" (KITS), >= 5 s (dancer.md) | same |
| Warchain anchor (Kael E, `juggernaut.json` e) | no hp, 5 s | the chain does no damage to a rock it bites | the timer, a stun, a miss, a downed foe, a merge: the chain snaps | 5 s, "a stun breaks it" (KITS, wiki) | same |

Fixes to kit JSON: none. Every number the source gives (6 s dagger, 5 s chain, 2.5 s zone, 6.5 s growth, freeze by recast, shots stopped and aegis blocking) already matched. The numbers the source never gives (all the HPs) are ours and were left.

## Differences left, as suggestions (ours-only, not built)
1. **Brimseed fizzle (ours).** The source has no expiry for the Anomaly; ours drops an unpopped seed 10 s after it is full (anti-parking). Suggest raising `hold_full` or removing it; `--ostra-combo-check` asserts the fizzle today, so it moves with the rule.
2. **Warchain on a barrier that breaks.** The hook anchors on a point; if the rock or Rink Wall under it breaks, the chain stays until its 5 s. The source says only "walls". Suggest snapping the chain with the barrier.
3. **Sable's knife in a barrier** is left to `ext/sable-dagger-barriers`.
4. **Only shots hurt a barrier.** Melee, zones and cones do not (the source has "explosive: more damage to destructibles", Kingpin and Void wiki rows, and the Longneedle "pierces destructibles"). `ext/barrier-block-parity` makes a beam hit one; a bigger rule (melee and blasts hurting rocks and ice) needs an owner call.
5. **Tetraform rank rows** (+2.5 s of terrain per rank) wait for a rank system on X.
