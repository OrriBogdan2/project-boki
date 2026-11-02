2026-11-02T19:20:12Z

ext/classes | cacd796 | REOPENED per INBOX 19:10 (Hunters wording, pick 1 + 2 early unlocks, no weight labels, hunter viewer, hold-to-unlock); rework queued on Opus medium | 0.14.0 | -
ext/hero-shots | 3bd0520 | done: 12 heroes + farm building + classes; all portraits show signature weapons | - | -
ext/kits2-nor | 4b1214b | ready to merge (on sync62 4f82978; main now 18fab56) | 0.15.0 (kit move id on hunter snapshot idx 31) | full suite 0 failures except --teammate-check 1 ("steps between you and a rival", dot -nan), identical on plain main 4f82978; simtest seed-5 known wipe. Note: no class R left on any hero now.
ext/farmbuild | efa72a7 | ready to merge (on sync62 4f82978; main has moved on) | 0.14.0 (no new sync) | full suite + farmbuild/farm-start/work/incubator 0 failures; simtest seed-5 known wipe. Merge note: docs/decisions/0004-farm-building.md collides with main's 0004-merge-augments.md, renumber one; main.gd at 4098/4100.
ext/aimkit | 577412e | ready to merge (on main 18fab56); kit branches build on it | 0.15.0 (main's; no new sync, telegraphs local-only) | full suite 0 failures, --aimkit-check 55 checks, simtest extracted. Shots in ext/hero-shots aimkit/. Owner Qs: should foes online see "all" telegraphs (needs Net)? telegraph brightness OK?
ext/kitfix-dancer-juggernaut, ext/kitfix-pin-bjorn | - | running (Opus, from ext/aimkit 6dcdc22) | pending | pending
ext/kitfix-vireo-venator | - | running (Opus) | pending | pending
ext/kitfix-linwick-dredge | - | running (Opus) | pending | pending
ext/kitfix-moosh-tamsin | - | running (Opus) | pending | pending
ext/kitfix-breah-ostra | - | queued (starts when a slot frees) | - | -

Running now: kitfix-dancer-juggernaut, kitfix-pin-bjorn, kitfix-vireo-venator, kitfix-linwick-dredge, kitfix-moosh-tamsin (all Opus)
Queued: kitfix-breah-ostra, then ext/classes rework (Opus); both start as slots free (cap 5, five kit agents running)
Last INBOX entry handled: 2026-11-02 19:15 UTC (19:10 owner answers, 19:12 Zedran and 19:15 small-mechanics section relayed to all 5 running kitfix agents and added to the queued breah-ostra prompt; ext/classes reopened)
Watcher: received 19:06 UTC entry
Questions for the owner: see ext/classes line.
Net note: main is now 0.15.0, which kits2-nor also uses (0.15.0, kit move id on the snapshot); main session to reconcile. Kitfix branches that need a bump use 0.15.2 (dancer-juggernaut), .3 (pin-bjorn), .4 (vireo-venator), .5 (linwick-dredge), .6 (moosh-tamsin), .7 (breah-ostra).
