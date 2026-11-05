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
