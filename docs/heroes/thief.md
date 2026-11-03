# Silver Thief (base character Sable; archetype id `thief`, light)

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

Ratios, not raw numbers: a bolt is 9 (the source basic attack, 137), the empowered bolt is 3.5x (474),
a Mark is +10% of a bolt (the data's +16 on its 160 bolt), the Bola is 5 (74) and +13 for a pair (199), an Encore blade
is 8 (about 0.9 of a bolt: 114-127 against 137) and +4 from the outer band (the card's +50%: 36 + 19% against
+18 + 9.5%). Cooldown ratios: Vault 4.5s (Cartwheel 4.2), Bola 7s (Trickshot 6.7), Shadow Knife 15s (Phantom
Dagger 15), Encore 24s (Death Blossom 23.1, about 3.5 Trickshots).

## Per-slot table

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| LMB, Arc Bolts | hold | A spinning gold chakram from alternating hands every 0.45s, 34 m/s; it flies to the cursor (12m at most) and fizzles there in a blue-violet puff. A thin white aim line to the cursor with an arrow tick, gold while the next bolt is empowered | Arcslinger: the same, cursor-placed, 0.45s | Range 12m (the footage shows at least 7 bh); no magazine |
| Passive, Marks | none | Every bolt that hits adds a Mark (no cap, 4s, refreshed; eight diamonds show): +10% bolt damage per Mark. A knock heals 15% on top of the shared 10% (25% in all) with a crimson star on the knocked and a green pillar on her | Malice: about +12% of a shot per consecutive hit, still climbing at 8; knock heal with a green pillar | Gold diamonds over the target keep the stack readable (ours) |
| Dash, Vault | Shift | A 4.5m sideways cartwheel (0.42s; both x the global dash feel, so about 3.8m in 0.48s) the way you move: a burst that peaks near 0.15s and runs down into the hasted run, a cyan and lilac arc traced by hands and feet, cyan streaks behind; +18% speed until the next hit (2s at most); the next bolt within 3s is empowered: a big blue chakram in a gold lightning streak, 3.5x, 2 Marks, Shred; landing it gives the Vault back; rank 2: empowered +20%, rank 3: +40% in all and the speed boost half again as big | Cartwheel: a short sideways cartwheel, the next LMB empowered, a hit resets it | As the source |
| RMB, Bola | tap | A 0.4s wind-up (whirled overhead) with a chevron lane showing (1.4m wide, 10.8m long) that follows your aim, then the Bola flies 7m: 5 and a Mark, the first foe Grounded 1.5s with yellow binding rings, and it flies on 3.8m; it bounces once off a wall; a second foe: both stunned 0.9 and +13 | Trickshot: the lane for 0.4-0.6s, Grounded on the first, Stunned on two, bounces off terrain | As the source |
| E, Shadow Knife | tap, recast | A dagger to the cursor (14m at most): it sticks in the first foe on the way (8, slowed 50% for 2.5s) or lands where you aimed; a white circle marks it; recast blinks you there through 5 cyan afterimages; after 6s you step anyway; rank 3: sticking in a foe gives the Vault back | Phantom Dagger: sticks or lands, recast teleports with a ghost chain | As the source |
| X, Encore | tap (level 6) | A violet ring grows round her from 2.3m to 5.4m (3 bh) over 0.4s, everyone sees it, then rides with her for 2s: every 0.4s a blade flies at each foe inside (5 at most each): 8, and 12 from the outer band (past 75% of the radius), which also blights 6s. She keeps walking, shooting and dashing; casting it gives the Vault back; every blade refreshes her Marks; three blades circle her while it runs; a plain fade at the end. 24s cooldown. A blade landing on a rival hunter fills the bond (the best event of the cast counts) | Death Blossom: the ring grows 1.3 to 3 bh in 0.4s, up to 5 shots at each enemy over 2s, the outer band hits harder and Anti-Heals 6s | As the source; the look (her violet ring with a gold outer band, violet blades) is ours |
| Merge (its own key, `ultimate`) | tap | The Boki Merge | (n/a) | The Merge is the same for every hero |

## Body and movement (hero sheet "Body, scale and movement feel")

- Model about 0.95 of a medium (`body.size` 1.11 on the light build); hit radius unchanged (0.35).
- Nameplate height 2.15 m (`body.plate`; read by the HUD through `Arch.plate_y`).
- Runs pitched far forward (about 0.57 rad at a run).
- Ground Cartwheel: 4.5 m with the measured speed curve; the long (air) dash is the same sideways cartwheel
  carried flat on its speed for 8 m over 0.95 s (x the dash feel), ending where she lands. From a jump it
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
10. **Encore cadence:** one blade every 0.4s per target (5 in 2s); the footage shows 0.2 to 0.4s between blades.
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
| Vault, then a bolt that hits | empowered: 3.5x, 2 Marks, Shred; Vault back; the speed ends | `combo dancer: Vault > bolt = empowered hit + Vault reset` |
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

`KMovesDJ` (scripts/match/kmoves_dj.gd): `thf_lmb_r` / `thf_lmb_l` (the body for each throw: release at
0.08s, follow-through to 0.22, back by 0.42; the arm is the twin-hold swing), `thf_primed`, `thf_vault_r` /
`thf_vault_l` (the ground Cartwheel inside the 0.48s dash: a 0.05s crouch with the arms swung up, a push-off
into a star, one turn over the top by 0.30, a landing crouch at 0.36, up by 0.48), `thf_exdash` (the air
Cartwheel: a tucked flick, the star turned over by 0.34, then carried flat and stretched until she lands),
`thf_land` (touching down from it: a low crouch for 0.1s), `thf_bola` (whirl overhead through the 0.4s lane, sling at
0.42), `thf_knife` (a spin into a side-arm throw, released at 0.12), `thf_arrive`, `thf_encore` (X: blades raised as the
ring grows, then a full spin as it opens), `thf_encore_throw_r` / `_l` (each volley: the torso snaps round
as one arm flings a blade out; no leg keys, so she walks).

## Look and sound (all ours)

- Arc Bolts model: two dark ring blades with swept spikes and a gold inner edge (scripts/match/hero_arms_dj.gd).
- Effects: scripts/arch/kits/dj_fx.gd and shaders/dj_fx.gdshader, every node pooled: the gold chakram and its
  comet trail, the empowered blue chakram in a lightning streak, the fizzle puff, the Bola's two weights, the
  dagger, the cyan afterimage chain, the knock star and heal pillar, the cartwheel arc.
- Sounds: tools/gen_dj_sfx.py (`dj_*`), synthesized.

## Engine notes

- Bolts are weapon shots (`h.fire()` with `h.shot_aim = AimMode.CURSOR`); the kit then moves the start to the
  throwing hand, re-aims at the clamped cursor point, and hangs a `kx` end callback for the impact and the
  empowered hit. The empowered damage is on the shot itself.
- The Bola is kit-run (it flies on through its first foe and bounces), with the stage's effects applied on the wrap.
- Holds cleared by `_drop_holds()` on a merge: `bola_cast`, `encore.st` (Encore, `ThiefUlt.drop`).
- Encore lives in `scripts/arch/kits/thief_ult.gd` (`ThiefUlt`, owned by the kit); X reaches it through
  `ArchKit.cast_ult()` on the `hunter_ult` action. Its numbers are `x` in content/archetypes/thief.json; the shared X base (gate, cooldown `cd["x"]`, HUD slot, bond) is `HeroUlt` (scripts/arch/hero_ult.gd).
  Sounds: `dj_encore` (the ring opening), `dj_encore_whirr` (the 2s it runs), `dj_encore_hit` (a blade landing).
- The Jackpot fold (the fifth Mark set off a short Death Blossom) is gone: with Encore on X it duplicated the
  ultimate, so the passive is back to the source's (Marks ramp the bolts, knocks heal).
