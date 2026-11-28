## Cinder dash stun (`ext/cinder-dash-stun`, 2026-11-28)

Gap from the kit catalog (Cinder, "Change first" 3): the source's flaming dash stuns the foe it hits for about 1 s and knocks it back. Ours knocked (push 7) but did not stun. Now the Soot Ram hit sets `dash.stun` 1.0 in `content/archetypes/ashwick.json` and passes it to the foe's hurt as `stun` (the shared stun path, with diminishing returns like Albert's and Lace's). The knock was already there.

Asserted in `--cinder-shift-check` ("Cinder Shift hit"): a medium foe 2 m ahead is stunned 0.9 to 1.1 s (measured 1.00 s) and rests 1.8 to 2.2 m on (measured 2.01 m).

### Crowd control

| Hunter | Effect (ours) | Source | Verdict |
|---|---|---|---|
| Cinder | Soot Ram hit: stun 1.0 s (`dash.stun`), stops on the first foe | Pyro Pounce: "stun 1s" [D] | match |

### Knock distances

| Hunter | Knock (ours) | Push, lift | Ours at rest | Source | Kind | Distance |
|---|---|---|---|---|---|---|
| Cinder | Spark Leap hit (`dash.kb`), now with the 1.0 s stun | 7 | 2.01 m (a medium foe, asserted 1.8 to 2.2) | Pyro Pounce: "knockback, stun 1s" [D]; no read of the target's flight [F] | match | `[?]` |

Dash row of the Cinder table above: Soot Ram hit now also stuns 1 s; verdict stays match.
