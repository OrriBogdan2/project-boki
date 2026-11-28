## Last-hit tell (StealTell, `tell_at`)

DECISIONS 2026-11-10 "XP follows the source": the last hit takes the kill, so the final stretch needs a readable cue,
with no new HUD element (it reuses the boss bar and the monster's body). `content/rules/steal_window.json` `tell_at`
(0.15 of max health) is the line. At or under it a lair boss or a camp chief (a prize monster, `StealReel.is_prize`):

- **Body.** Pulses a gold wash (`Ent.wash`, `StealTell.wash`, set each step by `StealReel.tick` on every machine)
  from health alone; the boss's enrage glow gives way to it. No words (owner 11-11).
- **Bar.** The fill turns the steal window's gold (world bar and top boss bar, chiefs included), and a 3 px strip along
  a lair boss's bar (lower edge) takes the colour of the squad that has dealt the most damage (`Mob.lead`, `Data.TEAM_COLORS`).
- **Net.** The leader is not in the monster snapshot: a lair boss's "bat" event ends with it (`BossNet`, Net 0.24.30), and
  the remote copy keeps it in `Mob.lead_team`. A camp chief has no "bat" event, so it gets the body pulse and the gold
  fill (both read off its health, nothing synced) but no leader strip.

Check: `--steal-tell-check` (section 5). Shots: `--combat-hud-shots`.
