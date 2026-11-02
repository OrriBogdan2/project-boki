# 0005: Hunter unlocks, the Hunter viewer and hold to unlock

- **Status:** accepted (owner answers, 2026-11-02 19:10 UTC; was 0004-class-unlocks, renumbered because main took 0004 for merge augments)
- **Date:** 2026-11-02
- **Area:** save / UI / progression

## Problem
All twelve playable characters were open from the first minute: a new player met a wall of choices and had no long-term goal beyond gear. The first pass (pick 1 of 3 starters, auto-unlocks, "class" wording, Light/Medium/Heavy shown) was reopened by the owner: they are **Hunters**, the weight labels go, the pick needs a proper viewer, and an unlock is something you do by holding a button.

## Options
1. Auto-unlock when a goal is met (the first pass): no moment, no choice.
2. Free picks only: fast, but no long-term goals.
3. Both (decided): a free pick for each early goal, then a goal and account level per Hunter, every unlock taken by holding.

## Decision
- **Starting Hunter:** at character creation (hatch.gd's first stage) the player picks 1 Hunter from `starters` in `content/rules/class_unlock.json` (all twelve for now) in the Hunter viewer.
- **Early unlocks:** `early` holds two cheap goals (play 1 expedition, then make it out of 1). Each one done, in order, is a free pick of any locked Hunter. The numbers are placeholders until the owner sets them.
- **After that:** a Hunter is ready when its own goal is done and the account level is reached (`classes` in the same file). Account XP comes from every expedition, with caps per kind.
- **Hold to unlock:** nothing opens by itself. A ready Hunter shows "Hold to unlock" on the Hunters screen (`HoldUnlock`): a bar slides out and fills over `hold_s` while the Hunter powers up in the viewer; letting go early cancels; full unlocks it (`ClassUnlock.unlock`, spending a free pick only when its own goal isn't met) and plays the reveal burst (`ClassReveal.show_for`).
- **The viewer** (`HunterViewer`): the real model on a turntable in a SubViewport, playing each ability in turn with the kit's own moves (`content/rules/hunter_viewer.json`, ids from `HunterAnim.KMOVES`), the key and plain line under it, and the L picker's plain-words card. Used on the Hunters screen (J on the farm, `HomeClasses`) and at character creation (`ClassPick`).
- **Wording:** player-facing text says Hunter / Hunters everywhere; no Light/Medium/Heavy or "weight" in the UI (health and dash counts instead). Internal ids, file names and the save key `classes` keep their names. Display names come from hero data, so the kitfix renames carry through.
- **Save:** v6, `classes` = `{all, starter, open, early_used, told, reveal, seen, xp}`. Missing keys read as 0 / [], so earlier v6 test saves load; v5 saves migrate with everything open.
- Locked Hunters stay playable in the Arena, the Training Grounds and the practice picker, but are never saved as the expedition Hunter.

## Consequences
- New: `hunter_viewer.gd`, `hold_unlock.gd`, `hunter_pick_row.gd`, `content/rules/hunter_viewer.json`. Reworked: `class_unlock.gd`, `class_pick.gd`, `class_reveal.gd`, `home_classes.gd` (the Hunters screen), `home_hero.gd`, the Try-on rack and the duel bot (pick a Hunter, not a weight). `home.gd` and `hud.gd` only changed lines in place.
- `--hunter-unlock-check` (alias `--class-unlock-check`) covers the flow; `--hero-check` and the practice picker check use the new wording.
- `Net.VERSION` unchanged: nothing here syncs.
- Owner questions: the starter set, the early goals, every goal number and the hold time are data only.
