## Farm avatar and crop beds (2026-11-25)

On the farm you are yourself, the Empty (`Unmasked.worn()`, as DECISIONS says), not your Hunter's .glb. In the close
third-person view the Empty read as a black blob. Not the void body (it is a smooth cut-out of night, by design) but the
shroud: `HunterBody.mats` draws the cloth at HSV value 0.30 to 0.36 whatever colour you picked, and the farm's far-side
light took the rest, so a slate-blue shroud came out at 20 to 45 of 255. `Shrouds.dress` now keeps the cloth at least
`CLOTH_VALUE` bright in the picked hue and lights it `CLOTH_FILL` of its own colour (`own_ambient`), so the cloak reads
as the creator's swatch, folds and hood included. The house, the town and the creator draw the same model, so they match.

Crop beds are solid: `PlotBlocks.tiles` (the tiles a 1.7 m bed covers by more than a hand's width) become blocked in
`HomeBuild._apply_blockers`, so you and the Boki walk round a bed and the grass scatter (which skips blocked tiles)
leaves its soil bare; a tile walled in beside a bed is blocked too (`PlotBlocks.pockets`). When a crop patch moves, the
ground meshes (and so the grass) are rebuilt a moment later, so the new soil is clear and the old spot grows grass again.
A bed is worked from beside it: the home validator and `keeps_paths` accept a tile two away (`PlotBlocks.REACH`).
`--farm-start-check` asserts walking at a bed stops at its edge and that moving a patch re-grows the grass;
`--farm-cam-clip` films idle, walking and beside a bed on the GPU.
