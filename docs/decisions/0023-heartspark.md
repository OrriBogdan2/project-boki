# 0023 - The Heartspark loop (prototype)

Status: prototype on `ext/heartspark`. Owner decision of 2026-11-08: every expedition is a fight over the Heart.
Heart Night (the later all-night variant) is deliberately **not** built.

## The loop
Each match picks a Heart site (one of the three biggest islands, seeded) and a Heart Gate about 24 m away.
State machine in `scripts/match/heart.gd`: `charging -> ready -> carried -> cooling -> charging`.

1. **Tide.** From 15 s the Blight's tide ring closes on the Heart (130 m -> 34 m over 240 s). Outside it the Blight is
   stronger (`BlightDir.level`/`level_here`) and Skitters come sooner (`_spawn_tick` heat). There was no closing zone
   before, so this is the "Blight closes toward the Heart". A Hunter standing outside it also takes the source's
   death-circle damage (`Heart.tide_dmg`, parity 2026-11-09): the close is split into the source's 11 stages (0-10,
   ~22 s each, the last holding once closed), each a flat hit every 1 s of 3/6/50/100/.../450 source health scaled by
   our medium health over theirs (145/1290), so a stage kills as fast as there (medium: 430 s, 215 s, 26 s ... 3 s).
2. **Charge.** 75 s, visible to everyone: map marker with a charge ring, world beam, waypoint.
3. **Take it.** Hold interact (F) 1.5 s within 2.2 m. The carrier is slowed 15% (`heart_slow` meta, read in
   `Hunter._chase_mod`) and revealed on every map. Down or death drops it where they fell.
4. **Heart Gate.** Lights only while carried and accepts only the carrier (hold 2.5 s).
5. **Reward** (`Heart.pay`, `Heart.settle`): a rare egg, the four evolution foods x2, heartwood + starstone, 60 gems,
   and bond/trust on the carrier's Boki. All of it is in `content/rules/heart.json`.
6. **Cooldown.** 90 s, then a new Heartspark charges.
7. Skiff / hatch / uplink extraction is unchanged. A carrier who leaves that way leaves the spark behind, no reward.

## Net
Host-authoritative `["ht", ...]`: `s` (state snapshot, every 3 s and on change), `pick`, `drop`, `done`.
Clients only predict timers. `Net.VERSION` 0.25.0.

## The edge in the world and on the maps (ext/blight-edge-read)
The tide ring is also a wall in the world (`scripts/match/blight_wall.gd`, `shaders/blight_wall.gdshader`): one
open cylinder on `Heart.tide_r`, unshaded and alpha-only, so the Low preset pays for a flat ring and nothing
more; presets with `fx` above 0.5 get drifting bands and a patch of embers on the wall nearest the player
(`EMBERS` 150 x `fx`, CPU particles, one emitter). Out past the ring the HUD tints the screen, says so with the
damage per second, and pulses the edges red on every tide hit (reduced by "Reduce flashes"). The maps draw the
ring now (solid) and the ring it closes to next (dashed; before the tide starts, the first ring, so the drop
map shows it). The steep play camera sees only the nearest ground, so the wall is seen near, and from
60 m only from a low camera; the maps are how it reads at range. `--blight-edge-shots` takes the sheets.
There is no "very low" preset (Low, Medium, High, Ultra), so Low is the cheap path.

## Alternatives not taken
- Block the carrier from normal exits (kept exits unchanged instead; the spark drops).
- The tide without damage (the prototype's first cut; parity with the source's death circle added it).
- The source's raw values against our ~9x smaller health (stage 2 would kill in 3 s instead of 26 s).

## Known gaps
Bots ignore the Heart. Online path is implemented but untested with real peers. `--heart-demo[=ready|carry|gate|cool|charging]`
and `--heart-check` cover the offline loop.
