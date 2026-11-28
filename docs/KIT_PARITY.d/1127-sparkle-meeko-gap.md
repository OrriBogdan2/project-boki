## Sparkle charge guard and Meeko carry shield (2026-11-27, branch ext/parity-sparkle-meeko-1127)

The four catalog gaps (Sparkle dash immunity, Motley Snap burst, Meeko carry shield, Sable knock heal). Two were already built and are now stated with their checks; two changed.

| Item | Was | Now | Reason |
|---|---|---|---|
| Sparkle Wirerun charge | only the streak let shots through; the charge hold took every hit in full | the charge also lets shots pass through her, and any other hit lands at `guard` 0.5 of its damage and knock; a stun still cuts the charge | the reference's dash ignores projectiles for its whole run, melee and crowd control still land; the 0.5 figure is an estimate (the source gives none) |
| Meeko carry shield | none (cut 2026-11-07 as an ours-only rider) | a pickup gives a shield of 24 (grows 6% a level, refilled by each pickup); a hit that breaks it, or a stun, drops them, stuns her 1 s on the break and locks pickup 4 s; a root, slow, knock-back, heal or a hit the shield soaks holds them | the catalog shows the reference has it, so it was never ours-only; 200 on the reference's 1285 health is about 0.12 of ours (24); the 1 s break stun is an estimate |
| Motley Snap burst | already built: rank 3 gives +11% speed on the cast and +22% on a hit for 2 s | same | the reference's tier IV burst; stays rank 3 gated; asserted by `--ostra-combo-check` "data rank 3" rows |
| Sable knock heal | already built: a knock heals her `heal_knock`, an assist `heal_assist` | same | asserted by `--knock-reset-check` ("sable: her knock heals her") |

Not changed, still open: the reference carries up to 2 and ours carries up to 2 with the same pickup, but the 0.7x carry slow stays out (data pass); Sparkle's guard also applies to the Wirerun streak only through its existing phase, no extra reduction there.

Checks: `--tender-combo-check` 162/162 (Carrier rows in `tools/support_check.gd`, "mm carry" rows in `tools/care_carry_check.gd`); `--archetype-check` two new "vireo Wirerun charge" rows; the other `--archetype-check` and `--mage-combo-check` fails are the same as main (clip-dependent rows, run without clips).
