# RIGFIX: rig + weapon fix pass on all 12 Hunters, then lock one shared rig standard (owner brief, 2026-11-04 20:14 UTC)

USAGE: the account is at ~83% until the Saturday 11pm reset. Be cheap. Use ONE Sonnet agent; don't run anything else in parallel. Run only the checks listed below, and don't do exploratory full-suite runs.

Read first: AGENTS.md and CLAUDE.md, then on ext/agent-briefs: briefs/DECISIONS.md and the newest MAIN_TO_EXT entries ("OWNER playtest of the 3D Hunters", "MAIN HANDOFF").

The 3D Hunter pipeline:
- scripts/heroes/warden_glb.gd (WardenGlb)
- content/rules/warden_look.json
- art/wardens/src/<hero>_fit.json and <hero>_rig.json (the RIG_CONTRACT)
- HunterAnim

Base your branch on **origin/integ91**, which has the newest models.

Repo rules:
- health --strict must pass.
- Never use --fresh or the shared save, and never pkill.
- Don't change the git remote. Never hide git errors, and no force-push.
- Never sign up for accounts.
- Wrap every godot run in `timeout 1200`.

GOAL: a RIG + WEAPON FIX PASS on all 12 Hunters, then LOCK one shared rig standard so the animation work can build on it. No new art, and no face or texture work.

1. **Audit all 12:** Vex, Kael, Hem, Breaker, Ryzz, Claire, Pip, Tarek, Dredge, Ostra, Sable, Cinder. For each, render idle, walk, run, dash, each attack/cast pose and a hit pose, at match zoom and close up. List any of these problems:
   - Bad skin weights or deformation: candy-wrapper twists, collapsing knees or elbows, limbs stretching or popping. (Tarek's legs are reported "glitchy, wonky".)
   - Feet sliding or sinking.
   - The weapon not seated in the hand: wrong angle or scale, clipping through the body, or detaching mid-move. (Breaker's weapon is reported "very off".)
   - The offhand, shield or twin weapon wrong.
   - Missing or hidden parts. (Dredge lost his limbs once.)
2. **Fix each issue at the source:**
   - Weights and joint positions: in the fit/rig files and the Blender pass.
   - Weapon placement: the sockets (weapon, weapon_offhand, weapon_muzzle, hammer_pivot) and warden_look "weapon_scale" (now in main: Kael 0.85).
   - Also see OWNER_REVIEW_1103 items 76/76b: the weapon is part of each Warden's design and should stay seated on the model, skinned to its hand or arm bones, not pinned to the old procedural Gun node.
   - Apply the DECISION that Breaker's model is 1.5x a medium hunter (the hitbox stays).
   - Keep the owner's recent tweaks: Kael body 1.06, Ostra body 0.9, Hem red.
3. **LOCK the standard:** write docs/RIG_STANDARD.md, covering:
   - the same skeleton and joint names for all 12
   - the attachment points (weapon, offhand, muzzle, shield, anchors) and how each one is placed
   - the scale rules
   - the rest/A-pose

   Any future model rebuild (the face/texture accuracy pass) MUST keep this skeleton and these sockets so animations carry over. Add a check that every Hunter matches the standard, including the weapon staying in the hand within tolerance during each anim state. Either extend --warden-model-check or add --rig-standard-check.
4. **Two checks currently fail on integ91.** Fix both as part of this:
   - --warden-model-check fails, probably from Kael's body 1.06 / Ostra's 0.9 size change.
   - --hero-combo-check fails 2 Hem "pin heavy" rows. The owner made the Heavy Shot the bow arrow, much bigger and red: HEAVY_SCALE is 6.0 and the core is hidden. Update those assertions to that spec.
5. **Checks, only these:** --import, --check, --warden-model-check, --warden-glb-check, --hero-combo-check, --hitbox-size-check, --warden-stance-check, the new rig check, health --strict, gen_wiki --check.
6. **Commit and report:**
   - End each commit message with these two lines:
     ```
     Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
     Claude-Session: https://claude.ai/code/session_01MALB68fe92fxp7EyG4cLYN
     ```
   - Push the branch as origin **rigfix**.
   - Post "READY rigfix <hash>" in briefs/EXT_TO_MAIN.md, with a before/after contact sheet per Hunter (match zoom + close-up, mid-attack) in briefs/rigfix/.

Then **STOP** for the owner's review. The animation pilot comes after.
