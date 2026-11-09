# Parity reels: "done means played"

One short reel per Hunter (about 40 s), played by `--hero-vfx-reel --reel-parity` (tools/vfx_reel/parity.gd) in the
Training Area against a dummy at the match camera, with the key on screen in the top left. Order: LMB tap, LMB hold,
RMB, E, R, ground dash, air dash (Space, then Shift), glide (Space, then hold), mantle (a running jump late into the
Arena's dais face, the ledge caught on the way up). Played through the real input paths (`inp` fire / sec / sig,
`HunterKeys.ult_pressed`, `do_dash`, jump and glide), not scripted effects. Rendered on the GPU workers
(`jobq submit --needs gpu`), 30 fps, 800 px wide, no sound.

Re-render one: `jobq submit --needs gpu --tree <tree> --out reel -- --hero-vfx-reel --reel-parity --reel-hero=<id> --reel-frames --shots-dir=reel`, then
`ffmpeg -framerate 30 -i <out>/frames/%05d.jpg -c:v libx264 -crf 30 -maxrate 700k -bufsize 1400k -pix_fmt yuv420p <id>.mp4`.

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

