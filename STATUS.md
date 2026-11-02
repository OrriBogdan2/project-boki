2026-11-02T20:08:04Z

ext/classes | cacd796 | REOPENED per INBOX 19:10 (Hunters wording, pick 1 + 2 early unlocks, no weight labels, hunter viewer, hold-to-unlock); rework queued on Opus medium | 0.14.0 | -
ext/hero-shots | 3bd0520 | done: 12 heroes + farm building + classes; all portraits show signature weapons | - | -
ext/kits2-nor | 4b1214b | ready to merge (on sync62 4f82978; main now 18fab56) | 0.15.0 (kit move id on hunter snapshot idx 31) | full suite 0 failures except --teammate-check 1 ("steps between you and a rival", dot -nan), identical on plain main 4f82978; simtest seed-5 known wipe. Note: no class R left on any hero now.
ext/farmbuild | efa72a7 | ready to merge (on sync62 4f82978; main has moved on) | 0.14.0 (no new sync) | full suite + farmbuild/farm-start/work/incubator 0 failures; simtest seed-5 known wipe. Merge note: docs/decisions/0004-farm-building.md collides with main's 0004-merge-augments.md, renumber one; main.gd at 4098/4100.
ext/aimkit | 577412e | ready to merge (on main 18fab56); kit branches build on it | 0.15.0 (main's; no new sync, telegraphs local-only) | full suite 0 failures, --aimkit-check 55 checks, simtest extracted. Shots in ext/hero-shots aimkit/. Owner Qs: should foes online see "all" telegraphs (needs Net)? telegraph brightness OK?
ext/kitfix-dancer-juggernaut, ext/kitfix-pin-bjorn | - | running (Opus, from ext/aimkit 6dcdc22) | pending | pending
ext/kitfix-vireo-venator | - | running (Opus) | pending | pending
ext/kitfix-linwick-dredge | - | running (Opus) | pending | pending
ext/kitfix-moosh-tamsin | 6bd7d71 | READY FOR LOCAL SCREENSHOT REVIEW (aimkit 577412e + main 9700dec) | 0.15.0 (no new sync) | full suite 0 failures; tender combo 37, rimewright combo 29, support 66, aimkit 55; simtest ran to end. Shots: ext/hero-shots moosh-moosh/v2, tamsin/v2 (+anim, before/after). Gaps left: Kindle damage-number tint (shared code), Tamsin rank-3 ice bridge (no terrain editing). Tamsin squad shield removed per owner. Owner Qs: Burrseed area sticks to foe or ground? footage 0.7s/1.6x vs wiki 2s/2x OK? Spear 2 charges/7s + 0.5s freeze? Rink Wall stop at cursor or fixed distance?
ext/kitfix-breah-ostra | - | running (Opus) | pending | pending

Running now: kitfix-dancer-juggernaut, kitfix-pin-bjorn, kitfix-vireo-venator, kitfix-linwick-dredge, kitfix-breah-ostra (all Opus)
Queued: ext/classes rework (Opus), when a slot frees
Last INBOX entry handled: 2026-11-02 19:15 UTC (19:10 owner answers, 19:12 Zedran and 19:15 small-mechanics section relayed to all 5 running kitfix agents and added to the queued breah-ostra prompt; ext/classes reopened)
Watcher: received 19:06 UTC entry
Questions for the owner: see ext/classes line.
Net note: main is now 0.15.0, which kits2-nor also uses (0.15.0, kit move id on the snapshot); main session to reconcile. Kitfix branches that need a bump use 0.15.2 (dancer-juggernaut), .3 (pin-bjorn), .4 (vireo-venator), .5 (linwick-dredge), .6 (moosh-tamsin), .7 (breah-ostra).

Hold state for MergeKit.drop_class_holds:
- tender: seed_aim, rmb_down (carry is set down by existing logic)
- rimewright: rinkrun, spear_aim, rmb_down, wall_cast
