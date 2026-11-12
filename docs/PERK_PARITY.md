# Perk orbs vs the source's perks

Every perk a perk orb can carry (`content/rules/perk_orbs.json` kinds), next to the source's closest
perk. Source: supervive.wiki.gg raw wikitext of the Perks page and each perk page, read 2026-11-10
(briefs/supervive-data has no perk list; docs/SUPERVIVE_DATA.md confirms the 5 perk slots). The
source holds up to 5 perks; its pages say nothing about holding two of the same, so our stack
limits are kept and flagged. Scales: source health is about 7.2x ours (briefs/UTILITY_PARITY.md),
and its run speed is 700 (docs/SUPERVIVE_DATA.md), so +6.7 Movement Speed is +0.96%. Ability or Dash
Haste of x% means x% more recharge rate (our `cdr` is a rate bonus; our `dodge` cuts the recharge
time, so 5% haste is 1 - 1/1.05 = 0.0476).

`--perk-orb-check` reads the Data column of this table and fails if `Data.PERKS` differs, if the
Text column is not the perk's text word for word, or if an orb perk has no row. Data keys are paths
into the perk's entry (`stats.speed`, `hp`, `max`).

Status: **source** = set to the source; **source, number unknown** = the source's effect, but its
page gives no number (an "X%"), so ours is kept; **ours** = no source perk does this (kept, flagged
to the owner).

| Orb | Source perk | Source effect | Text | Data | Status |
|---|---|---|---|---|---|
| `fleet` | Amplified Speed (Uncommon) | Gain 6.7 Movement Speed | 1% faster on foot. | stats.speed=0.0096, max=2 | source |
| `focus` | Amplified Haste (Uncommon) | Grants 5% Ability Haste | Abilities recharge 5% faster. | stats.cdr=0.05, max=2 | source |
| `toughskin` | Fortitude (Uncommon) | Grants 60 Health (60 / 7.2 = 8) | +8 max health, healed right away. | hp=8, max=3 | source |
| `secondwind` | Swiftness (Uncommon) | +5% Bonus Dash Haste (no source perk adds a dash charge) | Dashes recharge 5% faster. | stats.dodge=0.0476, max=1 | source |
| `remedy` | Heal Receptor (Uncommon) | Healing applied to you is 10% more effective | Heals on you are 10% stronger. | stats.heal_in=0.1, max=1 | source |
| `spyglass` | Farsight (Uncommon) | You see X% farther while sneaking | See 12% further while sneaking. | stats.sneak_sight=0.12, max=1 | source, number unknown |
| `featherfall` | Glider Coolant (Uncommon) | Grants X% additional Glider Heat Capacity | Your glider holds 60% more heat. | stats.heat=0.6, max=1 | source, number unknown |
| `tailwind` | Glider Booster (Uncommon) | listed on the Perks page, no page of its own | Glide 15% faster. | stats.glide_speed=0.15, max=1 | source, number unknown |
| `keen` | none (Devastation, Exotic: +15% LMB damage, is weapon only) | | 8% more damage. | stats.dmg=0.08, max=3 | ours |
| `plating` | none (armor is its own slot; Second Skin gives a 200 HP shield when armor breaks) | | +20 max armor. | stats.armor=20, max=2 | ours |
| `quickhands` | none | | Reload 30% faster. | max=1 | ours |
| `tinker_roll` | none (same effect as Quick Hands) | | Reload 15% faster. | stats.reload=0.15, max=1 | ours |
| `scavenger` | none (Prisma Collector and Living Gold make currency over time) | | Gems you pick up are worth 25% more. | max=2 | ours |
| `magpie` | none (same effect as Scavenger) | | Gems you pick up are worth 25% more. | stats.gems=0.25, max=1 | ours |
| `field_kit` | none (Heal Receptor is Remedy's match) | | Tonics heal 35% more. | stats.tonic=0.35, max=1 | ours |
| `overcharge` | none (Boki bond) | | Your bond ultimate charges 30% faster. | max=1 | ours |
| `satchel` | none (owner kept it, 2026-11-02) | | One more backpack slot. | stats.pack=1, max=2 | ours |
| `hotload` | none as a perk (the source upgrades weapons by tier) | | Your weapon hits 10% harder. | wup.dmg=0.1, max=4 | ours |
| `deepmag` | none as a perk | | 20% more rounds before a reload. | wup.mag=0.2, max=3 | ours |
| `quickfeed` | none as a perk | | Your weapon fires 7% faster. | wup.rate=-0.07, max=3 | ours |
| `longreach` | none as a perk | | 12% more range, or reach for blades. | wup.range=0.12, max=2 | ours |
| `brand_fire` | nearest: Combustion (Exotic): any damage burns 60 over 2s (8 over 2s here) | | Your hits burn: 5 damage a second for 3s. | wup.brand=fire, max=1 | ours |
| `brand_frost` | none | | Your hits slow 35% for 1s, and every 5th roots for 0.6s. | wup.brand=frost, max=1 | ours |
| `brand_storm` | none | | Every 4th hit arcs to 2 more foes for half damage. | wup.brand=storm, max=1 | ours |
| `brand_venom` | none | | Your hits poison for 3 damage a second for 3s and slow 35% for 0.35s. | wup.brand=venom, max=1 | ours |
| `brand_void` | nearest: Amplified Omnivamp (Uncommon): 2.7% omnivamp on all damage | | Your hits heal you for 8% of the damage. | wup.brand=void, max=1 | ours |

Dash and movement: the only orbs that touch them are Fleet Foot (+0.96% run speed per stack, the
source's Amplified Speed), Second Wind (+5% dash recharge, the source's Swiftness; it no longer adds
a dash charge), and the glider pair Featherfall and Tailwind (the source's Glider Coolant and
Glider Booster). Remedy now covers every heal you receive, as Heal Receptor does; the per-second
regen out of combat is not a heal event and is not boosted.
