## Farm hunter look and crop beds (2026-11-25)

The farm's close third-person view put the avatar in the middle of the screen, and it was the Empty (`Unmasked.worn()`:
a void body with an ink line), which reads as a black glossy blob up close. `Home._hunter_model()` now builds you the
way a match does (`Unmasked.mask_look()`, your archetype's Warden .glb, textures and `HunterAnim` idle/walk). The house
(`interior.gd`) and the town still show the Empty; one call each to change if the owner wants them to match.

Crop beds are solid: `PlotBlocks.tiles` (the tiles a 1.7 m bed covers by more than a hand's width) become blocked in
`HomeBuild._apply_blockers`, so you and the Boki walk round a bed, and the grass scatter (which skips blocked tiles)
leaves its soil bare. A bed is worked from beside it: the home validator and `keeps_paths` accept a tile two away
(`PlotBlocks.REACH`) for beds. `--farm-start-check` asserts the avatar is your hunter and that walking at a bed stops at
its edge.
