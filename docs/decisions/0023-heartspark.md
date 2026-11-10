# 0023 - The Heartspark loop (prototype)

Status: prototype on `ext/heartspark`. Owner decision of 2026-11-08: every expedition is a fight over the Heart.
Heart Night (the later all-night variant) is deliberately **not** built.

## The loop
Each match picks a Heart site (one of the three biggest islands, seeded) and a Heart Gate about 24 m away.
State machine in `scripts/match/heart.gd`: `charging -> ready -> carried -> cooling -> charging`.

1. **Tide.** From 15 s the Blight's tide ring closes on the Heart (130 m -> 34 m over 240 s). Outside it the Blight is
   stronger (`BlightDir.level`/`level_here`) and Skitters come sooner (`_spawn_tick` heat). There was no closing zone
   before, so this is the "Blight closes toward the Heart".
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

## Alternatives not taken
- Block the carrier from normal exits (kept exits unchanged instead; the spark drops).
- A hard-damage closing zone (the tide only buffs the Blight; no new damage rule).

## Known gaps
Bots ignore the Heart. Online path is implemented but untested with real peers. `--heart-demo[=ready|carry|gate|cool|charging]`
and `--heart-check` cover the offline loop.
