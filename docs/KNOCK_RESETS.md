# Knock and kill resets

Every reset or refund a knock, a kill or a hit earns. Sources: the source data `supervive_kits.md` [D],
owner notes [O] (OWNER_REVIEW item 159, DECISIONS), the wiki [W]. Trust order: owner > data > wiki.
Proof: `--knock-reset-check` (tools/knock_reset_check.gd), plus the combo checks named below.

## Game-wide (DashReset, scripts/match/dash_reset.gd)
| Trigger | Rule | Source |
|---|---|---|
| Your blow knocks an enemy hunter | Dash back: a one-charge dash whole, a dash with charges +1 charge; long-dash cooldown cleared; heal 5% max health | [O] 159, [W] patch "multi-charge: 1 charge on Knock" |
| A teammate knocks a hunter you hit or crowd-controlled in the last 4 s (assist) | The same dash back, no heal, softer cue (`"assist"`) | [O] 159 ("assists count", ~4 s); decision 0022-knock-dash-refresh-assists |
| Your blow kills a downed hunter | The knock rule again | ours (kept from the takedown reset) |
| A third team's knock, a mob kill | Nothing | [O] 159 |

Ryzz/Sparkle keeps it although the source removed it from Joule ([O] 159: "ALL").

## Per hunter
| Hunter (source) | Trigger | Rule | Ours | Check |
|---|---|---|---|---|
| Vex (Ghost) | Knock | Combat Slide cd reset [D] | the game-wide rule (kit duplicate removed) | knock-reset |
| Vex | Knock, Spike Grenade upgrade | RMB cd reset [D] | rank 3 Burr Charge: cd and charges back on his knock | knock-reset |
| Kael (Brall) | Own knock, or minion kill | heal [D] | 20% of the foe's max health; a monster kill heals a share of its health | knock-reset |
| Kael | Knock after Execution Slam | Volcanic Rebuke cd reset [D] | knock (own or assist) within 2 s of the Finishing Slam hitting them | knock-reset |
| Kael | Rebuke kills a living enemy | Rebuke cd reset [D] | the cleave takes a hunter who was up down (our lethal hit is a knock); a downed hunter or a plain hit: no | knock-reset, juggernaut-combo |
| Cinder (Felix) | Knock | Heat Shield cd reset [D] | her own knock resets the Furnace Cloak; an assist does not | knock-reset |
| Cinder | Own knock | heal | 16% max health (wiki only, owner card) | knock-reset |
| Sable (Shiv) | Own knock | heal [D] | 15% max health; an assist heals 25% (ours, kept) | knock-reset |
| Sable | Fusillade cast | Quickflip reset [D] | the Encore gives the Vault back | knock-reset, dancer-combo |
| Sable | Empowered Arcslinger hit | Quickflip reset + mana [D] | the Primed bolt gives the Vault back (no mana) | dancer-combo |
| Sable | Farstep Dagger upgrades | 25% cd on terrain, 50% on a foe; a foe resets Quickflip [D] | rank 3 Shadow Knife, the same | dancer-combo |
| Sparkle/Ryzz (Joule) | Surge through 4 Static | Surge cd reset [D] | the Blowout gives the Wirerun back | knock-reset, sparkle-dash |
| Sparkle/Ryzz | Lightning Orb pickup | Surge reset [D] | closed by the owner | - |
| Grimble (Kingpin) | Knock or assist | +1 Feed the Beast stack [D] | +1 Salvage stack | knock-reset |
| Grimble | Air dash upgrade: shots hit | dash cd cut [D] | rank 3: a pellet hit trims 0.25 s | dredge-combo |
| Grimble | Own knock | heal | 16% max health (ours, owner card) | dredge-combo |
| Meeko (Elluna) | Air dash upgrade: wisp pickup | air dash cd refresh [D] | rank 3: picking up a teammate clears the long air dash | knock-reset |
| Lace/Hem (Myth) | Heartpiercer upgrade: wall stun | +1 dash charge [D] | rank 3, the same | archer-combo |
| Mossy (Oath) | Dash upgrade: a dash hit | Shield Bash cd refund [D] | rank 3 360 Smash refunds the Shield Charge | bulwark-combo |
| Neve (Celeste), Tarek (Tetra), Ostra (Void) | - | no reset in the data | only the game-wide rule | - |

Not built: Brall's Flame Step and Shiv's Quickflip mana refunds (we have no mana). Open for the owner:
DECISIONS "Sable: reset only on an empowered hit" read literally would also drop the Encore and knife
resets; both are in the data and stay until the owner says otherwise.
