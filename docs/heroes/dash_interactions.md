# Dash and ability interactions (Vireo and Venator)

Table source: `content/rules/dash_interactions.json`, read by `DashRules` (`scripts/arch/dash_rules.gd`). An attack tapped
while the dash blocks it is held and goes off when the dash ends, inside a 0.15 s window; it is never dropped.
fires = works during the dash; buffers = waits for the dash to end; cancels = ends the dash or the ability.

| Hero | Pair | Source | Ours |
|---|---|---|---|
| Vireo (Wirerun) | dash then LMB, ground and air | no lock listed; the dash is invulnerable | buffers: a bolt tapped inside goes off at the end |
| Vireo | dash then RMB / E / X | no lock listed | fires: E and the spear start mid-dash |
| Vireo | dash then dash | charge spent on the press | buffers (0.18 s, existing) |
| Vireo | E / X then dash | no lock listed | fires |
| Vireo | RMB hold then dash | the spear hold ends | cancels the hold |
| Venator (Slipstep) | ground dash then LMB | the rifle keeps firing through the skid | fires |
| Venator | air dash then LMB | no air slide in the footage | buffers |
| Venator | dash then RMB / E / X | no lock listed | fires: Longneedle starts mid-slide |
| Venator | RMB / E / X then dash | no lock listed | fires |

Checked in `--mage-combo-check` and `--gunslinger-combo-check` ("dash table" lines).
