## Vex Daze team and coin wall stun (2026-11-27, branch ext/vex-kit-parity-1127)

Second-pass parity on the reference catalog's three Vex gaps. The rifle was already there; the Daze payoff and the coin's wall stun moved.

| Item | Was | Now | Reason |
|---|---|---|---|
| Rifle front-load | 8 a round, a string loses a fifth over 10 rounds, a 0.35 s rest starts it over; 30-round drum refills 40/s after 0.35 s (dry to full about 1.1 s) | same (owner 11-24 numbers kept; the reference loses half) | already the reference's burst-and-release shape; now asserted (`--vex-daze-check`) |
| Daze payoff | rifle +76%, Palm Lance +20% | also Coin Blast (direct hit and cone, on a foe already Dazed) and Cinderfall's impact +20% (`rattle_k` 0.2 in `rmb.burr` and `x`) | reference: one Daze boosts several abilities |
| Coin Blast wall slam | stun 0.7 s, Daze +0.6 s | stun 1.2 s, Daze +0.6 s | the reference's wall stun for its grenade cone |
| Slipstep | 1 charge | 1 charge | owner ruling (dash = 1 charge) |

Not changed, still open: Coin Blast cone hit refunds no cooldown (the reference's does; `--gunslinger-combo-check` asserts none); Cinderfall burn ticks get no Daze bonus (impact only); cooldowns stay the owner rows (RMB 6.5, X 42).

Checks: `--vex-daze-check` 9/9; `--gunslinger-combo-check` 150 pass, the same 5 known fails as main (see `1126-vex-recheck.md`); `--archetype-check --ak-only=gunslinger` 13/13; `--wall-stun-check` 95/95.
