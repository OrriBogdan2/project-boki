# Sable the Silver Thief (archetype id `thief`, light)

Branch history: kits2 ported the kit from the source hero, kits2-nor (Nov 2) removed its R,
ext/kitfix-dancer-juggernaut (Nov 2, server update 5) matched it to the gameplay footage and renamed the hero
from Thief to Dancer, and the ult pass (server update 6) gave her own ultimate back on X. Player-facing names and text are ours; the source is named only in this research
section, in docs/ARCHETYPES.md and in docs/wiki/Inspirations.md. Ids and file names stay `thief`.

## Research summary

- **Source hero:** Shiv, from SUPERVIVE. The kit now follows the footage reference sheet
  (`briefs/hero-ref/dancer.md`, frames at 5 fps) where it disagrees with the wiki text.
- **The big change:** the source's left click is a ranged bolt from alternating hands that stops at the
  cursor. Our old signature (Twin Blades, a melee combo) is replaced by **Arc Bolts** (our name, our model).
- **Not reproduced:** mana (the game has none), the dagger sticking to moving props.

## Scaling

Ratios, not raw numbers: a bolt is 13 (the source basic attack, 137; raised from 9 on the owner's "plain autos carry her"), the empowered bolt is 2.34x (the data's +214 on 160),
a Mark is +10% of a bolt (the data's +16 on its 160 bolt), the Bola is 5 (74) and +13 for a pair (199), an Encore blade
is 4 and +2 from the outer band (the source's 0.2s cadence, item 54: twice the blades of the old 8 and +4, the same
40 and 60 over a cast; the old pair was about 0.9 of a bolt, 114-127 against 137, and the card's +50%, 36 + 19%
against +18 + 9.5%). Cooldown ratios: Vault 4.5s (Cartwheel 4.2), Bola 7s (Trickshot 6.7), Shadow Knife 15s (Phantom
Dagger 15), Encore 24s (Death Blossom 23.1, about 3.5 Trickshots).

## Feel pass (item 7)

Owner review 1103 item 7: her Cartwheel, the empowered bolt after it and the reset are the source's identity.
[game data] is briefs/supervive-data/supervive_kits.md (Shiv, read at level 15); [footage] is
briefs/hero-ref/dancer.md (5 fps, a frame is 0.2s; px at 1 px = 0.0375 m). Asserted in `--dancer-combo-check`
(tools/dancer_feel_check.gd, lines `dancer feel: ...`).

| What | Source | Ours before | Ours now |
|---|---|---|---|
| Ground Cartwheel distance | 105-144 px, about 4.5m (3.9-5.4) [footage] | 4.5m x the global dash feel = 3.8m | 4.5m (taken off the global dash feel, content/rules/dash_feel.json) |
| Ground Cartwheel time | 0.37-0.57s above run speed; crouch 0.05s, over the top by 0.3, landing crouch, upright by about 0.5s [footage] | 0.42s x 1.15 = 0.48s | 0.48s (the `thf_vault` keys: crouch 0.05, over the top 0.30, landing 0.36, up 0.48) |
| Ground speed curve | peak 15-16.5 m/s at +0.1-0.27s, then a steady run-down into the faster run [footage] | the same curve, peak about 12.5 m/s | peak about 14.8 m/s at 0.14s |
| Air Cartwheel | 225 px, about 8.4m over about 0.95s, about 2x run speed held until she lands [footage] | 8m x 0.85 = 6.8m over 1.09s | 8.4m over 0.95s, held to the landing |
| Cooldown, charges | 5s at rank IV, 6 mana, 1 charge [game data]; the card in the footage says 4.2s [footage] | 4.5s, 1 charge | unchanged (between the two; landing the shot resets it anyway) |
| What empowers | the dash empowers the next Arcslinger [game data]; from a jump too (0129-0143) [footage] | the dash, ground and air (its dash -> LMB row) | unchanged |
| How long it waits | not given; the gold aim line held about 0.8s before the shot (0139-0143) [footage] | 3s | unchanged (an assumption) |
| Empowered damage | +214 on a 160 bolt, so 2.34x [game data]; 474 and 561 on a 137 bolt in the footage, which is 2.34x plus about 9 and 14 stacks of +17 [footage, derived] | 3.5x the bolt, Marks multiplying all of it | a bolt plus 1.34 bolts (2.34x); Marks add 10% of a bolt each, flat, as the source's +16 a stack |
| Empowered ranks | +20% damage twice [game data] | +20% / +40% on the whole shot | +20% / +40% on the bonus (2.61x, 2.88x) |
| Empowered extras | an Arcslinger hit: 1 stack [game data] | 2 Marks and Shred (+15% damage taken, 3s) | 2 Marks (the owner's spec: the empowered hit stacks faster; MAIN_TO_EXT 03:20); Shred gone (not in the source) |
| Empowered range, look | 850 -> 950 units (+12%) [game data, wiki]; a large yellow lightning streak carrying a blue chakram, a vertical blue blade flash at her hands, a red-white flash on the target (0143, 0187) [footage] | +12%; the blue chakram in a gold streak; the shared payoff burst (two rings and 36 sparks) on the target | +12%; the same bolt; on the hit a blue-white star and an upright blue blade arc, no rings or burst |
| The throw | 2-3 frames, one arm whipped from a wide stance [footage] | the body pitched, no arm keys | `thf_primed`: coiled with both blades cocked behind the shoulders, both driven out at 0.04, held to 0.12, a recoil onto the heels by 0.24, settled by 0.55 |
| Auto rate | 0.45s [footage card] | 0.45s | unchanged |
| Reset | landing the empowered shot resets Quickflip and refunds its mana [game data]; hit at 0187, the next Cartwheel at 0193 [footage] | the Vault back on the hit | unchanged, asserted on the hit's own step; a cyan star at her hip and the `thf_reset` heel snap |
| Speed boost | Quickflip gives one (rank IV makes it +50% bigger) [game data]; +15-20% for about 1-1.5s after a Cartwheel [footage] | +18% for 2s at most, ended by firing the empowered bolt | unchanged |
| Dash -> shot rhythm | 0193: the Cartwheel and the empowered shot leave on the same frame (mid-flip); 0137 -> 0143: up after the flip, the gold line, the shot about 1s later; the loop about 1.4s (0187 -> 0194) [footage] | fires mid-flip (row `fire`); a click while the last bolt still cooled was lost | the same, and a click while the bolt cools (mid-flip too) is kept for one bolt's interval and goes the moment it can; two empowered hits fit inside 1.4s with LMB held |

## Audit (Nov 3 23:40)

The kit audit (briefs/specs/kit-audit/vex_vireo_sable.md, Sable rows, against main 200effce), row by row: (a) already
done on this branch, (b) fixed now, (c) not applicable or disagree, with the source. Asserts are in
`--dancer-combo-check` (tools/dancer_parity_check.gd, dancer_feel_check.gd, dancer_jug_check.gd).

| Row (sev) | Call | What and where |
|---|---|---|
| Plain bolt too weak, prime 3.5x (HIGH) | (a) / (b) | The empowered bolt is 2.34x (the data's +214 on 160): f6bb27c3 (dancer-feel). The plain bolt is now 13, up from 9 (the owner's "plain autos carry her", MAIN_TO_EXT 03:20; 137 in the footage at our ~1/10 scale). Assert `Sable audit: the plain bolt deals 13 ...` |
| The mid-flip empowered shot has no body read (MED) | (b) | A bolt thrown mid-cartwheel now whips both blades out in a V (the cartwheel moves carry `"swing": 2`, the blade swing layered over the flip; 2b20e31f made the swing). The cartwheel is not cut short. Footage 0193. Assert `Sable audit: a bolt mid-flip goes empowered ...` |
| Blink-arrival ring (MED) | (b) | Removed; the cyan afterimage chain and the puff stay. Assert `Sable audit: the blink leaves no ground ring` |
| Self shake on the empowered bolt, blink, Tangle (MED) | (a) / (c) | The empowered bolt's own `add_trauma` went in c7453578. `Feel.shake` and the punches belong to ext/no-shake (item 50); nothing added here |
| Empowered extras: Shred, Marks, haste end (LOW) | (a) / (b) / (c) | Shred is gone (f6bb27c3). Marks: back to 2 on the empowered hit, the owner's spec (MAIN_TO_EXT 03:20, "keep 2 Marks"; the feel pass had made it 1). The speed boost ending on the empowered shot is the wiki's Quickflip rule (Small mechanics), kept. Assert `dancer empowered bolt: a big hit, 2 Marks ...` |
| Bola's slow on Grounded (LOW) | (b) | Removed by the audit: the data's Ground is no dash or jump, no slow. Back by the owner's override (item 53): 30% for the Ground's 1.5s. Assert `dancer Bola: one foe caught is Grounded and slowed 30%` |
| Bola cooldown 0.54x the data, pair stun 0.9s (LOW) | (c) | 7s follows the footage card (6.7s); the 1.8s is how long the STUNNED word showed, not a measured stun. Owner pacing call |
| Knife cooldown (LOW) | (c) | 15s is the footage card; the data's 28s base is level 1. Owner pacing call |
| LMB range 12m vs "850 uu" (LOW) | (c) | 850 uu isn't in briefs/supervive-data; the footage shows hits at about 7 bh (12.6m). Kept 12 |
| Other Vault resets: Encore, knife at rank 3 (LOW) | (c) | Both are in the data (Fusillade, Farstep IV). DECISIONS' "reset only on an empowered hit" is about the empowered bolt hitting vs missing |
| Encore edge bonus: ring rim vs platform edge (LOW) | (c) | Follows the footage's fine print (the ring's outer band) |
| Shift, passive, dash-flow rows (-) | (c) | Match (Shift per the feel pass) |

## Parity pass (LMB first)

The owner's parity request (INBOX 13:45 ET): the attack animations, how the aim tracks, and the cadence, slot by
slot against the source. [game data] is briefs/supervive-data (Shiv; the shared rotation rate from
supervive_physics.md); [footage] is briefs/hero-ref/dancer.md (5 fps). Asserted in `--dancer-combo-check`
(tools/dancer_parity_check.gd, lines `dancer parity ...`); the Cartwheel and the empowered bolt are the feel
pass above.

| Slot | Beat | Source | Ours before | Ours now |
|---|---|---|---|---|
| LMB | throw | one arm whipped forward from a wide low stance, the torso turned ~30 degrees into it, 2-3 frames a shot, left then right [footage 0028-0039] | the bolt left at 0.0 while the arm was still being cocked; full reach at 0.08 | the arm starts cocked (the last throw's recovery drew it back) and is out by 0.04; overshoot 0.12, settled 0.26 |
| LMB | anticipation | each throw starts from the other's follow-through [footage] | each throw cocked its own arm after the bolt had left | by 0.45 (the next bolt) the other arm is cocked and the torso wound toward it; no next bolt: lowered by 0.7 |
| LMB | legs | wide low stance standing; running, "the torso snaps to the cursor while firing with either hand, and the legs keep running" [footage] | the throw's legs at full weight for 0.35s of every 0.45s, running or not (the feet froze mid-run) | the legs are a stance (`"stance": true`): full standing, none at a run, so the legs keep running |
| LMB | tracking | the bolt flies to the cursor point; the body faces the cursor, yaw 1280 deg/s [footage, game data] | the same | unchanged; asserted: a bolt swung behind her leaves on the new cursor, the body turns 180 degrees in 0.13s |
| LMB | cadence | 0.45s [footage card] | 0.45s | unchanged; asserted held (a bolt every 0.45s, hands alternating) |
| LMB | move while firing | 77-86 px/s firing against 113 (unconfirmed) [footage] | 90% of the run | unchanged (90%); asserted she keeps 85% or more |
| LMB | the empowered bolt's own kick | a big streak and a blade flash at her hands [footage 0143] | a screen shake on your own camera | no screen shake (owner rule 50); the streak, the flash and the sound carry it |
| RMB | wind-up | the bolas whirled overhead through the 0.4-0.6s lane [footage 0100-0101] | the whirl, the legs locked through it | the legs are a stance (walking, she keeps walking) |
| Shift, E, X | | see the feel pass, the per-slot table and the small mechanics | | unchanged (already at the source's beats) |

## Animation timing (ext/anim-time-sable)

Every move of content/rules/warden_anim/sable.json measured in game: the kit's keyed time (KMovesDJ) drives the
skinned clip, so wind-up start, release and recovery end are the kit's; what the clip adds is the blend in and out
(`FADE` 0.1 s). [footage] is briefs/hero-ref/dancer.md at 5 fps (one frame = 0.2 s, so a release is only known to
a frame); [game data] has no animation timings. "Shown" is the share of the move's clip on show (body weight times
the new channel's crossfade) on a standing Sable at the move's first key, measured by `--dancer-combo-check`
(tools/dancer_timing_check.gd, lines `dancer timing ...`).

| Move | Source s | Ours before | Ours after |
|---|---|---|---|
| LMB throw (`thf_lmb_r/l`) | arm whipped out inside a 2-3 frame shot, a hit every 0.45 s [footage] | release 0.04 in the kit, but the clip was 25% shown at it (a 0.1 s blend in, twice, body and channel) | blend in 0.03: 100% shown at 0.04 |
| Empowered LMB (`thf_primed`) | one big shot, same beat [footage] | 25% shown at 0.04 | 0.03: 100% |
| Cartwheel (`thf_vault_r/l/f/b/twist`) | dash 0.37-0.57 s, 3 frames with recovery [footage] | 0.48 s in the kit (in the window), the crouch at 0.05 was 25% shown | 0.48 s; blend in 0.04: 100% at 0.05 |
| Air Cartwheel (`thf_exdash`), landing (`thf_land`) | the same flick, then carried to the ground [footage] | 25% shown at their first key | 0.04 and 0.03: 100% |
| Bola (`thf_bola`) | whirled through the 0.4-0.6 s lane, slung at its end [footage] | cast 0.4 s, sling at 0.42, whirl full by 0.1 | unchanged (already at the source) |
| Knife (`thf_knife`) | dagger in the air one frame after the spin starts [footage] | released at 0.12; the spin (0.04-0.09) mostly hidden | blend in 0.04: spin on show; release 0.12 unchanged |
| Encore ring (`thf_encore`) | ring grows 0.4 s [footage] | 0.4 s | unchanged |
| Reset (`thf_reset`) | the heel-snap on the card, 0.4 s | 25% shown at 0.05 | blend in 0.04: 100% |

Clip lengths against the kit's moves are within 0.06 s for every move (asserted), and the clips' peak motion lands on
the kit's release frames (the lmb whip 0.00-0.03, the bola sling 0.37-0.40, the knife release 0.10-0.13), so no clip
re-key is needed for the hit frames. The fade is a per-move `"fade"` in the clips file (default `FADE`), read by
WardenClips on the way in only: the way out is unchanged.

Clip re-keys the model would want (not done here: the GLB and tools/art1 are out of scope; for the
ext/sable-v2-model branch): none for the hit frames. If its clips start with a settled pose, key the first pose of
each move at 0.0 (the lmb whip, the vault crouch, the knife spin) so the blend has less to hide; with that the
`"fade"` values in sable.json can go back to the default.

Suggestions (ours, not built): a held LMB could cross-fade the two arms' clips on the release instead of the
channel swap; a 0.03 s hit-stop on the empowered bolt.

## Per-slot table

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| LMB, Arc Bolts | hold | A spinning gold chakram from alternating hands every 0.45s, 34 m/s; it flies to the cursor (12m at most) and fizzles there in a blue-violet puff. A thin white aim line to the cursor with an arrow tick, gold while the next bolt is empowered | Arcslinger: the same, cursor-placed, 0.45s | Range 12m (the footage shows at least 7 bh); no magazine |
| Passive, Marks | none | Every bolt that hits adds a Mark (no cap, 4s, refreshed; eight diamonds show): +10% bolt damage per Mark. A knock heals 15% on top of the shared 10% (25% in all) with a crimson star on the knocked and a green pillar on her | Malice: about +12% of a shot per consecutive hit, still climbing at 8; knock heal with a green pillar | Gold diamonds over the target keep the stack readable (ours) |
| Dash, Vault | Shift | A 4.5m sideways cartwheel in 0.48s (the source's measured one, off the global dash feel) the way you move: a burst that peaks near 0.15s and runs down into the hasted run, a cyan and lilac arc traced by hands and feet, cyan streaks behind; +18% speed for 2s at most; the next bolt within 3s is empowered: a big blue chakram in a gold lightning streak, 2.34x (Marks add flat), 2 Marks; landing it gives the Vault back at once; rank 2: the bonus +20%, rank 3: +40% in all and the speed boost half again as big | Cartwheel: a short sideways cartwheel, the next LMB empowered, a hit resets it | As the source |
| RMB, Bola | tap | A 0.4s wind-up (whirled overhead) with a chevron lane showing (1.4m wide, 10.8m long) that follows your aim, then the Bola flies 7m: 5 and a Mark, the first foe Grounded and slowed 30% for 1.5s with yellow binding rings, and it flies on 3.8m; it bounces once off a wall; a second foe: both stunned 0.9 and +13 | Trickshot: the lane for 0.4-0.6s, Grounded on the first, Stunned on two, bounces off terrain | As the source |
| E, Shadow Knife | tap, recast | A dagger to the cursor (14m at most): it sticks in the first foe on the way (8, slowed 50% for 2.5s) or lands where you aimed; a white circle marks it; recast blinks you there through 5 cyan afterimages; after 6s you step anyway; rank 3: sticking in a foe gives the Vault back | Phantom Dagger: sticks or lands, recast teleports with a ghost chain | As the source |
| X, Encore | tap (level 6) | A violet ring grows round her from 2.3m to 5.4m (3 bh) over 0.4s, everyone sees it, then rides with her for 2s: she dances, and every 0.2s a blade leaves her hand at each foe inside (10 at most each): 4, and 6 from the outer band (past 75% of the radius), which also blights 6s. She keeps walking, shooting and dashing; casting it gives the Vault back; every blade refreshes her Marks; three blades circle her while it runs; a plain fade at the end. 24s cooldown. A blade landing on a rival hunter fills the bond (the best event of the cast counts) | Death Blossom: the ring grows 1.3 to 3 bh in 0.4s, up to 5 shots at each enemy over 2s, the outer band hits harder and Anti-Heals 6s | As the source; the look (her violet ring with a gold outer band, violet blades) is ours |
| Merge (its own key, `ultimate`) | tap | The Boki Merge | (n/a) | The Merge is the same for every hero |

## Body and movement (hero sheet "Body, scale and movement feel")

- Model about 0.95 of a medium (`body.size` 1.11 on the light build); hit radius 0.384 (`body.hit_r`, docs/HITBOX_SIZE.md).
- Nameplate height 2.15 m (`body.plate`; read by the HUD through `Arch.plate_y`).
- Runs pitched far forward (about 0.57 rad at a run).
- Ground Cartwheel: 4.5 m in 0.48 s with the measured speed curve; the long (air) dash is the same sideways cartwheel
  carried flat on its speed for 8.4 m over 0.95 s, ending where she lands (both off the global dash feel). From a jump it
  empowers the next bolt too (the source's Quickflip does; its dash -> LMB row in content/dash_flow/thief.json).
- Her dashes leave her own cyan streaks and stars, not the shared after-image. No ring or burst on a dash or a
  landing: the empowered bolt shows as a tight gold glint (a hot core and a turning four-point star) in the hand
  it will leave from, flaring as she lands; online viewers get a small ping at that hand.
- Presses during the Cartwheel (content/dash_flow/thief.json, docs/heroes/dash_interactions.md): every slot
  fires mid-flip (a bolt held through it goes at once, empowered); a move it starts waits out the flip, so the
  cartwheel is never cut short; the dagger's recast blink ends the cartwheel.

## Assumptions (where the footage is silent; easy to change in content/archetypes/thief.json)

1. **Trickshot input:** a fixed 0.4s cast with the lane, not a hold-and-release. The lane follows the aim during the cast.
2. **Trickshot stun:** only a second foe stuns; a wall bounce does not count as a second target.
3. **Arcslinger range:** 12m (about 6.7 bh), clamped; the cursor point is the landing point.
4. **Mark cap and time:** no cap (the data's rule), 4s each, refreshed by every hit; the readout shows eight diamonds and a count.
5. **Cartwheel direction:** the movement direction (WASD), the aim when standing still; the cartwheel turns in the plane of travel.
6. **Phantom Dagger timer:** 6s, then you step to it anyway (the wiki's rule); no target: it lands at the cursor.
7. **Encore and Marks:** its blades refresh Marks but do not add them, and do not count as bolt hits (the Mark bonus does not apply to them).
8. **An empowered bolt that misses** is spent (no Vault reset).
9. **Malice** has no stack cap or duration in any source; ours are 8 and 4s (see 4).
10. **Encore cadence:** one blade every 0.2s per target (10 in 2s), the footage's rate (item 54), with the damage split so the total stays. She is not slowed: the footage shows her walking and firing freely.
11. **Encore's "weaker dashes":** the wiki's two charges of a weaker Shift while it runs become the Vault given back on the cast (one cartwheel, the normal one).
12. **Encore needs line of sight:** a blade isn't thrown at a foe behind a wall, even inside the ring.
13. **Encore on a merge or a knock:** it ends at once (no more blades); what landed still pays the bond.
14. **Encore targets:** foes only (hunters and monsters, not Boki); allies are untouched.
15. **The bond:** paid as blades land on a rival hunter, topped up to the best event of the cast (a hit, a knock or a kill) by `HeroUlt.landed`, which calls the main session's `KinBond.from_ult` once it exists; nothing when no blade landed on a hunter.

## Small mechanics

From the wiki's ability page and patch notes (https://supervive.wiki.gg/wiki/Shiv), two guides
(https://gamerblurb.com/articles/supervive-how-to-play-shiv) and the footage sheet. "Built" means it is in the kit
and asserted in `--dancer-combo-check` / `--kit-combo-check`.

| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| The empowered shot flies further than a normal bolt (850 -> 950 units) | wiki patch 26.11.2024 | yes (0143, long streak) | Built: 12% further; asserted at 13.4m |
| The speed boost ends when the empowered shot is used (fired, not landed) | wiki Shift | n/a | Built; asserted |
| Landing the empowered shot resets Quickflip | wiki Shift | yes (0187-0193) | Built; asserted (and the loop twice) |
| The bolas fly on after hitting an enemy **or a destructible** | wiki RMB | n/a | Built: a crate counts as the first catch; asserted |
| Two targets caught: both stunned, bonus damage; top rank pools their stacks | wiki RMB | yes (0117) | Built; asserted |
| The bolas bounce off terrain | footage 0103-0105 | yes | Built (once); asserted |
| The dagger sticks to any surface or character, and to shields and barricades | wiki patch 20.11.2024 | yes | Built for hunters, monsters and the ground; shields: not yet (our walls are terrain) |
| After 6s she teleports to the dagger anyway; recast to go early | wiki Q | yes (0237) | Built; asserted |
| A dagger in an enemy slows them 50% | wiki Q | yes (0258) | Built (2.5s, our TTK) |
| A dagger in an enemy at the top rank resets Quickflip; terrain refunds 25%, characters 50% | owner's game data (Farstep rank IV) | n/a | Built on the Knife's rank 3 (it was on Vault's); asserted |
| Quickflip: +20% empowered damage twice, then +50% speed boost | owner's game data | n/a | Built: +20% at rank 2, +40% in all at rank 3 with the speed boost half again as big |
| The ult fires after a short delay (the ring growing) | wiki R | yes (ult f27-f31) | Built: 0.4s, no blade before it; asserted |
| Up to 5 shots at each nearby enemy over 2s | wiki R | yes | Built; asserted (10 blades on two foes) |
| The ult's outer ring deals bonus damage and anti-heals 6s | wiki R | yes (ult f121, f127) | Built on the outer 25% (blight 6s); asserted |
| Every ult shot refreshes all stacks | wiki R | n/a | Built; asserted |
| LMB keeps firing during the ult, and she moves freely with the ring attached | wiki R, gamerblurb | yes (ult f41-f47) | Built; asserted |
| The ult resets Cartwheel (the wiki: dashes while active) | in-game card, wiki R | yes (0193) | Built as the Vault back on the cast; asserted |
| The ult's numbers grow with rank (rank 2: damage, cooldown) | wiki R levels | n/a | Not built: the X ultimates have no ranks (HeroUlt); its damage grows with level through ability power |
| A knock or assist heals 25% | wiki passive | yes (0063) | Built; asserted |

## Combinations

All are scripted in `--kit-combo-check` (also inside `--archetype-check`) and `--dancer-combo-check`
(tools/dancer_jug_check.gd); the check names are the strings it prints.

| Sequence | Result | Check |
|---|---|---|
| Vault, then a bolt that hits | empowered: 2.34x, a Mark; Vault back; the speed ends | `combo dancer: Vault > bolt = empowered hit + Vault reset` |
| Vault > bolt > Vault > bolt | the reset loop | `combo dancer: the reset loop (Vault > bolt > Vault > bolt)` |
| Vault, then a bolt that misses | spent, no reset | `combo dancer: an empowered bolt that misses is spent` |
| Shadow Knife into a foe (rank 3) | Vault back; half the Knife's cooldown back | `combo dancer: Knife in a foe (rank 3) = Vault reset + refund` |
| Shadow Knife, then E | step to them | `combo dancer: Knife > E = step to them` |
| Bola catches two (rank 3) | their Marks pool | `combo dancer: Bola on two (rank 3) = pooled Marks` |
| Bola, then Grounded | no dash, jump or glide | `combo dancer: Bola > Grounded = no dash` |
| Bola, then X | the Grounded foe can't leave the ring: every blade lands | `combo dancer: Bola > X = the Grounded foe takes every blade` |
| X, then Vault and bolts | she walks and shoots through it, the ring rides along | `dancer X small mechanic: she walks and fires freely, the ring moves with her` |
| X with a foe in the outer band | harder blades and a 6s blight | `dancer X small mechanic: the outer band hits harder and blights 6s; ...` |
| X, then a merge | Encore ends, no blade after | `merge hold dancer: Encore's blades stop and its ring goes` |
| Knock or assist | heal (25% in all), star and pillar | `dancer passive: a knock heals (25% in all), star + pillar` |

## Animation moves

`KMovesDJ` (scripts/match/kmoves_dj.gd): `thf_lmb_r` / `thf_lmb_l` (each throw starts cocked, out by
0.04s as the bolt leaves, overshoot at 0.12, settled by 0.26, the other arm cocked by 0.45 where the next throw
starts, lowered by 0.7 with no next bolt; the legs a stance), `thf_primed` (the empowered
throw: both blades cocked behind the shoulders, driven out together at 0.04, a recoil onto the heels by 0.24, settled
by 0.55), `thf_vault_r` /
`thf_vault_l` (the ground Cartwheel inside the 0.48s dash: a 0.05s crouch, the arms swinging up by 0.08 (they trail the body), a push-off
with the crossbows tucked by 0.16 and the wings flaring, one aerial turn by 0.30, a landing crouch at 0.36, up by 0.48),
`thf_vault_f` / `thf_vault_b` (the routine's tucked somersault, on the same beats), `thf_vault_twist` (its corkscrew;
ThiefChain runs cartwheel, somersault, twist through a reset chain), `thf_exdash` (the air
Cartwheel: a tucked flick, the star turned over by 0.34, then carried flat and stretched until she lands),
`thf_land` (touching down from it: a low crouch for 0.1s), `thf_bola` (whirl overhead through the 0.4s lane, sling at
0.42), `thf_knife` (a spin into a side-arm throw, released at 0.12), `thf_arrive`, `thf_encore` (X: blades raised as the
ring grows, then a full spin as it opens), `thf_encore_dance` (eight 0.2s beats that loop, a fling on each: two side flings, a pirouette, two low sweeps, a twirl back with the crossbows overhead; the legs are a stance, so walking she keeps walking)

## Look and sound (all ours)

- Arc Bolts model: two dark ring blades with swept spikes and a gold inner edge (scripts/match/hero_arms_dj.gd).
- Effects: scripts/arch/kits/dj_fx.gd and shaders/dj_fx.gdshader, every node pooled: the gold chakram and its
  comet trail, the empowered blue chakram in a lightning streak, the fizzle puff, the Bola's two weights, the
  dagger, the cyan afterimage chain, the knock star and heal pillar, the cartwheel arc.
- Sounds: tools/gen_sfx_sable.py (`dj_*`, `thief_*`), synthesized; set in content/sfx/thief.json.

## Engine notes

- Bolts are weapon shots (`h.fire()` with `h.shot_aim = AimMode.CURSOR`); the kit then moves the start to the
  throwing hand, re-aims at the clamped cursor point, and hangs a `kx` end callback for the impact and the
  empowered hit. The empowered damage is on the shot itself.
- The Bola is kit-run (it flies on through its first foe and bounces), with the stage's effects applied on the wrap.
- Holds cleared by `_drop_holds()` on a merge: `bola_cast`, `encore.st` (Encore, `ThiefUlt.drop`).
- The Vault loop lives in `scripts/arch/kits/thief_chain.gd` (`ThiefChain`): the routine of flips (cartwheel, somersault,
  twist; a 2s gap starts it over) and the kept Shift presses (mid-flip to the flip's end, in the empowered bolt's flight
  to its landing). A reset gives back the air Vault's cooldown too. Asserted in `tools/dancer_loop_check.gd`.
- Encore lives in `scripts/arch/kits/thief_ult.gd` (`ThiefUlt`, owned by the kit); X reaches it through
  `ArchKit.cast_ult()` on the `hunter_ult` action. Its numbers are `x` in content/archetypes/thief.json; the shared X base (gate, cooldown `cd["x"]`, HUD slot, bond) is `HeroUlt` (scripts/arch/hero_ult.gd).
  Sounds: `dj_encore` (the ring opening), `dj_encore_whirr` (the 2s it runs), `dj_encore_hit` (a blade landing).
- The Jackpot fold (the fifth Mark set off a short Death Blossom) is gone: with Encore on X it duplicated the
  ultimate, so the passive is back to the source's (Marks ramp the bolts, knocks heal).
