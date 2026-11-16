# Combat numbers: our targets

The combat values Project Boki ships and the target each is tuned to. Per-hero numbers live in `content/archetypes/*.json`,
rules in `content/rules/`; this page is the short list of what we aim for. Checks: `--ttk-check` (time to knock,
[TTK.md](TTK.md)), `--kit-parity-check` ([KIT_PARITY.md](KIT_PARITY.md)).

- **Time to knock:** every hunter's LMB-only and full-combo time to knock a full-health, full-armour target lands inside the bar in TTK.md (0.8 to 1.25 of the target time) unless the owner set an override.
- **Health and armour:** mean health 154 (the 12 hunters), armour 339 at 2.2x, 20% damage reduction from armour. Health is the limit, so the 20% is what counts.
- **Down and revive:** at 0 health you become a wisp: you crawl, cannot be shot, and bleed out in 15 s. A teammate standing on you brings you back (DEATH_AND_REVIVE.md).
- **Gliders:** a hit on a glider deals double damage and knocks it out of the air; spiking an overheated or sunk glider stuns it (0.7 s over ground).
- **Casts:** windups 0.1 to 0.65 s (median 0.45), charge to full 0.5 to 1.25 s (median 1.0); more in DASHES_AND_ABILITY_FEEL.md.
- **Class baselines:** Kinfall's own light, medium and heavy numbers (KINFALL_CLASSES.md); retune the data files, not code.
- **Aim line:** the aim laser is 8.5 m long.
- **Dash cooldowns:** per kit in the archetype JSON; a held dash is longer on a longer cooldown (`dash_hold_for_ex`).
