# INBOX for S6 (cloud session): BOKI art. ext (the coordinator) posts orders here; check every 30 min.

## 2026-11-05 06:30 UTC (ext): models + animations for every Boki species (owner: max pace)
- **Read first:**
  - `docs/BOKI_IDENTITY.md` + DECISIONS.
  - The approved starter: `ext/boki-starter` (Vespyx, ~5aaaf165), its shots in `ext/hero-shots-s2` `boki/starter/`. **Owner fix:** smaller eyes in game.
  - Species data in `content/kin_v2/`: burrlet, cairnback, cindle, hivara, pebbit, puddlet, wisplet, zapple, zephyrak.
- **Per species, one branch `ext/boki-<species>` from origin/main** (up to 4 agents in parallel, Opus):
  - A cute, readable creature model matching Vespyx's quality and style.
  - A face that emotes: happy / sad / sleepy / angry.
  - Element colours from its data.
  - **Animations:** idle, walk, run, attack, its ability, happy hop, sleep, eat, work (chop / mine / carry, item 91), get-petted.
  - Turntable + an anim GIF.
  - Then its grown/Fused forms if time allows.
- **Blender:** if Blender isn't available in this environment, try `pip install bpy --break-system-packages` (Blender as a Python module). If that fails too, say so in EXT_TO_MAIN and build in Godot instead (procedural mesh + AnimationPlayer), matching the Vespyx style.
- **Reserved files:** kin_* / merge_* / capture* / boki_hud / bot_kin are untouched. Ship new assets + a loader, and list one-line wiring for main (S5 merges it).
- **Report:** READY per species in `briefs/EXT_TO_MAIN.md`.
- **Rules:** fresh XDG, `timeout 1200`, health --strict, normal pushes, push every 30 min.

## 2026-11-05 06:40 UTC (ext): STRETCH, after the 9 existing species: NEW Boki designs
The owner wants new Boki too. Look at `ext/boki-roster50` (the planned 50-species roster: names, elements, roles) for which species aren't modelled yet.
- For the next ones on it (or new designs that fill elemental/role gaps):
  1. Make a **concept sheet** per species: front, side, back, an expression row, its grown/Fused forms if known, in the Vespyx style.
  2. Save it to `briefs/art-refs/boki/<species>_concept.png` on ext/agent-briefs.
  3. Model and animate it like the others.
  4. **Mark these "NEW: owner approval pending"** in the READY report. The owner reviews new designs before they ship to players. Original designs only (no existing creature IPs).

## 2026-11-05 12:12 UTC (ext): OWNER APPROVED the new Boki designs
Glintmole, Gloamshell, Rimeshrew, Selenfin (+ Glomwort) are approved ("look good"). Finish them like the others:
- grown/Fused forms
- the face detail pass (same issue as the Heroes: fine detail; eyes not oversized)
- wiring snippets for main
- READY reports
Then continue down the roster (`ext/boki-roster50`) with more new species. Keep going at full pace.

## 2026-11-05 16:05 UTC (ext): OWNER RULE: never stop to ask the owner a question and wait. He is often away. Make the most reasonable call, note it (with the alternative) in your READY/STATUS or EXT_TO_MAIN for review, and keep working. Only an irreversible, risky action (deleting data, force pushes, publishing outside your approved scope) waits, and then you continue with other work meanwhile.

## 2026-11-05 16:10 UTC (ext): OWNER: LOW-SPEND MODE until Fri 06:00 Toronto (the account has ~25% left; S5 + S2 get priority)
Use 1 agent at a time, Sonnet (not Opus), finish only your current in-flight branch(es), push, post READY, then wait. No new big tasks, no full-suite reruns. Full speed resumes Friday on a fresh account.

## 2026-11-05 17:00 UTC ext → S6: owner item 123 (Boki Guard zone), next once you're back from low-spend
- Guard this spot: a small (~5 m), clearly drawn zone. It never chases out past ~2 m beyond the edge, can't be baited, and walks back to the centre. guard_leash 24 m is the problem today. Full spec in OWNER_REVIEW_1103 item 123. If S5 takes it first, skip it.

## 2026-11-05 17:29 UTC ext → S6: FYI, the owner removed Boki dash riders entirely (DECISIONS.md). S5 is stripping them. Don't design new riders for the new species.

## 2026-11-05 17:58 UTC ext → all: the SUPERVIVE reference footage is on branch `ext/hero-ref-footage`
The frames behind briefs/hero-ref/*.md (5 fps JPGs; the README maps the folders to our heroes). Fetch only the folders you need (`git checkout origin/ext/hero-ref-footage -- footage/<id>`). Use them for any "like <SV hunter>" note. Don't merge that branch.

## 2026-11-06 03:22 UTC ext → S6: OWNER RULE (DECISIONS.md) + your first job on Fri: item 184b
Boki abilities must never move, swap, teleport, launch, root or steer the player. Audit all kin → docs/BOKI_AGENCY_AUDIT.md, and replace each offender with a same-theme ability that acts on foes/the world (e.g. Moon Swap → Moon Mark). Keep the identity and balance. A scripted check that the owner's position is never changed by kin.
