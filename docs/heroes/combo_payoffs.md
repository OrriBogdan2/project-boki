# Mark-then-payoff pairs across the 13 kits (the combo-clarity rule)

Internal design note. Owner rule (decisions 2026-11-08, two-step abilities): a rival carrying your mark, Daze or
stack shows a clear icon over it (what it is, time left); the payoff gets a strong hit flash and a sound.
The tag is `scripts/ui/combo_mark.gd` (`ArchKit.combo_read` -> icon, pips, time ring, only for the viewer's own
marks); the payoff is `ComboMark.payoff` (the body flashes white for 2 frames, a light flash, the `combo` chime).
Probe: `godot --headless --path . -- --combo-payoff-check` (tools/combo_payoff_check.gd).

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

## Other states a foe carries (all probed: icon in the plate status row, payoff flash)

These need no `combo_read`: the state is a plain status the plate row already draws (`HudPlate.statuses`). Their
payoffs go through `ArchKit.payoff_fx`, which now calls `ComboMark.payoff` for its victim, so every one of them gets
the same white body flash and chime as a mark payoff.

| Hunter (id) | State on the foe | Row icon | Payoff (`payoff_fx`) |
|---|---|---|---|
| Albert (`bulwark`) | wall or foe stun | stun | CRUSHED |
| Lace (`archer`) | Heavy Shot pin (stun) | stun | EXECUTED (ult) |
| Grimble (`dredge`) | Anchor reel Ground; Blast Blight | Ground; Blight (new) | HAULED |
| Tenzo (`dolm`) | rock Shred (takes +% damage) | Shred (new) | rock fall |
| Motley (`ostra`) | Shard Snap stun; Trade Disoriented (slow) | stun; Slow | collapse |
| Sable (`thief`) | Primed shot Shred | Shred (new) | the empowered bolt (see the Marks row) |
| Kael (`juggernaut`), Cinder (`ashwick`) | Blight | Blight (new) | none |

Lace's Red Thread (a hurt rival outlined through cover) has no icon on purpose: it is a passive outline that follows
the foe's health, with no timer to show. Shred and Blight have only a vector glyph so far (`Icons`, ids
`status_shred`, `status_blight`); a painted icon is owed (`--icon-art-check` lists painted statuses).
A remote body does not carry Shred or Blight timers (the Net `kst` note keeps only Ground, Daze and Slow), so the
icon shows on bodies this game owns and on monsters.

`--combo-payoff-check` prints a `MARKSTATE` line per state (kit, state, icon yes/no, flash yes/no) and fails on any
`no`, or on a `payoff_fx` call in the kits that does not name its victim.

## Gaps left (not wiring only)

- Sparkle's 4th Static (Live) has its own word and sky bolt but no body flash; it is the mark completing, not the
  payoff, so left alone like Sable's uncapped Marks.
- Squad-mate tags (a teammate's marks on a foe) are drawn beside yours; the probe covers the viewer's own.
