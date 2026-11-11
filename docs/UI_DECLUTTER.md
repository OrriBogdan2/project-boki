# Combat UI declutter (2026-11-11)

The owner, 11-11: "i want stuff like sweetspot and anything like it removed. sable dagger can flash when its
about to run out or something but it shows E on it which i dont like ... do this for all of the ui stuff that
clogs the screen."

The rule now: **in a fight, nothing floats or sits on the world as a word or a key letter.** What a player must
know about a timer is shown as a pure visual (a flash, a pulse, a ring). Damage and heal numbers stay.

## Removed

| What | Where it was | Why it goes / what carries the info now |
|---|---|---|
| Every floating callout word in combat (about 100: SWEET SPOT, CRUSHED, EXECUTED, BLOWOUT, ROCKFALL, COLLAPSE, HAULED, DEAD CENTRE, SKEWERED, WALLED, CHAINED, ANCHORED, MISS, SNAGGED, HOOKED, SCOOPED, PARRIED, SNAP, TRAP, STUNNED, ROOTED, DAZED, SLOWED, SHRED, GROUNDED, HEXED, INTERRUPTED, UNSTOPPABLE, INVULNERABLE, VULNERABLE, STOPPED, BONDED, BOND +N%, BOND READY, the combo labels (POUNCE, FLARE, COMBO), the Boki ability name over a Boki, ability and ultimate names on cast, perk names on pickup, RAGE, ENRAGED, RIPOSTE READY, CLOAK READY, SPEED + SHIELD, SALVAGE N, KINDLED, MENDED, HEARTH, SHATTER, RIMELOCK, NO GLIDE, KEY / N KEYS, BEACHED! and its 2/3 count, +N heal words...) | `fx.word` calls in `scripts/arch`, `scripts/combat`, `scripts/kin`, `scripts/match` | Callouts. The hit's own vfx, sound, hitstop and shake already sell it; statuses are on the HP bar's status row; heals already show as green `+N` numbers (`Hunter.heal`). `fx.word` remains for farm gains and costs only. |
| `payoff_fx` / `armed_fx` word argument, `CareUtil.payoff` (unused), `ROCK_PAY`, `OstraKit.PAY`, combos' `"label"` data | kits, `content/combos` | Only fed the words. |
| Crosshair ready words (SHIELD SLAM READY, EMPOWERED · land it to reset Vault, LIVE FOE: WIRERUN THROUGH, SMASH · aim it, ENRAGED, FLASHOVER, SWOLLEN, SALVAGE) | `ArchKit.ready_label`, `hud.gd` crosshair | The resource arc at the crosshair already goes full/bright, and the slot gets its ready dot. |
| Key letter on the recast object (the **E on Sable's dagger**, the seed, the hammer, the landing spot) with its AGAIN / WAIT label | `RecastCue._marker` | Replaced by a glow that blinks hot/white on the object in the last 0.6 s (`RecastCue._closing`). |
| "E AGAIN" / "WAIT" / "EXPIRED" text on the ability slot | `RecastCue.slot` | The slot still pulses with its timer ring (red in the last 0.6 s), dims while a press is eaten, darkens when it ran out. The slot's key cap is the only key shown. |
| RecastCue badges over foes (MARKS 3.2, DAZED, SPARKS, CHAR/ABLAZE, CHILL, FAN, SLAMMED, COMBO) | `ArchKit.combo_marks` + 7 kit overrides | Doubled the ComboMark tag for Sable/Vex/Sparkle; the rest were text badges. Statuses show on the body and on the HP bar row. |
| Seconds text beside the ComboMark tag | `ComboMark.draw` | The ring around the tag shows the time left. |
| DOWN word in the knock burst on a plate | `HudPlate._burst` | The plate itself switches to the downed look; the rays stay. |
| STAGGERED / STAGGERABLE words over monsters | `hud.gd` | A yellow ring (staggered) / pulsing purple ring (staggerable) in the same spot. |
| RELOADING / DRINKING / REPAIRING under your own bars | `hud.gd` | The filling ring beside your head stays; the weapon card still says RELOADING (ability bar, core). |
| "Perfect dodge! Next shots crit" toast, "REFLECTED" toast | `match.gd`, `verbs.gd` | Callouts; the ring, burst, slow-mo and sound stay. |

## Kept (core info)

HP / shield / armour bars and nameplates (the worst-status word on the bar, the status icon row and its seconds, the downed line);
damage and heal numbers; the ability bar with key caps, cooldowns and resource readouts; the crosshair and its
resource arc; objective and exit markers, bounty marker, zone and Blight; interaction prompts ("Hold F to loot",
these are not on ability objects); one-time teaching toasts (first combo, Bond full with its key); failure notes
("No ground to plant on"); ComboMark tags (icon, pips, time ring, no text); the payoff burst on a foe; tutorial
and drill text (`kit_drill.gd`, `tutorial.gd`).

## Alternatives not taken

- Gate `fx.word` off in fights instead of deleting the calls: smaller diff, but ~100 dead calls (AGENTS.md: no
  leftovers).
- Keep a slim timer ring on the recast object for the whole window: the slot ring already shows it, so the
  object only flashes when it is about to close.
- Keep the Boki combo badge over a set-up foe: the foe is stunned/rooted already (status row), and the loading
  tip teaches "stunned foe: shoot now".

## Checks

`--recast-cue-check` (a busy Sable fight floats numbers only; the cue carries the window; the dark slot; marks
reach ComboMark), `--hero-combo-check` (no INVULNERABLE word), `--archetype-check`, `--dancer-combo-check`,
`--hudref-check`, `--clarity-check`, `--level-vfx-check` and the kit combo checks.
Shots: `--declutter-shots --shots-dir=<dir>` (jobq --needs gpu), before/after in `/home/boki/meshy/declutter-1111/`.
