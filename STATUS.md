2026-11-02T18:39:16Z

ext/classes | cacd796 | ready to merge (on sync62 4f82978) | 0.14.0 (no new sync; save v5->v6 adds "classes", old saves stay all-unlocked) | full suite 0 failures, --class-unlock-check 81 checks; --farm-start-check flaky on main too; simtest seed-5 known wipe. Starters default Thief/Gunslinger/Juggernaut (data). Display names come from hero data; the SERVER_UPDATE5 renames land in the kitfix branches. Owner questions: starter set, goal/XP numbers, "Weight" as the Light/Medium/Heavy term, rename the "Hero" hub to "Class"?
ext/hero-shots | 3bd0520 | done: 12 heroes + farm building + classes; all portraits show signature weapons | - | -
ext/kits2-nor | 4b1214b | ready to merge (on sync62 4f82978; main now 18fab56) | 0.15.0 (kit move id on hunter snapshot idx 31) | full suite 0 failures except --teammate-check 1 ("steps between you and a rival", dot -nan), identical on plain main 4f82978; simtest seed-5 known wipe. Note: no class R left on any hero now.
ext/farmbuild | b7537bd (sync62 merge local, 53955ae) | running: 15 of 20 checks green, farm checks + simtest pending, then push | main's 0.14.0 | 15/15 so far 0 failures
ext/aimkit | 6dcdc22 | running: API pushed, final suite in progress | pending | pending
ext/kitfix-dancer-juggernaut, ext/kitfix-pin-bjorn | - | running (Opus, from ext/aimkit 6dcdc22) | pending | pending
ext/kitfix-vireo-venator | - | running (Opus) | pending | pending
ext/kitfix--linwick-dredge, -moosh-tamsin, -breah-ostra | - | queued (worktrees and prompts ready; start as slots free, cap 5) | - | -

Running now: ext/aimkit (final suite), farmbuild re-merge, kitfix-dancer-juggernaut, kitfix-pin-bjorn, kitfix-vireo-venator
Queued: kitfix-linwick-dredge, kitfix-moosh-tamsin, kitfix-breah-ostra
Last INBOX entry handled: 2026-11-02 18:25 UTC
Questions for the owner: see ext/classes line.
