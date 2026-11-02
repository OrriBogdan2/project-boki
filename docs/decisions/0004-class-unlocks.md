# 0004: Class unlocks and the "class" rename

- **Status:** accepted (owner decisions in docs/HANDOFF_main_overflow.md section 3 and the "equal footing" entry of MAIN_TO_EXT: classes unlock through play as a choice, not power)
- **Date:** 2026-11-02
- **Area:** save / UI / progression

## Problem
All twelve classes are open from the first minute, so a new player meets a wall of choices, and there is no long-term goal beyond gear. Players also saw "archetype" for the kit you play and "class" for Light/Medium/Heavy.

## Options
1. Gate classes behind account level only: simple, but no clear thing to do.
2. A goal per class only: clear, but no pacing across the account.
3. Both (decided): a goal per class and an account level, both data in `content/rules/class_unlock.json`.

## Decision
- A new save picks one of three starters (Thief, Marlowe the gunslinger, Juggernaut: one per weight) on a class screen before the hunter creator. Everything else opens when its goal is done and the account level is reached. Account XP comes from every expedition (played, extracted, monsters, knocks, bosses, Boki brought home), with caps per kind.
- Locked classes stay playable in the Arena and the practice areas' picker (HeroGrid, not gated), but are never saved as the expedition class. The farm picker and the expedition panel grey them out and show the goal; the Classes screen lists open, in-progress and locked ones with progress bars. A reveal plays when one opens (`ClassReveal`, queued in the save).
- Player-facing "archetype" is now "class"; Light/Medium/Heavy is the "weight". Internal ids, files and save keys keep their names.
- **Save:** v5 to v6. `classes` = `{all, starter, open, reveal, seen, xp}`. The migration sets `all: true`, so existing saves keep everything open (and still earn account XP). A save dict with no `classes` entry counts as open.
- **Logic** lives in `ClassUnlock` (core), `ClassCard`/`ClassPick`/`ClassReveal` (UI), `HomeClasses` (farm); `game.gd`, `match.gd`, `hatch.gd`, `home.gd` only get wiring lines.

## Consequences
- New: `content/rules/class_unlock.json`, `class_unlock.gd`, `class_card.gd`, `class_pick.gd`, `class_reveal.gd`, `home_classes.gd`, `tools/class_unlock_check.gd` (`--class-unlock-check`). Changed: `hero_grid.gd` (gated flag, goal blocks), `practice_hero.gd`, `portraits.gd` (a standing full-body option), `hatch.gd` (starter stage), the expedition panel in `home.gd`, the results screen (account line).
- `Net.VERSION` unchanged: nothing here syncs.
- Starter set, goals and XP numbers are owner questions; they are data only.
