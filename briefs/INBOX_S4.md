# INBOX for S4 (cloud session). ext (the coordinator) posts orders here; check every 30 min.

## 2026-11-05 06:30 UTC (ext): SOUND for all 12 Hunters + Boki + UI (owner: max pace)
Your four items are merged, thanks. New job.
- **Agents:** up to 4.
- **Branches:** `ext/sfx-<hero>`, `ext/sfx-boki`, `ext/sfx-ui` from origin/main.
- **Per Hunter:** weapon fire, each ability (cast + impact), dash, footsteps by surface, hurt/downed/death grunts (no words), plus signatures:

| Hunter | Signature sounds |
|---|---|
| Vex | minigun spin-up + grenade thunk |
| Lisette | thread twang |
| Kael | chain rattle + blade hiss |
| Breaker | hull creak + hammer clang |
| Motley | music-box jingle + spring boing |
| Cinder | flame roar + tank hiss |
| Grimble | coin jingle + junk clatter |
| Claire | skate scrape + ice chime |
| Pip | lantern chime |
| Sable | flintlock crack |
| Ryzz | zap + bubblegum pop |
| Tarek | rock crunch |

- **Sources:** synthesis/layering in code, or CC0 only, logged in `docs/CREDITS.md`.
- **Mix:** consistent loudness; the right buses (Match bus, item 103). Replace weak files in `audio/`.
- **Report:** post READY per group in `briefs/EXT_TO_MAIN.md`; S5 merges.
- **Rules:** as before.

## 2026-11-05 06:35 UTC (ext): OWNER REQUIREMENT: every READY report must include the hero's rows from `briefs/art-refs/FIDELITY_CHECKLIST.md` as a ✅/❌ table with proof screenshots (e.g. Vex's cannon IS her right arm, Ryzz fires PINK lightning from her fingertips). Check your in-flight work against it now.

## 2026-11-05 12:00 UTC (ext): add a Ryzz bubblegum pop sound (blow + pop) to `ext/sfx-ryzz` if missing, hooked to her idle/emote/kill events (S2 adds the anim).

## 2026-11-05 12:17 UTC (ext): OWNER PLAYTEST: Vex sounds too LIGHT. Make her intimidating
Owner: "Vex doesn't sound very intimidating; her sounds are kind of light for how dangerous she should be." Redo `ext/sfx-vex` (branch `ext/sfx-vex-2`):
- **Minigun (LMB):**
  - A heavy, chunky mechanical roar, not a pea-shooter. A deep low-end thump per shot, a metallic barrel-spin whine underneath, a rising spin-up on press, a spin-down tail on release.
  - Layer: a punchy low transient + mid crack + mechanical rattle + brass casings tinkling.
  - It should feel like a heavy weapon you fear hearing nearby.
- **Grenade (RMB, now fired from the arm-cannon top tube, item 112):** a deep hollow "THUNK" launch + a big bassy explosion with debris and a rumble tail.
- **Her cybernetic body:**
  - Servo whirs and hydraulic hisses on the dash/slide; heavier boot steps with a metal clank (robotic arm + chrome knees).
  - The dash = a hard mechanical burst.
- **Longneedle (E):** a deep charge hum building, then a loud piercing crack/boom on release.
- **Impact:** hits on enemies get a meatier impact sound.
- **Distance:** she should be audible and threatening from range: a distance-filtered low end so you hear her coming.
- **Mix:** louder/heavier relative to the lighter Hunters (still within the bus loudness targets).
- **Other carries:** apply the same "weight" check to the other damage carries (Kael, Grimble's blunderbuss, Breaker's hammer). The owner may say the same; strengthen them where they're thin.
- **Post:** a short A/B note in READY (old vs new).

## 2026-11-05 12:22 UTC (ext): OWNER (playtest): Lisette RMB charge needs a MUCH stronger sound while held (rising tension creak + thread hum), plus a heavy release twang/whoosh. Item 114.4. Same weight check as Vex.
