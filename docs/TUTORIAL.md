# Tutorial guidance, garden only

## Garden first 15 (`--garden-first-15-check`)

The game is playable without extraction, and in the first visit the player must never be left without
a next step. The check plays a fresh save that skips the match tutorial ("Skip the tutorial" on the
naming card), takes the first Relic and lands on the garden (`base_mode` on). A bot then plays 15
minutes of garden time, never opens a match, and every second asks what is on screen to guide the
player:

- the tutorial line, or the marker in the world
- a Boki's want bubble
- a Goals row the player can finish at home (first-day list, garden, farm milestone or level; a
  Hunter's unlock or mastery row needs a match and does not count)

A 10 s window with none of them is logged; a stretch of 20 s fails the check. The interact prompt does
not count: it shows only once you stand next to the thing.

The bot acts 8 s after a prompt appears: it does the tutorial steps, then feeds, plays at a toy and
runs the Training post. It has one Boki the whole time, as a new save does.

### Gaps, before and after

| Window | Before | After |
|---|---|---|
| 0-42 s | tutorial line, marker, then the first-day list | same |
| 42-900 s | nothing: first-day list down to the two lines that need a second Boki (nap pile, Nook pair), no other home goal | "Next: Raise <Boki> to level 2" with an XP bar |
| Worst gap | 859 s (85 windows without guidance) | 0 s |

Fixes (Goals tracker, no new screen):

- A `garden` row, "Raise <Boki> to level N", with the Boki's XP towards the next level. It is there
  for the whole game at home, and feeding, petting, fetch and drills all move its bar.
- "See a nap pile" and "Pair two Boki in the Nook" stay off the card while you have one Boki, so the
  top line is never something you cannot do. They show as soon as a second Boki is on the farm.

Left open (not fixed here): a one-Boki save has no garden way to a second Boki before the market
stall is level 2 (the Shelter), and a visitor needs a built zone. The level row covers the gap, but
breeding stays out of reach for a while.
