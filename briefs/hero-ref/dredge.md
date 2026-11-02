# Dredge: reference sheet (source: Kingpin)

Footage: `/home/claude/svvid/hero/dredge/frames`, 5 fps, video 456-526 s, so frame N = second 456 + (N-1)/5. The video has no audio.
Our code was read at origin/main **4f82978**. That is a direct descendant of the brief's 7881774; the only change for this hero is dash tuning (barge 0.34 s).

**Segment check:** the guess is correct. The cards and the end-of-kit summary (`frames/0336.jpg`) show the five abilities named in the brief, plus the passive *Feed the Beast*. That matches docs/heroes/dredge.md and the Inspired-by table (Kingpin):
- 7-slug gun
- arm grab that pulls
- dash that goes further in the air
- fist slam that stuns
- R: two volleys with anti-heal

Our doc calls the R "Slugwave". The in-game name is *Kaiju Blast*; it works the same way.
The kit ends at 522 s. The 526-578 s gap is a different hero (Spike Grenade, Combat Slide, Ion Cannon, Mini Nuke), not Kingpin.
The summary screen (`0336`) shows that player's own keybinds (Grasp on E, Dash on Space, Smash on L Shift, Blast on Q). The in-demo cards use the default layout used in the table below.

Scale: the hunter is about 55 px tall at this zoom (1 unit = 1 body height). Ranges below are in body heights (bh).

## 1. Source summary

| Slot | Ability | Input | Aim type | Cooldown (card) | Cost | Effect |
|---|---|---|---|---|---|---|
| Passive | Feed the Beast | none | none | none | none | Knocks and assists give bonus max health; bonus backstab damage |
| LMB | Buckshot | hold (auto-repeat) / tap | cone of slugs to a fixed range (does not stop at the cursor) | 0.5 s | 10 mana | "Fire a burst of slugs": about 7 slugs that slow and stop about 3.5 bh out |
| RMB | Kaiju Grasp | tap | skillshot line, first enemy hit, **passes through terrain** | 11.7 s | 40 | Huge arm shoots out, grabs, reels the target to your feet; target STUNNED, you GROUNDED while reeling; grabs wisps along the way |
| L Shift | Brute Dash | tap | toward the cursor | 5 s | 15 | Short dash; further when airborne |
| E | Iron Smash | tap | short forward hop + slam in front (facing / cursor) | 6.7 s | 30 | Fist slam: damage + stun |
| R | Kaiju Blast | tap (2 casts) | cone telegraph, fan of orbs | 20.8 s | 25 | Two energy blasts: damage + Anti-Heal |

Damage numbers seen (dummy, hunter level 9): a close full Buckshot volley 193 (`0076`); a knock volley 451 (`0110`); Iron Smash 349 (`0235`); Kaiju Blast 756 per close volley (`0294`).
**Ratio to keep:** Smash ≈ 1.8× a point-blank volley.

## 2. Per ability

### Passive: Feed the Beast (`0092`)
1. **Input:** none.
2. **Aim:** none.
3. **Reticle:** none.
4. **Anim:** none of its own.
5. **VFX:**
   - A knock gives a large crimson starburst on the victim, with a big pink number (451), then the victim turns into a wisp (`0110`, `0112`).
   - After the knock, a red tint pulse fills the ground around the hunter for about 0.4 s (`0112`).
   - Backstab hits have no visible tell of their own beyond larger numbers.
6. **Sound:** n/a.
7. **Numbers:** the card text only: "Knocks and assists grant bonus Max Health. You deal bonus backstab damage."
8. **Combo:** knock with the gun from behind; Grasp pulls them to you facing away? (not shown).

### LMB: Buckshot (`0040`, `0046`, `0080`)
1. **Input:**
   - Hold to auto-fire. The shots are 2-3 frames apart (0.4-0.6 s), which matches the 0.5 s card.
   - Movement continues while firing; the hunter walks between shots.
2. **Aim:**
   - The slugs fly in a fan centred on the cursor direction and **stop at a fixed range of about 3.5 bh whatever the cursor distance**. In `0046` the cursor is at 1.2 bh and the slugs hang at 3.5 bh.
   - The hunter turns to the cursor.
3. **Reticle** (`0040`, `0112`):
   - The cursor is a small white ring with a dot.
   - Two thin white lines (about 1 px, roughly 70% opacity) start just in front of the hunter and run out to the slugs' stop range, marking the **edges of the spread cone**.
   - The cone is about 30° (`0040`) and narrows to about 20° (`0112`).
   - When idle it collapses to **one thin line from the hunter to the cursor** (`0092`).
   - The reticle is world-space and always drawn under the hunter.
4. **Anim:**
   - One-handed hip-fire: the gun is held out in front.
   - On the shot frame there is a bright muzzle flash at the barrel tip (`0041`, `0044`), the barrel kicks up, and the torso rocks back (`0045`, `0080`: the body turns side-on, gun arm swung across).
   - Recovery takes about 1 frame (0.2 s) before the next shot.
5. **VFX:**
   - Muzzle: a white-hot flash about 0.4 bh across, 1 frame.
   - Slugs: about 7 small bright pink-white streaks with short trails that fan out (`0042`, `0047`). They decelerate and **hang as small blue-violet glowing dots at the stop line for about 0.2-0.4 s**, then fade (`0043`, `0046`).
   - Hits: a white flash on the target and stacked white numbers.
6. **Sound:** n/a.
7. **Numbers:**
   - Cooldown 0.5 s, 10 mana.
   - A point-blank volley lands about 193 (`0076`): slugs 49/97 stacking into one number.
8. **Combo:** the finisher after Grasp + Smash.

### RMB: Kaiju Grasp (`0119`, `0123`, `0127`, `0141`, `0147`)
1. **Input:**
   - Tap. Our doc says only the dash can be used while it reels; the video doesn't test this.
   - The hunter keeps moving during the throw: the body stays planted, the arm extends.
2. **Aim:**
   - A skillshot along the cursor direction. The thin aim line (`0119`) runs from the hunter to the cursor.
   - It flies to max range (about 6-7 bh) or to the first enemy.
   - It **does not stop at terrain**: in `0141` the arm passes through a rock pillar (drawn as a dark-blue silhouette behind the rock) and grabs the dummy beyond it. The dummy is then dragged across the rock (`0147`).
   - The card also says "Grabs wisps along the way".
3. **Reticle:**
   - Only the standard thin aim line to the cursor. No range circle and no width indicator are visible.
4. **Anim:**
   - Frame 121: the gun goes to the off side and the free arm punches forward.
   - Frames 121-123 (0.4 s): the arm extends to about 5 bh, so roughly 12 bh/s.
   - Frame 124: the grab. Frames 124-129 (about 1.0 s): the pull, about 5 bh/s.
   - Through the pull the hunter is braced and side-on, turned toward the target. The pull follows the hunter, not the cursor: in `0147` the cursor is elsewhere.
   - The target ends adjacent, in front of the hunter (`0130`).
5. **VFX** (`distinctive`):
   - A thick, glowing magenta-to-violet energy arm made of 2-3 twisting strands, with a bright clawed "hand" at the tip.
   - The strands spiral around each other along the whole length.
   - Status labels: the **caster gets "GROUNDED" with a white chain ring at his feet**, and the **target gets "STUNNED" during the pull** (`0127`, `0147`).
6. **Sound:** n/a.
7. **Numbers:** cooldown 11.7 s, 40 mana. Grab damage is small (not legible).
8. **Combo:** Grasp, then the target arrives stunned at your feet, then Iron Smash and Buckshot.

### L Shift: Brute Dash (`0188`)
1. **Input:** tap. The card says it goes further when airborne.
2. **Aim:**
   - Toward the cursor: in `0186`-`0189` the cursor is to the right and the dash goes right.
   - About 2.5-3 bh in one frame (≤0.2 s).
3. **Reticle:** none.
4. **Anim:**
   - Body pitched forward, gun trailing.
   - Lands in a crouch and turns back to the aim within 1 frame.
5. **VFX:**
   - At the **start point** a large red burst: a red sphere about 1 bh across with red spikes radiating out (`0188`).
   - It leaves an orange ember scorch on the ground for about 1 s (`0189`).
   - No trail along the path.
6. **Sound:** n/a.
7. **Numbers:** cooldown 5 s, 15 mana. One charge is visible.
8. **Combo:** usable during the Grasp reel (per the doc). It is not shown shoving anyone.

### E: Iron Smash (`0221`-`0223`, `0233`-`0236`)
1. **Input:** tap. It resolves in about 0.4 s.
2. **Aim:**
   - Lands in front of the hunter, in the facing/cursor direction.
   - A small forward hop of about 1 bh.
   - The hit area is a short arc right in front, about 1.5 bh deep and 2 bh wide.
3. **Reticle:** none before the cast. A faint white rectangle outlines the hit box on impact (`0223`).
4. **Anim:**
   - f1, the wind-up (`0221`, `0232`): the fist is hauled back and the shoulder turns away.
   - f2 (`0222`, `0233`): a hop up and forward. The hunter is visibly airborne and the shadow stays behind.
   - f3, the impact (`0223`, `0234`): the fist drives down.
   - f4-f5: a crouched follow-through, then recovery.
   - Press to impact is about 0.4 s, and the total is about 0.8 s.
5. **VFX** (`distinctive`):
   - A **giant translucent magenta fist** appears above the target point and slams down, about 2 bh tall.
   - A bright pink crescent shockwave sweeps across the front.
   - Next frame, a big white dust cloud about 1.5 bh across (`0236`). It thins over 2 frames into sparkles.
   - The target shows "STUNNED" with a dark spiral over its head.
6. **Sound:** n/a. (It should feel like a heavy thud plus a crunch.)
7. **Numbers:**
   - Cooldown 6.7 s, 30 mana.
   - Hit 349.
   - **STUNNED is shown for about 1.2-1.4 s** (frames 235 to 241).
8. **Combo:** the core payoff. Grasp brings the target to your feet already stunned, then you Smash.

### R: Kaiju Blast (`0290`, `0294`, `0302`)
1. **Input:** tap, then recast: two blasts about 4-6 s apart (`0294`, `0320`).
2. **Aim:** a cone toward the cursor, about 120° wide and 3-4 bh deep.
3. **Reticle:** a translucent white fan or semicircle on the ground in front, about 3 bh in radius, shown while it charges (`0290`, `0318`).
4. **Anim:**
   - About 0.6 s of charge: magenta crackle around the hands, hunched.
   - Then a forward thrust.
5. **VFX:**
   - About 6-7 large violet-blue (first blast) or magenta (second) orbs in a fan.
   - **Anti-Heal:** green vertical streaks rising out of the target for about 1 s (`0302`).
6. **Sound:** n/a.
7. **Numbers:** cooldown 20.8 s, 25 mana, about 756 per close volley.
8. **Combo:** not used. For us R is the Boki Merge and the doc drops this ultimate, so this is reference only.

## 3. Key frames (`/home/claude/hero-ref/dredge/`)

| File | Caption |
|---|---|
| 0040.jpg | Buckshot reticle: cursor ring plus two cone-edge lines out to the slug range |
| 0046.jpg | Slugs stopped and hanging as blue dots at about 3.5 bh, past the cursor |
| 0080.jpg | Point-blank volley; recoil turns the body side-on |
| 0092.jpg | Idle: a single aim line; passive card (Feed the Beast) |
| 0110.jpg | Knock: crimson starburst, 451 |
| 0119.jpg | Grasp aim: thin line to the cursor; card shows 11.7 s |
| 0123.jpg | Grasp arm fully out (0.4 s after cast), twisted strands and a claw hand |
| 0127.jpg | Reel: caster GROUNDED with a chain ring, target STUNNED |
| 0141.jpg | Grasp goes through a rock pillar (silhouette through the occluder) |
| 0147.jpg | Target dragged over the rock toward the caster; cursor elsewhere |
| 0188.jpg | Brute Dash: red burst left at the start point |
| 0221.jpg | Iron Smash wind-up: fist back |
| 0222.jpg | Iron Smash hop: airborne, shadow behind |
| 0223.jpg | Iron Smash impact: giant fist, crescent, hit-box outline (miss) |
| 0234.jpg | Iron Smash on the dummy: fist plus crescent |
| 0235.jpg | 349, STUNNED |
| 0236.jpg | Dust cloud after the slam |
| 0290.jpg | Kaiju Blast cone telegraph |
| 0302.jpg | Anti-Heal: green streaks on the target |
| 0336.jpg | Kit summary screen (names and text) |

## 4. Gaps against ours, ranked by how much they change the feel

1. **[mechanic] The Grapnel stops at walls; the source goes through terrain.**
   - Source: the arm passes through rocks and pillars and drags the target over them (`0141`, `0147`).
   - Ours: `DredgeKit.fire_rmb` stops at a wall ("SNAGGED"), and `_tick_pull` ends the reel at walls ("WALLED").
   - The doc says this was a deliberate brief choice. Owner call: to match the source, give the hook's projectile pierce-terrain, and in `_tick_pull` move the body without `m.world.occupy` (keep the abyss rule).
2. **[numbers] Cooldowns are all longer than the source, and the gun fires at half the rate.**
   - Buckshot 0.5 s vs ours `shotgun.json` `rate` 1.0.
   - Grasp 11.7 s vs `dredge.json` `rmb.cooldown` 14.
   - Dash 5 s (1 charge) vs `dash.cd` 12 (2 charges).
   - Smash 6.7 s vs `e.cooldown` 10.
   - Suggest: rate 0.5 (rescale `dmg` so DPS holds), Grapnel 11.7, Anchor 6.7. Barge: 1 charge at 5 s, or keep 2 charges at about 10 s.
3. **[numbers] Anchor stun is about a third of the source's.**
   - Source STUNNED reads about 1.2-1.4 s (`0235`-`0241`); ours `e.stun` is 0.45.
   - Damage ratio: source Smash ≈ 1.8× a point-blank volley; ours is 25 vs 28 (0.9×).
   - Change in `dredge.json` `e`: stun ≈ 1.0-1.2, dmg ≈ 50.
4. **[reticle] No shotgun cone in the world.**
   - Source: two thin cone-edge lines from the hunter to the slug stop range, widening with bloom and collapsing to one line when idle (`0040`, `0092`).
   - Ours: only the HUD crosshair gap opens (`scripts/ui/hud.gd` `_draw_crosshair`).
   - Add a world-space ground cone (two lines, length = `range`, half-angle = (`fan_deg` + `wbloom`)/2) for pellet weapons, drawn under the hunter. It could live in `Hunter` or `hud.gd` (projected).
5. **[mechanic] Who is Grounded during the reel is inverted.**
   - Source: the caster is GROUNDED (chain ring) while reeling and the target is STUNNED for the whole pull.
   - Ours: the target gets `stun_t` 0.2 refreshed each tick (equivalent) and is Grounded 1 s **after** arriving. The caster isn't grounded.
   - In `_grab`, put a `KitStatus "gnd"` on `h` for the reel time (no jump, no glide). Keep the target stunned. The landing Grounded can stay as ours.
6. **[anim] Anchor Drop has no forward hop.**
   - Source: wind-up (1 f), a hop up and about 1 bh forward (1 f), slam (impact at about 0.4 s).
   - Ours: `dr_anchor` stands in place with a 0.22 s wind-up.
   - Lengthen `e.windup` to about 0.35-0.4. In `kmoves_pair.gd` `dr_anchor`, add a `lift` rise at 0.15-0.25 and a forward root motion of about 1 bh (move `h.pos` in `_anchor` or with a small `travel` in `cast_e`).
7. **[vfx] The Anchor slam has no "giant fist" read.**
   - Source: a huge translucent fist about 2 bh tall drops onto the point, then a crescent shockwave, then a white dust cloud and stun spirals (`0234`-`0236`). This is `distinctive`.
   - Ours: `m.fx.cone` + ring + dust.
   - Keep the function: a big translucent anchor (our object) dropping from above onto the cone centre for 1-2 frames, then a crescent sweep, then a larger dust cloud (`m.fx.dust` count ×2, bigger). Add a stun swirl over the victim. In `DredgeKit._anchor`.
8. **[vfx] The Grapnel line is too thin and plain.**
   - Source: a thick, twisting double or triple strand with a claw at the tip, drawn through occluders (`0123`, `0141`). Both the twist and the claw are `distinctive`.
   - Ours: a single 0.08 m glow box (`_grab`).
   - Make our rope thicker (0.18-0.25), braided (2 boxes with a phase offset), with a hook head mesh. Use `no_depth_test` so it shows through rocks when it pierces.
9. **[mechanic] The source Grasp grabs wisps along the way.**
   - The card text says the arm also picks up wisps (downed hunters) it passes.
   - Ours: nothing. Possible: in the hook's flight, collect downed hunters within 0.5 m of the path and reel them too. Owner call, since it interacts with life.gd stomps.
10. **[vfx] The Barge has no start-point burst.**
    - Source: a red spiky burst at the origin plus a 1 s ember scorch (`0188`, `0189`).
    - Ours: a `dust` trail only (`on_dash`). Add `m.fx.burst` + a scorch decal at `from`.
11. **[numbers] Shotgun range and fan.**
    - Source slugs stop at about 3.5 bh and the fan is about 30° (rested 20°).
    - Ours: `range` 5 m and `fan_deg` 60 (+ bloom up to 24).
    - Our fan is about twice as wide. Suggest `fan_deg` ≈ 30, `bloom_max_deg` ≈ 15. Check the m-per-bh scale before changing `range`.
12. **[vfx] Slugs don't hang at the stop line.**
    - Source: the slugs come to rest as small blue-violet dots for about 0.2-0.4 s, then fade (`0046`).
    - Ours: `decel` stops them and they vanish at life end (+0.05 s).
    - Extend the shot life by about 0.25 s after they stop, with a fade (`Hunter._emit_shot` `life` for `decel` weapons; fx in `m.spawn_shot`).
13. **[anim] Shotgun recoil.**
    - Source: on each shot the body rocks back and turns side-on, with a big muzzle flash 1 frame.
    - Ours: the class default fire pose (doc: "none").
    - Add a `dr_shot` KMOVE (0.0 kick: pitch back 0.25, yaw 0.4; back by 0.25 s) and play it from the kit on fire.
14. **[sfx]** No audio in the footage, so there's nothing to compare.

## 5. Rename
Dredge keeps its name; it isn't in the rename list.

## 6. Open questions
- Whether the reel can be cancelled, or the hunter can shoot during it. The video only shows standing still.
- Whether Grasp has a grab hitbox wider than the arm, and how far max range is with no target. No full whiff is shown.
- The air dash distance ("further while airborne") isn't shown.
- Whether Iron Smash in the air drives you down (our rank feature). Not shown.
- What the backstab bonus is worth; not shown separately. Also the max-health gain per knock (the HP bar isn't legible).
- Whether Buckshot uses ammo or a magazine. No reload is seen in about 20 s of fire, and each shot costs 10 mana.
