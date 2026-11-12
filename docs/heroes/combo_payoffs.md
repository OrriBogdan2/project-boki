# Mark-then-payoff pairs across the 13 kits (the combo-clarity rule)

Internal design note. Owner rule (decisions 2026-11-08, two-step abilities): a rival carrying your mark, Daze or
stack shows a clear icon over it (what it is, time left); the payoff gets a strong hit flash and a sound.
The tag is `scripts/ui/combo_mark.gd` (`ArchKit.combo_read` -> icon, pips, time ring, only for the viewer's own
marks); the payoff is `ComboMark.payoff` (the body flashes white for 2 frames, a light flash, the `combo` chime).
Probe: `godot --headless --path . -- --combo-payoff-check` (tools/combo_payoff_check.gd).

Needs `ext/ui-combo-tag-rest` (stacked on `ext/ui-combo-marks-c` and `ext/combo-marks-a/b`): on main only Sable,
Vex and Sparkle read through the tag; this branch carries the rest.

## Pairs with a mark on the foe (all probed: tag, flash, sound)

| Hunter (id) | Mark / state | Payoff | Icon + time left | Flash + sound | Probe row |
|---|---|---|---|---|---|
| Sable (`thief`) | Marks (uncapped, 4 s), pips toward the diamond count | Empowered Vault bolt landing on a marked foe | gem, pips, ring | yes | `thief` |
| Vex (`gunslinger`) | Daze from the Burr cone/wall (2 s) | rifle shot (+90%, every shot) | concussion, ring | yes, per shot | `gunslinger` |
| Vex (`gunslinger`) | the same Daze | Longneedle down the lane (damage + `payoff`) | same | yes | `gunslinger (needle)` |
| Sparkle (`mage`) | Static, 4 stacks, 4.5 s | Wirerun through a Live foe: Blowout | shock, pips, ring (lifted above her Static marker) | yes | `mage` |
| Cinder (`ashwick`) | Ablaze (Char full) | Cinder Shot on a burning foe: bonus damage + spread | fireball, 2 pips, ring = burn left | yes | `ashwick` |
| Cinder (`ashwick`) | Ablaze | the burn stoked again: Flashover | same | **was missing, fixed here**: word, column, sound and HUD flash, but no body flash and no chime | `ashwick (flashover)` |
| Neve (`rimewright`) | Chill (4 s) | Shatter: a knock or kill on a Chilled foe | frost, ring | yes | `rimewright`, `rimewright (knock)` |
| Meeko (`tender`) | Kindle stacks (4 s), 5 max | full Kindle (KINDLED), every shot hits harder | burst, pips, ring | yes | `tender` |
| Gil (`gil`) | Splash marks, 3 different within 5 s | Beach (stun 0.75 s) | tonic, pips, ring | yes | `gil` |
| Kael (`juggernaut`) | Slam window (2 s after the Finishing Slam) | a knock readies the Riposte | slam, ring | yes | `juggernaut` |
| Kael (`juggernaut`) | Warchain hold (5 s) | the pull | chain, ring | yes | `juggernaut (chain)` |

Each row asserts: the tag has an icon and a time left inside its total while the mark runs; the payoff stamps the
foe (`cm_pay`), sets `flash_t` to the 2-frame white and moves `Sfx.last_played["combo"]`. The tag's own rows
(shrinks, gone at the end, belongs to the applier) stay in tools/combo_mark_check.gd, run by each kit's combo check.

## Kits with no mark on the foe

Their two-step is a stun, a pin or a position, not a carried mark, so there is no icon to show. Payoffs go through
`ArchKit.payoff_fx` (word, burst, sound, HUD flash) with no white body flash and no tag.

| Hunter (id) | Setup | Payoff |
|---|---|---|
| Albert (`bulwark`) | knock a foe into a wall or another foe (stun) | CRUSHED (`bulwark_kit.gd` payoff block) |
| Tenzo (`dolm`) | a punched rock | rock fall payoff, wall stun |
| Grimble (`dredge`) | Anchor reel (stun spiral on the foe, `stunned`) | HAULED |
| Motley (`ostra`) | Shard Snap stun, Brimseed bomb growing | collapse at full growth |
| Lace (`archer`) | Heavy Shot pin; Hawk Sense reveal under half health | EXECUTED (ult) |

## Gaps left (not wiring only)

- A tag for the stun/pin setups above (Grimble's reel, Motley's stun before the bomb, Albert's wall stun, Lace's pin)
  would need a new `combo_read` per kit (what counts as the state, its total time) and a decision on whether a stun
  is a "mark" under the rule. Not built. The foe's own stun effect already shows.
- The `payoff_fx` payoffs (CRUSHED, HAULED, rock fall, collapse, SWEET SPOT, EXECUTED) have no white body flash. One
  call to `ComboMark.payoff` per site would add it, but their rings/burst already read; owner call.
- Sparkle's 4th Static (Live) has its own word and sky bolt but no body flash; it is the mark completing, not the
  payoff, so left alone like Sable's uncapped Marks.
- Squad-mate tags (a teammate's marks on a foe) are drawn beside yours on `ext/ui-combo-tag-rest`; the probe only
  covers the viewer's own.
