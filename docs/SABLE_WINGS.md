# Sable's moth wings

Her moth wings are folded down against her back most of the time. Now and then they come up, raised open behind her
(a slow moth spread, a hold with a small flutter, a slow fold back).

## After a body swap: the one command

```
python3 tools/art1/sable_wings.py NEW_BODY.glb art/wardens/sable/sable.glb
godot --headless --path . --import && godot --headless --path . -- --sable-wings-check
```

The tool takes any rigged Sable GLB with a `hips` joint (a Meshy body through the v95 swap, a Blender export). It:

- adds the two wing chains `spring_wing{R,L}_{0,1,2}` under `hips`, or resets them to the donor's place if the body
  already has them;
- adds the wing cards (`card-wing` material, `sable_wings` texture), skinned to the chains, replacing any old ones;
- fits them to the new back. If the body pokes through the folded cards more than the approved art does, it moves
  each wing's root back and tips the hanging cards back about it, the least that clears (at most 8 cm and 30
  degrees). It then measures the raised pose.

It prints the fit, for example `root 3 cm back, cards tipped back 26 deg ... folded 0 (donor 2), raised 0`. It exits
1 with a WARN if the body still pokes through; then the body needs a look, not a nudge. Re-running it on its own
output changes nothing.

The donor (the cards, their weights and the chain, relative to the hips) is `art/wardens/src/sable_wings.json` with
its texture `sable_wings.jpg`. Both were cut from the approved main model with
`python3 tools/art1/sable_wings.py --extract art/wardens/sable/sable.glb`. Re-extract only if the wing art itself is
redrawn.

Instead of the tool, the swap spec could list the wing bones and cards under `keep` so they carry over. That only
works while the new body's back sits where the old one did; the tool fits them to whatever back it gets.

## How they move (runtime)

The animation is procedural, with no clips, so it works on any body that has the chains:

- `scripts/heroes/warden_wings.gd` (WardenWings) decides how far open the wings are each frame, from 0 (folded) to
  -1 (raised), and sets it on the model's `WING_FOLD` meta. HunterAnim makes one for any Hero whose
  `content/rules/warden_anim/<art>.json` has a `"wings"` block (only Sable).
- `WardenGlb.Springs` (scripts/heroes/warden_glb.gd) turns that into the pose. A hanging wing chain swings back and
  up about its root (`RAISE`, 2.4 rad), then out to her side (`SPREAD`, 0.45 rad), and the verlet springs ease it
  there.

They rise:

- **now and then while she stands**: every `idle_gap_s` (8 to 15 s, random, on each Sable's own clock) they open
  over `open_s` (1.1 s), hold for `idle_hold_s` (1.6 to 3 s) with a flutter, and fold back over `close_s`;
- **in the kit's two big moments**, through the kit move's `wg` channel: the Vault's routine of flips and the Encore's
  dance;
- **in the air**: a jump, a dash or a roll opens them to `air_open` (0.85) in `quick_s`, once she has been off the
  ground for `air_delay_s` (0.12 s, so a step's lip at a run does not flick them);
- **on an emote**.

They fold straight back down (`run_close_s`) when she runs faster than `fold_speed` (3 m/s) or is downed. All the
timings are in sable.json's `"wings"` block.

## Checks

- `--sable-wings-check`: in each pose (folded, raised, run, shoot, shoot raised, a flip), it skins the cards and the
  body and counts the card vertices inside her coat, braid or head. It also checks how far any card edge stretches
  (tearing).
- `--clip-live-sable-check`: in a real match, she raises her wings while standing, folds them again, keeps them
  folded while running and raises them on a jump. It also runs WardenWings' timing on its own.
- `--sable-wings-shots --shots-dir=docs/shots/sable-wings` (with a renderer) writes `game.png` (folded and raised at
  the match camera), `poses.png` and `open_close.png`.

The shots in `docs/shots/sable-wings/` are of the main model; `bugeye/` is the same set on the v95 appeal3 bug-eye
body after the tool (root 3 cm back, cards tipped back 26 degrees). On that body the raised wings stand a little more
upright (the tip adds to the raise: 0.49 m up, 0.20 m back at the tip, against 0.36 and 0.43 on the main model).
