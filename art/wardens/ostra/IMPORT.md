# Ostra (Motley, the Void Jester): import note (ART-1, 2026-11-05)

## Owner fix 2026-11-12: cards (`tools/art1/warden_fix_1112.py ostra`, on the 11-11 file)
"He should be having those cards in his hand, and the cards floating around him should be much smaller." The fan of cards
(on `x_fan`, a child of `hand.L`) floated about 10 cm off the appeal glove: it is turned over and its foot set in the
glove's palm, so it fans out past the fingertips between thumb and fingers. The eight orbiting cards are 0.42 of their
size (about one fan card); their orbits, the sway and the clips are unchanged.

`ostra.glb` is the owner's final design, a cursed jack-in-the-box, built by script in Blender on the shared armature; id and files stay `ostra`.
v2 (2026-11-07) follows briefs/art-refs/motley_v2 (motley_v2_turnaround, motley_v2_master_sheet; the older motley_turnaround is retired): the
sheet's painted palette (magenta-violet and plum doublet, lilac ruff and gloves, muted bronze spring, mauve box with spades front and back and
diamonds on the sides), a near-cube box, no crank mesh, the head and hat at 0.82 of v1 (`HEAD_K`; the sheet's is smaller, kept larger so the grin
reads at the match camera and he keeps the line-up height), the ruff at 0.80, six broad coat tails flung out (reach 0.46-0.56) with the bells hanging clear above the box at z 0.62-0.66 so the spring shows (the sheet's float), arms spread wide in the base pose (`STILL`), one column of buttons, a broader flat void ribbon. He has no legs and hovers (the clips). Under the 15k budget, 6 materials, 36 hand-keyed clips at 30 fps.

    blender -b --factory-startup --python tools/art1/ostra_build.py            # ~/art1/motley/ostra.blend (OSTRA_WORK moves it)
    blender -b ~/art1/motley/ostra.blend --python tools/art1/ostra_anim.py -- all --export art/wardens/ostra/ostra.glb
    godot --headless --path . --import

Re-keying clips on the swapped model (there is no ostra.blend with its mesh): key on the game .glb's own rig, then copy the clips in
(every other clip stays byte for byte the same):

    blender -b --factory-startup --python tools/art1/ostra_anim.py -- walk_f,orb --from art/wardens/ostra/ostra.glb --export /tmp/keyed.glb
    python3 tools/art1/glb_add_clips.py art/wardens/ostra/ostra.glb /tmp/keyed.glb walk_f,orb

`x_breath` (the idle's rib cage, 11-18) went on the v95 glb the same way, with no re-export (once; a later glb swap needs it again):

    blender -b --factory-startup --python tools/art1/ostra_anim.py -- idle,stance --from art/wardens/ostra/ostra.glb --export /tmp/keyed.glb
    python3 tools/art1/glb_add_bone.py art/wardens/ostra/ostra.glb /tmp/keyed.glb x_breath --zone 1.06,1.40,0.21 --clips idle,stance

**Appeal swap (2026-11-11, owner-approved):** the mesh is now the appeal3 master, body b with the new starry face (`~/meshy/v95/Motley/r2/appeal3/cand_b.glb`),
put on this rig, its clips and anchors by the v95 swap (`art/wardens/src/ostra_v95.json`, docs/art/wardens/V95_SWAP.md). It replaces the
build above's mesh (the build scripts still make the rig and clips): one 2048 atlas (`ostra_atlas.jpg`) and a baked `ostra_normal.jpg`, slots
glow-face (the face window), cloth-ruff, leather (the box and lid), metal (bells, buttons, spring) and cloth. `ostra_face*.jpg`, `ostra_void.jpg`
and `ostra_wisp.jpg` are gone with the meshes that used them; the cards and fan keep `ostra_glow.jpg` and `void_card.png`.

- **Rig:** `root` is the Rig; the box rides `x_box` under it, with `x_boxlid` (the lid, 0 open as modelled, 1 shut), `x_crank` (a bone with no mesh since v2; kept for the clips and `anchor_crank`),
  `x_void` (the void tail goes into the box with him), `x_smoke` (the smoke wound on the spring, scaled to nothing in every still). `hips` sits at the
  top of the spring: the spring is a blend of x_box and hips, so moving the hips compresses it. Clips key the hips' position and scale (`offset_bones`):
  a scale of 0.02 with the lid shut is "down in the box" (the arrive, the emote, the death).
- **Normal map:** `ostra_normal.jpg`, since the appeal swap baked from the master's own normal map (before it, from the paint's relief, `ostra_paint.normal_map`). hero_toon `use_nrm`, `normal_k` per slot in warden_look.json.
- **Face:** since the appeal swap, painted in the master's atlas on the glow-face slot (warden_look.json: the glow look, dark_lift 0 so the void stays black). Before it: an emissive texture on a dished plane inside the hood (`tools/art1/ostra_mask.py`, to briefs/art-refs/ostra_head.png), tipped up 16 degrees for the match camera; `x_jaw`,
  `x_brow.*`, `x_cheek.*` bent the grin and slits (since the swap the face rides `head`; those bones stay in the rig, unweighted). 11-08 rework: a near-black void, thick crescent eyes glaring down at the nose (inner end low), one clean wide grin with a jagged fang seam.
- **No weapon (item 136):** the void orb is gone. `anchor_orb`, `anchor_hand_r` (right palm), `anchor_hand_l`, `anchor_cards` (left palm), `weapon_muzzle` (right fingertips, an FX
  point the Gun follows). The fan of cards on `x_fan` is the deck. The flurry's card is `void_card.png`, built by `scripts/heroes/void_card.gd`.
- **Cards:** `orbit_cards`, `orbit_cardsb` on the hips, tumbled by WardenSway (`sway` in content/rules/warden_anim/ostra.json), some burnt or torn.
- **Clips:** `tools/art1/ostra_clips.py` (keys; gliding, the box swings back on the spring's top, `swing`, and treads), `ostra_pose.py` (hands by target, two-bone IK, fingers, face, box), `ostra_anim.py` (30 fps from frame 0).
- Imports: `animation/fps=30`, `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`; textures `compress/mode=2`,
  high quality, mipmaps (S1's budget).

**Shard Snap's free arm (2026-11-17, port of ext/ostra-gait-rebased):** `snap_wind` and `snap` hold the fan in at the ruff (`HELD_L`), re-keyed on this glb's rig
(`ostra_anim.py -- snap_wind,snap --from`) and copied in with `glb_add_clips.py ... snap_wind,snap --hold-moved-rest` (nothing held). The old branch's
bounding walk and run were not ported: main's tread gait (Nov 11) stays.

## 2026-11-24 native fix (hunter-round-1124, ostra_meshy.glb only)
Meshy's auto-rig skinned the box, spring, void tube and coat tails to two invisible legs (LeftUpLeg..RightToe_end), so in run,
attack and jump the box swung up behind him like a pair of feet and the coat panel kicked out. Every leg-chain influence now
sits on Hips (31,601 verts; arms, hands, head untouched). The void tube's albedo already is the violet starfield, but the toon
shading crushed it to black: the material gets an emissive texture (`ostra_meshy_void_emit.jpg`) = that same albedo under a
void mask, capped at 0.5 (its pale lilac texels emit violet instead, like the turnaround's streaks), so the game's emit layer (WardenGlb._toon use_emit) makes it glow. Albedo, mesh and clips unchanged.
Recipe: /home/boki/gens/hunter-round-1124/motley/r1/tools (voidmask.py, uvmask.py, mkfix2.py).

**Box on the floor (2026-11-24 r2):** riding Hips rigidly sank the box up to 30 cm under the floor and tipped it 42 deg (the clips drop and lean
Hips: Attack z 0.84, Jump_Run 0.85, rest 1.17). The box and its lid now sit on a new unanimated bone `BoxRoot` (child of SmartRigArmature,
identity, no clip keys it), so the box stays upright on the floor in every clip; the spring and the void's root blend from BoxRoot (box top,
y 0.34) to the body (y 0.74, smoothstep), so the spring squashes and stretches like a jack-in-the-box. Coat tails/bells stay on the body.
Recipe: /home/boki/gens/hunter-round-1124/motley/r2/tools/mkfix3.py (input = the r1 glb).

**r3 (2026-11-24, hunter-round-1124 job 20261124-204852-a1):** r2 snapped any vertex with y>0.56, r>0.26 to the body "for the coat tails", which
caught the void's own S-curl: a weight step = black fins and the curl folding out of the box as a lobe (idle 31/40 spike frames). Now the box->body
ramp is smoothstep(y 0.30->1.02) diffused over the welded mesh (box + lid pinned, coat tails pinned only off the void mask). Finger joints fold onto
their Hand bone (rigid mitts), Left/RightHand clip rotations soft-clamp above 50 deg from rest (Attack bent the wrist 159 deg = spiky hand).
New joints: `CoatLag` (Hips' channels delayed 0.10 s, up to 0.45 on the coat-tail tips: the tails trail and swing) and BoxRoot clip keys = half of
the hips' horizontal travel (the box slides with the attack lunge, stays on the floor and upright). Void emission = r2 layer + a violet glow toward
the box mouth + 246 sparse twinkle stars inside the void mask. Mesh and albedo unchanged. Spike frames (glbstretch, 10 fps) live -> r3:
Idle 0->0 (r2 31), Attack 27->5, Jump_Run 1->0, Crouch 0->0. Recipe: /home/boki/gens/hunter-round-1124/motley/r3/tools/mkfix4.py fix3.glb out 0.10 0.45 0.5.

**r4 (2026-11-25, hunter-round-1124 job 20261125-000830-a3):** the left glove is modelled curled (the right one is an open palm), so r3's rigid
mitts kept a cupped left fist in every clip. The live left-finger skin weights are back (4,150 verts) and every left finger joint is posed 80% of
the way to mirror the open right hand (mapped through the two hand frames), held constant in every clip (Meshy's finger curls dropped). The void's
pale-lilac texels emit 60% less (albedo luminance 0.45->0.75 ramp; stars and the box-mouth glow kept), so the curl reads deep violet from the side.
Mesh, albedo and body motion unchanged. Left-hand stretched edges (ratio>2, 10 fps) live -> r4: Idle 4413->1460, Attack 3843->1436.
Recipe: /home/boki/gens/hunter-round-1124/motley/r4/tools/mkfix5.py fix4.glb live.glb out 0.8 6, then mkfix6.py out final 0.6.

**r5 (2026-11-25, hunter-round-1124 job 20261125-021454-a4):** the side "pale column" was the ALBEDO: Meshy had baked big white/pale-lilac
highlight smears into the void's texture (the turnaround's void is deep violet with violet wisps and small stars, no white). The void now
takes its colour from a Meshy retexture of this exact mesh (task 01a21081-9f73-7765-b33b-af14fac3bdeb, meshy-7, original UVs kept: 100% of
UVs match, refs = turnaround front/side/back), pasted ONLY inside the r1 void UV mask (feathered 3 px, islands edge-padded); coat, box,
spring, face, gloves and bells keep the live texels. The emission layer is re-derived from the new void albedo (r1 formula; r3 stars and
box-mouth glow kept). Mesh, skin, rig and clips are byte-identical to r4 (all 2821 accessors). `ostra_meshy_comp_B.jpg` is the new embedded albedo.
Recipe: /home/boki/gens/hunter-round-1124/motley/r5/tools/{pad.py,mkfix7.py,compact.py} (pad.py live.glb tex.png pad.png; mkfix7.py r4.glb pad.png out; compact.py).

**r12 (2026-11-27, job 20261127-180721-a1):** the void read electric indigo/hot pink at the match camera; its albedo is now the
Meshy void retexture w28 (r8 round) histogram-matched in full to the turnaround void crops, darkened x0.55, saturation x0.75, red x1.22
(hue back to violet), emission rebuilt hue-locked violet (swirl 0.12, box-mouth 0.06) with 400 sparse star dots. Only texels inside
the void UV mask change (mask rebuilt from the r7->r10 void diff: /home/boki/gens/hunter-round-1124/motley/r12/void_uvmask_rec.png).
All 2822 accessors (mesh, skin, rig, clips) byte-identical to r10; glb compacted 10.0 -> 7.3 MB. Game view, side, void pixels
(live -> r12): value 0.71 -> 0.64, hue 273 -> 267 (turnaround 270), pink share 15% -> 12%. (Lowering painted rim_far 0.5 -> 0.08 was
tested: no measurable change, so the look rule is unchanged.) Recipe: /home/boki/gens/hunter-round-1124/motley/r12/tools/mk12.py
r10.glb ../r8/mx/w28/tex0_base_color.png c5.glb --match=1.0 --dark=0.55 --sat=0.75 --red=1.22 --swirl=0.12 --star=0.55 --nstars=400 --srad=4 --mouth=0.06

**r14 (2026-11-28, job 20261128-022706-a4):** r12's void paste and 3 px feather also painted violet smudges on the box faces, ruff,
hat horn and gloves: the r12 void UV mask covered ~7,000 triangles above the waist (ruff/head/hat) and its blur crossed island borders.
The void is now the r13 f2 candidate (r12 void at 0.75x albedo, less pink), kept ONLY on void-mask triangles whose 3D centroid
is below y=1.2 (the tail), with a 3 px gutter that may grow only into UV texels no other triangle uses. Every other texel (albedo and
emission) is restored to live main (8905d8ca); 0.03% of UV outside the new mask differs from live. All accessors byte-identical
to r12/live. Game view, side, void pixels (live -> r14): value 0.61 -> 0.64 at eye, pink share 21% -> ~9%. art-gate game sheet
(side, real GPU): GAME 5.3 vs LIVE 4.5. Known open issue: the starfield still covers the black coat tails (they share the void mask
below the waist). Recipe: /home/boki/gens/hunter-round-1124/motley/r14/tools/{mask14.py mask_k4.png, mk14.py ../r13/f2.glb live.glb
k4.glb --mask=mask_k4.png}, then r11/tools/compact.py.
