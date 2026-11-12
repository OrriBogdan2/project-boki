# Uthana AI motion pilot (2026-11-10)

Pilot of Uthana (uthana.com) text-to-motion on two Boki hunters, with a hard cap of $10.

**Spend:** start balance $24.5958, end balance $21.1791, **spent $3.4167** (itemised in `art/uthana_pilot/ledger.txt`).

**Review:** side-by-side renders (ours on the left, Uthana on the right) are in `/home/boki/art-review/uthana-1110/INDEX.html`.

## Method
- Uploaded our own rigged GLBs with `auto_rig:false`. This is free, and Uthana accepted our rig as-is.
  - Albert (Breaker body) = `cNMFJdZsQR9W`
  - Lace (Hem body) = `cJePL9fZWEff`
- Each motion was generated **once** and downloaded for **both** hunters. Retargeting happens at download time and costs nothing. The balance didn't move across about 60 downloads.
- Downloads are at 30 fps, in two forms: motion-only (`/motion/animation/...`) and with mesh (`/motion/file/...`). PAYG has no download cap.
- Godot 4.6 import:
  - The GLB with mesh imports as `Armature/Skeleton3D` with our exact bones (31 on Albert) and an AnimationPlayer.
  - The motion-only GLB imports as a node tree, and Godot renames `thigh.L` to `thigh_L`. `tools/render.gd::_remap_anim` maps the tracks back to `Armature/Skeleton3D:<bone>` and restores `.L`/`.R`. After that, the clips play on our skeleton.
  - Root motion is translation on `root`.
- Looping:
  - `create_looped_motion` on our characters fails with "Parent is not root index" (no charge).
  - Workaround: loop on stock character Tar, then download onto ours.
- Tools, prompts and the motion-only GLBs are in `art/uthana_pilot/`. The scripts never echo the key.

## Moves and verdicts
Albert's prompts play him as a calm ferryman knight with a shield and oar. Lace's play her as a precise ex-seamstress archer with a thread motif. Full prompts are in `tools/prompts_*.tsv`; per-clip notes are in `verdicts.tsv`.

| Move | Model | Verdict |
|---|---|---|
| walk loop | locomotion `heavyset` + stitch-loop | needs cleanup (forward axis, style) |
| run loop | locomotion `on_toes_bent_forward` + loop | needs cleanup (forward axis, speed) |
| idle | TTM 2.0 | Lace usable as-is; Albert needs cleanup (shield arm) |
| hit react | TTM 2.0 | needs cleanup (trim 4 s down to about 0.5 s) |
| light attack | TTM 1.0 / 2.0 | not usable (weapon never swings) |
| light attack | TTM 3.0 | needs cleanup (prop hand alignment) |
| heavy attack | TTM 3.0 | needs cleanup: best read of the set, but trim and fix the shield |
| dodge/roll | TTM 3.0 | not usable: the root sinks about 0.8 m under the floor |
| death | TTM 3.0 | usable as-is (slight foot slide) |
| victory | TTM 3.0 | needs cleanup (shield arm); good personality |
| ability cast | TTM 3.0 | needs cleanup: generic, and the thread motif barely comes through |

## Retarget issues
1. **Forward axis:** Uthana's forward is about 90° off from our clips on locomotion, so it needs a root yaw offset at import.
2. **Albert's left arm:** on the bulky Breaker rig, the left arm and shield sit splayed out flat in every clip. The arm rest pose doesn't match the human prior; Lace, with near-human proportions, retargets cleanly.
3. **Props:** Uthana doesn't know about props. Hands don't hold the bow string or follow the hammer grip, so prop clips need IK or hand cleanup.
4. **Floor contact:** acrobatic 3.0 clips can drop the root through the floor (dodge). Idles sometimes lift the feet about 0.1 m.
5. **Scale:** correct, with no drift.
6. **Foot slide:** small on locomotion and idle. The crude metric is in `slide_metrics.txt`; it includes swinging feet.
7. **Length:** generated clips run about 4 s. Combat moves need trimming to game timing.

## Cost and models
- TTM 3.0 costs $0.10/s, about $0.40 per 4 s move. It's the only model that follows weapon and personality prompts, so **use it for all action moves.**
- TTM 1.0 and 2.0 ($0.02–0.03/s) are fine only for idle and hit reacts.
- Locomotion plus stitch-loop is about $0.05 per loop and the best value.
- **A full ~20-move set comes to about $6–7 per hunter:** about 14 moves on TTM 3.0 plus 6 locomotion moves, with about one reroll in four.
- Shared moves (hit, death, locomotion) can be retargeted to every humanoid hunter for free, so per-hunter cost drops after the first.

## Non-humanoid creatures
Not feasible. Uploading nettlynx (a quadruped kin) was rejected for free with `could not map arm [ear1.l]`, because the joint mapper needs a humanoid skeleton. The models are trained on human motion. The animal-ish locomotion styles (cat, dinosaur, and so on) are humans imitating those animals.

## Notes and deviations
- **Auto-recharge is ON** (it tops up when the balance drops below $10). The owner's note says it is off. The cap kept the balance above $14.60, so it never triggered. I left the setting unchanged.
- **Godot queue was jammed:** all 14 slots were held by stale processes from other jobs. Renders ran `/opt/godot/godot-bin` directly under `nice`, xvfb-run and the gl_compatibility renderer (`tools/render.sh`), in a temp project at `/tmp/uthp`. `jobq` wasn't used because the renders are CPU frames.
