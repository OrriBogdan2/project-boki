# 0017: One build and decorate UI for the farm and the house

- **Status:** accepted (owner, Nov 4 00:35 to 00:37 UTC)
- **Date:** 2026-11-04
- **Area:** farm / house / UI / save

## Problem
Build mode (farm) and decorate mode (house) were two different bars. Rotating was only hinted in a footer line, a refused spot gave no clue what was in the way, the house started furnished with two fixed pieces, and building stayed on after every placement.

## Decision
- One bar for both: `BuildCatalog` (category tabs, search, big tiles with a picture, name, price in have/need colours and an owned count, a Storage tab, Undo, Done). The farm feeds it from `HomeBuild`, the house from `Decorate`.
- `BuildKeys`: clickable buttons with key caps above the bar (Rotate with R or right-click, Place, Store, Cancel; Move and a put-away mode when nothing is held) and a tag by the cursor with the same keys and the refusal reason. Key text always comes from `Settings.key_cap`. New action `store` (X, Delete), allowed to share X with Fuse because they never apply in the same place.
- `BuildMenu`: click a placed piece for Move, Rotate, Store (and Colour where it has one). X over a piece stores it at once.
- `Placement`: the held piece eases to each quarter turn; a placed piece's Rotate spins it; the camera eases to a build view (`CamRig.top`) and back; the piece in the way is lit.
- Blocked spots read "Blocked by: <piece>" (farm and house) or "Keep the doorway clear".
- Placing one thing leaves build mode with a "Placed! <Build key> to build more" toast. Lines and brushes (fences, paths, water, clearing) stay in their tool; holding Shift keeps the same piece in hand.
- The house starts empty. The journal and gramophone are ordinary pieces (`RoomPieces`, Data.FURN); every piece can be moved or stored, only the door and walls are fixed.

## Save
Version 11 (`HouseSave`). A save that has played keeps its house as it was, and the old fixed journal and gramophone become pieces standing where they stood. A save with no Boki yet starts with an empty house and both pieces in storage. New saves get both in storage.

## Consequences
- `HomeBuild` entries use `name`, `note`, `cost`, `owned` instead of a text blob; checks that read the old `t` text were updated.
- Checks: `--build-ui-check` (new); `--farmbuild`, `--farm-tutorial-check` and the farm checks updated. Screenshots: `--build-ui-check --build-ui-shots=<dir>`.
