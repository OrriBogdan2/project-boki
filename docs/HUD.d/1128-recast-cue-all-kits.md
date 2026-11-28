## Two-step abilities: the cue in all 13 kits, and on the starters' first fights (11-28)

DECISIONS 2026-11-08 "two-step abilities must be obvious and in your face". Every kit's data was read for a second
press (`recast_hint` in `content/archetypes/<id>.json`, `recast_window()` in its kit, `ult_recast` / `e_recast`).
"Cue" = the kit reports a window, so `RecastCue` pulses the slot ("<KEY> AGAIN", a timer ring, EXPIRED) and rings the
spot in the world: a plain ring, no word and no key letter on any world object (owner 11-11). One kit had a second
press with no cue: Gil's Tidal Wave (R again leaps off the crest early). It now reports an `x` window over the surf
(`GilKit.recast_window`, `recast_hint.x`) and `--recast-cue-check` covers it.

| Hunter (id) | Two-step ability | Second press | Cue |
|---|---|---|---|
| Lace (`archer`) | none (Heavy Shot is hold and release) | | n/a |
| Kael (`juggernaut`) | E Warchain | E hauls him to the hooked foe or wall | yes |
| Vex (`gunslinger`) | none (E is stand, charge and release) | | n/a |
| Sable (`thief`) | E dagger | E blinks to it | yes |
| Meeko (`tender`) | E Hearthlight | E throws the light (it flares by itself, so no EXPIRED) | yes |
| Motley (`ostra`) | E Brimseed | E pops the seed (no world ring: the seed is the ring, owner 11-08) | yes |
| Neve (`rimewright`) | E Rink Wall, X Rimelock | E freezes the wall; X cracks Rimelock now | yes, yes |
| Albert (`bulwark`) | LMB hammer | LMB recalls it (no timer while it lies) | yes |
| Sparkle (`mage`) | X Kitefall | X strikes down at the cursor | yes |
| Cinder (`ashwick`) | X Flue Flight | X lands early | yes |
| Tenzo (`dolm`) | Shift Rock Hop | Shift hops on to the next rock | yes |
| Gil (`gil`) | E Riptide, R Tidal Wave | E lets the spout go; R leaps off the wave | yes, yes (R added 11-28) |
| Grimble (`dredge`) | none | | n/a |

A foe's mark, stack or Daze is not a second press: it is the plate status row (`ArchKit.combo_read`).

### The starters' first fights

Lace and Vex teach no second press. Kael's E Warchain does: in the fighting tutorial it opens on the "kin" step, the
E slot pulses "E AGAIN" on screen at 1280x720 (slot at 328,610, 50 px), and the world ring carries no word. The
tutorial shows no first-time line on top of it (`RecastCue._first_hint` skips the tutorial, training, the arena and
autoplay: the course teaches its own way); the first expedition shows the one line, "E again to haul yourself to the
chain", once. `--tutorial-recast-cue-check` plays the three starters' course and a first expedition and asserts all of
it, so a kit that gains a second press without the cue fails there.
