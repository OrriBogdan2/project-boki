# Warden concept sheets

One sheet per Warden (`<id>.png`, built from `src/<id>.svg.in`), plus `lineup.png`, which shows all twelve at true height on one metre scale with a black-silhouette row (the gameplay-zoom read).
To rebuild them, run `src/render.sh [ids...]`. It needs Python 3 and the queued Godot; see the docstring in `src/build.py` for the authoring shorthands.

## Heights and recommended hitbox size (OWNER_REVIEW item 46)

The heights are the visual heights in the concepts. Hitboxes follow them, compressed into 0.85-1.15x of the standard hunter radius (1.00 = a 1.78 m hunter of average build).
Build counts as well as height: the broad Wardens sit higher than their height alone would put them, and the thin ones lower.

| id | Warden | height | build | relative size |
|---|---|---|---|---|
| bulwark | Bjorn | 2.45 m | tallest and widest | 1.15 |
| dredge | Dredge | 2.25 m (to the stack) | hulking, hunched | 1.13 |
| juggernaut | Zedran | 2.00 m | broad, heavy | 1.07 |
| gunslinger | Venator | 1.82 m | broad | 1.04 |
| ostra | Ostra | 2.25 m (floating) | tall and thin; hitbox at ground level (item 18) | 1.03 |
| mage | Vireo | 1.80 m | average | 1.00 |
| archer | Pin | 1.72 m | lean | 0.98 |
| dolm | Tarek | 1.70 m | lean, average | 0.97 |
| thief | Sable | 1.68 m | lean, average | 0.96 |
| rimewright | Tamsin | 1.70 m | slight | 0.95 |
| ashwick | Cinder | 1.41 m crouched (1.63 m upright) | low, hunched, long tail | 0.94 |
| tender | Moosh Moosh | 1.05 m | small (about 0.6 of a standard hunter) | 0.85 |
