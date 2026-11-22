# Speed-up plan (owner, 2026-11-05: "whichever has access to the hetzner server + local for my gaming pc - goal is speed")

Fast machines take the heavy code work. Cloud sessions keep art, VFX and sound.

| Session | Machine | Owns | Branch prefix |
|---|---|---|---|
| S5 | cloud | integrate/merge/release + quick fixes | (main) |
| **K1 "kits"** | Hetzner server, tmux `boki` new window | hero kit items 120-160 (OWNER_REVIEW_1103), one hero per branch | ext/kit2-<hero> |
| **S1 "physics"** | Hetzner server, tmux window 0 (existing S1) | 149, 150, 151, 162, 163 (movement parity, wall bounce, layout, drop + glide) | ext/phys-* |
| **P1 "UI"** | owner's gaming PC (Claude Code local, real GPU) | the Void & Masks restyle (UI_STYLE.md) for every screen + screenshots; 87c perf (hover stutter) | ext/ui-* |
| S7 | cloud | the onboarding rework (the tutorial + farm, list in INBOX_S7) | ext/onb-* |
| S2 | server window 1 | models/anims | ext/art* |
| S3/S4/S6 | cloud | VFX / sound / Boki | as before |

All of them: read briefs/MAIN_TO_EXT.md (the latest entries), OWNER_REVIEW_1103.md for your items, DECISIONS.md, UI_STYLE.md. Post READY to EXT_TO_MAIN.md with the branch + commit + checks + screenshots; S5 merges. Never block on owner questions (decide, note it, continue). Don't force-push; don't touch main directly.

## Start prompt: K1 (Hetzner, new tmux window)
You are K1, the hero-kit session for Project Boki (Godot 4.6.2, repo OrriBogdan2/project-boki).
- Clone/fetch; read briefs/SPEEDUP_FRI.md, briefs/MAIN_TO_EXT.md (the last 20 entries), briefs/DECISIONS.md, briefs/supervive-data/*, and `git fetch origin ext/hero-ref-footage` for the reference frames (see its README).
- Own OWNER_REVIEW_1103 items 120, 121/b/c, 122, 123, 124, 125/b, 126, 127, 128, 130, 132, 133/b, 134/b, 135, 136 (kit half), 138, 140/b, 141, 142, 144/b, 146, 147, 159, 160, unless S5 already shipped one (check main's log first).
- One branch per hero (ext/kit2-<hero>), with the kit checks green (--<kit>-combo-check etc.) and a 4-frame screenshot strip per item.
- Post READY per branch in EXT_TO_MAIN.md. Use Opus. Go fast, in parallel with subagents per hero where the files don't overlap.

## Start prompt: P1 (owner's gaming PC, Claude Code local)
You are P1, the UI session for Project Boki (Godot 4.6.2, repo OrriBogdan2/project-boki), running on the owner's gaming PC (a real GPU: use it for rendered screenshots and perf probes).
- Read briefs/UI_STYLE.md, the refs in briefs/art-refs/ui/, DECISIONS.md, MAIN_TO_EXT.md (the latest), and OWNER_REVIEW_1103 items 152, 155, 156, 157, 170, 174, 175, 176, 177/b, 87c.
- Build the Void & Masks theme once (a Godot Theme + reusable scenes: torn panel with an edge-glow shader, parchment strip, mask badge, ticket button, void portrait window, stamp).
- Convert the screens in order: title/main menu → hatch flow → the Boki list/sheet → home panels/markets/Black Market → settings/pause/loading → results → the HUD palette.
- One branch per screen group (ext/ui-*); before/after screenshots at 1080p in each READY post to EXT_TO_MAIN.md. Add the UI-overlap probe (175).
- Never write to the owner's save or settings: use a fresh XDG_DATA_HOME per Godot run.
