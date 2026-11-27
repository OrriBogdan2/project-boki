# The vet booth

A booth beside the market stall in the hub (`scripts/home/vet_booth.gd`, numbers in `content/rules/vet_booth.json`,
`--vet-check`). Walk up and the panel lists every Boki out on the island with a free check-up: health (good shape,
weak or sick from hunger, as `KinAiling` droops it), mood (its joy need in four words) and likes (food, play and the
food it hates). A weak or sick Boki has a Cure button for `cure_gems`; it does what a snack does (`Care.feed` erases
the starve clock) and the Boki perks up (`KinAiling.perk_up`).

- The booth is a hub fixture (`HubLayout.DECO`). A hub saved before it existed gets it the next time the hub opens
  (`HubLayout._add_missing`); no save format changed, it is one more deco entry.
- Opening it needs `VetBooth.find` / `label` / `open` routed from `home.gd` (three lines, see the PR).
- Render: `--vet-booth-shots --shots-dir=<dir>` (GPU).
