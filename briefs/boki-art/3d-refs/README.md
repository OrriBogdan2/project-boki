# Boki 3D reference renders

28 models, 6 views each (168 PNGs), plus one contact sheet per model and one overview sheet.
Rendered 11-10 from the game .glb files in Blender 4.5 (Cycles, flat #d8d8d8 background, soft key + fill light, rest pose = first frame of the idle animation, model fills about 80% of a 1024x1024 frame).

- `OVERVIEW.jpg`: every model, front 3/4 view, labelled.
- `<id>/<id>_sheet.jpg`: all 6 views of one model, labelled.
- `<id>/<id>_{front,front34l,sideleft,back,back34r,top45}.png`: 1024x1024, palette-quantised to stay under 400 KB.

Views: `front` (camera straight ahead of the face), `front34l` (front 3/4, camera 40 deg to the model's left), `sideleft` (90 deg), `back` (180), `back34r` (back 3/4 from the opposite side, -140 deg), `top45` (45 deg down, from the front).
Camera elevation is 8 deg above level for all views except `top45`.

## How to use these (read this first)

1. Use the renders as **pose, angle, shape and proportion references** for splash art, key art, turnarounds and scenes with a Boki in them: where the limbs go, how big the head is against the body, what the silhouette looks like from the back or from above.
2. **The approved 2D design wins for looks.** Where the approved design (Bokidex portrait, `batch/approved.json`, `LIVE_MANIFEST.json`, turnarounds) differs from the 3D model, copy the 2D design's colours, markings, face, patterns and detail. Take only angle, pose and volume from the 3D render. The 3D models are low-poly game assets with simple vertex colours and a gradient on the belly; do not copy the plum-purple foot/belly gradient or the shading.
3. None of these ids is on the `redesign_lookalike` list (that list holds other species), so no extra caution is needed on that front.
4. The five `*_fusion` models are **loose parts, not whole creatures** (wings, tail, mushroom or fin pieces meant to attach to a base Boki in the game). They look odd or broken in a rest pose. Use them only as shape hints for the fused look, never as a full-body reference.
5. `caecilith` and `gibbelle` are **pilots, not in the game** (Meshy-generated test meshes). Treat them as optional shape references only.

## Where the 3D clearly differs from the current 2D design

Different creature or very different look (rely on the 2D design; use the 3D only for volume):

| Boki | 2D design | 3D model |
|---|---|---|
| Glomwort | see its approved sheet | a completely different creature |
| Cairnback | see its approved sheet | clearly different body and build |
| Glintmole | see its approved sheet | clearly different body and build |
| Hivara | wasp/mantis insect, honeycomb wings, upright | chubby round bee with antennae, frog-like face |
| Kestrike | red and slate kestrel, feather crest, long barred tail | round grey owl-like bird, twig on head, short tail |
| Kindlewren | black chick, red comb, glowing lava cracks, flame tail | brown round bird, spike on head, ball on tail |
| Lodestick | long twig stick-insect with orbiting rocks | round-bodied spider, green-tipped antennae |
| Marchleaf | green leaf mantis, fiddlehead antennae | red-brown ant carrying a leaf |
| Rimeshrew | white ferret with a snow-globe dome on its back | grey-purple shrew with crystal spikes |
| Zephyrak | slim coiled serpent-dragon | whale/fish blob with fins and green spikes |
| Gibbelle (pilot) | adult gong-chest monkey, mallet tail | chibi baby curled up, holding a gong |

Moderate differences (same idea, different details or colours):
Gloamshell, Mossgrade (3D is a dark tardigrade with many legs; 2D is a mossy pig-like tardigrade), Nettlynx (3D olive lynx with leaf tufts; 2D tan kitten with round bush pompoms), Selenfin (3D lumpy fish, grey-purple; 2D white moon fish with crescent markings), Thrumbird (3D has a spike beak and no fork feet; 2D has a tuning-fork beak and fork feet), Pebbit (3D has orange-brown face and green stripes; 2D is dark with purple stripes and a pale belly).

Close match (shape agrees with the 2D design): Burrlet (hedgehog with mushrooms), Caecilith (pilot; worm shape agrees, but the 3D has no zipper).

No approved 2D design on file for Cindle, Puddlet, Wisplet, Zapple. For those four the 3D model is currently the only design, so use it for looks as well.

## Models

"In game" is yes for models on origin/main, no for pilots. Source paths are in the game repo; blob is the git blob sha of the file.

| id | folder | in game | source (repo path) | git blob |
|---|---|---|---|---|
| burrlet | `burrlet/` | yes | `art/kin/burrlet/burrlet.glb` @ origin/main | `f7fcee30268d` |
| burrlet_fusion | `burrlet_fusion/` | yes (fusion part) | `art/kin/burrlet/burrlet_fusion.glb` @ origin/main | `920df461ddc1` |
| cairnback | `cairnback/` | yes | `art/kin/cairnback/cairnback.glb` @ origin/main | `637bbe7d3fde` |
| cindle | `cindle/` | yes | `art/kin/cindle/cindle.glb` @ origin/main | `5fcb0e0ccfd2` |
| cindle_fusion | `cindle_fusion/` | yes (fusion part) | `art/kin/cindle/cindle_fusion.glb` @ origin/main | `672a713dd4bd` |
| glintmole | `glintmole/` | yes | `art/kin/glintmole/glintmole.glb` @ origin/main | `9853613652ce` |
| gloamshell | `gloamshell/` | yes | `art/kin/gloamshell/gloamshell.glb` @ origin/main | `c2cf6f30bd89` |
| glomwort | `glomwort/` | yes | `art/kin/glomwort/glomwort.glb` @ origin/main | `ce7fde4ee3b1` |
| hivara | `hivara/` | yes | `art/kin/hivara/hivara.glb` @ origin/main | `84188d542a51` |
| kestrike | `kestrike/` | yes | `art/kin/kestrike/kestrike.glb` @ origin/main | `d6dde6c539c8` |
| kindlewren | `kindlewren/` | yes | `art/kin/kindlewren/kindlewren.glb` @ origin/main | `a4acf066fda8` |
| lodestick | `lodestick/` | yes | `art/kin/lodestick/lodestick.glb` @ origin/main | `49d49b197bb0` |
| marchleaf | `marchleaf/` | yes | `art/kin/marchleaf/marchleaf.glb` @ origin/main | `da9c35416440` |
| mossgrade | `mossgrade/` | yes | `art/kin/mossgrade/mossgrade.glb` @ origin/main | `5e859befa225` |
| nettlynx | `nettlynx/` | yes | `art/kin/nettlynx/nettlynx.glb` @ origin/main | `d072342b1bea` |
| pebbit | `pebbit/` | yes | `art/kin/pebbit/pebbit.glb` @ origin/main | `65cb9fb12022` |
| puddlet | `puddlet/` | yes | `art/kin/puddlet/puddlet.glb` @ origin/main | `65aed8f2876a` |
| puddlet_fusion | `puddlet_fusion/` | yes (fusion part) | `art/kin/puddlet/puddlet_fusion.glb` @ origin/main | `61369ff41dfa` |
| rimeshrew | `rimeshrew/` | yes | `art/kin/rimeshrew/rimeshrew.glb` @ origin/main | `15cc4ede2d5e` |
| selenfin | `selenfin/` | yes | `art/kin/selenfin/selenfin.glb` @ origin/main | `002aabf41fa9` |
| thrumbird | `thrumbird/` | yes | `art/kin/thrumbird/thrumbird.glb` @ origin/main | `6755386dd77b` |
| wisplet | `wisplet/` | yes | `art/kin/wisplet/wisplet.glb` @ origin/main | `9e0e02f4242f` |
| wisplet_fusion | `wisplet_fusion/` | yes (fusion part) | `art/kin/wisplet/wisplet_fusion.glb` @ origin/main | `2a04252d1f06` |
| zapple | `zapple/` | yes | `art/kin/zapple/zapple.glb` @ origin/main | `3bd0920d62a8` |
| zephyrak | `zephyrak/` | yes | `art/kin/zephyrak/zephyrak.glb` @ origin/main | `ff38fa1155eb` |
| zephyrak_fusion | `zephyrak_fusion/` | yes (fusion part) | `art/kin/zephyrak/zephyrak_fusion.glb` @ origin/main | `223204ae28ad` |
| caecilith | `caecilith/` | NO - pilot, not in game | `art/kin/caecilith/caecilith.glb` @ origin/ext/boki3d-meshy-pilot-rebased | `2dbb12be38c0` |
| gibbelle | `gibbelle/` | NO - pilot, not in game | `art/kin/gibbelle/gibbelle.glb` @ origin/ext/boki3d-meshy-pilot-rebased | `9eff4c448425` |

Source commits: origin/main d255acbee; origin/ext/boki3d-meshy-pilot-rebased 1956f2a31. The same .glb files are also in `briefs/boki-art/3d-models/<id>/` if you want to open them in Blender yourself.
