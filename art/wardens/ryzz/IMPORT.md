# Ryzz (mage), stage 1: import note

`ryzz.glb` is the locked Ryzz design (ext/imagegen 93a2757f docs/art/gen/wardens_r3/ryzz_* and RYZZ_KIT.md;
INBOX_S2 2026-11-04 11:00). Stage 1 of the Warden fan-out: Meshy, bake, fit, scripted pieces; no hand polish yet.
Built by script, nothing hand-edited in Blender; run log in docs/art/wardens/PIPELINE.md "Ryzz".

    # 9:16 crops of ryzz_front / _side / _back, edited (pigtails, ties and rods out; side: jacket off the
    # shoulders, the scarred eye closed): meshy_task.py edit (prompts in ~/meshy/ryzz/edit_*/request.json)
    blender-python -I tools/meshy/ryzz_prep.py tools/meshy ~/meshy/ryzz        # padded squares into in/
    python3 -I tools/meshy/meshy_task.py create ~/meshy/ryzz/run1 in/front.png in/side.png in/back.png --texture-refs in/front.png in/side.png in/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/ryzz_bake.json
    godot --headless -- --warden-rig-json --warden=mage
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/ryzz_fit.json

- **Body:** Meshy meshy-7.1 (three edited views, 2k geometry, 8k texture, no remesh), baked to 34k triangles with a
  4096 atlas (2048 in the game). Scar and wink on her RIGHT eye as the art draws them. Scaled so her hip-to-shoulder
  span is the rig's; head x1.12, hand x1.2.
- **Pigtails:** tools/meshy/ryzz_parts.py, 10 chunky locks each, blue to hot pink with zigzag ends, out of one
  copper-coil tie on each hair knot; `spring_pigtail_L_*` / `_R_*` (3 bones) under the head. `ryzz_pigtail_atlas.jpg`.
- **Rods:** three copper rods in a riveted mount on her back (rigid on the hips); the middle one, her relic, is
  scorched black and bent. `ryzz_rods_atlas.jpg`.
- **Glow:** `ryzz_body_emit.jpg`, the emission layer projected from the art's neon (scar, choker charm, corset piping,
  forearm veins); the game draws it in `model_glow.core` of content/archetypes/mage.json (hot pink #ff3fb4).
- **Weapon:** none held (her kit fires from her hands; the Storm Rod is the kit's own summon): an empty `weapon`
  hides the procedural one.
- Imports: the extracted atlases lossless (`compress/mode=0`); `ryzz.glb.import`: `generate_lods=false`,
  `force_disable_compression=true`.

Stage 2 (round 2, the r3c recipe; credit-free):
- **Paint-over:** smoothed within UV islands, then ramps of the art's colours per slot (sky-blue hair with hot-pink
  ends, peach skin, hot-pink corset, near-black leather, copper, hazard yellow); the scan's smeared nose ring painted
  over as skin and rebuilt as a copper septum ring (geometry on the head).
- **Hair hue:** content/rules/mantle_look.json "mage" now carries the art's colours and a `tint` block with no hue
  pull on hair or skin (the player's pick pulled her blue hair toward violet in the toon shader's tint).
- **Pigtails:** 22 locks a side in an S-fall from a puff at the tie down to the jaw; the scan's hair knots squashed
  under the ties (`knot_r`); no ink shell on them.
- **Rods:** seated on her back along its slope (clear by 4 mm), two riveted straps across the mount, a V from the
  mount up past her shoulders; brighter copper.
- **Glow:** the charm's art halo kept off the emission mask (`strict` region); emission 2.6, flicker 0.12.
- **Look:** content/rules/warden_look.json "ryzz" (skin warmer with no sky tint or match lift, hair brighter at the
  match camera, copper and hazard yellow on the metal slot lifted at distance).
- **Stance:** content/rules/warden_stance.json "mage": weight on her right hip, hips 9 cm over, shoulders tilted,
  her hands on her hips (she holds nothing).
