# Bjorn (id `bulwark`, Heavy) - fidelity pass (hero sheet bjorn.md)

Behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (internal note; nothing of the source's names or look ships). Player-facing names are our own. Display name Bjorn (was Bulwark); the id, files and save keys stay `bulwark`. The minigun ability that was also called "Bulwark" (content/abilities/bulwark.json) is now Bracewall.

## Research summary
Sources (gameplay only; notes in our own words, nothing of the source ships):
- The hero sheet `briefs/hero-ref/bjorn.md`, written from 5 fps gameplay footage (one frame = 0.2 s). Its ranked gap list drove this pass.
- The owner playtest notes (sync61), which override the footage: LMB hold spins the hammer, release is a strong slam that carries him forward; the throw lands at the cursor; his shield looks unique to him.
- The earlier accuracy pass for what the footage doesn't show.

What the source does: tap throws the hammer to the cursor, where it stays planted under a tall light ray until a second tap calls it back (equal hits out and back); holding charges one big forward swing (about 3x the throw at minimum, 5.6x full) with a growing glint on the head, a full-charge flare and a flaming 180 degree crescent; a curved gold barrier shield held to the cursor; Shift is a short fixed dash ending in one 360 spin hit (2x the throw); E heals at the planted hammer (on himself with the hammer in hand), a light column coming down first. Knockout: hitting foes into walls stuns them.

## Per-slot table (slot, input, our behaviour, source behaviour, difference and why)
| Slot | Input | What it does now (our words) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive | knock into wall/foe | Crushed: stun 0.5, 8 damage, heal 24 (Bash, Shield Charge, full Crushing Blow); Guard from blocking (50 = Shield Slam) | Knockout: knocked into a wall, stunned | The heal and Guard stay our own loop (the footage neither confirms nor contradicts the heal) |
| LMB | tap | War hammer thrown to the cursor (clamped to 9 m, at least 2.5 m), 24 m/s, through foes (12); stays planted (head-down in the ground under an upright gold beacon ray with rising chevrons, your team sees foes within 4.5 m) until called back | Lands at the cursor, stays until recalled | Matches; no auto-return |
| LMB | tap again | Recall: flies back hitting on the way (12), caught with an ember flash | 175 out, 175 back | Equal hits, as the source |
| LMB | hold | Owner note: the hammer spins in his hand, faster as it charges, while he keeps facing the cursor (walks at 55%); a glint on the head from 0.6 s that grows, a flare and a cursor flare at full (1.25 s). Release: Crushing Blow 36-66 (3x-5.5x the throw), 180 degree reach 2.8 m, knock 5-13, stun 0.4 at full; a flaming crescent (white-yellow core, orange and red edges); the slam carries him 1.6-3.4 m forward in 0.24 s; white dust on the target, a debris trail as it flies | A static charged swing, no lunge (footage) | Spinning and the forward carry follow the owner; glint, flare, crescent and ratios follow the footage |
| RMB | hold | His aegis: a curved gold slab (3 m chord) with ribs, a hammer sigil and a bright rim, shimmering; sparks and a flash on each block, cracks as it weakens, gold shards and SHIELD BROKEN when it breaks (locked 3 s) | Curved pale gold slab, sparks, a break burst | Matches, our own look |
| RMB | tap / release | Bash (cone 2.6 m, 12, push 9); Guard 50+: Shield Slam (0.3 s tell, 18, stun 0.6) | Bash only as an augment | Kept as our documented extension |
| Shift | tap | 360 Smash: a hard fixed 3.5 m dash (~20 m/s, 0.17 s, the sheet's run-up), sliding on about 1 m through one full spin hit around him (2.2 m, 24 = 2x the throw, push 7) with a red-gold swirl ring | Short fixed dash, one 360 spin on arrival (350 = 2x the throw) | Matches; cooldown 9 s (source 9.2) |
| Shift | aegis up | Shield Charge (4.2 m, invulnerable, 10, push 11, Crushed on a wall) | - | Our extension, kept |
| Shift | LMB held | a short plain dash, half a charge, the spin keeps charging | - | Our extension, kept |
| Shift | long dash | In the air or out of charges: a lumbering shoulder shove (`bul_lumber`), shoving foes aside | (base dash) | Our per-hero base dash variant |
| E | tap | Mending Ground: at the planted hammer, or on himself with the hammer in hand; a green light column comes down over 1 s with a filling ring everyone sees, then a green ring bloom: heals allies inside 26 (mends the aegis 60 while raised), slows foes. Cooldown 11 s | Purify Zone at the hammer or on himself (10 s) | Matches the source ratio to the 360 Smash (10 : 9.2) |
| X | tap (level 6) | Faultline: planted 0.4 s with the hammer overhead while a 16 m lane of four cells, 4 m long and 4.5 m wide, shows to everyone; the slam strikes the near cell (4, stun 0.3), then the ground erupts cell by cell (0.15 s apart) and throws each foe once (18, stun 0.5, slowed 50% for 1.5 s). A wall, ledge or drop stops it. A glowing scar stays 10 s and slows foes on it 20%. A stun in the wind-up interrupts it (cooldown back to 8 s). Cooldown 33 s | Earthshatter / Abyssalbreaker: a fissure down a lane, a small first hit with a brief stun, cascading eruptions with a heavy slow, blocked by walls, a lingering crack | Lane 2.5 bh wide and 8.9 bh long, as the sheet. Eruption 1.5x the throw (source 1.2x) |
| R | - | the Boki Merge | - | R is the Merge for every hero. No slot held a folded Earthshatter, so nothing is unfolded |

## Assumptions (the footage is silent; the owner can correct these)
- He can walk while spinning the hammer (55% speed), as before; the footage only shows him standing.
- The throw's max range is 9 m (never thrown beyond about 7 bh in the footage); a cursor past it lands at 9 m.
- The planted hammer never returns by itself (it comes back if he goes down or out).
- The 360 Smash is a fixed distance (it stopped short of the cursor once) and only invulnerable for its first 0.1 s.
- Knockout keeps our heal (24) and a 0.5 s stun.
- The aegis keeps 160 HP, regenerating 20/s after 2 s down, and he walks at 60% behind it.
- The blue ring on the target before the Smash is the hammer's reveal, not part of the dash.
- The wind-down is a 0.3 s glider lock after the slam and the 360 spin.
- "Begin to resurrect" is +0.35 of a downed teammate's revive bar.
- Faultline: the lane's direction is locked on the press; he can't move, swing, block or dash while planted (0.4 s wind-up and 0.2 s after the slam).
- Faultline: "knocked up" is a 0.5 s stun with a lift; the lingering crack (function unknown in the footage) slows foes on it 20% for its 10 s.
- Faultline: a stun, a knock or going down in the wind-up interrupts it, and the cooldown comes back to 8 s (as the old R fuse did).
- Faultline: a raised ledge, a wall tile or a drop stops the fissure at that cell (wiki: blocked by walls); the near cell always strikes.
- Faultline hits each foe once per cast (the near cell's strike, then one eruption).
- The throw flies at least 2.5 m: the owner wants it to land where the cursor is anywhere in range, so the source patch note's 5 m minimum is cut to 2.5 m (a point-blank click still clears his own feet).
- Mending Ground's cooldown is 11 s against the 360 Smash's 9 s, the source's ratio (10 : 9.2).

## Body and movement (hero sheet: Body, scale and movement feel)
- About 1.15 of a medium tall (content `body.size` 0.975 over the heavy look) and ~1.35 wide (`body.build` 1.18 over the heavy build); the hit radius stays 0.5 so the wider model isn't an easier target.
- Runs pitched far forward (~0.32 rad at a full run), the shield shoulder leading, shoulders square; quick steps at `spd*2.9` (HunterAnim.STRIDE), as fast as the lights.
- His dash after-image is his own: a gold chevron wake at chest height (BjornFx.afterimage), not the shared ghost.
- Nameplate at 2.6 m (`body.plate`, ArchKit.plate_height for the HUD branch to read).

## Small mechanics (fine print; source, footage, ours)
| Mechanic | Source | Footage | Ours | Check |
|---|---|---|---|---|
| The throw lands at the cursor, clamped to range | sheet bjorn.md, owner note | confirms (0408, 0024-0029) | built | `bjorn aim: the hammer lands at the cursor` |
| The hammer flies a minimum distance | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Oath) (5 m) | consistent | built at 2.5 m so close clicks land near the cursor (owner: anywhere in range) | `bjorn small: a close cursor still throws 2.5 m` |
| A recall can't come within 0.25 s of the throw | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Oath) | consistent (0.4 s round trips) | built | `bjorn small: a recall in the first 0.25 s is ignored` |
| It passes through enemies, hitting out and back for the same damage | [wiki: Magnetic Hammer](https://supervive.wiki.gg/wiki/Oath) | confirms (0041, 0043) | built | `bulwark LMB` lines |
| Allies get vision round the planted hammer | [wiki](https://supervive.wiki.gg/wiki/Oath) | not visible | built (already ours) | archetype check |
| No automatic return | sheet | 3.6 s+ planted | built | `bjorn: the planted hammer never comes back by itself` |
| Wind-down frames after the swing and the spin: no glider straight away, so momentum carries | [wiki patch 05.02.25](https://supervive.wiki.gg/wiki/Oath) | not visible | built: 0.3 s glide lock after the slam and the 360 spin | `bjorn small: wind-down after the slam` |
| Hammer Smash full at 1.25 s | [wiki](https://supervive.wiki.gg/wiki/Oath) | full by 2.4 s | built | `bjorn LMB held: the full-charge flare at 1.25s` |
| Shift during a Hammer Smash: a short dash without the spin, reduced cooldown | [wiki: Spin Dash](https://supervive.wiki.gg/wiki/Oath) | not shown | built (already ours: half a charge) | `combo bulwark: hold LMB > Shift` |
| Shield up + Shift: a bash, briefly invulnerable | [wiki: Shield Bash](https://supervive.wiki.gg/wiki/Oath) | not shown | built: Shield Charge | `combo bulwark: shield up > Shift` |
| Knock into a wall or another enemy (Shield Bash or full Smash) stuns 0.5 s, heals | [wiki: Valiant Strength](https://supervive.wiki.gg/wiki/Oath) | confirms the stun (0171) | built | `combo bulwark: Bash > wall` |
| Regen Field: at the hammer, bonus burst after a delay; heals the shield only while it's up; never repairs a broken one | [wiki: Regen Field](https://supervive.wiki.gg/wiki/Oath) | confirms the zone (0414) | built | `bjorn small: Mending Ground doesn't repair a broken aegis` |
| Allied wisps hit by the burst begin to resurrect | [wiki: Regen Field](https://supervive.wiki.gg/wiki/Oath) | not shown | built: a downed teammate inside gets a third of the revive | `bjorn small: a downed teammate ... starts reviving` |
| Ult: a fissure that travels forward from him | [wiki: Abyssalbreaker](https://supervive.wiki.gg/wiki/Oath), sheet | confirms (f29-f39) | built: 4 cells near to far, 0.15 s apart | `bjorn ult payoff` |
| Ult: the first strike is small and briefly stuns; the eruptions hit hard and slow heavily | [wiki](https://supervive.wiki.gg/wiki/Oath) | not legible | built: 4 + stun 0.3, then 18 + stun 0.5 + slow 50% | same |
| Ult: blocked by walls | [wiki](https://supervive.wiki.gg/wiki/Oath) | not shown | built | `bjorn ult small: a wall stops the fissure` |
| Ult: planted for the wind-up and slam, the lane shown first | sheet | confirms (f25-f31) | built | `bjorn ult cast: planted`, `bjorn ult telegraph` |
| Ult: a crack stays about 10 s | sheet | confirms (f43-f71) | built: slows 20% | `bjorn ult small: the scar ...` |
| Ult: interrupted by a stun in the wind-up | ours | - | built | `bjorn ult small: a stun in the wind-up interrupts it` |
| Dash hits refund Shield Bash (rank 4) | [wiki](https://supervive.wiki.gg/wiki/Oath) | - | not built: our ranks stop at 3 | - |

## Scaling
Heavy class (193 HP): throw 12 and recall 12; Crushing Blow 36-66 (3x and 5.5x the throw, the source's 3x and 5.6x); 360 Smash 24 (2x the throw); Bash 12, Slam 18; Crushed 8 + stun 0.5 + heal 24; Mending Ground 26; Faultline 4 strike + 18 eruption (33 s cooldown, about 3.6x the 360 Smash as in the source). Numbers follow the source's ratios, not its values.

## Cross-ability interactions (combos)
| Combination | Result | Check |
|---|---|---|
| Throw at a 5 m cursor | Lands and stays planted 5 m away under the beacon; a far cursor clamps to 9 m | `--bulwark-combo-check` |
| Hammer planted, then E | Mending Ground blooms where the hammer stands | same |
| Hammer in hand, then E | It comes down on him | same |
| Hold LMB 1.25 s, release | Spin, glint from 0.6 s, flare at full, then the slam carries him forward with a crescent | same |
| Full Crushing Blow into a wall | Crushed | same |
| Half-charged blow into a wall | No Crush | same |
| Bash into a wall | Crushed: stun 0.5, heal | same |
| Aegis up, Shift | Shield Charge, Crushed on a wall | same |
| 360 Smash at a foe | No hit on the way, one spin hit on arrival, no Crush | same |
| Hold LMB, Shift | Short dash for half a charge, still charging | same |
| E with the aegis down / raised | Heals / heals and mends it | same |
| A Boki merge mid spin / aegis | The charge drops with no swing; the aegis comes down keeping its HP | same |
| Aegis up, then Faultline | The aegis comes down as he plants | `--bulwark-combo-check` |
| Faultline down a line of foes | Each thrown once; the bond pays the cast's best event once | same |
| Faultline toward a ledge | Stops at the ledge | same |
| A merge in the Faultline wind-up | No slam; a fissure already running finishes | same |
| Faultline then a merge on a full-health light hunter | Standing (burst cap) | same |

## Animations (KMovesPinBjorn ids per ability; timed to 5 fps footage frames)
| Ability | Move id(s) | Notes |
|---|---|---|
| LMB tap (throw) | `bul_throw` | cocked low and behind one frame, overhand throw |
| LMB tap again (recall) | `bul_recall` | hand out, the catch |
| LMB hold (spin) | `bul_smash_wind` (held) | side-on, crouched, hammer arm out, the hammer spinning (BjornFx turns the model's "Hammer" pivot) |
| LMB release (Crushing Blow) | `bul_smash` | sweep from behind to front in one frame, crash down, lunge, 0.4 s recovery |
| RMB hold (aegis) | `bul_guard` (held) | braced low behind it |
| RMB tap / release (Bash) | `bul_bash`; Shield Slam `bul_slamshield` | the slam has its own 0.3 s wind-up |
| Aegis broken | `bul_break` | rocked back, shield arm flung wide |
| Shift (360 Smash) | `bul_whirl` | a hard 0.17 s run-up, one full turn in 0.16 s with the hammer at arm's length while he slides on, a low crouched recovery to 0.58 s |
| Shift aegis up / LMB held / long dash | `bul_charge`, `bul_short`, `bul_lumber` | |
| E (Mending Ground) | `bul_mend` | hammer hauled to the sky, driven down |
| Payoffs / procs | `bul_crush`, `bul_armed` | the hammer raised in triumph; a Guard pip shrug |
| X (Faultline), 10 fps beats | `bul_ult_wind` (held), `bul_ult_slam` | planted wide, the hammer hauled overhead and leaning back (0.4 s); one frame down into the ground, a deep crouch, a slow rise |
Strips: `--arena-demo=anim_<id> --arena-shot=<png>`.

## Engine notes
- Kit: `scripts/arch/kits/bulwark_kit.gd`, `bjorn_fx.gd` (pooled effects: hammer, beacon, glint, flare, crescent, swirl, aegis, column, disc), `kit_shaders.gd` / `kit_meshes.gd`, `scripts/match/pin_bjorn_weapons.gd` (war hammer under a "Hammer" pivot, the aegis-sigil tower shield), `scripts/match/kmoves_pin_bjorn.gd`. Data: `content/archetypes/bulwark.json` (`lmb.carry`, `lie_t` 0 = never auto-recall, `dash.spin_r`), `content/weapons/tower_shield.json`.
- The throw uses `AimMode.dist(h, throw_range)`; the slam's carry is a 0.2 s `Hunter.dash_with` (no dash rider, no dash sound).
- The aegis draws over the verbs wall (its plain node hidden); the wall still does the blocking.
- Telegraphs and cursor: `AimKit.charge` / `flare` during the spin, `AimKit.circle` "e" (all) while Mending Ground comes down.
- Sounds: `tools/gen_pin_bjorn_sfx.py` writes `audio/bjorn_*.wav`.
- Merge: `_drop_holds()` drops the spin (`lmb_t`, `h.mel_hold`, the spinning hammer and glint), lowers the aegis, and drops the Faultline wind-up (`BjornUlt.phase == "wind"`).
- Ult on X: `scripts/arch/hero_ult.gd` (HeroUlt, the shared X base: `cast_ult` returns `HeroUlt.press(self, _start_ult)` behind main's `HunterKeys.ult_pressed`), `scripts/arch/kits/bjorn_ult.gd` (BjornUlt: the lane, the slam, the eruptions, the scar, pooled basalt spikes, seams, streak and scar). Data: `content/archetypes/bulwark.json` `x`. Sounds: `bjorn_ult_wind`, `bjorn_ult_slam`, `bjorn_ult_rumble`, `bjorn_ult_crackle`. Telegraph: one AimKit `lane` per cell (`x0`..`x3`, `all`).
- No Net shape change.

## Payoff
CRUSHED: stun, heal, T4 hitstop and shake, own sound, `bul_crush`.
