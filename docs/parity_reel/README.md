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

