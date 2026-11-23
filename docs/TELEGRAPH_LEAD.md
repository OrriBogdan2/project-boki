# Telegraph lead: ground hits that land after a delay

The lead is the time from the ground telegraph appearing (an AimKit entry with `all`, drawn for every player)
to the first damage. The source figures come from the reference footage sheets (`briefs/hero-ref`). Check:
`--telegraph-lead-check` (tools/telegraph_lead_check.gd). It casts each hit on a flat strip, asserts the lead
is at least the figure in the last column, that the telegraph is up with no gap until the hit, and that a
rival's view of it is tinted toward the hostile rim colour (`Feel.RIM_ENEMY`, done by `AimDraw`).

| Hero | Hit | Lead today | Source | Verdict |
|---|---|---|---|---|
| Tenzo | Quakefall (hold) | cap 0.45 s, 0.25 s shown, then the hop 0.6 s | 1.0-1.5 s (charge) | Fixed: the circle was hidden when the hop began (it ended 0.60 s before the hit); it now stays on the landing spot to the slam, 0.83 s measured. Still under the source: owner item 61 caps the charge at 0.45 s, so the check floor is 0.8 s |
| Tenzo | Basalt Spine | 0.2 s crack | 0.2 s | Matches |
| Albert | Faultline | 0.4 s wind-up, whole lane drawn | 0.4 s | Matches |
| Sparkle | Skycall | 0.8 s, ring and arrow | 0.8 s | Matches |
| Sparkle | Eye of the Storm landing | 0.22 s marker | 0.1-0.2 s | Matches |
| Neve | Ice Spear blast | 1.8 s ring from the landing | 1.8-2.0 s | Matches |
| Meeko | Burrseed | 0.7 s from the stick | 0.6 s | Matches |
| Motley | Nightwell dome | 1.0 s | 0.8-1.0 s | Matches |
| Motley | Brimseed pop | ring from the cast; the pop is the player's recast (from 0.3 s) | recast from 0.3 s | Matches |
| Kael | Finishing Slam | 0.6 s lane | short lane at the end of the wind-up | Matches |
| Kael | Meteor Drop | 0.22 s measured from a 3 m jump (0.08 s hang + the 24 m/s drop) | marker up for the 0.85 s airtime | Shorter than the source, kept: the straight-down slam (0a97eddab) is a split-second press by design; floor 0.2 s. Its 2.4 m circle sits 0.8 m ahead, so the check stands the target 2 m off |
| Vex | Burr Charge | 0.9 s fuse | about 0.8 s | Matches |
| Vex | Nuke | 1.6 s | 1.5 s | Matches |
| Grimble | Anchor slam | 0.38 s | about 0.4 s | Matches |
| Sable | Ultimate ring | 0.4 s | 0.4 s | Matches |
| Lace | Hail Wall | 0.35 s lob | 0.35 s | Matches |
| Cinder | none | Furnace Cloak fires on the press by design (docs/heroes/ashwick.md) | | No delayed ground hit |

The healing zones (Albert's Purify, 1.0 s; Meeko's Hearthlight) are not hits and are not listed.
