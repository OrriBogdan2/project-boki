# INBOX for S7 (cloud session): FARM + STORY gameplay items. ext (the coordinator) posts orders here; check every 30 min.

## 2026-11-05 06:30 UTC (ext): owner items 77-93 (+107 if S2 hasn't shipped it)
- **Read:** `briefs/OWNER_REVIEW_1103.md` items 77-93 (later items override earlier ones) + DECISIONS. Skip 78 (marked LATER), 85 (done) and 88 if already fixed on main.
- **Highlights:**

| Item | Work |
|---|---|
| 79/79b | Empty: void head, shroud body |
| 80 | "Motes" → "Aura" |
| 81 | Empty feet clip |
| 82 | new-Boki screen hoverable moves |
| 83 | epic Mask moment |
| 84 | shared dash UI with pips |
| 86 | outposts as structures |
| 87 | Hob offers the 2nd Mask |
| 88 | Mask-screen lag |
| 89 | Hob as a real vendor at the stall + camera intro |
| 90 | hold-to-build, Boki help |
| 91 | tools + chop/mine animations, weapon holstered |
| 92 | farm wording + the Boki page from anywhere |
| 93 | Trial Expedition |

- **Branches:** one per item group, from origin/main; up to 4 agents (Opus for 83/89/93, Sonnet otherwise).
- **Report:** READY in `briefs/EXT_TO_MAIN.md` with checks + screenshots.
- **Rules:** big files wiring-only, reserved files untouched, fresh XDG, `timeout 1200`, health --strict, normal pushes every 30 min.

## 2026-11-05 16:05 UTC (ext): OWNER RULE: never stop to ask the owner a question and wait. He is often away. Make the most reasonable call, note it (with the alternative) in your READY/STATUS or EXT_TO_MAIN for review, and keep working. Only an irreversible, risky action (deleting data, force pushes, publishing outside your approved scope) waits, and then you continue with other work meanwhile.

## 2026-11-05 16:10 UTC (ext): OWNER: LOW-SPEND MODE until Fri 06:00 Toronto (the account has ~25% left; S5 + S2 get priority)
Use 1 agent at a time, Sonnet (not Opus), finish only your current in-flight branch(es), push, post READY, then wait. No new big tasks, no full-suite reruns. Full speed resumes Friday on a fresh account.

## 2026-11-05 16:40 UTC (S7, handoff): low-spend mode until Fri 6am Toronto; S7 is stopped
Status of items 77-93, for the session that takes over:
- **Shipped on main:** ext/s7-empty-77-81, ext/s7-boki-82-92, ext/s7-dash-outpost-84-86, ext/s7-build-90-91.
- **READY, not merged:** ext/s7-mask-hob-83-89 486e652c (83, 87, 88, 89); see EXT_TO_MAIN.
- **WIP, not ready:** ext/s7-trial-93 f264f3e5 (93, Trial Expedition).
  - Done: lesson cards that pause the world, the Trial lesson order, quiet real expeditions with first-time tips and a Tips log (content/rules/tips.json), --trial-check, marker on the lesson goal, origin/main a06099f3 merged.
  - The agent had last noted "the remaining teammate failure is the same on main; next: commit, merge main, check the StyleBoxFlat issue".
  - Still to do:
    1. --uipolish-check, and replace any StyleBoxFlat with the UI helpers
    2. the skip/replay entry from the menu, verified
    3. --tutorial-hud-check, --trial-check, --check
    4. screenshots: lesson cards, skip/replay, a quiet first expedition with one tip
    5. READY in EXT_TO_MAIN
- Agent brief used for S7 item work: the repo rules plus "build exactly what the item asks". Godot runs here used a local wrapper (/home/claude/gq) that won't exist in a new container.

## 2026-11-05 17:58 UTC ext → all: the SUPERVIVE reference footage is on branch `ext/hero-ref-footage`
The frames behind briefs/hero-ref/*.md (5 fps JPGs; the README maps the folders to our heroes). Fetch only the folders you need (`git checkout origin/ext/hero-ref-footage -- footage/<id>`). Use them for any "like <SV hunter>" note. Don't merge that branch.

## 2026-11-05 18:08 UTC ext → S7: owner item 151 (layout: no 1-high rocks, SV layout rules) is a good fit for you when your low-spend window ends (Fri 6am). Check MAIN_TO_EXT first; if S5 hasn't taken it, it's yours.

## 2026-11-05 20:00 UTC ext → S7: when you're back (Fri 6am), you OWN the onboarding rework (the tutorial + farm)
Items in OWNER_REVIEW_1103: 164, 165, 166, 167, 178, 178b-i, 169, 169b, 171, 171b, 172, 172b, 174, 174b, 175, 155, 154, 157 (the info-strip part), 179.
Source: the owner's dad playing it cold. Make it handholding: key-first prompts at the object, gold highlights, escalation when ignored, one instruction at a time. Release in slices, tutorial first.
- 169c (added 18:40 UTC): the farm tutorial in strict mode. Only the step's target is interactable. Logical order (no planting the starter berries before the buy step). Buy → auto-close → an arrow back to the patch. A scripted off-step-action test.
- 164b (21:00 UTC): no wild monsters on the first/teaching islands; only the step's own creatures (the taming Boki, dummies).
