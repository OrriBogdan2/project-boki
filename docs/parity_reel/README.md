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
| 0:24.4 | dash on the ground, there and back | Shift, D, A |
| 0:28.2 | jump, then dash in the air | Space, Shift |
| 0:32.0 | jump and hold Space: the glide, steering round | Space, WASD |
| 0:37.1 | mantle | none (the catch is automatic) |

- Kael's and Meeko's R parts set up their ultimate (`ext/parity-reel-dummies`): Kael starts at 60% hp and the dummy
  stands 3 m off, inside the cleave's strip, and fires its own rifle at him once 0.4 s in (in the guard); Meeko's
  part puts a downed ally dummy (a Training Grounds dummy on her team) 5 m off and aims R at it.
  `juggernaut.mp4` and `tender.mp4` are re-rendered with it (xvfb opengl3 on rpc3, same tool and timeline: R still
  at 0:17.5; GPU jobs 20261112-014915-17204 / -014932-30197 queued at the time).
- The second press is the same for every Hunter. It does something only where the kit has a recast (Neve E and R,
  Motley E, Sable E, Sparkle R); elsewhere it just shows the next cast or nothing.
- The Training Grounds has no terrace to run into, so the mantle part drops the Hunter just under an island rim,
  moving in, and the lip catch carries them over (the `--cliff-mantle-check` "abyss" case). A terrace mantle is
  covered by that check, not by a reel.
- The dummy stands 7 m away (12 m for the three travel parts). The Training Grounds spot sits 11 m from the
  island's east rim, so the travel parts start 5 m west of it, keeping 4 m of island past the far dummy; the
  Hunter walks only to 2 m short of the dummy, and the second ground dash comes back west (two long dashes east,
  like Kael's ~14 m one, are longer than the 24 m island). `REEL_TRAVEL` lines say where each part ends.
- The first-time kit drill is marked done for the reel (in memory, the save is never written), so its card does
  not sit under the title.
- Motley's E part waits for the Brimseed to grow full (6.5 s, her `e.grow`) before the recast, so it runs
  about 5 s longer than the other Hunters' E parts and her later parts start that much later.
- Re-render one: `jobq submit --needs gpu --tree <tree> --out shots -- --parity-reel --shots-dir=shots
  --reel-hero=<id>`, then `ffmpeg -framerate 30 -i shots/frames/%05d.jpg -c:v libx264 -crf 30 -pix_fmt yuv420p
  <id>.mp4` (`tools/parity_reel.gd`, built on `tools/hero_vfx_reel.gd`; `--reel-only=<part>` plays one part).
- The R segment of the first six MP4s is spliced from a second render of just that part (the first render pressed R
  through the wrong key path); the timeline above is unchanged. The four slice Wardens' reels and Meeko's and
  Tenzo's are one render each.
- R stands for the ultimate in every reel; in the game it is on X (Hearth Call, Basalt Spine and the rest).

## Shared by all twelve

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

Seen in the reel: the reel predates `ext/parity-reel-tool`, so the Brimseed is popped at 1.8 s and its full growth
(the footage's room-sized violet globe) is not shown; the tool now holds it to full size (not re-rendered); the Nightwell tell is a pale-cyan disc where the footage's vortex is a
violet swirl [F].

# The four slice Wardens (main 88b06b9e7, 2026-11-11)

Rendered from `ext/parity-reel-slice4` (main 88b06b9e7, docs only) with the command above. The MP4s here are the
xvfb opengl3 render on rpc5 (same tool, camera and timeline); the GPU jobs 20261111-191900-30189 (Vex),
-191911-32717 (Kael), -191919-05384 (Lace) and -191933-26636 (Cinder) were still queued (59 deep) when this was
written. The lists start from `docs/KIT_PARITY.md` and `docs/heroes/<id>.md`, re-read against main's data; the
footage was checked through the key-frame captions in `briefs/hero-ref/{venator,juggernaut,pin,linwick}.md`, since
the frames themselves (`/home/claude/svvid`, `/home/claude/hero-ref`) are not on rpc5.

**Owner-direct 11-11 branches not in main** (none of the four is merged, so these reels show the kits before them):
- `ext/vex-rmb-1111` a796f3a38: the Burr Charge lane's end is a dud on the ground or in the air; only a wall cone.
- `ext/kael-owner-1111` 4cb48148d: tap RMB is a locked 4.3 x 0.72 lane, no Chain Lunge, hold has no lane or ring,
  Meteor Drop centred under him. Based on ext/release-integ-0245, not main.
- `ext/lace-1111` cf1adae16: Heavy Shot from the bow mouth, no feet crescent, roll 3.375 m, crimson kit colours,
  red laces for Hail Wall. Based on ext/release-integ-0245, not main.
- `ext/albert-hold-cinder-orb` 4cf2f22b4: Cinder's cyan palm orb becomes a gold/white tell in the 0.2 s spool only.

**Reel-tool fixes** (`ext/parity-reel-tool`): these four reels show the kit drill card ("1/5, Skip drill") under
the title and both dash parts ending in the void, because the 12 m dummy stood past the island rim. The tool now
skips the drill and keeps the travel parts on the island (see the notes at the top); only `juggernaut.mp4` is
re-rendered with it so far (xvfb opengl3 on rpc3; GPU job 20261112-030437-07461 queued ~146 deep at the time).

**KIT_PARITY rows now stale on main:** Kael's animation (gap 1) is closed: `kael.glb` has 49 clips and
  `warden_anim/kael.json` exists. Lace's Focus/Deadeye (gap 5) is gone (Hawk Sense only), and her Heavy Shot wall
  payoff (gap 6) is `wall_mult` 4.94. Lace and Cinder's dash to LMB rows are `fire` now; Kael's ground and air rows
  still `buffer`.

## Vex the Hired Gun (`gunslinger`, source Ghost)
[gunslinger.mp4](gunslinger.mp4)

Still differs:
- RMB Burr Charge: a launcher shot on the press along a fixed 10.5 m lane, no hold lane, no throw (owner item
  112); the source throws a sticky grenade along a held lane [F 0039]. On main a lane's end with no foe or wall
  still sticks and blows the cone (the "always procs in the air" bug); `ext/vex-rmb-1111` makes it a dud.
- Cooldowns at rank 1: RMB 6.5 s vs 9 [D] / 5.4 [F], Slipstep 8.5 vs 11.5 / 7.5, Longneedle 11.5 vs 12 / 10,
  Cinderfall 42 vs 55 (gap 10, owner call).
- Cinderfall's burn lasts 3 s; the footage's zone ticks about 4 s [F 0245].
- The Coin Blast rename and coin look (DECISIONS 11-08) are not built.
- Her light is ember orange (our palette); the source's is green and cyan with a purple slide trail [F 0118].

Seen in the reel: the rifle hits the dummy from 7 m; RMB is a red tracer to the dummy, which reads DAZED with a gold
pip; Longneedle is a long orange line through the rock and past the frame, like the footage's beam through terrain
[F 0182] but thin, with none of its green-white thickness or smoke ring [F 0170]; Cinderfall shoots a light column
up, then a ticked orange disc and a burning patch with SLOWED, the footage's beats [F 0197, 0203]; the slide shows
a pale ring at her feet for a few frames at the start, which the owner's "no rings on dashes" rule (gunslinger.md row 10)
says should not be there: worth a look.

## Kael the Unbroken (`juggernaut`, source Brall)
[juggernaut.mp4](juggernaut.mp4)

Still differs:
- RMB on main: the tap slam is a ring round him and the hold is the forward lunge pose with its lane; the
  owner's 11-11 playtest (`ext/kael-owner-1111`) wants a locked lane strike, the hold with no lane or ring (blade
  over the head), no Chain Lunge and the Meteor Drop circle under him.
- Dash: 4.5 m raw, felt 3.8 m / 0.2 s with a 0.07 s dip, 2 charges, cd 10.4 vs 13 (owner 113.8); the source has 3
  Quick Dash charges [F summary_screen].
- Dash to LMB: ground and air rows `buffer` (gap 9, item 51 says combine).
- Warchain: tether 24 m is ours; the source's throw is about 12.6 m and the leash is unknown `[?]`. Cd 12.8 vs 16.
- Riposte: the kill reset is `[?]`; cd 36 vs 45. RMB cd 2.0 vs 2.5, air drop 7.2 vs 9.
- His glow is white-hot (owner); the source's is hot red.

Seen in the reel: the LMB hold lays a long gold lane to the dummy (the source shows a white arc round him [F
0087]); the tap slam is an orange ring; the chain is a thin dotted line and the dummy reads CHAINED, where the
footage's is a thick wavy orange chain [F 0304]; Riposte's guard shows a gold strike rectangle like the footage's
[F 0435]; the dummy's rifle shot lands in the guard and reads BLOCKED in gold (0:18.7, no damage); the cleave is an
orange-gold arc up the strip into a gold impact cloud (0:19.1), where the footage's is a huge red vertical crescent
and a white cloud [F 0430-0431, 0438-0439]; it hits the dummy for 52 and SLOWS it, and the heal shows as a green
+41 over him (116 to 158 hp, 0:19.2), with no green light-rain column (the footage's heal column is the knock heal
[F 0455-0458], not the Retaliation's); the air dash puts a wide grey disc round him.

## Lace the Red Stitch (`archer`, source Myth)
[archer.mp4](archer.mp4)

Still differs:
- Heavy Shot: on main a magenta ring sits at her feet while she draws; `ext/lace-1111` starts the shot at the bow
  mouth and drops the ring. Wall x4.94, 1.2 s stun. Her card says push 6 to 12 but the data's `push` is 8 to 12
  (card text to fix).
- Shift: a 3.0 m / 0.27 s roll, then Spirit Walk through rocks, trees and barriers; raised walls and ledge faces
  are still on unmerged `ext/lace-phasewalk-verify` (gap 8). `ext/lace-1111` makes the roll 3.375 m.
- Passive: Hawk Sense 22 m only; the source's tall-ledge climb is not built.
- Her kit colours on main are violet/magenta; the owner's 11-11 crimson (d41e2e) is on `ext/lace-1111`.
- 8 of her 17 dash flow rows are unsourced `[?]`.

Seen in the reel: the draw's white line runs to the cursor ring like the footage [F 0102 to 0105]; Heavy Shot
shoves the dummy most of the way to the rim, with no big white impact burst [F 0270, 0273]; Hail Wall is a pale
curved band with violet panels at the cursor distance, the footage's curved arc [F 0457] but where the owner now
wants red laces; R's shots are long violet lines past the dummy, like Supercharged running to max range [F 0168];
the roll shows no dark-blue Spirit Walk tint [F 0360].

## Cinder the Flame Queen (`ashwick`, source Felix)
[ashwick.mp4](ashwick.mp4)

Still differs:
- The cyan pilot (#6fe8ff) burns in her palm all the time, idle too: a footage carry-over [F 0021, one frame
  before the fire]; `ext/albert-hold-cinder-orb` shows it gold/white only in the 0.2 s spool-up.
- Furnace Cloak (E): instant pull, r 4.5, 14 m/s, no 0.2 s arm-fling ring (owner item 11); cd 10.5 vs 13.
- Cooldowns: Cinder Shot 7 vs 9, Flue Flight 36 vs 45 (0.78x to 0.8x).
- During Flue Flight only E works (owner, Nov 5); the source allows more.

Seen in the reel: the cyan orb is in her palm from the first frame; the hose is a narrow-then-billowing orange stream
like the footage [F 0024]; the RMB aim is a white lane with an arrow tip and the bolt hits with FLASHOVER and an
orange sunburst [F 0077]; the Cloak is a crackle of yellow sparks round her and the dummy, not the footage's
swirling shield ring [F 0186]; Flue Flight lays a thick orange fire carpet and carries the dummy with her to the
island rim, close to the footage's wide magma band [F 0226].

## Meeko the Dawnfox (`tender`, source Elluna)
[tender.mp4](tender.mp4)

Still differs:
- Burrseed: a fixed 1 s wind-up with a 6 m dotted lane (owner item 118), then a seed that sticks to the first foe
  and roots after 2 s of them staying within 15 m of her, unwinding twice as fast outside it (owner 11-10). The
  source's is a tap shot down a lane to maximum range that roots about 0.6 s after the hit [F] (2 s on the wiki).
  Cooldown 10.5 s vs 11.5 [D] (the footage card reads about 7.2 s).
- Hearthlight: cooldown 11 s vs 12 [D]; heals her at a third (ours); the throw latches onto the first teammate it
  passes (owner call), where the source's lands on the cursor and no latch was seen [F].
- Hearth Call: cooldown 46 s vs 60 [D] (0.77x; the card reads 41.6); with no teammate in the match it lights on her
  (ours). The channel is 5 s where the footage's tether runs about 2.4 s [F 0249-0271].
- Lantern Crook: Empowered shots reach 40% further (ours); the ramp per hit matches.
- Relay Step: Elluna's numbers (3.6 m in 0.2 s, the air glide 13.3 m in 0.95 s, 7 s and 14 s): match; the glide's
  steering is the owner's. No refund for passing through a teammate (the footage card's Super dash has one).
- Bearer: the Carrier shield is cut (tender.md, owner 11-07); the KIT_PARITY row still lists it and should be
  updated. Which hits drop a carried teammate was not traced.
- Body 0.66 of a medium (owner item 108).

Seen in the reel: the Crook's shots are small gold sparks with a Kindle glow, where the footage's are a blue comet
flying on past the cursor [F]; the Burrseed disc is violet like the footage's but wider for her size and ringed
with thorns, and the root shows as a white swirl where the footage has a smaller disc and a purple beam [F]; the
thrown Hearthlight is a pale disc with a teal rim, close to the footage's cyan disc, but the ring on her before the
throw barely shows and there is no green plus on the summon [F]; Hearth Call on the downed ally: HEARTH CALL in
green over her and a pale gold-white beam from her hand to the ally (0:18.3), which lies as a pale orb inside its
cyan "Revive" ring, held for 5 s; the footage's beam is pink-gold with green plus sparkles on the ally [F 0249-0271],
ours shows no plus sparkles there; at the end (0:23.3) a white burst plays where the ally lay and it stands up at her
side in a gold ring, like the footage's ally appearing next to the hunter [F 0279].

## Tenzo the Stone Seer (`dolm`, source Tetra)
[dolm.mp4](dolm.mp4)

Still differs:
- Stone Row (E): three rocks 3.4 m ahead, cooldown 12.5 s [D]; he climbs them by walking (owner item 25), allies hop
  them by jumping as in the source (owner 23:55, `StoneStand`). KIT_PARITY gap 14 and dolm.md's "not built" rows
  still say allies cannot, and should be updated.
- Rock Hop (Shift): up to three steerable hops off rocks he raises, cooldown 12 s (owner item 111), in place of
  Landslide's short dash with a rock riding ahead [F]; the rolling rock at the end keeps the source's slow and knock.
- Basalt Spine (X): nine rocks erupting centre-out along a 12 m arc, a 35% slow for 1 s, a drag sets the angle,
  cooldown 45 s [D]. The source's Tetraform is one spiked ridge about 18 to 22 m long [F]; ours was shortened from
  19.8 m on purpose with no owner line either way (KIT_PARITY ranges, `[?]`).
- Tremor Sense: the cone is a fixed 16 m, widening 25 to 40 degrees over 2 s; the source's also lengthens, to about
  18 to 25 m [F] (dolm.md gap 9). `ext/tenzo-cone-length` c557c270d grows it to 25 m and is not on main. Not in the
  reel (it needs a sneak).
- Quakefall (RMB): the charge is capped at 0.45 s (owner item 61); cooldown 11 s matches [D].
- Punch hold: he walks at 85% while charging and at 55% through the Quakefall hold; `ext/feel-charge-walk` (docs
  only) finds the source standing in every hold seen [F]. An air punch no longer slows him below his flying speed.
- Molten Guard: the shield per punch matches; the charge scaling is ours.

Seen in the reel: the boulder trails an orange dotted line and bursts small, where the footage's bursts in a big
fire flash with the damage number [F]; the punch shows its pale chevron lane but little impact, the footage a
bright streak and rocks bursting in fire; the Quakefall hold circle is pale blue-white where the footage's is red,
while the dark red crater with orange cracks matches; Stone Row's molten basalt columns read like the footage's
spiked rocks; Basalt Spine is a row of separate rocks where the footage's is one continuous orange spiked ridge
with fire [F]; the Rock Hop shows a blue landing circle and a "SHIFT AGAIN" prompt, with no fire burst like the
footage's Landslide.
