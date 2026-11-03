# Bjorn (id `bulwark`, Heavy) - fidelity pass (hero sheet bjorn.md)

Behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (internal note; nothing of the source's names or look ships). Player-facing names are our own. Display name Bjorn (was Bulwark); the id, files and save keys stay `bulwark`. The minigun ability that was also called "Bulwark" (content/abilities/bulwark.json) is now Bracewall.

## Research summary
Sources (gameplay only; notes in our own words, nothing of the source ships):
- The hero sheet `briefs/hero-ref/bjorn.md`, written from 5 fps gameplay footage (one frame = 0.2 s). Its ranked gap list drove this pass.
- The owner playtest notes (sync61), which override the footage: release is a strong slam that carries him forward (the sync61 "spinning hammer" hold was replaced by the source's dragged-back wind-up in the parity pass, owner 18:45); the throw lands at the cursor; his shield looks unique to him.
- The earlier accuracy pass for what the footage doesn't show.

What the source does: tap throws the hammer to the cursor, where it stays planted under a tall light ray until a second tap calls it back (equal hits out and back); holding charges one big forward swing (about 3x the throw at minimum, 5.6x full) with a growing glint on the head, a full-charge flare and a flaming 180 degree crescent; a curved gold barrier shield held to the cursor; Shift is a short fixed dash ending in one 360 spin hit (2x the throw); E heals at the planted hammer (on himself with the hammer in hand), a light column coming down first. Knockout: hitting foes into walls stuns them.

## Parity pass (owner 18:45: the animations and abilities closer to the source; LMB first)
| Slot | Source | Ours before | Ours now |
|---|---|---|---|
| LMB hold: pose [footage 0102-0108, 0133-0145] | crouched side-on, the hammer held back low behind him, the shield arm forward, no spin | the hammer whirled round over his shoulder with a trail (sync61 owner note), the coil only at full | the source's pose: dragged back low behind him from the start of the hold, the coil deepening to full; no whirl, no trail, one whoosh as it goes back |
| LMB hold: tracking [footage 0102-0108] | turns freely with the cursor (1.5 turns in 1.2 s) | faces the aim (shared turn) | same; asserted: trails a 1.25 turn/s sweep by <= 25 deg, standing and walking (15 deg measured) |
| LMB hold: movement [footage] | stands in the two holds seen (unclear if forced) | walks at 55% | kept (owner note; the sheet's open question) |
| LMB release: timing [footage 0146-0149] | one-frame sweep, the impact the frame after, ~0.4 s recovery | the same keys (`bul_smash`), 0.61 s before the next action | unchanged; asserted: the swing goes on the release step at the cursor (even behind him), the hit within 0.1 s, 0.61 s recovery |
| LMB release: lunge [footage] | none | 1.5-1.8 m step, 4 m perfect launch | kept (owner #30, #49) |
| LMB tap: throw [footage 0033-0036] | one frame of wind-up, cocked low behind, then an overhand throw | the hammer left on the press while the arm was still cocking | leaves the hand ~0.12 s after the press, as the arm comes through (`THROW_WIND`); asserted |
| LMB cadence [game data, card] | throw 0.45 s card | 0.48 s (owner #10) | unchanged |
| RMB [game data: Brightshield 0.1 s; footage 0185-0200] | up after a 0.1 s cast, sweeps round with the cursor at once | up after 0.2 s, follows the aim | up after 0.1 s; asserted both |
| Shift [footage 0369-0380, game data Spin Dash] | ~3.5 m hard dash, one spin, 0.4 s recovery; 8 s (data at level 15) / 9.2 s (card) | matched in the earlier pass (3.5 m, 0.17 s, one spin) | unchanged; cooldown 9 s kept (the card's; the data's 8 s was read with upgrades) |
| Shift while charging [wiki] | a short dash without the spin, ending the charge, on a reduced cooldown | short dash for half a charge | short dash on a full charge (owner #51 keeps the charge, so the reduction has no reason left; the game data doesn't list one) |
| E, X, passive | see the per-slot table | matched in the earlier passes | unchanged |
| Camera | - | a directional camera nudge on the swing | removed (item 50: no self-caused camera motion) |

## Per-slot table (slot, input, our behaviour, source behaviour, difference and why)
| Slot | Input | What it does now (our words) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive | knock into wall/foe | Crushed: stun 0.5 and 8 damage when any knock of his (Crushing Blow of any charge, 360 Smash, Shield Charge, Shield Slam) drives a foe into a wall or another foe; no heal. Guard from blocking (50 turns the Shield Charge into a Shield Slam) | Valiant Strength: knocked into a wall, stunned | Data: any knock into a wall, no heal. The foe-into-foe case and Guard stay our own loop |
| LMB | tap | War hammer thrown to the cursor (clamped to 9 m, at least 2.5 m), 24 m/s, through foes (12); stays planted (head-down in the ground under an upright gold beacon ray with rising chevrons, your team sees foes within 4.5 m) until called back | Lands at the cursor, stays until recalled | Matches; no auto-return |
| LMB | tap again | Recall: flies back hitting on the way (12), caught with an ember flash | 175 out, 175 back | Equal hits, as the source |
| LMB | hold | Side-on and crouched with the hammer dragged back low behind him and the shield arm forward (the source's wind-up), turning with the cursor (walks at 55%); a glint on the head from 0.6 s that grows. At full (1.25 s) he coils deepest: a short ring-free flash on its head, a click and the cursor flare open the perfect window (0.18 s, the glint burning white-hot while it's open). Release: Crushing Blow 36-66 (3x-5.5x the throw), 180 degree reach 2.8 m, knock 5-13, stun 0.4 at full; a flaming crescent (white-yellow core, orange and red edges); the slam steps him 1.5-1.8 m forward in 0.24 s; white dust on the target, a debris trail as it flies | A static charged swing, no lunge (footage) | The forward step and the walk follow the owner; pose, tracking, glint, flare, crescent and ratios follow the footage |
| LMB | release in the perfect window | Perfect swing (owner #49): the same blow with 1.4x the knock, a T4 hit-stop (no screen shake: owner #50), and a launch: 4 m forward in 0.3 s, feet off the ground (`bul_launch`), a plant and skid on landing, no ground burst. Carried off a drop (2 m+ or the abyss) the glider opens by itself; glide or jump pressed during it jumps him out into a glide. Either way the glider takes the launch's speed by the shared hand-off (`Hunter.glide_handoff`, 75%). Let go in the air (out of a jump or a dash: owner #51) it launches him on from there, holding his height like an air dash, then the glider takes it (2 m+ up) or he drops on with its speed. A mantle ends it at once; a jump or Shift in it goes within a step | No lunge at all (footage) | Owner override: a timing reward and a movement tool |
| RMB | hold | Up 0.1 s into the hold, following the cursor at once. His aegis: a curved wall of riveted, forged gold plates (4.2 m chord, 1.7 m tall) with ribs, a rim and a hammer boss that rises out of the ground in a puff of dust; sparks and a flash on each block, darkening as it weakens, crumbling into chunks and SHIELD BROKEN when it breaks (locked 3 s). A foe that meets it is pushed back 2 m (once per 0.6 s each; a dashing one is stopped), shown by a pulsing double chevron in front of it that flashes on a push | Curved pale gold slab, sparks, a break burst | Matches, our own look |
| RMB | tap / release | Nothing: letting go only lowers the aegis. The Bash is the Shield Charge on Shift | Shield Bash only with Shift while shielding | Data: the bash lives in one place |
| Shift | tap | 360 Smash: a hard fixed 3.5 m dash (~20 m/s, 0.17 s, the sheet's run-up), sliding on about 1 m through one full spin hit around him (2.2 m, 24 = 2x the throw, push 7) with a red-gold swirl ring | Short fixed dash, one 360 spin on arrival (350 = 2x the throw) | Matches; cooldown 9 s (source 9.2) |
| Shift | aegis up | Shield Charge (the Bash): 4.2 m, invulnerable, 10, push 11, Crushed on a wall. Its own 6 s cooldown on the RMB slot (no dash charge spent; on cooldown the Shift does nothing); at 50 Guard it ends in a Shield Slam (cone 2.6 m, 18, push 12, stun 0.6, spends 50) | Shield Bash (6 s, Brightshield + Shift), shield briefly invulnerable | Data: own cooldown. Slam carried over from the old RMB bash |
| Shift / jump | LMB held | Owner #51: the swing keeps charging through a jump and a Shift dash (on the ground the dash is the short plain one, no spin, on a full charge; in the air the lumber) and swings where he lets go: in the air with no step, keeping his speed; in a dash riding it; in the window a perfect launch from there. Out of the dash he eases back into the wind-up pose at the charge reached. A mantle (owner #30), glide, knock, stun or another ability ends the hold, and the button must come up before it can start again; a jump or Shift in the swing's step or the launch goes at once | Wiki (Spin Dash): Shift while charging ends the Hammer Smash in a short dash without the spin | Owner #51 keeps the charge (supersedes #30's dash cancel) |
| Shift | in a dash / planted | A press in the dash: LMB waits for its end (a tap throws or recalls, held it winds up), RMB, E and Q go mid-dash, X ends the dash and plants him. Shift while planted for Faultline goes when the plant ends. Every pair: [dash_interactions.md](dash_interactions.md) (content/dash_flow/bulwark.json) | Not in the data or footage beyond the Shield Bash and the short dash out of a Hammer Smash | Our picks, nothing dropped |
| Shift | long dash | In the air or out of charges: a lumbering shoulder shove (`bul_lumber`), shoving foes aside | (base dash) | Our per-hero base dash variant |
| E | tap | Mending Ground: round the hammer wherever it is (planted, flying, or on himself with the hammer in hand), following it. A green light column comes down over 1 s with a filling ring everyone sees, then a lasting zone: allies inside get 2 health every 0.5 s for 4 s, and it ends in a burst of 18 (mends the aegis 60 while raised; a downed teammate inside gets a third of the revive). No slow on foes. Cooldown 12 s | Regen Field: a healing zone round the hammer wherever it is, bursting for extra healing | Data: a lasting zone with a burst, 12 s base (8 s at the top rank) |
| X | tap (level 6) | Faultline: planted 0.4 s with the hammer overhead while a 16 m lane of four cells, 4 m long and 4.5 m wide, shows to everyone; the slam strikes the near cell (4, stun 0.3), then the ground erupts cell by cell (0.15 s apart) and throws each foe once (18, stun 0.5, slowed 50% for 1.5 s). A wall or ledge stops it; it runs on over a drop or the abyss (drawn at his height). A glowing scar stays 10 s and slows foes on it 20%. A stun in the wind-up interrupts it (cooldown back to 8 s). He is planted only for the wind-up and the slam (0.6 s); from there he walks at full speed while the lane erupts where it was cast. Cooldown 33 s | Earthshatter / Abyssalbreaker: a fissure down a lane, a small first hit with a brief stun, cascading eruptions with a heavy slow, blocked by walls, a lingering crack | Lane 2.5 bh wide and 8.9 bh long, as the sheet. Eruption 1.5x the throw (source 1.2x) |
| R | - | the Boki Merge | - | R is the Merge for every hero. No slot held a folded Earthshatter, so nothing is unfolded |

## Assumptions (the footage is silent; the owner can correct these)
- He can walk while spinning the hammer (55% speed), as before; the footage only shows him standing.
- The perfect window starts at full charge and lasts 0.18 s (owner default); held past it the swing is a normal one (it still goes off by itself 0.4 s after full). Let go in the air, a normal swing takes no step (he keeps his speed) and a perfect one still launches him (owner #51: "pair it together").
- The perfect launch counts as a dash for DashFlow: it runs through `Hunter.dash_with` like the normal step (move kind "dash"), so his existing dash rows apply unchanged (LMB presses wait for its end, RMB / E / Q go during it, X ends it) and a jump in it is the dash's own jump-out that hands its speed to the glider. Shift in the step or the launch cuts it and dashes at once (owner #51: out of any recovery within 0.1 s).
- The throw's max range is 9 m (never thrown beyond about 7 bh in the footage); a cursor past it lands at 9 m.
- The planted hammer never returns by itself (it comes back if he goes down or out).
- The 360 Smash is a fixed distance (it stopped short of the cursor once) and only invulnerable for its first 0.1 s.
- Knockout is a 0.5 s stun and 8 damage; the old heal (24) is gone (data). The stun length is ours (the data says "Stunned").
- The aegis keeps 160 HP, regenerating 20/s after 2 s down, and he walks at 60% behind it.
- The blue ring on the target before the Smash is the hammer's reveal, not part of the dash.
- The wind-down is a 0.3 s glider lock after the slam and the 360 spin.
- "Begin to resurrect" is +0.35 of a downed teammate's revive bar.
- Faultline: the lane's direction is locked on the press; he can't move, swing, block or dash while planted (0.4 s wind-up and 0.2 s after the slam).
- Faultline: "knocked up" is a 0.5 s stun with a lift; the lingering crack (function unknown in the footage) slows foes on it 20% for its 10 s.
- Faultline: a stun, a knock or going down in the wind-up interrupts it, and the cooldown comes back to 8 s (as the old R fuse did).
- Faultline: a raised ledge or a wall tile stops the fissure at that cell (wiki: blocked by walls); a drop does not (owner), its trail keeps drawing over the abyss; the near cell always strikes.
- Faultline hits each foe once per cast (the near cell's strike, then one eruption).
- The throw flies at least 2.5 m: the owner wants it to land where the cursor is anywhere in range, so the source patch note's 5 m minimum is cut to 2.5 m (a point-blank click still clears his own feet).

## Body and movement (hero sheet: Body, scale and movement feel)
- About 1.15 of a medium tall (content `body.size` 0.975 over the heavy look) and ~1.35 wide (`body.build` 1.18 over the heavy build); the hit radius stays 0.5 so the wider model isn't an easier target.
- Runs pitched far forward (~0.32 rad at a full run), the shield shoulder leading, shoulders square; quick steps at `spd*2.9` (HunterAnim.STRIDE), as fast as the lights.
- His dash after-image is his own: a gold chevron wake at chest height (BjornFx.afterimage), not the shared ghost.
- Nameplate at 2.6 m (`plate_offset` in the archetype JSON, read by `HudPlate.plate_offset(h)`).

## Small mechanics (fine print; source, footage, ours)
| Mechanic | Source | Footage | Ours | Check |
|---|---|---|---|---|
| The throw lands at the cursor, clamped to range | sheet bjorn.md, owner note | confirms (0408, 0024-0029) | built | `bjorn aim: the hammer lands at the cursor` |
| The hammer flies a minimum distance | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Oath) (5 m) | consistent | built at 2.5 m so close clicks land near the cursor (owner: anywhere in range) | `bjorn small: a close cursor still throws 2.5 m` |
| A recall can't come within 0.25 s of the throw | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Oath) | consistent (0.4 s round trips) | built | `bjorn small: a recall in the first 0.25 s is ignored` |
| It passes through enemies, hitting out and back for the same damage | [wiki: Magnetic Hammer](https://supervive.wiki.gg/wiki/Oath) | confirms (0041, 0043) | built | `bulwark LMB` lines |
| Allies get vision round the planted hammer | [wiki](https://supervive.wiki.gg/wiki/Oath) | not visible | built (already ours) | archetype check |
| No automatic return | sheet | 3.6 s+ planted | built | `bjorn: the planted hammer never comes back by itself` |
| Wind-down frames after the swing and the spin: no glider straight away, so momentum carries | [wiki patch 05.02.25](https://supervive.wiki.gg/wiki/Oath) | not visible | built: 0.3 s glide lock after the slam and the 360 spin (not after the perfect launch, which hands its speed to the glider: owner #49) | `bjorn small: wind-down after the slam` |
| Perfect window: launch >= 3.5 m in it, step <= 2 m outside, off a ledge into a glide at >= 70% of the launch speed | owner #49 | (no lunge in the footage) | built | `bjorn #49 ...` (tools/bjorn_launch_check.gd) |
| Ult: free to move from the end of the slam while it erupts | owner #48, sheet f25-f49 | confirms (planted f25-f31, then he shifts) | built | `bjorn #48 ult: ...` |
| Hammer Smash full at 1.25 s | [wiki](https://supervive.wiki.gg/wiki/Oath) | full by 2.4 s | built | `bjorn LMB held: the full-charge flare at 1.25s` |
| Shift during a Hammer Smash: a short dash without the spin, reduced cooldown | [wiki: Spin Dash](https://supervive.wiki.gg/wiki/Oath) | not shown | built as the short dash without the spin; owner #51 keeps the charge, so it costs a full charge (the reduced cooldown went with the ending) | `combo bulwark: hold LMB > Shift` |
| Shield up + Shift: a bash with its own 6 s cooldown, briefly invulnerable | in-game data, [wiki: Shield Bash](https://supervive.wiki.gg/wiki/Oath) | not shown | built: Shield Charge on the RMB slot's cooldown | `combo bulwark: shield up > Shift`, `... spends no dash charge and has its own 6 s cooldown` |
| Any knock into a wall (the Spin Dash included) stuns, no heal | in-game data, [wiki: Valiant Strength](https://supervive.wiki.gg/wiki/Oath) | confirms the stun (0171) | built: any Crushing Blow, the 360 Smash, the Shield Charge and Slam; also into another foe | `combo bulwark: the 360 Smash into the wall Crushes`, `a half-charged blow ... Crushes`, `a Crush no longer heals him` |
| Regen Field: a lasting zone round the hammer with a burst at its end; heals the shield only while it's up; never repairs a broken one | in-game data, [wiki: Regen Field](https://supervive.wiki.gg/wiki/Oath) | confirms the zone (0414) | built: 4 s of ticks, then the burst | `combo bulwark: Mending Ground is a zone`, `bjorn small: Mending Ground doesn't repair a broken aegis` |
| Allied wisps hit by the burst begin to resurrect | [wiki: Regen Field](https://supervive.wiki.gg/wiki/Oath) | not shown | built: a downed teammate inside gets a third of the revive | `bjorn small: a downed teammate ... starts reviving` |
| Ult: a fissure that travels forward from him | [wiki: Abyssalbreaker](https://supervive.wiki.gg/wiki/Oath), sheet | confirms (f29-f39) | built: 4 cells near to far, 0.15 s apart | `bjorn ult payoff` |
| Ult: the first strike is small and briefly stuns; the eruptions hit hard and slow heavily | [wiki](https://supervive.wiki.gg/wiki/Oath) | not legible | built: 4 + stun 0.3, then 18 + stun 0.5 + slow 50% | same |
| Ult: blocked by walls | [wiki](https://supervive.wiki.gg/wiki/Oath) | not shown | built | `bjorn ult small: a wall stops the fissure` |
| Ult: planted for the wind-up and slam, the lane shown first | sheet | confirms (f25-f31) | built | `bjorn ult cast: planted`, `bjorn ult telegraph` |
| Ult: a crack stays about 10 s | sheet | confirms (f43-f71) | built: slows 20% | `bjorn ult small: the scar ...` |
| Ult: interrupted by a stun in the wind-up | ours | - | built | `bjorn ult small: a stun in the wind-up interrupts it` |
| Dash hits refund Shield Bash (rank 4) | in-game data | - | built at rank 3 (our last rank): a 360 Smash that hits refunds the Shield Charge | `combo bulwark: rank 3, a 360 Smash that hits refunds the Shield Charge` |

## Kit data pass (SERVER_UPDATE7, in-game data wins over the footage)
| Item | Before | After | Conversion |
|---|---|---|---|
| E zone | one burst 1 s after the cast, 26 heal, foes slowed 25%, cooldown 11 s | a column for 1 s, then a 4 s zone round the hammer (wherever it is, following it): 2 every 0.5 s, ending in a burst of 18 (the aegis mend 60 and the revive start on the burst); no foe slow | the 4 s zone length, the 2-per-tick and the burst 18 are our picks (the data gives no duration or numbers): a full zone gives 34 against the old 26 |
| E cooldown | 11 s | 12 s (rank 3: 8 s) | seconds taken from the data directly (12 s base, -4 s at the third upgrade) |
| E ranks | rank 2 healing +25%, rank 3 +25% and +0.5 m, +10 heal | rank 2 healing +25%, rank 3 the cooldown to 8 s and healing +50% in all | source II +25% heal, III -4 s, IV +25% heal; our rank 3 folds III and IV |
| Passive | heal 24 on a Crush; only a Bash, Shield Charge or full Crushing Blow could Crush | no heal; any Crushing Blow, the 360 Smash, the Shield Charge and the Shield Slam Crush | stun 0.5 and 8 damage kept (our numbers) |
| Bash | RMB tap or release after a block, plus Shift behind the aegis | Shift behind the aegis only; an RMB tap does nothing | none |
| Shield Charge cooldown | spent a dash charge | its own 6 s cooldown on the RMB slot (the old RMB cooldown number), 4.5 s at dash rank 2, 3 s at rank 3; the HUD shows it on the aegis | 6 s taken directly; the -1.5 s per rank is the data's Shield Bash and Spin Dash upgrade |
| Shield Slam | RMB tap with 50 Guard | the Shield Charge ends in it with 50 Guard (same numbers, a 0.3 s lane tell replaced by the charge) | none |
| Dash refund | missing | rank 3: a 360 Smash that hits a foe refunds the Shield Charge | the data's fourth upgrade lands on our last rank |
| Shield upgrades | rank 3 +60 HP | rank 2 +25% HP (200), rank 3 +50% HP (240), regen 20 -> 30 per second, the post-break lock 3 -> 2 s, the wait 2 -> 1.4 s | +25% per rank from the data; the repair numbers are ours (the data says "faster") |

Rank paths that do not fit our system: the Spin Dash's own cooldown still uses the shared -15% a rank (9 -> 7.65 -> 6.3 s, the data's -1.5 s a rank would be 7.5 -> 6) because the dash recharge is shared code (Hunter.dash_regen); the data's four tiers fold into our three (III and IV share our rank 3); the shared +15% damage a rank applies to the Crush and Slam where the data names no damage upgrade; the data's -1.5 s Shield Bash is on the dash rank here, as the data lists it under the Shift upgrades. Skipped: R (Abyssalbreaker) is the Faultline on X, untouched; the Guard meter stays as our own loop (the data has no such meter, but the Shield Slam payoff depends on it).

## Scaling
Heavy class (193 HP): throw 12 and recall 12; Crushing Blow 36-66 (3x and 5.5x the throw, the source's 3x and 5.6x); 360 Smash 24 (2x the throw); Slam 18; Crushed 8 + stun 0.5; Mending Ground 2 per 0.5 s for 4 s + a burst of 18; Faultline 4 strike + 18 eruption (33 s cooldown, about 3.6x the 360 Smash as in the source). Numbers follow the source's ratios, not its values.

## Cross-ability interactions (combos)
| Combination | Result | Check |
|---|---|---|
| Throw at a 5 m cursor | Lands and stays planted 5 m away under the beacon; a far cursor clamps to 9 m | `--bulwark-combo-check` |
| Hammer planted, then E | Mending Ground blooms where the hammer stands | same |
| Hammer in hand, then E | It comes down on him | same |
| Hold LMB 1.25 s, release | Spin, glint from 0.6 s, flare at full, then the slam steps him forward with a crescent | same |
| Hold LMB, release in the window | Perfect swing: the launch, a harder knock and hit-stop | `bjorn #49` lines |
| Perfect swing off a ledge / glide pressed in it | Straight into a glide at the launch's speed (the shared hand-off) | same |
| Faultline, then walk | Planted 0.6 s, then full speed while the lane erupts behind | `bjorn #48` lines |
| Full Crushing Blow into a wall | Crushed | same |
| Half-charged blow into a wall | Crushed too (any knock) | same |
| RMB tap | Nothing (no Bash on the RMB) | same |
| Aegis up, Shift | Shield Charge on its own 6 s cooldown, Crushed on a wall (stun, no heal); at 50 Guard it ends in a Shield Slam | same |
| 360 Smash at a foe | No hit on the way, one spin hit on arrival; into a wall it Crushes; at rank 3 a hit refunds the Shield Charge | same |
| Hold LMB, Shift | Short dash on a full charge, still charging; let go in it, the swing goes at once | same, `bjorn #51` lines |
| Hold LMB, jump, let go in the air | Charges on through the jump; the swing goes in the air, no step, his speed kept | `bjorn #51` lines |
| Hold LMB, jump or Shift, let go in the window | The perfect launch from there (in the air, at his height) | same |
| Swing's step or perfect launch, then jump or Shift | Acts within 0.1 s | same |
| E with the aegis down / raised | Ticks heal; the burst heals / heals and mends it |
| Hammer recalled while the zone stands | The zone follows it back to him | same |
| A Boki merge mid spin / aegis | The charge drops with no swing; the aegis comes down keeping its HP | same |
| Aegis up, then Faultline | The aegis comes down as he plants | `--bulwark-combo-check` |
| Faultline down a line of foes | Each thrown once; the bond pays the cast's best event once | same |
| Faultline toward a ledge | Stops at the ledge | same |
| A merge in the Faultline wind-up | No slam; a fissure already running finishes | same |
| Faultline then a merge on a full-health light hunter | Standing (burst cap) | same |

## Animations (KMovesPinBjorn ids per ability; timed to 5 fps footage frames)
| Ability | Move id(s) | Notes |
|---|---|---|
| LMB tap (throw) | `bul_throw` | cocked low and behind one frame (0.07 s), the overhand throw (0.14 s); the hammer leaves the hand ~0.12 s after the press, as the arm comes through |
| LMB tap again (recall) | `bul_recall` | hand out, the catch |
| LMB hold (wind-up) | `bul_smash_wind` (held) | sheet 0133-0145: side-on and crouched, the hammer dragged back low behind him over 0.15 s (BjornFx cocks the model's "Hammer" pivot), the shield arm forward, the coil deepening; at full the coil (`BUL_COIL`): twisted hardest away, sunk lowest |
| LMB release (Crushing Blow) | `bul_smash` | from the coil, sweep from behind to front in one frame, crash down, the step, 0.4 s recovery |
| LMB release in the window (perfect) | `bul_launch` | from the coil, a full-body heave after the hammer (stretched, the back leg driving), airborne with the knees tucked over the 0.3 s launch, the front leg reaching, a hard braced plant and skid, a slow rise |
| RMB hold (aegis) | `bul_guard` (held) | braced low behind it |
| Shield Slam (Guard 50, Shift behind the aegis) | `bul_slamshield` | played as the charge arrives |
| Aegis broken | `bul_break` | rocked back, shield arm flung wide |
| Shift (360 Smash) | `bul_whirl` | a hard 0.17 s run-up, one full turn in 0.16 s with the hammer at arm's length while he slides on, a low crouched recovery to 0.58 s |
| Shift aegis up / LMB held / long dash | `bul_charge`, `bul_short`, `bul_lumber` | |
| E (Mending Ground) | `bul_mend` | hammer hauled to the sky, driven down |
| Payoffs / procs | `bul_crush`, `bul_armed` | the hammer raised in triumph; a Guard pip shrug |
| X (Faultline), 10 fps beats | `bul_ult_wind` (held), `bul_ult_slam` | planted wide, the hammer hauled overhead and leaning back (0.4 s); one frame down into the ground, a deep crouch through the 0.2 s plant, then the legs free to walk while the back comes up |
Strips: `--arena-demo=anim_<id> --arena-shot=<png>`.

## Engine notes
- Kit: `scripts/arch/kits/bulwark_kit.gd`, `bjorn_fx.gd` (pooled effects: hammer, beacon, glint, flare, crescent, swirl, aegis, column, disc), `kit_shaders.gd` / `kit_meshes.gd`, `scripts/match/pin_bjorn_weapons.gd` (war hammer under a "Hammer" pivot, the aegis-sigil tower shield), `scripts/match/kmoves_pin_bjorn.gd`. Data: `content/archetypes/bulwark.json` (`lmb.carry`, `lie_t` 0 = never auto-recall, `dash.spin_r`), `content/weapons/tower_shield.json`.
- The throw uses `AimMode.dist(h, throw_range)`; the slam's step is a 0.24 s `Hunter.dash_with` (no dash rider). The perfect launch is `scripts/arch/kits/bjorn_launch.gd` (BjornLaunch: the window, the launch, the jump-out and the off-ledge glide); data `lmb.perfect` (`window`, `dist`, `time`, `kb_k`).
- The aegis draws over the verbs wall (its plain node hidden); the wall still does the blocking.
- Telegraphs and cursor: `AimKit.charge` / `flare` during the spin, `AimKit.circle` "e" (all) while Mending Ground comes down.
- Sounds: `tools/gen_pin_bjorn_sfx.py` writes `audio/bjorn_*.wav`.
- Merge: `_drop_holds()` drops the spin (`lmb_t`, `h.mel_hold`, the spinning hammer and glint), lowers the aegis, and drops the Faultline wind-up (`BjornUlt.phase == "wind"`).
- Ult on X: `scripts/arch/hero_ult.gd` (HeroUlt, the shared X base: `cast_ult` returns `HeroUlt.press(self, _start_ult)` behind main's `HunterKeys.ult_pressed`), `scripts/arch/kits/bjorn_ult.gd` (BjornUlt: the lane, the slam, the eruptions, the scar, pooled basalt spikes, seams, streak and scar). Data: `content/archetypes/bulwark.json` `x`. Sounds: `bjorn_ult_wind`, `bjorn_ult_slam`, `bjorn_ult_rumble`, `bjorn_ult_crackle`. Telegraph: one AimKit `lane` per cell (`x0`..`x3`, `all`).
- No Net shape change.

## Payoff
CRUSHED: stun, heal, T4 hitstop and shake, own sound, `bul_crush`.
