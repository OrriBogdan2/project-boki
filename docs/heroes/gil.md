# Gil the Novice Mage (archetype id `gil`, Light, Controller)

A pet fish a spell stood up on two legs. He fences with a swordfish, throws whatever potion comes out of the bag, and
chains crowd control until a foe is Beached. **Gil is ours, not from the source**: there is no parity target, no
footage and no source row. Every number below is the live data (`content/archetypes/gil.json`) and code
(`scripts/arch/kits/gil_kit.gd`) on origin/main 88b06b9e7, probed headless. `--gil-combo-check`
(`tools/gil_combo_check.gd`, old name `--gil-kit-check`) asserts each row; the quoted names are its check lines.

## Per-slot table
| Slot | Input | What it does | Numbers (live) |
|---|---|---|---|
| Passive, Fish Out of Water | none | each different potion effect (shock, slime, gust, fire, zeep) puts a splash mark on the foe it hits; three different marks inside the window Beach them (a stun, "BEACHED!"), then the marks clear | window 5 s, 3 marks, stun 0.75 s, once per foe every 8 s; the Fencer, Riptide, Ground Swim and the wave mark nothing |
| LMB, Fencer (swordfish) | hold | two quick thrusts and a longer lunge, each stepping him in; the lunge slows | 7 / 7 / 11 damage, reach 2.5 / 2.5 / 3.2 m, arc 50 / 50 / 34 deg, step 0.7 / 0.7 / 1.3 m, knockback 1.2; 0.32 s between thrusts, 0.48 s after the lunge; the chain restarts after 0.75 s idle; the lunge slows 30% for 0.5 s (a 0.1 hit carries it) |
| RMB, Grab Bag | tap; hold (0.25 s) to aim further; in the air it drops | throws the next potion from a shuffled bag in an arc to the cursor; the next one shows on the slot and glows in his hand | 2 charges, 5 s each; 8 m at most (hold: x1.5 = 12 m); flight 0.35 s + 0.03 s a metre (0.59 s at 8 m); in the air: straight down, 0.25 s; the bag is 2 Thunder, 2 Slime, 2 Air, 2 Fire, 1 Super Zeep, reshuffled when empty |
| Shift, Ground Swim | tap | dives and swims the shared dash direction, the fin cutting the ground; still hittable; surfacing knocks nearby foes up. The air dash (long dash) is a plain travel with no dive or surfacing | 6 m in 0.4 s (the shared dash feel's time scale), surfacing radius 2.2 m, 4 damage, lift 8, knockup 0.5 s; 8 s a charge |
| E, Riptide | tap, then E again (or wait) | spins with the swordfish, hitting around him, then sends a waterspout down the aim; the longer the spin, the longer, wider and faster the spout | spin up to 2 s, radius 2.2 m, a tick every 0.25 s rising 2 -> 5 (8 ticks: 2.0 ... 4.8), he walks at 70%; spout 7 -> 11 m long, 1.2 -> 2.2 m wide, 14 -> 22 m/s, 10 damage, lift 9, knockup 1 s, each foe once; 12 s |
| X, Tidal Wave (level 6) | tap | surfs a wave 14 m down the aim, untargetable; every foe it rolls over is knocked up then slowed; lands with a shield | 14 m in 1 s, 3.6 m wide, 18 damage, knockup 1 s, then 50% slow (2 s after the knockup), shield 40 for 3 s; 90 s |
| R | | the Boki Merge (not a hero ability) | |

### Grab Bag potions (`rmb.vials`)
| Potion | Radius | Damage | Effect | Mark |
|---|---|---|---|---|
| Thunder | 2.4 m | 10 | stun 0.5 s inside the 1 m core | shock |
| Slime | 2.4 m | 4 | 40% slow 1.5 s; a 2.4 m puddle for 4 s that slows 25% | slime |
| Air | 2.6 m | 4 | pushes foes out from the centre (push 4, lift 3) | gust |
| Fire | 2.2 m | 12 | burn 4 for 3 s | fire |
| Super Zeep | 3.6 m | 16 | lift 9, knockup 0.75 s | zeep |

### Ranks (the shared steps; Gil has no `rank_cd` / `rank_dmg` rows)
RMB and E cooldowns x0.9 at rank 2 and x0.8 at rank 3 (RMB 4.5 s / 4 s, E 10.8 s / 9.6 s); damage +15% / +30%; Shift
recharges 15% faster a rank (6.8 s / 5.6 s). Tidal Wave has no rank. The rank texts in gil.json promise more than
this: see F6.

## Combinations (all scripted in `--gil-combo-check`)
| Do this | You get | Asserted by (check line) |
|---|---|---|
| Hold LMB on a foe | three thrusts, each stepping in, the third slowing | "Fencer: a three-hit chain lands on the dummy"; "Fencer: each swing steps him forward"; "Fencer: the third, longer thrust slows (30% for 0.5 s)"; "numbers LMB: ..." (3 lines) |
| Throw each potion | its own effect | "Thunder: ..."; "Slime: ..." (2); "Air: ..."; "Fire: ..."; "Super Zeep: ..." |
| Empty the bag | 2/2/2/2/1, refilled and reshuffled, the next potion on the HUD | "bag: ..." (4 lines) |
| Hold RMB / RMB in the air | 12 m / straight down | "Grab Bag hold: lands +50% further (12 m against 8)"; "Grab Bag in the air: drops the vial straight down" |
| RMB x3 | two throws, the third does nothing; a charge back 5 s after the first | "numbers RMB: ..." (3 lines) |
| Three different potions on one foe in 5 s | Beached 0.75 s, then 8 s before the next | "Fish Out of Water: ..." (4 lines) |
| Two potions, wait 5 s, a third | no Beach (the old marks dropped) | "numbers passive: marks last 5 s (two, a 5 s wait, a third: no Beach)" |
| Shift near a foe | 6 m under the ground, hittable, a knockup where he surfaces | "Ground Swim: ..." (4 lines); "numbers Shift: ..." (3 lines) |
| E | the spin hurts round him, rising | "Riptide: E starts the spin"; "Riptide: the spin hurts foes around him"; "numbers E: 8 spin ticks, 2 at first, rising, under 5"; "numbers E: he moves at 70% while he spins" |
| E, then E again / E and wait 2 s | the spout runs the line, knocks up 1 s; a full spin makes the biggest spout | "Riptide recast: ..."; "Riptide: at 2 s the spout goes on its own"; "Riptide: a longer spin makes a wider spout"; "numbers E: a full 2 s spin sends an 11 m, 2.2 m wide, 22 m/s spout"; "numbers E: the spout does 10 ..." |
| X | untargetable for the ride, knockup then slow, a shield on landing, 90 s | "Tidal Wave: ..." (5 lines); "numbers X: ..." (4 lines) |
| Ranks 2 and 3 | the shared steps | "numbers ranks: ..." (3 lines) |

## Cancels (ability to ability)
What a second press does while the first action runs: **both** (the second goes now, the first runs on), **waits**
(buffered, and until when), **locked** (refused, nothing spent, not replayed) or **ignored**. There is no source
column (Gil is ours); every row is the live behaviour, and the "Kind" column says whether a data row or the kit
chose it (designed) or it is just what the shared code does (default). Dash rows are in the next section. Any pair not
listed: both (ArchKit has no shared cast lock); every press is ignored, not buffered, while stunned or downed.

| First (phase) | Second | Ours | Kind | Asserted by |
|---|---|---|---|---|
| E Riptide spin (up to 2 s) | LMB | both: the thrusts land, the spin goes on | default | "cancel E spin + LMB: ..." |
| E spin | RMB | both: the potion flies, the spin goes on | default | "cancel E spin + RMB: ..." |
| E spin | Shift | locked: no swim, no charge spent | designed (`into_dash.e` lock) | "cancel E spin + Shift: ..." |
| E spin | jump | both: he hops, still spinning | default | "cancel E spin + jump: ..." |
| E spin | E | sends the spout (from 0.12 s; earlier the press is eaten) | designed | "recast E: ..." (see Recast windows) |
| E spin | X | the spout goes first, then the wave | designed (`_start_wave`) | "cancel E spin + X: ..." |
| E spin | stunned | the spin goes on and keeps hitting through the stun (F5) | default | "cancel E spin + stunned: ..." |
| E spin | Boki merge | it ends, no spout | designed (`_drop_holds`) | "cancel E spin + Boki merge ..." |
| X Tidal Wave ride (1 s) | E, RMB, LMB | waits for the landing, then goes (a spin, a potion, a fresh first thrust) | default (the ride is an Effects dash, so DashFlow buffers) | "cancel X wave + E, RMB, LMB: ..." (2 lines) |
| X ride | Shift | locked: dropped, no charge, no swim after the landing | designed (`into_dash.x` lock) | "cancel X wave + Shift: ..." |
| X ride | X | nothing: no early landing | designed (no `ult_recast`) | "cancel X wave + X: ..." |

## Dash interactions (content/dash_flow/gil.json, `tools/dash_flow_check.gd`)
Rows run inside `--gil-combo-check` ("dash flow: every row in content/dash_flow/gil.json holds ..."); the full table
for every hero is in [dash_interactions.md](dash_interactions.md).

| Row | Ours |
|---|---|
| ground or air dash -> LMB, RMB, E, X, Q | buffered to the dash's end (the default row; pressed early or on the last step, it goes the step the swim ends) |
| jump -> any slot | fires mid-jump |
| any slot -> jump out of it | acts at once |
| LMB, RMB, Q -> Shift out of it | acts at once |
| E (the spin) -> Shift | **lock**: "Riptide is a planted spin that ends in the waterspout; Shift during it would drop the spout he is aiming. Recast E sends it early." |
| X (the ride) -> Shift | **lock**: "Tidal Wave: he rides the wave down its line, untargetable, until it lands; the wave is his movement." |
| RMB held through a ground dash, an air dash, a jump | kept (the hold goes on) |

## Recast windows (the 2026-11-08 two-step rule)
| Recast | Window | Ours |
|---|---|---|
| E Riptide | from 0.12 s to 2 s of spin; at 2 s it sends itself | `recast_window()` reports slot `e` at Gil while he spins; a press before 0.12 s does nothing and is not buffered (F2); the window's total is its time left (F1); the auto spout leaves EXPIRED on the slot (F1) |
| X Tidal Wave | none | no window, a second X does nothing |

Check lines: "recast E: ..." (5), "recast X: Tidal Wave opens no recast window".

## Clips and animation
The Relic screen's ability clips (`AbilityClip`): the lines come from `clip.lines`; the effects come from the
deliveries because gil.json has no `clip.fx`: LMB `swing`, RMB `bolt`, E `nova`, Shift `dash`, X `strike`. Gil has no
keyed moves (`HunterViewer.moves_for` is empty for every slot, `tools/rig_standard_check.gd`: "Gil has no keyed
moves yet"), so his rig plays the generic poses and the swordfish uses the sword hold. Check lines: "clips: ..." (3).

## Findings (shared rules; no tuning changed, nothing fixed here)
- **F1 two-step clarity, the Riptide cue.** `e_def` has no `time`, so `ArchKit.recast_window()` reports the total as
  the time left: the slot's timer ring stays full and never empties. The spin sends the spout on its own at 2 s, but
  the window isn't flagged `auto`, so RecastCue shows EXPIRED and plays the miss click although the spout went. Gil is
  not in `--recast-cue-check`'s CASES or HUD.md's "Kits reporting" list. Fix: a `recast_window()` override in
  gil_kit.gd (`RecastCue.window("e", e_t, spin_t, h.pos, spin_t >= 0.12, true)`) plus a CASES entry.
- **F2 two-step clarity, the early press.** An E press in the first 0.12 s of the spin returns true from `e_recast()`
  without sending the spout, so it is eaten: not buffered (the rule asks for ~0.15 s) and not shown as WAIT. The
  `armed` flag in F1's fix lets the shared `RECAST_BUFFER` keep it.
- **F3 ability colour, the RMB slot.** `slot_info("sec")` paints the Grab Bag slot in the next potion's colour
  (blue, green, white, red, orange), so his RMB slot and its clip are not colour-coded to him (DECISIONS 2026-11-08:
  "every Hunter's abilities are colour-coded to them"). It is how the next potion shows. Alternative: keep the slot
  blue and show the potion as the icon or a pip.
- **F4 ability colour, overlap.** All of Gil's colours are blues (#4aa8ff, #7fd8ff, #3ad0ff, #2a8cff), next to Tenzo,
  whom the owner named blue (#3a7cff and #5a9aff to #8fb4ff), and Grab Bag's #7fd8ff is exactly Neve's X colour. An
  owner call: give Gil a sea-green or teal of his own, or accept the overlap.
- **F5 (not a shared rule, flagged).** A stun does not end the Riptide spin: it keeps hitting while he is stunned.
  Cinder's flight ends on a stun; ask the owner whether a stun should drop the spin (no spout).
- **F6 card clarity, the ranks.** gil.json `rank2.dash` says "8s -> 7s, surfacing radius +0.3m" and `rank_next.dash`
  "8s -> 6s", but the live dash is 6.8 s / 5.6 s (the shared 15% a rank) and the radius never grows. The `rank3`
  specials (the next two potions show, surfacing slows 30% for 1 s, the spout pulls to its line) exist only as text:
  gil_kit.gd never reads a rank. The text needs to match the kit, or the kit needs to build what the text says.
- **F7 clips.** With no `clip.fx`, the Grab Bag clip shows a straight `bolt` (the potion arcs), Riptide a `nova`
  with no spout, and Tidal Wave a `strike` from above (the wave runs along the ground). A `clip.fx` block in gil.json
  (data only) would fix the look; the effect ids to choose from are in `AbilityClip`.
- **Key caps: no break.** Every key on his HUD comes from `Settings.key_cap` (`--hudref-check`). The E text's
  "Press E again" is fixed text, as on Sable, Motley, Kael, Neve and Meeko; if a rebind should change card text,
  that is one pass over all six.

## Engine notes
- The bag uses the kit's own seeded generator (`hash("gil_bag_<instance id>")`), so the match decides the order, not
  a global roll.
- The Fencer's slow rides a 0.1 hit from `on_deal` within 0.3 s of the lunge, so the lunge reads as 11.1 on a dummy.
- Tidal Wave is an `Effects` dash with `invuln` for its time, plus `incoming()` returning 0 while `untarget_t` runs.
- Ground Swim keeps him hittable (`incoming` passes damage through); `swim_t` scales with the shared dash feel's time.
