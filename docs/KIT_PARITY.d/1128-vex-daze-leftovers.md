## Vex Daze leftovers: neither gap has a source row (2026-11-28, branch ext/vex-daze-leftovers)

The two items `1127-vex-daze.md` left open were read against the reference kit data (private reports repo, `sv/briefs/kits.md`, `kit_comparison.md`, `hero-ref/venator.md`, `specs/kit-audit/vex_vireo_sable.md`). Neither is a source row, so nothing was built.

| Item | Source says | Decision |
|---|---|---|
| Coin Blast cone hit refunds cooldown | Grenade card: 9 s, "Upg: -1.5s x2 / CD resets on knock". No refund on a cone or wall hit. `kit_comparison.md` item 4 lists "a wall stun cuts the grenade cooldown 40%" as invented, and the owner data pass cut it | left as is: the cone hit refunds nothing (rank 3 still resets on a knock). `--gunslinger-combo-check` keeps `the cooldown is not shaved` |
| Cinderfall burn ticks get the Daze bonus | Daze: "extra dmg from Rifle (LMB) and Railgun (E)" only; the fire zone is "59 dmg/s + Slow" with no Daze rider | left as is: impact only (the 11-27 +20% on the impact and Coin Blast is already beyond the card; not reverted here) |

The `1127-vex-daze.md` line "Not changed, still open" is closed by this note: both are source-silent, not gaps. No code, data or check changed. Cooldown rows untouched (RMB 6.5, X 42).
