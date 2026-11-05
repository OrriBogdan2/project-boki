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
