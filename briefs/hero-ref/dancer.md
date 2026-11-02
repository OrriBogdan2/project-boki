# Dancer (`thief`): reference sheet from the Shiv footage

## Source and method

- Frames: `/home/claude/svvid/hero/dancer/frames`, cut from all.mp4 278 to 360 s at 5 fps. Frame N is video second
  278 + (N-1)/5.
- Key frames: copied to `/home/claude/hero-ref/dancer/`.
- Our code: compared against origin/main 4f82978, worktree `/home/claude/ref-vireo`.
- Our side has no `docs/heroes/thief.md`. The Shiv port is described in `docs/ARCHETYPES.md`, under "Kits2: the
  Thief and the Juggernaut ported from SUPERVIVE" (around line 1032).
- Scale: Shiv is about 40 px tall. The two training dummies stand about 280 to 300 px (about 7 bh) from the hero in
  most shots.
- In-game info panel (frames 0399 to 0405, `0401.jpg`): it uses a different keymap (E = Trickshot, SPACE = Cartwheel,
  L SHIFT = Phantom Dagger, Q = ult) and adds these rules:
  - Trickshot **Grounds** the target.
  - Phantom Dagger **Slows** what it hits.
  - Death Blossom deals bonus damage near the edge and **resets Cartwheel**.
  - The passive heals when you knock an enemy.

## 1. Source summary

| Slot (video) | Ability | Input | Aim type | Cooldown / cost | Effect |
|---|---|---|---|---|---|
| Passive | Malice / Star of the Show | n/a | n/a | n/a | Each LMB hit on the same target deals more damage: steps of about +17 (137, 172, 189, 206, 223, 241, 258, 275). A knock or assist heals her (+384, green pillar). |
| LMB | Arcslinger | hold (auto-repeat) | **ranged** projectile; ends **at the cursor** (clamped to max range) | 0.45 s | Fires a bolt of energy: an orange-gold chakram streak. It fizzles in a blue-violet puff at the cursor point. |
| RMB | Trickshot | press: a lane shows about 0.4 to 0.6 s, then the throw | skillshot lane toward the cursor, fixed length (about 5.5 to 6 bh) | 6.7 s, 40 mana | Chain bolas. The first target hit is **GROUNDED** (74 damage, yellow binding ring). The bolas flies on, and a 2nd target hit means both are **STUNNED** (199, about 1.8 s). It bounces off terrain. |
| Shift | Cartwheel | tap | short dash, about 2 bh | 4.2 s, 0 mana | A sideways cartwheel. It empowers the next LMB (gold aim line, big lightning shot, 474 to 561 yellow damage). Hitting with the empowered shot resets Cartwheel. |
| E | Phantom Dagger | press, then **reactivate** | skillshot toward the cursor | 15 s, 30 mana | Throws a dagger. It sticks in the first enemy (and slows it) or lands at the end of its path. Reactivate to teleport to it: a near-instant blink that leaves a chain of 4 to 5 cyan afterimages. |
| R | Death Blossom | tap | self-centred ring (radius about 3.5 bh) | 29.1 s, 20 mana | For 2 s she flings blades at every enemy inside the ring, about 0.2 s apart, while moving and firing freely. Hits near the edge deal more (151 to 236 versus 88 to 108 at close range). Resets Cartwheel. |

## 2. Per-ability detail

### Passive: Malice / Star of the Show (card visible at `0027`; frames 0019 to 0063 and 0337 to 0353)

- **What it does:** consecutive LMB hits on the dummy climb by about +17 each: 137 → 172 → 189 → 206 → 223 → 241
  → 258 → 275 (frames 0021 to 0042).
- **Visual feedback:**
  - There is no stack counter over the target, only the rising numbers.
  - On some hits (the 2nd, 4th and 8th) the dummy flashes solid red (`0026`, `0032`, `0042`). The 275 hit at `0042`
    adds a yellow starburst.
- **Knock** (`0063`, `0351`):
  - A huge crimson four-point star bursts on the target. Mark this `distinctive`.
  - A green **+384** and a green vertical light pillar appear over Shiv for about 0.6 s. That is the heal.
- **Sound:** no audio in the footage.

### LMB: Arcslinger (frames 0001 to 0045; card visible at `0027`)

**Input**
- Hold to keep firing. Hits on the dummy land every 2 to 3 frames, about every 0.5 s, which matches the card's 0.45 s.
- The 0.45 s is a cooldown, not a magazine. There is no reload in the footage.

**Aiming: cursor-placed**
- When the cursor is closer than the dummy, the bolt flies to the cursor and fizzles there. You see a blue-violet puff
  exactly at the cursor:
  - `0004` → `0005`: cursor about 190 px (4.7 bh) away.
  - `0009` → `0010`: same thing.
- Against the dummy, about 290 px (7 bh) away, every bolt hits.
- So the bolt **stops at the cursor point, clamped to max range**. That is the Myth / Oath pattern, not Ghost's.
- Max range is at least about 7 bh. The footage doesn't show the exact clamp.

**Reticle**
- Cursor: a small white ring with a centre dot and a dark outline, about 22 px across.
- A thin white line at about 30% opacity runs from Shiv **to the cursor and ends there**, with a small arrow tick
  (`0005`, `0010`, `0145`).
- With an empowered shot ready, the line turns **gold and brighter** (`0139` to `0142`).

**Animation** (`0028` to `0039`, zoomed)
- She holds a weapon in each hand and fires them alternately: left, then right.
- Each shot is a whip of one arm forward from a wide, low stance. The torso twists about 30 degrees toward the firing
  arm.
- About 2 to 3 frames per shot.
- She faces the cursor while firing, and her legs keep their stance.

**VFX**
- Projectile: a short orange-yellow chakram / comet with a flared head about 0.5 bh long. Fast: it covers 200 px in
  about 0.2 s, roughly 25 bh/s.
- Impact: a small yellow starburst with a white cross flare (`0042`).
- Muzzle: a small yellow flash.

### RMB: Trickshot (frames 0076 to 0128; card visible at `0095`)

**Input**
- On press, a **translucent white rectangular lane with chevrons** shows from Shiv toward the cursor. It is about
  1 bh wide and about 5.5 to 6 bh long, and it does not follow cursor distance.
- The lane stays for 2 to 3 frames (`0085` to `0087`, `0099` to `0101`, `0112` to `0113`). Then a yellow flash at
  Shiv marks the throw (`0087`, `0114`).
- So there is roughly a 0.4 to 0.6 s cast time. It could also be a hold-and-release; see the open questions.

**Animation**
- She whirls the bolas overhead with one arm during the lane window (`0100` to `0101`), then slings it with a forward
  lunge (`0102`).

**VFX**
- The bolas is two glowing yellow-violet weights on a lightning chain. It spins as it flies, about 30 bh/s
  (`0102` to `0105`).
- First hit (`0088`):
  - **GROUNDED** label and 74 damage.
  - The target flashes red, and **yellow rings bind it** (about 1.5 bh) for about 0.6 s.
- The bolas then flies on toward the end of the lane (`0090`, `0091`). You can see the chain flying past the dummy.
- Against a pillar with no target (`0103` to `0105`), it **hit the pillar and bounced back** about 3 bh at an angle.
- Second-target case (`0115` to `0125`):
  - GROUNDED, then STUNNED with 199 damage.
  - Yellow rings, pink sparkles and a stun swirl over the target.
  - The label lasts about 9 frames, about 1.8 s.
  - The only nearby things were the dummy and a tree, so either the bounce or terrain counted as the second "target".
    See the open questions.

**Numbers:** 6.7 s cooldown, 40 mana.

### Shift: Cartwheel (frames 0130 to 0213; card visible at `0170`)

**Input:** tap.

**Movement**
- A short dash of about 1.5 to 2.5 bh. The camera follows her, so it's hard to measure.
- The direction looks like the movement direction, not always the cursor: at `0134` to `0137` she flips sideways
  while the cursor is up-left.

**Animation**
- A real sideways cartwheel, with the body rotating in the screen plane.
- A thin white swoosh arc traces the hands and feet (`0134` to `0137`).
- About 3 frames (0.6 s) including recovery. Later casts show a white halo ring around her (`0193`).

**Empowered shot**
- Once the next LMB is empowered, the aim line is gold (`0139` to `0142`) and stays until she fires.
- The empowered shot (`0143`) is a large yellow lightning streak carrying a blue chakram. A vertical blue blade-flash
  appears at her hands.
- It travels to the cursor, the same as the normal LMB.
- On a hit: yellow damage numbers 474 (`0187`) and 561 (`0194`), with a red and white flash on the target.

**Reset loop** (`0184` to `0195`)
1. The empowered hit lands at `0187`.
2. Cartwheel is ready again and used at `0193`.
3. The empowered shot is fired again (`0193`) and hits at `0194`.

That is about 1.4 s per loop.

**Numbers:** 4.2 s cooldown, 0 mana.

### E: Phantom Dagger (frames 0219 to 0280; card visible at `0260`)

**Input:** press to throw, then reactivate to teleport.

**Throw** (`0222` to `0225`)
- She spins into a side-arm throw with a yellow flash.
- The dagger flies as a dark blade with a violet and gold trail, about 25 bh/s.
- With no target, it lands about at the cursor or end of range, about 9 bh, and lies there with a yellow glow
  (`0236`).
- In the second cast it **stuck in the dummy** (`0255` to `0258`): yellow glow on the target, which is slowed.
- A white circle about 1.5 bh in radius appears around the dagger's spot (`0259`). This is probably the arrival
  marker.

**Teleport**
- After she presses again (`0237` → `0238`, and `0278` → `0279`), a chain of **4 to 5 cyan ghost copies** stretches
  from her to the dagger.
- On the next frame she is at the dagger. The blink is near-instant (1 frame, under 0.2 s).
- Mark the ghost chain as `distinctive`. Keep the function: an afterimage trail that tells enemies where she went.

**Dagger lifetime:** at least 5 s before recast (`0253` → `0278`).

**Numbers:** 15 s cooldown, 30 mana.

### R: Death Blossom (frames 0290 to 0357; card visible at `0330`)

**Input:** tap.

**Wind-up** (`0293` to `0295`)
- A **cyan ring** grows out from her to a radius of about 3.5 bh over about 0.4 s, with a dark tint inside it.

**Active** (`0296` to `0303`, `0319` to `0350`)
- For about 2 s she flings glowing blue-red blades.
- Each blade homes on an enemy inside the ring, about every 0.2 s.
- She **walks and fires her LMB freely** throughout (`0299` to `0302`), and the ring moves with her.

**Hits on the dummy:** 88 to 108 close in, and 151 to 236 when the dummy was near the ring's edge. That fits "bonus
damage near the edge".

**Animation:** she turns side to side, snapping the free arm out. The ring fades at the end.

**For us:** R is the Boki Merge. See the gaps below.

## 3. The combo the kit is built around

1. Stay on one target with LMB. The damage ramps with every hit.
2. **Cartwheel**, then the empowered shot: a big hit, and Cartwheel comes back on a hit. Repeat about every 1.4 s
   while the shots keep landing.
3. **Trickshot** grounds a target, so it can't escape the ramp. Catching a second target stuns both.
4. **Phantom Dagger** is the gap-closer and the escape.
5. **Death Blossom** gives sustained damage around her and resets Cartwheel.
6. A knock heals her.

## 4. Key frames (`/home/claude/hero-ref/dancer/`)

| File | Caption |
|---|---|
| 0005.jpg | LMB bolt fizzles in a blue puff exactly at the cursor (cursor-placed); the white aim line ends at the cursor |
| 0027.jpg | Passive and Arcslinger cards; the ramping hit numbers on the dummy |
| 0042.jpg | 8th consecutive hit: 275, with a starburst |
| 0063.jpg | Knock: crimson star on the dummy, green +384 heal pillar on Shiv |
| 0085.jpg | Trickshot lane (white rectangle with chevrons) before the throw |
| 0088.jpg | Bolas first hit: GROUNDED, 74, yellow binding rings |
| 0103.jpg | Bolas hits the pillar and bounces |
| 0117.jpg | Two-hit case: STUNNED, 199 |
| 0136.jpg | Cartwheel: sideways flip with a white swoosh arc |
| 0141.jpg | Empowered shot ready: gold aim line to the cursor |
| 0143.jpg | Empowered shot: big yellow lightning streak with a blue chakram |
| 0187.jpg | Empowered hit: yellow 474 (Cartwheel resets) |
| 0193.jpg | Reset Cartwheel used again, the next empowered shot already out |
| 0223.jpg | Phantom Dagger in flight (violet and gold trail) |
| 0238.jpg | Teleport: cyan afterimage chain from her to the dagger |
| 0258.jpg | Dagger stuck in the dummy (yellow glow) |
| 0296.jpg | Death Blossom: cyan ring of about 3.5 bh, blades flying out |
| 0344.jpg | Death Blossom hits, bigger near the rim (151, 236) |
| 0401.jpg | In-game info panel: Ground, Stunned, Slowed, edge bonus, Cartwheel reset |

## 5. Gaps against ours, ranked by how much they change the feel

Files involved:
- `scripts/arch/kits/thief_kit.gd`
- `content/archetypes/thief.json`
- `content/weapons/twin_blades.json` (the signature weapon) and `smg.json`
- `scripts/match/hunter_anim.gd` (`thf_*`)
- `scripts/match/match.gd` `_update_aim()`
- `scripts/match/hunter.gd` primary fire

1. **[mechanic] [aim] [anim] The signature weapon is melee, but the source is a ranged dual-wield bolt.**
   - Ours: `"signature": "twin_blades"`, a melee 3-hit combo with a spin (2.3 m reach). The only ranged option is the
     SMG: 0.12 s, spread, 7 m, falloff.
   - Source:
     - A single aimed bolt every 0.45 s from alternating hands.
     - It ends at the cursor (clamped to max range, at least 7 bh).
     - It is fast, about 25 bh/s.
   - This one change matters more than everything else here. Every other ability (empowered shot, Death Blossom, the
     ramp) is built around a ranged LMB.
   - Change:
     - Add a new signature weapon `content/weapons/<ours>.json` (for example "Arc Bolts"; the name is ours) with
       `rate` 0.45, no `mag` (or a large one), `range` about 8, `speed` about 30, and **`boom`-style cursor clamping**.
     - `hunter.gd` already sets `life = dist / spd` when the weapon has `"boom"`. Add a flag that only clamps life
       without the explosion, for example `"to_cursor": true`.
     - Set `"signature"` in `thief.json` and `title.gd` `WEAPONS["thief"]`.
     - Animation: a new `thf_lmb_l` / `thf_lmb_r` alternating arm whip, played per shot.
2. **[aim] [reticle] The LMB aim line should end at the cursor, plus the gold empowered line.**
   - Ours: `match.gd _update_aim()` draws a white line to `min(cursor, range)`, which already ends at the cursor. Keep
     it.
   - Add an arrow tick at the end.
   - When `ThiefKit.primed_t > 0`, tint the line gold (res_col) and make it brighter: alpha about 0.7 instead of
     0.22.
   - Today Primed is only a glint at the hand (`_tick` glint) plus a crosshair label.
3. **[mechanic] [numbers] The passive is a flat per-hit ramp with no cap in sight, and no visible stacks.**
   - Ours: Marks, +8% each up to 5, lasting 4 s, at most one every 0.3 s, shown as gold diamonds over the target.
   - Source:
     - About +12% of the base per hit, and still climbing after 8 hits.
     - No icon; you see it only in the numbers.
     - The red full-body hit flash marks some steps.
   - Change: `res_def().max` up to about 8 to 10. Raise `per_mark` to about 0.12, and drop `gap` to 0 (with a 0.45 s
     LMB every hit counts).
   - Keep our diamonds. They are more readable, and the brief allows our own look.
4. **[mechanic] Empowered shot = the dash payoff, and it must be the next ranged shot.**
   - Ours: `_primed_hit` adds +10 as a separate melee-tagged `hurt` (`"melee": true`, kb 3).
   - Source: a single big projectile, about 3.5x a normal bolt (474 vs 137), with its own look: a lightning streak and
     a blue chakram.
   - Change:
     - When `primed_t > 0`, swap the next shot's visuals and damage on the weapon itself. In `thief_kit`, hook the
       shot spawn (an `outgoing` multiplier of about 3.5 for the primed shot) instead of adding a second hit.
     - Drop `"melee": true` from `_primed_hit`.
   - The reset-on-hit and Shred already match.
5. **[numbers] Dash and cooldowns.**
   - Source: Cartwheel 4.2 s, with the loop about 1.4 s while hits land. Trickshot 6.7 s. Dagger 15 s.
   - Ours: Vault `cd` 6.5, Bola 12, Knife 18.
   - Change: Vault to about 4.5, Bola to about 7, Knife to about 15.
   - Vault distance: ours is 3.4 m in 0.16 s. The source is shorter and slower to read, about 2 bh over about 0.3 s.
     Set `dist` to about 2.4 and `time` to about 0.25.
6. **[anim] Vault should be a sideways cartwheel with a swoosh arc.**
   - Ours: `thf_vault_f/b/l/r` is a tucked flip chosen by direction.
   - Source: always a cartwheel, with the body turning in the plane of travel and the hands and feet tracing a white
     arc.
   - Change:
     - Make `thf_vault_l/r` the default, using `fz` rotation (already there) with the arms out, for every direction.
     - Add an arc trail. `travel(..."trail": "ghost")` becomes a new `"trail": "arc"` in fx.
7. **[reticle] [mechanic] Bola cast window and lane.**
   - Source: on press, a white chevron lane about 1 bh wide and about 6 bh long shows for about 0.4 to 0.6 s before
     the throw.
   - Ours: `fire_rmb` waits 0.14 s with no lane.
   - Change:
     - Raise the delay to about 0.4.
     - In `fire_rmb`, add `tele_lane(h.pos, aim_dir, range, 1.0, col, 0.4)` that follows the aim during the wait. Use
       the `coil_tele` pattern from `mage_kit.gd`.
     - Range: ours is 10 m, then 5 m after the first foe. The source lane is about 6 bh in total. Set `range` to
       about 7, with `after` inside the lane.
8. **[mechanic] Bola bounces off terrain.**
   - Source: the bolas rebounds off a pillar (`0103` to `0105`).
   - Ours: `_tick_bola2` ends at `is_block`, and the first leg is a plain stage projectile.
   - Change: on a wall hit, reflect `dir` once and keep `left`.
   - Whether a wall counts as the 2nd target for the stun is an open question.
9. **[vfx] Bola Grounded tell.**
   - Source: bright yellow binding rings around the target (about 1.5 bh) while Grounded.
   - Ours: depends on KitStatus `gnd`. Check that it shows a ring.
10. **[mechanic] Phantom Dagger teleport.**
    - Source: an instant blink with a cyan afterimage chain.
    - Ours: `_step_to_knife` teleports at once (`h.teleport`) and adds one `fx.ghost` plus a bolt line.
    - Change: spawn 4 to 5 `fx.ghost` copies evenly along `from` → `to`.
    - Ours steps you to the knife automatically after 5 s (`_e_end`). The source didn't auto-teleport within 5 s;
      check the wiki's 6 s rule.
11. **[mechanic] R: dropped under the Merge rule, but our data still has it.**
    - `thief.json` still defines `"r": Jackpot`, wired to R via `use_r()`. It only runs when `KinCommand.class_ults()`
      is on (`hunter.gd:2178`).
    - `docs/wiki/Classes.md` line 54 still lists Jackpot.
    - Decide one of two things:
      - Fold its function in: "for 2 s after a Primed hit, the LMB also auto-fires at every foe in 3.5 bh" is one
        option, or put the Cartwheel reset on E.
      - Or remove `r` from the data and the wiki.
    - Our Jackpot numbers (8.5 m reach, 5 m inner) also don't match the source (radius about 3.5 bh, edge bonus,
      cyan ring).
12. **[vfx] Knock feedback.**
    - Source: a big crimson four-point star on the knocked target, and a green heal pillar with the number on Shiv.
    - Ours: the word TAKEN or ASSIST and a green burst.
    - The green pillar is generic enough to add (`on_knock`).
13. **[sfx]** No audio in the footage.

## 6. Rename: every player-facing place that still says "Thief" (it should say Dancer)

| File | What |
|---|---|
| `content/archetypes/thief.json` line 3 | `"name": "Thief"`. The kit card, HUD, title and gen_wiki read it. |
| `scripts/match/hero_kit.gd` line 14 | `"thief": {"name": "Thief", "cls": "light"}`, the roster |
| `docs/wiki/Class-Thief.md` | Generated page. Rename it by regenerating `tools/gen_wiki.py`, then delete the old file. |
| `docs/wiki/Classes.md` lines 7, 41, 54, 73 | Lines 54 and 73 are generated tables; regenerate. Lines 7 and 41 are prose. Check whether gen_wiki writes them; if not, edit by hand. |
| `docs/wiki/Weapons.md` line 30 | Twin Blades row ("Thief"); generated |
| `docs/wiki/Home.md` line 22 | Class list, **hand-written**. It also needs Dancer, Pin, Bjorn, Venator, Linwick, Moosh Moosh and Breah. |
| `docs/wiki/_Sidebar.md` line 7 | Sidebar link, hand-written |
| `docs/wiki/Inspirations.md` | Thief row |
| `docs/wiki/Build-and-Ship.md` line 34 | Historical note; probably keep |
| `content/weapons/twin_blades.json` `desc` | Doesn't name the hero, but it says "Right click to knife and step behind the target", which is stale. The RMB is the Bola. |

Code ids only (not player-facing): `ThiefKit` (`thief_kit.gd`, `arch_kit.gd:40`, `arch_demo.gd:122`,
`arena_demo.gd:114,134`), comments in `hud.gd`, and `tools/archetype_check.gd`, `tools/arena_check.gd`,
`tools/sfx_combat.py:543`.

Not found: no "Thief" in `translations/rebrand.en.po`. A msgid/msgstr pair there is an alternative to changing the
JSON.

## 7. Open questions

1. **Trickshot input:** is it a hold-and-release or a fixed cast time? The lane was visible for 0.4 to 0.6 s every
   time.
2. **Trickshot stun:** at `0117` the second "target" was not obvious. Does terrain or a bounce count, or was a
   second dummy off-screen?
3. **Arcslinger max range:** the exact clamp isn't shown. The cursor-placed fizzle was seen at about 4.7 bh, and hits
   at about 7 bh.
4. **Passive ramp:** the cap and the decay time aren't shown, since it was still climbing at 8 hits. What does the
   periodic red full-body flash mean?
5. **Cartwheel direction:** movement direction or cursor?
6. **Phantom Dagger:** is there an auto-teleport timer? What range does it reach with no target?
7. **Death Blossom:** does it apply passive stacks, and does it count as LMB hits?

## Ultimate (on X)

**Source:** Shiv, Death Blossom. Card: "Shoot at each nearby enemy over 2s", 23.1 s, 20 mana. Frames are in `/home/claude/svvid/ult/dancer/` (frame N = 334 s + (N-1)/10). Casts start at f27, f77, f121 and f195.

1. **Input:** tap. Fine print: "after a short delay", it fires **up to 5 shots at each nearby enemy over 2 s**.
2. **Aim:**
   - **Self-centred** and auto-targeted: every enemy inside the ring is shot. The ring **moves with her**, and she runs freely during it (f41–f47 she walks left, ring attached).
   - No movement slow is visible. She can keep using LMB.
3. **Reticle / telegraph:**
   - A **cyan ring** grows from about 1.3 bh (f27) to about 3 bh radius (f31) over about 0.4 s. That growth is the "short delay".
   - The interior is tinted dark. The ring stays up for the 2 s duration.
   - Fine print: the **outer band** of the ring is a sweet spot.
4. **Animation beats:**
   - f27–f30: the ring grows while she raises her blades.
   - f31–f50 (about 2 s): small **blue-violet blade projectiles with red tips** orbit and fly out of her to targets inside the ring, one about every 0.2–0.4 s per target. She plays a spinning throw pose between shots (f33–f35).
   - The end is a plain fade. There is no final burst.
5. **VFX:** the blades are spinning crescent daggers with short blue trails. On hit: a red flash and damage numbers; the outer-band hits show a **⊘ Anti-Heal icon** over the target (f121). The ring plus orbiting blades read as a "blade storm"; the look isn't overly distinctive.
6. **Sound:** none. It suggests a whirr while active and quick thunks per hit.
7. **Numbers:**
   - Hits of **122, 127, 114**, then **236** (an outer-band hit with the bonus) on one dummy (f121–f127).
   - Fine print: each shot does 36 + 19%. Targets in the outer ring take +18 + 9.5% and are **Anti-Healed for 6 s**.
8. **Ends / combo:**
   - It ends after 2 s.
   - Combo: dagger-teleport (Phantom Dagger recast) into a group, then Death Blossom, keeping enemies at the ring edge for the bonus and Anti-Heal. Trickshot's ground, then Blossom, is also natural because grounded targets can't leave the ring.
   - Allies: unaffected.

**Key frames:** `dancer/ult_0027.jpg` (ring starts small), `ult_0029.jpg` (ring growing), `ult_0033.jpg` (full ring, first blades), `ult_0035.jpg` (blade release pose), `ult_0041.jpg` (moving with ring attached), `ult_0047.jpg` (blades crossing to a target), `ult_0121.jpg` (hit 122 with Anti-Heal icon), `ult_0125.jpg` (multi-hit numbers), `ult_0127.jpg` (outer-band 236).

**Build notes:**
- **What to build:** X = a self-centred 3 bh ring. It grows for 0.4 s, then auto-fires at every enemy inside for 2 s (up to 5 hits each). The outer 25% band adds bonus damage and Anti-Heal. She moves freely throughout.
- **Bond:** each blade that hits a hunter adds about 0.06, and an outer-band hit adds about 0.1, capped at **0.7** per cast. Five hits on one target gives about 35%; holding two at the edge gives about 70%. It rewards positioning, not just pressing.

## Body, scale and movement feel

Method and units are as in venator.md's section of the same name: the hunter's ground motion comes from tracking the bar plus the camera pan. Distances are in 960 px units, 1 px ≈ 0.0375 m, 1 bh = Ghost's height ≈ 48 px ≈ 1.8 m. Zoom is the same in every clip; the training dummy is an Oath-model hunter, ~107 px tall at 1080p. Video time t = 278 + (frame-1)/5.

### 1. Height and bulk
- **Shiv:** ~93-95 px at 1080p from head to sole (0003, 0094). The body is narrow, ~45-55 px wide, and the arms reach ~100 px when spread with the blades out.
  - The bar's cyan line sits ~100 px above the soles (~1.05 bh): **the lowest anchor of the six, along with Joule's.**
- **Against Ghost (~96 px):** **~0.95-0.98x as tall, the same slim width.** Against the Oath dummy: ~0.9x as tall, under half as wide.
  - The earlier "40 px" estimate in this sheet was low. Measured at full resolution she is close to Ghost's height.
- **Ours:** thief is light, 0.9 × 0.95 = **0.855x medium**.
- **Target scale factor ~0.95** (about ×1.11 on now). Keep the light build.

### 2. Locomotion
- **Run speed:**
  - The median steady move is 113 px/s ≈ 4.2 m/s, the same as the others.
  - **After a Cartwheel she runs 127-136 px/s for ~1-1.5 s** (0206-0212, 0242-0246, 0390-0395), about +15-20%.
  - Stretches while she fires the LMB are slower, 77-86 px/s (0006-0015, 0230-0233, 0323-0326). That may be an attack slow, but it isn't confirmed (see §9).
  - Ours: Vault haste +30% for up to 2 s, and light base 5.0.
- **Acceleration and stopping:** instant, like the others.
- **Cadence:** stride cycle ~2.3 Hz (≈4.5 steps/s). Ours: light 1.71 Hz (thief bounce 1.7 on top).
- **Lean:** the strongest lean of the six.
  - At a run she pitches far forward, almost horizontal through the torso, the coat streaming out behind, both arms out at the sides holding the blades ready to fire (319.0-319.9 s, 0206-0210).
  - The silhouette is long and low.
  - Ours: thief lean 0.22 + 0.12 at a run ≈ 0.34 rad. **The source looks nearer 0.6-0.7 rad.**
- **Bob:** springy but small. No bar movement is visible, and the body rise per step is under ~3 px.
- **Turning:** the torso snaps to the cursor while firing with either hand, and the legs keep running.

### 3. Idle
- She holds a wide, low stance with both arms raised, a blade up in each hand (0094, 334.0-335.2 s, 0281-0287).
- She stays almost still. No loop or fidget can be resolved at 5 fps or in the 10 fps strip.
- Ours (bounce 1.7, breath 3.1) is livelier than anything visible. That's acceptable, but keep the arms up rather than at the hips.

### 4. Ground dash (Shift: Cartwheel)
- **Body (312.9-313.6 s, 0176-0178):**
  - ~0.05 s of crouch.
  - The body turns sideways and goes over the top with the legs split wide (313.15-313.30 s), about a 0.25-0.3 s cartwheel.
  - She lands in a low crouch (313.35-313.45 s) and is up and moving by ~313.5 s.
  - It runs about 0.45-0.5 s from start to upright.
- **Distance and curve:**
  - Ground casts 0176-0204 cover 105-144 px ≈ 3.9-5.4 m ≈ 2.2-3.0 bh, above run speed for 0.37-0.57 s.
  - Peak 400-440 px/s (15-16.5 m/s) at +0.1-0.27 s, then a steady decay into the faster post-cartwheel run (e.g. 20 → 213 → 415 → 415 → 315 → 211 → 154 → 140 px/s).
- **Ours (kitfix-dancer-juggernaut):** Vault is 2.4 m in 0.25 s, and the `thf_vault` keys flip by 0.26, land at 0.33 and are up by 0.55. The timing is right. **The distance is short: the source covers ~4.5 m, about twice ours.**

### 5. Air dash (Cartwheel from a jump)
- **Body (303.8-304.5 s, 0129-0134; also 0153-0156):**
  - She jumps at 303.8 s; the gold landing marker and a round shadow appear under her.
  - She cartwheels in the air with the body horizontal and the legs split (304.0-304.25 s).
  - She lands at ~304.3 s in a low crouch and is back up by 304.45 s.
- **Distance:** the whole move covers 225 px ≈ 8.4 m ≈ 4.7 bh over ~0.95 s (also 223 px at 0153-0156).
  - Peak 496 px/s.
  - **The speed then holds near ~240 px/s (2x run) for ~0.5 s**, where the ground version decays.
- **Difference from the ground version:** the same flip, but about 1.7x the distance, because the air speed doesn't bleed off until she lands. There is no extra float or hang.
- **Ours:** `thf_exdash` is a tucked forward tumble (0.45 s), and the light ex-dash is 5 m in 0.2 s. **The source air move is the same sideways cartwheel, not a tumble.**

### 6. Jump and landing
- The jump at 303.8 s takes ~0.5 s from takeoff to touchdown.
- The bar-to-shadow gap suggests ~1-1.3 m of lift. Our jump is a 1.28 m apex in 0.55 s, so they match.
- Landing: a low crouch held ~0.1 s, then up in ~0.05 s. No dust.

### 7. Cast and attack body language
- **Budget:** large and constant.
  - Every shot whips one arm out from the wide stance with the torso turned ~30°.
  - The ult snaps the body side to side while walking.
- **Squash and stretch:** a stretch through the cartwheel and a squash on every landing.
- **Timing:** shots are 2-3 frames each, the cartwheel is ~0.3 s, and the landing is ~0.1 s.

### 8. Build notes
- **Model scale:** ~0.95 (up from 0.855).
- **Collision:** hit_r 0.35. With the scale up her silhouette stays narrow (~0.45-0.5 m), so 0.35 is still fair. Keep it.
- **Camera and nameplate:** her bar anchor is the lowest, ~1.05 bh ≈ 1.9-2.0 m. Use **~2.15 m** instead of the shared 2.35 so the plate hugs her head.
- **KMOVES and locomotion:**
  - Cadence about `spd*2.9`.
  - Running pitch toward ~0.6 rad: raise the thief run lean `r1*0.12` → ~0.35.
  - Arms out to the sides while running, blades forward.
  - Post-Cartwheel haste of ~1.15-1.2 rather than 1.3.
- **Dash curves:**
  - Ground Cartwheel: ~4.5 m. Peak ~16 m/s at ~0.15 s, decaying to the haste run speed by ~0.45 s. Keep the 0.55 s `thf_vault` keys.
  - Air Cartwheel: reuse the same flip keys. Hold ~2x run speed until landing; don't decay.
- **Sound:**
  - Footsteps: very light, quick taps.
  - Cartwheel: a sharp cloth snap, a whoosh over the top, and a soft two-beat landing (hand, then foot).

### 9. Unclear
- Whether firing slows her (77-86 px/s while shooting against 113 otherwise). Settle it with a clip of a straight run with and without LMB held.
- A cartwheel off a ledge (fall plus air carry). Settle it with an air Cartwheel over a gap.
- Exact cadence at 60 fps on a straight run with no firing.
