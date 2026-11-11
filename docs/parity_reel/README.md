# Parity reel (the Hunters against the source)

One reel per Hunter, played in the Training Grounds against a dummy at the match camera, with the keys shown along
the bottom. Each MP4 is 960x540, 30 fps, about 40 s, under 4 MB. Beside each reel is what still differs from the
source. Order of trust: owner notes (briefs/DECISIONS.md) over the source game data [D] over footage [F]
(briefs/hero-ref sheets). The lists start from `docs/KIT_PARITY.md` (re-checked on main d255acbee) and
`docs/heroes/<id>.md`, and were checked by eye against the footage frames and the reel.

## What a reel shows (same timeline for every Hunter)

| Time | Part | Keys |
|---|---|---|
| 0:00 | LMB tap, three times | LMB |
| 0:03.6 | LMB hold | LMB |
| 0:07.9 | RMB, then again | RMB |
| 0:12.7 | E, then a second press (the recast, for kits that have one) | E |
| 0:17.5 | R, then a second press | R |
| 0:24.4 | dash on the ground, twice | Shift |
| 0:28.2 | jump, then dash in the air | Space, Shift |
| 0:32.0 | jump and hold Space: the glide, steering round | Space, WASD |
| 0:37.1 | mantle | none (the catch is automatic) |

- The second press is the same for every Hunter. It does something only where the kit has a recast (Neve E and R,
  Motley E, Sable E, Sparkle R); elsewhere it just shows the next cast or nothing.
- The Training Grounds has no terrace to run into, so the mantle part drops the Hunter just under an island rim,
  moving in, and the lip catch carries them over (the `--cliff-mantle-check` "abyss" case). A terrace mantle is
  covered by that check, not by a reel.
- The dummy stands 7 m away (12 m for the three travel parts).
- Re-render one: `jobq submit --needs gpu --tree <tree> --out shots -- --parity-reel --shots-dir=shots
  --reel-hero=<id>`, then `ffmpeg -framerate 30 -i shots/frames/%05d.jpg -c:v libx264 -crf 30 -pix_fmt yuv420p
  <id>.mp4` (`tools/parity_reel.gd`, built on `tools/hero_vfx_reel.gd`; `--reel-only=<part>` plays one part).
- The R segment of each MP4 is spliced from a second render of just that part (the first render pressed R through
  the wrong key path); the timeline above is unchanged.

## Shared by all six

- **Cooldown pace:** 0.48x to 1.0x of the source's, per kit (KIT_PARITY gap 10, still open, owner call). Numbers per
  Hunter below.
- **Q** is ours (a glove); the source has no Q.
- **Jump** 6.8 m/s vs the source's 7.5 (kept on purpose, KIT_PARITY item 20).
- **Glide dive** (hold Ctrl under the glider) has the source's numbers, but the key is ours.
- **Dash to LMB/RMB flow rows** marked `[?]` have no source; they run as the kit's default.

## Grimble the Scrap King (`dredge`, source Kingpin)
[dredge.mp4](dredge.mp4)

Still differs:
- Cooldowns: Abyssal Hand 12 s vs 18, Anchor Drop 7 vs 12, Brass Broadside 21 vs 36 [D].
- Barge: three chained shoves with a 10 s recharge; the source has one dash per 7 s (owner, Nov 3 23:40: several
  short fast dashes). The air pounce has the source's own 12.5 s slot.
- The Hand is a bruised-purple bone-hook arm; the source's is a twisting double strand with a claw [F] (owner,
  Nov 7).
- Anchor Drop: our brass fist and a teal cone shown to everyone while it fills; the source shows a giant translucent
  fist and only a hit-box outline [F]. Stun 1.1 s vs 1.2 to 1.4 s [F]. The foe is Grounded 1 s after the stun (ours).
- The Barge has no red burst at its start point [F]; the owner forbids bursts on dashes.
- Brass Broadside turns with his aim through the charge and the waves (owner item 36); the source locks the fan at
  the press [F]. He walks at 30% then 20% through it (owner).
- Backstab +50% and a 16% heal on a knock are ours (wiki), not in [D].

Seen in the reel: the slugs hang as violet dots at the stop line like the footage; the arm reaches out, grabs and
drags (HOOKED); the cone telegraph and slam read; the Broadside's fan is a flat-edged amber wedge where the
footage's is a pale rounded fan [F]; the hero is smaller in frame than the source's view.

## Neve the Snowglide (`rimewright`, source Celeste)
[rimewright.mp4](rimewright.mp4)

Still differs:
- Ice Spear is pushed out of her palms and travels to the cursor, with a 2.2 m 35% slow zone and a burst at 1.8 s;
  the source throws a spear with a slow cone and a delayed blast (owner, Nov 5). Cooldown 10.2 s vs 12.
- Rink Wall: slides up to 50% further than the footage (owner item 13); cooldown 17 s vs 20.
- Skate: 11.5 m/s vs the footage's 10 to 11; an early release refunds up to 60% of the cooldown (owner); ice over the
  abyss only at rank 3.
- Rimelock: skating into it carries her 0.8 s and she is a frozen statue (owner items 62 to 65); the crash is
  40 damage and a 0.75 s stun, scaled down from the source's 155 and a stun by the owner's burst rule. The zone's
  stacking slow ramp is ours.
- Darts: four plain then three large, repeating; the footage shows a near-uniform stream and [D] puts the large
  three at the end of the burst only. The skating beams home late like the darts; the bend assert is pending on
  `ext/parity-neve-skate-home`.
- Body 1.014 vs the footage's 1.1 to 1.15 (owner height chart).

Seen in the reel: the spear's burst ring and the wall's tall pale-blue slab match the footage in shape; the ground
dash leaves an ice slab behind instead of the footage's streaking crystal ribbon; Rimelock is one big cyan disc
with a swirl, the footage's a smaller frost bud with the zone ring [F].

## Sparkle the Storm Chaser (`mage`, source Joule)
[mage.mp4](mage.mp4)

Still differs:
- LMB: 12 damage every 0.648 s, 13 m, stops on the first foe; the source's bolt is one every 0.8 s with its aim line
  running to maximum range [F] (owner items 70 and 116).
- Wirerun (Shift) at 40 m/s vs about 32 (owner), a 7.5 to 13 m lane, a 20 damage pass hit, Blowout reset; cooldown 8
  vs 9.
- Cooldowns: Storm Rod 8 vs 10, Skycall 10.5 vs 12, Kitefall 42 vs 60.
- The dash flow row into R is unsourced `[?]`.
- Skycall's cast is a small ring in our reel; the footage's is a dark disc with a gold pillar and a direction
  chevron [F]; the drag-aim for it exists but is not shown here.

Seen in the reel: the Storm Rod's pink burst reads like the footage's spear impact; Kitefall is a wide pink
storm field over the arena, where the footage zooms out to a dark ring with a gold marker at the cursor [F].

## Mossy the Barnacle Knight (`bulwark`, source Oath)
[bulwark.mp4](bulwark.mp4)

Still differs:
- The Guard meter and Shield Slam are ours and still on main (KIT_PARITY gap 15); `ext/parity-bulwark-guardcut`
  b2e942eb4 removes them and is not merged.
- LMB hold walks at 55% while charging, with a 1.5 to 1.8 m step and a 4 m perfect-release launch (owner items 30,
  49, 59); the source stands still [F].
- Aegis: a 160 HP shield with Shield Charge on Shift; the source's is regenerating shield energy and the routing is
  `[?]`.
- Faultline: four cells, 0.5 s stun, cooldown 40 vs 50; Mending Ground 12 s vs 8 at the top rank.
- The hammer has no auto-return (matches); the recall is a second press.

Seen in the reel: the throw's dotted line, the flame-arc swing and the green zone match the footage's beats; the
Faultline telegraph is an amber rectangle with rubble where the footage's is a cyan one with a gold eruption
[F]; the 360 Smash leaves an orange ring, the footage a red spin ring with a damage number.

## Sable the Silver Thief (`thief`, source Shiv)
[thief.mp4](thief.mp4)

Still differs:
- Cooldowns: Bola 7 s vs 13, Encore 24 vs 50, Shadow Knife 15 vs 20 at the top rank, Vault 4.5 vs 5.
- Bola slows 30% (owner item 53), Grounds for 1.5 s, range 7 m; the stun on two foes is 0.9 s.
- Marks add +10% each (16 of the 160 shot) with no cap; a knock heals 15% extra; the source stacks a flat +16.
- LMB: 12 m to the cursor (the footage's bolt also stops at the cursor); damage is the scaled 13.
- Encore's look (violet ring, gold outer band) is ours; the source's is a cyan ring about 3.5 body heights wide.

Seen in the reel: the Vault flip reads like the footage; the Encore is a wide pale-violet disc where the footage's
is a thin cyan ring [F].

## Motley the Void Jester (`ostra`, source Void)
[ostra.mp4](ostra.mp4)

Still differs:
- LMB: Tether Lantern, 9 damage every 0.6 s up to 14 m, with a waiting charge that adds 34% and a Slow; every orb
  pierces terrain (owner items 60 and 117). The source fires one orb, stronger after idling, through terrain only
  when empowered.
- Shard Snap: 0.32 s wind-up vs 0.2 (owner item 40); stun 0.8 to 1.8 s by flight distance.
- Brimseed: peaks at 3.5x like the source, but fizzles after 10 s unpopped (ours); cooldown 10 vs 8 at the top rank.
- Nightwell: about a 1 s cast lock (owner); the radius 3.6 m and a 12 m pull.
- Lantern Trade: 12 m lob; faster (1.25 s) only while Swollen.
- Footstep silence while floating is `[?]`.

Seen in the reel: the Brimseed is popped at 1.8 s by the reel's recast, so its full growth (the footage's
room-sized violet globe) is not shown; the Nightwell tell is a pale-cyan disc where the footage's vortex is a
violet swirl [F].
# Parity reels: "done means played"

One short reel per Hunter (about 40 s), played by `--hero-vfx-reel --reel-parity` (tools/vfx_reel/parity.gd) in the
Training Area against a dummy at the match camera, with the key on screen in the top left. Order: LMB tap, LMB hold,
RMB, E, R, ground dash, air dash (Space, then Shift), glide (Space, then hold), mantle (a running jump late into the
Arena's dais face, the ledge caught on the way up). Played through the real input paths (`inp` fire / sec / sig,
`HunterKeys.ult_pressed`, `do_dash`, jump and glide), not scripted effects. Rendered on the GPU workers
(`jobq submit --needs gpu`), 30 fps, 800 px wide, no sound.

Re-render one: `jobq submit --needs gpu --tree <tree> --out reel -- --hero-vfx-reel --reel-parity --reel-hero=<id> --reel-frames --shots-dir=reel`, then
`ffmpeg -framerate 30 -i <out>/frames/%05d.jpg -c:v libx264 -crf 30 -maxrate 700k -bufsize 1400k -pix_fmt yuv420p <id>.mp4`.

**Checked and not checked.** All 12 reels ran to the end on the GPU workers (rc 0, 9 parts each). A headless run of the same input script showed every Hunter's mantle catching the dais lip and climbing it, and every dash, air dash and glide staying on the island. No sound is in the clips. The lists are from the docs plus a sample of footage frames per Hunter (6 source frames against 12 reel frames), so a look that is not named may still differ: the final word is watching the clips.

**Reading the lists.** Sources: docs/KIT_PARITY.md (main 7907d9afe audit), docs/heroes/<id>.md, the source data
(briefs/supervive-data) and the source footage frames (briefs/hero-ref, ext/hero-ref-footage). "By eye" means a
frame set of the footage next to frames of the reel; it is a sample, not a frame-by-frame measurement. Owner notes
(briefs/DECISIONS.md) win over the source, so "owner" items are decisions, not gaps. Our palettes and art are our own
on purpose; only motion, timing and mechanics are compared.

**Shared by all 12 (KIT_PARITY gaps 2 to 4, 18):** stopping is near-instant (brake 110 vs about 22 m/s² in the source);
air control is about 20x the source's; dashes carry little speed out (15% / 30%); the glide has steered acceleration and
no dive (-32.5 m/s); jump is 6.8 vs 7.5 m/s (kept on purpose, terraces). Mantle: ours is a ledge float over a terrace
lip; the Arena has only a one-terrace dais, so the reel shows the catch, not the double-wall cases. Q (glove) and X
(Fuse) are ours and not shown.

## Vex the Hired Gun (`gunslinger`, source Ghost): [gunslinger.mp4](gunslinger.mp4)
Still differs (KIT_PARITY, docs/heroes/gunslinger.md):
- RMB: ours is a launcher shot (cd 6.5 / 9); the source throws a sticky Spike Grenade with a wall cone knock and Daze (owner item 112 keeps the side toss: not a gap).
- R: matches the shape (1.6 s delay, 3 s fire patch, 30% slow); cooldown 42 vs 55 s (0.76x, pacing).
- E and dash: match; dash cd 8.5 s sits between the data (11.5) and footage (7.5).
- Gaps shared with all (above); dash to LMB buffers (`fire`, sourced).
By eye (footage frames 12 to 235 next to the reel): the source's light is neon green and cyan with a purple dash trail, ours is ember orange (our palette, on purpose). The ult reads the same in both: a tall light column, a telegraph disc everyone sees, then a burning patch. The source's Ion Cannon is a long beam with a puff at the muzzle; I did not catch the beam in my sampled reel frames, so watch the E part for it. Source Ghost stands about 5% of the frame high; ours about 4% at the match camera.

## Cinder the Flame Queen (`ashwick`, source Felix): [ashwick.mp4](ashwick.mp4)
Still differs (KIT_PARITY, docs/heroes/ashwick.md):
- E: instant pull (r 4.5, 14 m/s); the source spins with a short (~0.2 s) arm fling and a shield per foe pulled (owner item 11 keeps ours).
- Dash: ground felt 2.9 m / .32 s vs about 3.4 m / .33 s (gap 11); the air dash applies the dash feel twice, 5.8 m / .32 s vs 6.8 m / .28 s (likely bug, small fix).
- Cooldowns at 0.78 to 0.8x of the data (RMB 7, R 36).
- During R only E works (owner, Nov 5): intended, the source allows more.
- LMB hose, RMB bolt and the Ignite passive match.
By eye (footage 25 to 285 next to the reel): the source's Jetpack leaves a wide, thick red-orange magma band behind her (about a body wide); ours is a thin orange lane, so the ult reads lighter. The source hose is a bright yellow-orange cone with a burning foe marker; ours reads the same shape. Flame Shield (E) in the source is a bubble on her with the pulled foes; check ours in the E part.

## Mossy the Barnacle Knight (`bulwark`, source Bjorn / Oath): [bulwark.mp4](bulwark.mp4)
Still differs (KIT_PARITY, docs/heroes/bulwark.md):
- LMB: tap is a whirl, hold is a charged swing with carry 1.5 to 1.8 m and a perfect launch of 4 m (owner #30, #49); the source throws the hammer and recalls it. Cadence .48 vs .45 (gap 12); he walks at 55% while holding where the source stands.
- Passive: the Guard meter and Shield Slam are ours, not in the source (gap 15, owner question open). Wall-knock Stun is built.
- E: matches (zone round the hammer, burst); cd 12 / 8. R: stun .5 s, cd 40 vs 50 (0.8x). Dash (Whirl 3.5 m, cd 8) matches.
- RMB shield routing (Shift = bash) not settled `[?]`. Dash to LMB buffers (gap 9).
By eye (footage 45 to 560 next to the reel): the source's Earthshatter is a tall cyan-outlined rectangle with a lightning crack and a stun marker; ours lays a lane of dark rocks inside an orange box, so the fissure reads as boulders, not a glowing crack. The source's Barrier Shield is a flat gold plate held in front of him; my sampled frames did not catch ours, so watch the RMB part. Our E is a pale green zone round the hammer. Our Mossy is 1.5x a medium Hunter (owner) so he is larger than the source's Oath on screen.

## Lace the Red Stitch (`archer`, source Myth / Pin): [archer.mp4](archer.mp4)
Still differs (KIT_PARITY gaps 5 to 8, docs/heroes/archer.md):
- RMB Heavy Shot: wall payoff about 0.4x vs about 5x in the source (wall_dmg 12, floor .4, stun 1.2); a .5 s dead zone before the draw reads (ours); cd 16.
- Dash: roll of about 3 m / .28 s; the source's Spirit Walk rolls to the cursor, then walks through terrain including raised walls. Ours walks rocks and barriers, not ledges (gap 8). Whether she can shoot in it is not in the footage.
- Passive: the source is fog vision of injured foes plus a tall-ledge climb; ours is Hawk Sense 22 m and an invented Focus / Deadeye over the draw (gap 5, owner question). The double-wall climb is not built.
- LMB (two-stage draw, perfect quick draw), E (cone, slow 35%, anti-heal), R (3 shots, cd 60): match. Dash to LMB buffers, 8 of 17 flow rows unsourced.
By eye (footage 110 to 604 next to the reel): the source shows a big white burst at the impact of Impaling Shot, a dark blue ghost-world look with the glowing portal during Spirit Walk, and a wide green arc of arrows for Rain of Arrows. Ours reads as thin red thread lines and small needle hits at the match camera; the impact has far less weight than the source's burst and my sampled dash frames show no phase look for the walk (watch the dash parts).

## Grimble the Scrap King (`dredge`, source Kingpin): [dredge.mp4](dredge.mp4)
Still differs (KIT_PARITY gaps 11, 13, docs/heroes/dredge.md):
- Dash: three chained dashes, cd 10 (owner); the source has one dash every 7 s with its own air dash slot at 12.5 s. Ours shares the slot and the air dash is scaled twice (3.1 m, single 3.7 m) (gaps 11, 13).
- E (Slam) and R (Kaiju Blast): mechanics match, cooldowns are 0.58x (7 vs 12 s, 21 vs 36 s). RMB: 0.67x (12 vs 18 s); reaches 11.5 m through terrain, reel, braced shuffle: match. LMB seven-slug blast with bloom, passive Salvage stacks: match.
- Not built: enemies Grounded on arrival is ours-only (Grounded on E), no bonus armour damage without spread, no destructible bonus (docs/heroes/dredge.md).
By eye (footage 46 to 302 next to the reel): the source's Buckshot is a wide fan of small blue pellets and its Kaiju Grasp a thick magenta arm with a diamond marker on the hooked foe; Kaiju Blast is a green beam with a wide ground telegraph. Ours at the match camera shows the slugs as a thin pink dotted line, and the blast reads smaller; the spread of seven slugs is hard to see in the reel.

## Kael the Unbroken (`juggernaut`, source Brall): [juggernaut.mp4](juggernaut.mp4)
Plays the generic parity set; his own detailed reel (slam, lunge, drop, chain spin) is the old `--hero-vfx-reel --reel-hero=juggernaut`.
Still differs (KIT_PARITY gap 1, docs/heroes/juggernaut.md):
- **Animation: missing.** `kael.glb` has 0 clips and no `warden_anim/kael.json`: all 20 moves run on the procedural HunterAnim, the biggest visible gap of any Hunter (gap 1, size L).
- RMB: context moves (Slam, Lunge, air Slam, chain Spin) match in shape; the over-head pose and perfect release differ by owner decision; cd 2.0 vs 2.5 (air drop 0.8x).
- E: tether 24 m (ours), cd 12.8 vs 16, source length unknown. R: Riposte shape matches (guard .65, strike .1, recover .35), the kill reset is `[?]`, cd 36 vs 45.
- Dash: 4.5 m / .3 s raw with the feel scale, 2 charges, cd 10.4 vs 13: distance scaled. Dash to LMB buffers, plus `cancel` rows on three kits (gap 9). Turning is not locked after an RMB dash (not built, would read as lag).
- LMB combo and hold fireblast, the passive (Rage, heal on knock): match.
By eye (footage 60 to 455 next to the reel): the source's chain is a thick yellow-and-black striped rope with a marker ring on the target; ours is a thin dotted line in the sampled frames. Retaliation in the source ends in a large green burst with a red slash flare; at the sampled reel frames I caught only the guard, so check the R part for the cleave. His glow is white-hot by owner note (not orange as in the source's hot red).

## Sparkle the Storm Chaser (`mage`, source Ryzz / Joule): [mage.mp4](mage.mp4)
Still differs (KIT_PARITY, docs/heroes/mage.md):
- LMB: bolt .648 s, range 13, no pierce; the source is .8 s with Static on hit (owner items 70, 116 keep ours).
- Dash: 40 m/s vs about 32 (owner), pass damage 20, reset on Blowout, cd 8 vs 9. Dash to LMB and X buffer rows (gap 9); 5 flow rows unsourced `[?]`.
- RMB cd 8 vs 10 (0.8x); R hover 1.7 s, cd 42 vs 60 (0.7x); E drag aim built, cd 10.5 vs 12. Mechanics match.
- Not built: Lightning Strike launching Wisps (no wisps), Static detonation restoring mana (no mana).
By eye (footage 20 to 380 next to the reel): the source's Eye of the Storm is a large amber ring with a glowing centre and the hunter in the sky; ours is a pink dome that fills about the whole arena at the match camera, so the size is similar but the look is a filled dome, not a ring. The source's Javelin is a thin yellow lance and Spear a white-yellow bolt with a spark; ours is hot pink on a thin line (our palette, on purpose). In the sampled frames the dash shows only a faint streak.

## Tenzo the Stone Seer (`dolm`, source Breah / Tetra): [dolm.mp4](dolm.mp4)
Still differs (KIT_PARITY gap 14, docs/heroes/dolm.md):
- E: Rock wall, cd 12.5, but allies cannot hop it by jumping (the source's allies can; owner item 25 keeps only the caster climbing). Source hop and the Landslide dash are not copied.
- Dash: Rock Hop, three hops, cd 12 (owner item 111) in place of Landslide (a dash that launches a rock); the air dash has no source.
- R: 9 rocks with drag, cd 45, Slow data present; the source's Tetraform is a tap wall or a held drag of one wall with a Slow (owner item 15 says rocks only). Terrain does not last longer per rank (our R has no ranks).
- LMB (boulder tap, punch hold), RMB (hold slam, glide slam), passive Shield: match. A flick-tech arc hit was removed in the source (not built).
By eye (footage 110 to 660 next to the reel): the source's Tetraform raises one long orange spiked ridge in a line and its rocks burst in orange fire; in the reel the R part scatters about nine separate red-brown rocks over a wide area instead of one lane, and the punch shows a pale box with little impact. Boulder and slam impacts have far less fire and flash than the source's.

## Motley the Void Jester (`ostra`, source Ostra / Void): [ostra.mp4](ostra.mp4)
Still differs (KIT_PARITY, docs/heroes/ostra.md):
- LMB: .6 s with a continuous charge to 1.4 s and every orb piercing (owner items 60); the source's idle next orb is stronger, terrain-stopped, with a Slow, and a firing-rate penalty card (not built, nothing to penalise at a fixed cadence).
- RMB: wind-up .32 vs .2, cd 10 (owner item 40). E: bomb grows 6.5 s, peaks 3x vs 3.5x, fizzles at 10 s (ours); the source reactivates.
- R: tell 1.0, 3.5 s, pull 12, cd 70 match; about a 1 s cast lock (owner). Dash: 1.8 s lob, drift 30%, swaps foes and allies: match. Floating passive `[?]`. The 40% slow on swapped foes is not built (no data).
By eye (footage 50 to 480 next to the reel): the source's Black Hole is a deep violet whirlpool with a dark core and bright violet rim that grows when empowered; ours is a flat teal disc with a dark blue rim that lingers through the dash and glide parts, so it reads as a puddle rather than a vortex pulling in. The Unstable Anomaly bomb is a dark blue sphere in the source; the Swap lob is a small projectile with a purple trail. Our orbs are small purple dots with little trail.

## Neve the Snowglider (`rimewright`, source Claire / Celeste): [rimewright.mp4](rimewright.mp4)
Still differs (KIT_PARITY gap 16, docs/heroes/rimewright.md):
- LMB: darts fly straight while skating (the source's are semi-homing; owner said homing, still an open fix, gap 16). Four plain plus three large darts.
- RMB: push-like emerge of the spear (owner); the source spear and delayed blast; 2 charges, cd 10.2 vs 12.
- Passive: the Chill 15% slow is ours (gap 19). E: slide and grow, cd 17 vs 20. Dash: 11.5 m/s for 1.6 s (source 10 to 11), early-release refund .6 (owner), cd 13 in the data. R: hold 3.5, carry .8 (owner), cd 80: match.
- Body 1.15 matches (1.1 to 1.15).
By eye (footage 50 to 392 next to the reel): the source's Ice Crash is a violent burst of long blue shards with a bright light column and a wide ring; in the reel it is a large flat pale-blue disc with a swirl, so it has the size but not the shard burst or column. The source's Ice Wall is a bright crystal cluster with a red aim line; ours is a thin pale strip. The dart is a long blue bolt in the source and a short pale bolt here.

## Meeko the Dawnfox (`tender`, source Pip / Elluna): [tender.mp4](tender.mp4)
Still differs (KIT_PARITY, docs/heroes/tender.md):
- RMB: a hop form with a 1.0 s wind-up, cd 10.5; the source fires a shot with a delayed Root, 11.5 s. The motion is `[?]` (not settled from code).
- Passive: carries up to 2 Wisps plus a Carrier shield (ours); the drop lockout (4 s) is built but which hits drop a Wisp was not traced.
- LMB: Empowered +40% range is ours (ramp per hit matches). E: 2.5 s zone, throw, cd 11 vs 12, self heal .33 (ours). R: tether 5 s, range 12.6, cd 46 vs 60 (0.77x), match in shape.
- Dash: ground 7 s and air 14 s match; the owner's air steer stays.
By eye (footage 74 to 279 next to the reel): the source's Moon Shot is a blue comet with a trail, Bound by Fate a white bolt with a rune ring, Rejuvenating Aura a big green-white disc, and Divine Intervention a long white arc to the ally. In the reel the shots are small gold sparks, the aura a thin gold ring, and the R tether read faintly; they have much less weight on screen than the source's.

## Sable the Silver Thief (`thief`, source Sable / Shiv / Dancer): [thief.mp4](thief.mp4)
Still differs (KIT_PARITY, docs/heroes/thief.md):
- RMB: Bola with a 30% slow (owner item 53); the source's bolas Ground and stun two targets. Cd 7 vs 13 (0.54x).
- R: Encore, 10 shots with a rim band, cd 24 vs 50 (0.48x, the lowest pace of any kit); E: dagger 14 m, 6 s, cd 15 (0.75x of the data at rank IV). The ult has no ranks (not built).
- Passive: Marks plus an empowered Shred that is ours (`[?]`). LMB range 12 m is unconfirmed. Dash: 4.5 m / .48 s, 2.34x prime, cd 4.5 (excluded from the dash feel scale): match.
By eye (footage 25 to 350 next to the reel): the source's Arcslinger shots and Death Blossom are bright red-white streaks with a pink knife flurry, Cartwheel a spinning flip with a purple trail, and Trickshot a wide pale cone lane. The reel shows a violet figure with thin small shots and a pale translucent disc for R; the sampled dash frames show little of the cartwheel flip, so check the dash parts. Her speed lines and the Death Blossom flurry are much lighter than the source's.

