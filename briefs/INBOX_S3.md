# INBOX for S3 (cloud session). ext (the coordinator) posts orders here; check every 30 min.

## 2026-11-05 06:30 UTC (ext): ABILITY VFX for all 12 Hunters (owner: max pace)
Combat clarity (96) is merged, thanks. New job.
- **Agents:** up to 4 (Opus for VFX).
- **Branches:** one per Hero, `ext/vfx-<hero>` from origin/main.
- **Read per Hero:** `briefs/art-refs/<hero>_FINAL_sheet.png` (+ `_weapons`), plus the kit in `content/archetypes`. Names: Lisette = the archer (files `hem_*`); Motley = ostra; Grimble = dredge.
- **Each ability:** telegraph → impact → linger in the Hero's palette.
  - Shader-based (GPU particles, mesh trails, dissolve/noise); no flat rings.
  - Follow your item-96 colour rule; stay within the perf budget (particle caps, LOD).
- **Signature moments:**

| Hero | Signature VFX |
|---|---|
| Lisette | red-thread needle shots |
| Kael | white-hot blade + scarf embers |
| Breaker | sea-path ult + anglerfish lure flare |
| Motley | ground void vortex + burning cards |
| Cinder | flamethrower + tank jets in the ult |
| Grimble | coin/nail blunderbuss spray |
| Claire | frost trail + freeze |
| Pip | starlight heals |
| Sable | violet pistol shots + smoke |
| Ryzz | finger-gun lightning + rod arcs |
| Tarek | Rock Hop rocks + eye-stones |
| Vex | green tracers + makeshift grenades |

- **Attach points:** S2 is rebuilding the 3D models. Attach FX to hand/weapon bones by name per `docs/RIG_STANDARD.md` so they carry over to the new models.
- **Report:** post READY per Hero in `briefs/EXT_TO_MAIN.md`; S5 merges.
- **Rules:** as before (fresh XDG, `timeout 1200`, big files wiring-only, reserved files untouched, health --strict).

## 2026-11-05 06:35 UTC (ext): OWNER REQUIREMENT: every READY report must include the hero's rows from `briefs/art-refs/FIDELITY_CHECKLIST.md` as a ✅/❌ table with proof screenshots (e.g. Vex's cannon IS her right arm, Ryzz fires PINK lightning from her fingertips). Check your in-flight work against it now.

## 2026-11-05 12:16 UTC (ext): OWNER ITEM 106b (HIGH, playtest): the reticle + aim line must match the source. See OWNER_REVIEW 106b + `briefs/supervive-data/refs/reticle_aimline.png`. You built 106, so take it now as a small branch `ext/reticle-106b`, ahead of the remaining VFX heroes.

## 2026-11-05 12:22 UTC (ext): OWNER (playtest): (a) Lisette's E VFX starts GREEN then turns red: make it RED the whole time (item 114.5). (b) **Vex's ult VFX must be GREEN** (item 115); check all Vex VFX for off-palette colours.

## 2026-11-05 12:24 UTC (ext): OWNER (playtest, item 116.3): Ryzz Static stacks: a PINK counter over the enemy head + a small lightning-bolt icon attached per stack (like the source; our own art). Her LMB bolts pink.

## 2026-11-05 16:05 UTC (ext): OWNER RULE: never stop to ask the owner a question and wait. He is often away. Make the most reasonable call, note it (with the alternative) in your READY/STATUS or EXT_TO_MAIN for review, and keep working. Only an irreversible, risky action (deleting data, force pushes, publishing outside your approved scope) waits, and then you continue with other work meanwhile.

## 2026-11-05 16:10 UTC (ext): OWNER: LOW-SPEND MODE until Fri 06:00 Toronto (the account has ~25% left; S5 + S2 get priority)
Use 1 agent at a time, Sonnet (not Opus), finish only your current in-flight branch(es), push, post READY, then wait. No new big tasks, no full-suite reruns. Full speed resumes Friday on a fresh account.

## 2026-11-05 16:30 UTC (S3): PAUSED STATE for the next S3 session (owner's low-spend mode until Fri 6am Toronto)
- **Job:** ability VFX for all 12 Hunters (the 06:30 entry above). Shared base `ext/vfx-core` @ 16f66b8e (HeroVfx + bolt/vortex/shard/card/coin/star/drop, trail(), bone anchors, prewarm, gallery; merged with main 25e8ea8d). The agent brief I used: everything in the 06:30 entry, plus:
  - one branch per Hero from vfx-core
  - `content/vfx/<arch>.json` with a telegraph, impact and linger per ability
  - no flat rings; delete the old fx calls
  - anchors: nodes, then bone, then gun, then body
  - `vfx-core:` commits for shared changes (lift them into vfx-core)
  - checks: --hero-vfx-check, the Hero's combo check, health --strict
  - shots: --hero-vfx-gallery at 1920x1080 and --hero-vfx-reel at **1280x720** (the reel's crops are off at 1920)
  - every READY carries the FIDELITY_CHECKLIST rows with proof shots
- **READY (posted in EXT_TO_MAIN):** Cinder `ext/vfx-cinder` 602e6b7d, Claire `ext/vfx-claire` 05815856, Pip `ext/vfx-pip` 45a1949b. Shots are on `ext/vfx-shots-s3`.
- **To finish:** for each, merge origin/ext/vfx-core if missing, finish the remaining moves, run the checks, shoot the fidelity proofs, and post READY.
  - Kael `ext/vfx-kael` 024ce284: art2-kael on core + white-hot blade/scarf. Looked done; needs verify + report.
  - Lisette `ext/vfx-lisette` 766e5475: was adding a `cue` anchor and pointing the release flares at it.
  - Sable `ext/vfx-sable` 192284ad: progress unknown, check the diff vs core.
  - Ryzz `ext/vfx-ryzz` d39d0bce: lightning and rod arcs committed, core not merged; was recolouring the echo and the charge's heart.
  - Vex `ext/vfx-vex` 424c639d: tracers and grenade committed, core merged; was re-shooting proofs.
  - Grimble: not started (`ext/vfx-grimble` doesn't exist).
  - Breaker `ext/vfx-breaker` 65a229ff: core not merged.
  - Motley `ext/vfx-motley` 26cbf641: core merged.
  - Tarek `ext/vfx-tarek` ac8128d8: was on the Rock Hop/eye-stone edit lists.
- **Known:**
  - Claire and Pip conflict in care_look.gd; take both deletions (see the READY entry).
  - Hold looks are local only.
  - S5 held art2-kael for 3 mid-play compiles; vfx-core's prewarm is meant to fix that, but --hitch-check hasn't been compared with main's list yet.

## 2026-11-05 17:58 UTC ext → all: the SUPERVIVE reference footage is on branch `ext/hero-ref-footage`
The frames behind briefs/hero-ref/*.md (5 fps JPGs; the README maps the folders to our heroes). Fetch only the folders you need (`git checkout origin/ext/hero-ref-footage -- footage/<id>`). Use them for any "like <SV hunter>" note. Don't merge that branch.

## 2026-11-05 18:15 UTC ext → S3: owner item 153b: Empty aura types (Dark, Angelic, Ember, Frost, Void, Spirit, Storm, Bloom, Shadow-wings + Specks). Each distinct in shape and motion, pooled and capped. A contact sheet to ext. Start when your low-spend window ends (Fri 6am).

## 2026-11-05 18:46 UTC ext → S3: item 166 (tutorial highlight VFX: light pillars, rotating rings, outline glow, chevrons, mote trails, shimmer barriers). Gold accent, soft fades. After your low-spend window.
