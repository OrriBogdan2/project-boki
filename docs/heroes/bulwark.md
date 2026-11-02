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
| LMB | tap | War hammer thrown to the cursor (clamped to 9 m, at least 1.5 m), 24 m/s, through foes (12); stays planted (tilted in the ground under a gold beacon ray with rising chevrons, your team sees foes within 4.5 m) until called back | Lands at the cursor, stays until recalled | Matches; no auto-return |
| LMB | tap again | Recall: flies back hitting on the way (12), caught with an ember flash | 175 out, 175 back | Equal hits, as the source |
| LMB | hold | Owner note: the hammer spins in his hand, faster as it charges, while he keeps facing the cursor (walks at 55%); a glint on the head from 0.6 s that grows, a flare and a cursor flare at full (1.25 s). Release: Crushing Blow 36-66 (3x-5.5x the throw), 180 degree reach 2.8 m, knock 5-13, stun 0.4 at full; a flaming crescent (white-yellow core, orange and red edges); the slam carries him 1.6-3.4 m forward in 0.2 s; white dust on the target, a debris trail as it flies | A static charged swing, no lunge (footage) | Spinning and the forward carry follow the owner; glint, flare, crescent and ratios follow the footage |
| RMB | hold | His aegis: a curved gold slab (3 m chord) with ribs, a hammer sigil and a bright rim, shimmering; sparks and a flash on each block, cracks as it weakens, gold shards and SHIELD BROKEN when it breaks (locked 3 s) | Curved pale gold slab, sparks, a break burst | Matches, our own look |
| RMB | tap / release | Bash (cone 2.6 m, 12, push 9); Guard 50+: Shield Slam (0.3 s tell, 18, stun 0.6) | Bash only as an augment | Kept as our documented extension |
| Shift | tap | 360 Smash: a fixed 4.2 m dash (18 m/s), then one full spin hit around him (2.2 m, 24 = 2x the throw, push 7) with a red-gold swirl ring | Short fixed dash, one 360 spin on arrival (350 = 2x the throw) | Matches; cooldown 9 s (source 9.2) |
| Shift | aegis up | Shield Charge (4.2 m, invulnerable, 10, push 11, Crushed on a wall) | - | Our extension, kept |
| Shift | LMB held | a short plain dash, half a charge, the spin keeps charging | - | Our extension, kept |
| Shift | long dash | In the air or out of charges: a lumbering shoulder shove (`bul_lumber`), shoving foes aside | (base dash) | Our per-hero base dash variant |
| E | tap | Mending Ground: at the planted hammer, or on himself with the hammer in hand; a green light column comes down over 1 s with a filling ring everyone sees, then a green ring bloom: heals allies inside 26 (mends the aegis 60 while raised), slows foes | Purify Zone at the hammer or on himself | Matches |
| R | - | none (R is the Merge) | Earthshatter | Folded away: the loop is block, knock into walls, heal |

## Assumptions (the footage is silent; the owner can correct these)
- He can walk while spinning the hammer (55% speed), as before; the footage only shows him standing.
- The throw's max range is 9 m (never thrown beyond about 7 bh in the footage); a cursor past it lands at 9 m.
- The planted hammer never returns by itself (it comes back if he goes down or out).
- The 360 Smash is a fixed distance (it stopped short of the cursor once) and only invulnerable for its first 0.1 s.
- Knockout keeps our heal (24) and a 0.5 s stun.
- The aegis keeps 160 HP, regenerating 20/s after 2 s down, and he walks at 60% behind it.
- The blue ring on the target before the Smash is the hammer's reveal, not part of the dash.

## Scaling
Heavy class (193 HP): throw 12 and recall 12; Crushing Blow 36-66 (3x and 5.5x the throw, the source's 3x and 5.6x); 360 Smash 24 (2x the throw); Bash 12, Slam 18; Crushed 8 + stun 0.5 + heal 24; Mending Ground 26. Numbers follow the source's ratios, not its values.

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
| Shift (360 Smash) | `bul_whirl` | dash lean 0.22 s, then one full turn |
| Shift aegis up / LMB held / long dash | `bul_charge`, `bul_short`, `bul_lumber` | |
| E (Mending Ground) | `bul_mend` | hammer hauled to the sky, driven down |
| Payoffs / procs | `bul_crush`, `bul_armed` | the hammer raised in triumph; a Guard pip shrug |
Strips: `--arena-demo=anim_<id> --arena-shot=<png>`.

## Engine notes
- Kit: `scripts/arch/kits/bulwark_kit.gd`, `bjorn_fx.gd` (pooled effects: hammer, beacon, glint, flare, crescent, swirl, aegis, column, disc), `kit_shaders.gd` / `kit_meshes.gd`, `scripts/match/pin_bjorn_weapons.gd` (war hammer under a "Hammer" pivot, the aegis-sigil tower shield), `scripts/match/kmoves_pin_bjorn.gd`. Data: `content/archetypes/bulwark.json` (`lmb.carry`, `lie_t` 0 = never auto-recall, `dash.spin_r`), `content/weapons/tower_shield.json`.
- The throw uses `AimMode.dist(h, throw_range)`; the slam's carry is a 0.2 s `Hunter.dash_with` (no dash rider, no dash sound).
- The aegis draws over the verbs wall (its plain node hidden); the wall still does the blocking.
- Telegraphs and cursor: `AimKit.charge` / `flare` during the spin, `AimKit.circle` "e" (all) while Mending Ground comes down.
- Sounds: `tools/gen_pin_bjorn_sfx.py` writes `audio/bjorn_*.wav`.
- Merge: `_drop_holds()` drops the spin (`lmb_t`, `h.mel_hold`, the spinning hammer and glint), lowers the aegis.
- No Net shape change.

## Payoff
CRUSHED: stun, heal, T4 hitstop and shake, own sound, `bul_crush`.
