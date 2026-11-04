# 0005: Hunter unlocks, mastery, the Hunter viewer and hold to unlock

- **Status:** accepted (owner answers 2026-11-03 01:55, 02:00, 04:25 and 04:30 UTC; replaces the 1-starter, free-pick and account-XP flow)
- **Date:** 2026-11-03
- **Area:** save / UI / progression

## Problem
All twelve Hunters were open from the first minute: a new player met a wall of choices and had no long-term goal beyond gear. The owner wants a small start (Vex, plus 1 of 3), every other Hunter earned through a short feat that shows off its kit, and per-Hunter goals that reward looks only, never power.

## Options
1. Free picks plus account level gates (the first pass): fast, but unlocks felt like a grind and had nothing to do with the Hunter.
2. One challenge per Hunter, tiered (decided): easy for the two unpicked starters, medium for most, hard and last for Ostra, Moosh Moosh and Breah. Vex is owned from the start, so he has no unlock challenge (his 4 mastery goals stay).

## Decision
- **Start:** a new save picks its first Hunter from `starters` and plays the tutorial as it. The other starters open by themselves after the first finished expedition (`bonus`, then a toast on the farm); Cinder is an easy challenge. Saves that already picked keep what they have. The new-game flow in hatch.gd is the prologue, one card, your Hunter pick (`ClassPick`: 1 of `starters`, Vex, Pin and Zedran by id, in the Hunter viewer), the egg pick, then the hatching and naming (your name is asked on the naming card). Nothing else is offered or accepted. The hunter creator is no longer on a new save's way: a default look is set, and Change your look in the farm menu opens it.
- **Challenges:** `unlock` in `content/rules/class_unlock.json`, one per Hunter: a stat, a target, a tier and one line of text. They count across every expedition, whoever you play. `after` makes a hard one wait until that many Hunters are open.
- **Hold to unlock:** a done challenge never opens a Hunter by itself. The Hunters screen shows "Hold to unlock" (`HoldUnlock`, 1.6 s); letting go early cancels; full plays the reveal (`ClassReveal`).
- **Mastery:** `mastery` holds 3-5 goals per Hunter, counted only in expeditions played as it, mixing kit feats, team play, exploration, extraction and Boki goals. Each one done is a mastery level and a cosmetic reward (glider, skin, colourway, emote, title, banner or trail). No stat, ability or perk reward exists.
- **Measuring:** `ClassUnlock.match_counts` reads one expedition's result; `HunterFeats` (a child of the match) records the feats from `CombatBus` (statuses, multi-hits, far and air hits, Boki hits, knocks while merged or under half health) into the hunter's match stats. Chests opened are one line in `Match._open_chest`.
- **Gliders:** looks, trail and sound only (`Gliders.SKIN_KEYS`); new designs (paper crane, Boki wings, cloth and leaf variants) come from mastery or account-wide challenges. The Hunters screen has a glider pick; the rack by the portal still works.
- **Save:** v6, `classes` = `{all, picks, open, bonus, fresh, told, reveal, seen, stats, hunters}` (`bonus`, `fresh` optional: an older save has neither and nothing waits). v5 saves had every Hunter, so they keep them all. A v6 save from the first flow keeps every Hunter it had open or was playing, and drops the old keys (`ClassUnlock.upgrade_early_v6`). A save from the pick-2-of-4 flow keeps both picks; the early-v6 upgrade adds Vex to its open list (`is_open` no longer counts him by default).
- Locked Hunters stay playable in the Arena, the Training Grounds and the practice picker, but are never saved as the expedition Hunter. Display names come from hero data; everything keys on ids.

## Consequences
- New: `scripts/match/hunter_feats.gd`. Reworked: `class_unlock.gd`, `class_pick.gd`, `class_card.gd`, `home_classes.gd`, `gliders.gd` (new shapes and unlocks), `synth.gd` (two glider sounds), `hatch.gd`. `match.gd` gains two wiring lines, `home.gd` none.
- `--hunter-unlock-check` covers the flow, the data rules (cosmetic only, no glide numbers in skins) and the migration.
- `Net.VERSION` unchanged: nothing here syncs (the feats are counted where each hunter's stats already live).
- Other cosmetic kinds (skins, colourways, emotes, titles, banners, trails) are earned and listed; showing them in game is a follow-up.
