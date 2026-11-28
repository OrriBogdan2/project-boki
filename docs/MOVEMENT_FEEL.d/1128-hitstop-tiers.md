## Hit-stop per hit tier against the source (`--impact-weight-check` section 11, 11-28)

Every LMB, RMB, E and R (ult, the code's `x` slot) hit of the 13 Hunters, measured by `--impact-weight-check`: each
Hunter presses the slot at a still dummy 3 m away (its Boki benched) and the check reads what Feel gave each of the
Hunter's hits. Columns 5-11 are rebuilt by the check every run (`tools/hitstop_tier_table.gd`); a cell that no longer
matches fails it and the check prints the row to paste (`TIERROW` lines). Builds on 1123-shake-table.md (eef629de8f2).

- **Source**: the source kit's role for the slot (docs/heroes/<id>.md): a basic attack is light, an ability's hit
  medium, a slam or an ult's hit heavy, none = no impact hit (a zone, a heal, a wall, a trail). The source data and the
  5-10 fps footage carry no hit-stop, flash or shake number (1123-shake-table.md), so the role is the only sourced
  weight. Source medium = our solid (light / solid / heavy = `content/rules/impact_weight.json`).
- **Rules**: the slot's tier in the rules. **Measured**: the tiers of the Hunter's own weighted hits on the dummy
  (T0, no stop = it hit only with ticks or slow-only touches; no hit on the dummy = the press never reached it, the
  rules tier stands).
- **Stop**: the struck body's hit-stop per tier, ms and frames at 60 fps (light 25, solid 50, heavy 90; capped at
  110 ms per 0.5 s). **Attacker**: your own freeze on that press (a melee or your own solid/heavy hit; `-` = none).
- **Flash**: the struck body's white flash (120 ms for every tier, 3 frames full then a fade; a combo payoff 153 ms).
- **Kick**: the camera kick on a struck player: the tier's `<tier>_hit` shake power and amplitude at the default
  30% slider (only heavy kicks). **Own cam**: your own camera's shake on the press: always 0 (owner rule: no
  self-shake, also none on your own dash, 1123-shake-table.md `self`/`dash` rows).
- The check also asserts: a slot the source makes heavy lands heavy (its lightest hit), and all 52 rows exist.

| Hunter | Slot | Ability | Source | Rules | Measured | Stop | Attacker | Flash | Kick (struck player) | Own cam | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Lace (archer) | LMB | bow shot (tap to Supercharged) | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | the charge stages all land light |
| Lace (archer) | RMB | Heavy Shot | medium (a charged ability shot; its wall hit is the payoff) | solid | no hit on the dummy | rules 50 ms (3.0 f) | n/a | n/a | 0 | n/a | the dummy is in the open: its wall pin (exploit) lands one tier heavier |
| Lace (archer) | E | Hail Wall | none (a rain zone: ticks and a slow) | solid | no hit on the dummy | rules 50 ms (3.0 f) | n/a | n/a | 0 | n/a | zone ticks have no stop (T0) |
| Lace (archer) | R | Starpiercer | heavy (ult) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Kael (juggernaut) | LMB | greatsword swing | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Kael (juggernaut) | RMB | Smash (Finishing Slam) | heavy (a slam) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Kael (juggernaut) | E | Warchain | medium (a hook and stun) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Kael (juggernaut) | R | Gilded Riposte | heavy (ult) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Vex (gunslinger) | LMB | rifle rounds | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Vex (gunslinger) | RMB | Coin Blast | medium (an ability shot) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Vex (gunslinger) | E | Palm Lance | medium (an ability hit) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Vex (gunslinger) | R | Cinderfall | heavy (ult) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | its burning zone after the strike ticks (no stop) |
| Albert (bulwark) | LMB | hammer throw / swing | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | a perfect-window swing is a payoff: solid (his doc's old T4 read) |
| Albert (bulwark) | RMB | Aegis | none (a shield wall) | solid | no hit on the dummy | rules 50 ms (3.0 f) | n/a | n/a | 0 | n/a | the wall deals no hit; its Crush is a utility payoff: heavy |
| Albert (bulwark) | E | Mending Ground | none (a heal) | - | no hit on the dummy | 0 | n/a | n/a | 0 | n/a | - |
| Albert (bulwark) | R | Faultline | heavy (ult, a slam) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Neve (rimewright) | LMB | ice fan | light (basic attack) | light | light+solid | 25 ms (1.5 f) / 50 ms (3.0 f) | - | 153 ms | 0 | 0.000 | her passive Splinter is a payoff: solid |
| Neve (rimewright) | RMB | Ice Spear | medium (an ability throw; the detonation is the payoff) | solid | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | the detonation lands one tier heavier |
| Neve (rimewright) | E | Rink Wall | medium (a sliding wall) | solid | T0, no stop | 0 | - | 0 | 0 | 0.000 | its touch only slows: no stop (T0, a slow-only touch) |
| Neve (rimewright) | R | Rimelock | heavy (ult) | heavy | no hit on the dummy | rules 90 ms (5.4 f) | n/a | n/a | 0.6 (0.045 m at 30%) | n/a | - |
| Cinder (ashwick) | LMB | flamethrower stream | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Cinder (ashwick) | RMB | Cinder Shot | medium (an ability shot) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Cinder (ashwick) | E | Furnace Cloak | medium (a blast round him) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Cinder (ashwick) | R | Flue Flight | none (a burning trail: ticks and a slow) | heavy | T0, no stop | 0 | - | 0 | 0 | 0.000 | the source ult deals its damage as a trail DoT: no stop (T0) |
| Tenzo (dolm) | LMB | punch / boulder | light (basic attack) | light | solid | 50 ms (3.0 f) | 50 ms (3.0 f) | 120 ms | 0 | 0.000 | the punch is an empowered hit (o.heavy): solid, heavier than the source; the boulder splash stays light |
| Tenzo (dolm) | RMB | Quakefall | heavy (a slam) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Tenzo (dolm) | E | Stone Row | medium (rocks) | - | no hit on the dummy | 0 | n/a | n/a | 0 | n/a | its rocks hit as the `rock` tag: solid |
| Tenzo (dolm) | R | Basalt Spine | none (rocks rise, a slow) | heavy | no hit on the dummy | rules 90 ms (5.4 f) | n/a | n/a | 0.6 (0.045 m at 30%) | n/a | 1 damage and a slow per rock: no stop (T0); the source Tetraform is terrain and a slow |
| Sparkle (mage) | LMB | storm bolts | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Sparkle (mage) | RMB | Storm Rod | medium (an ability throw, a stun) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Sparkle (mage) | E | Skycall | medium (a strike and pull) | solid | no hit on the dummy | rules 50 ms (3.0 f) | n/a | n/a | 0 | n/a | - |
| Sparkle (mage) | R | Kitefall | heavy (ult) | heavy | no hit on the dummy | rules 90 ms (5.4 f) | n/a | n/a | 0.6 (0.045 m at 30%) | n/a | - |
| Grimble (dredge) | LMB | scattergun volley | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Grimble (dredge) | RMB | Deep Reach | medium (a hook) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Grimble (dredge) | E | Anchor Drop | heavy (a slam, 1.1 s stun) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | fixed 11-28: was solid, the only slam not heavy (Kael's Smash, Tenzo's Quakefall, Albert's Faultline are) |
| Grimble (dredge) | R | Brass Broadside | heavy (ult) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Meeko (tender) | LMB | fox-fire bolts | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Meeko (tender) | RMB | Burrseed | medium (a root) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Meeko (tender) | E | Hearthlight | none (a heal) | - | no hit on the dummy | 0 | n/a | n/a | 0 | n/a | - |
| Meeko (tender) | R | Hearth Call | none (a heal tether) | heavy | no hit on the dummy | rules 90 ms (5.4 f) | n/a | n/a | 0.6 (0.045 m at 30%) | n/a | the rules' heavy is unused: no hit |
| Sable (thief) | LMB | crossbow bolts | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | the empowered bolt is solid (o.heavy; her doc's 0.03 s read is lighter) |
| Sable (thief) | RMB | Bola | medium (a bind) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Sable (thief) | E | Shadow Knife | medium (an ability hit) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Sable (thief) | R | Encore | heavy (ult) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Motley (ostra) | LMB | void bolts | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Motley (ostra) | RMB | Shard Snap | medium (an ability shot) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Motley (ostra) | E | Brimseed | medium (a recast blast) | solid | no hit on the dummy | rules 50 ms (3.0 f) | n/a | n/a | 0 | n/a | it waits for the recast: no hit on the press |
| Motley (ostra) | R | Nightwell | heavy (ult) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |
| Gil (gil) | LMB | tide bolts | light (basic attack) | light | light | 25 ms (1.5 f) | - | 120 ms | 0 | 0.000 | - |
| Gil (gil) | RMB | Grab Bag | medium (potions) | solid | no hit on the dummy | rules 50 ms (3.0 f) | n/a | n/a | 0 | n/a | the potions land at the cursor, past the dummy |
| Gil (gil) | E | Riptide | medium (a spin, then a spout) | solid | solid | 50 ms (3.0 f) | - | 120 ms | 0 | 0.000 | - |
| Gil (gil) | R | Tidal Wave | heavy (ult) | heavy | heavy | 90 ms (5.4 f) | 90 ms (5.4 f) | 120 ms | 0.6 (0.045 m at 30%) | 0.000 | - |

**Fixed (11-28).** Grimble's Anchor Drop (dredge E) was solid (50 ms, no kick): the only slam not heavy, while Kael's
Smash, Tenzo's Quakefall and Albert's Faultline are. Now heavy (`impact_weight.json` dredge `e`; its stun hit's own
`Feel.hitstop` call now names the E slot, so both its hits read the rule): 90 ms (5.4 f), the attacker 90 ms, kick 0.6.
Sable's bolt flash was the kit's own 0.12 s number (a section 9 stray, red on main): it now reads the light tier's
flash (the same 120 ms).

**Not changed (no clear tier miss; left for the owner).** No heavy stops less than a light and no sourced heavy lacks a
stop. Two doc reads are heavier than ours: Albert's perfect-window swing (his doc says T4, ours a solid payoff) and
Sable's empowered bolt (her doc says 0.03 s, ours solid 50 ms). Thirteen slots land no damage on the dummy, so their rules tier stands: five
are no hit by design (Lace's Hail Wall ticks, Albert's Aegis and Mending Ground, Meeko's Hearthlight and Hearth Call),
eight aim past or wait (Lace's Heavy Shot, Tenzo's Stone Row (its `rock` hits are solid) and Basalt Spine, Sparkle's
Skycall and Kitefall, Neve's Rimelock, Motley's Brimseed, Gil's Grab Bag). Alternative not taken: a per-hit sub-row for payoffs (wall pin, Crush, detonation); they are one tier up by rule.
