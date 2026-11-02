# 0002: The Boki follows you, and capture by scan

- **Status:** accepted (owner decisions of Nov 1 2026, after research)
- **Date:** 2026-11-01
- **Area:** combat / networking / save / UI (Boki behaviour, G wheel, capture, Field Book, Net)

## Problem
Riding on the shoulder until thrown makes the Boki dead weight between throws, and the old tame (daze it, then hold F for a few seconds beside it) is a long, unreadable channel with no risk model and no record of what you have met.

## Options
1. Keep the shoulder default and add a follow mode: two default states, more branching. Rejected.
2. Boki walks beside you and fights with you; the shoulder (and the mount seat) becomes a command called Return (decided).
3. Capture: keep the hold-F tame but shorten it. Rejected: the owner wants a committed, visible, interruptible action with a box limit.

## Decision
**Follow** (`scripts/match/kin_follow.gd`, `kin_path.gd`, `kin_wheel.gd`). One command id on the Boki (`cmd`): follow (default), guard, chase, return. The out states stay the existing FSM (active, flying, returning, flying_home); the shoulder state is now "Return" or a short traversal carry. Walking uses A* on the tile grid (windowed, repathed on a timer, never every step), arrive slowing and separation from you. Stuck for 1s or beyond recall_range: a visible leap back to your side, never an invisible teleport. A glide, a pad, a drop or a gap it cannot path: it hops onto you and hops off after you have been steady for a moment. G tap sends it at the cursor ("Sic"); tap while it is away is "Call back": a leap to your side with the old recall hit on the way. Hold G opens a 4-way flick wheel (Chase, Guard, Return, Follow); the wheel is local UI state, the pick is applied on the fixed step and the order is sent in the kin snapshot. Carried passives and on_shot riders apply only while it is on you. Mounts: Return is riding it, Sic dismounts and charges, a jump dismounts. In combat the Boki never refuses an order: a hesitation of 0.3s and a bark replace the refusal. Net: the command, plus kcmd events for hops and wheel picks.

**Capture** (`scripts/match/capture.gd`, `scripts/core/field_book.gd`). A wild Boki must be dazed. Hold F for 0.4s to commit, then a 4s scan plays on its own: you are rooted, can aim but not shoot, a dash cancels it, crowd control interrupts it, damage does not. The daze timer pauses during the scan. Success puts a capsule in h.caught (the box, 3 by default in `content/rules/capture.json`, shown on the HUD); a full box blocks the scan, and the backpack has a Release button. A captured Boki stays a capsule for the whole match: it never follows, fights, or replaces or joins the active Boki (one active Boki per hunter), and it is not spawned in the world. Your own Boki never finishes a knocked-out wild Boki (it cannot be hit while it waits to be scanned). Bots scan the same way. Rivals see the beam and hear the sound (Net kcmd event). The Field Book (the old Kindex page, renamed) logs every species the moment you see it, with where; save v4 migrates old saves.

## Consequences
- Net.VERSION 0.9.0 to 0.10.0 (kin snapshot carries the command; kcmd gains hop/wheel/scan kinds).
- Save v3 to v4 (dex entries gain "places"; species you own count as seen).
- Removed: hold_mode, the heel (shoulder-walking) visual, the daze-then-hold-F tame channel and its text, "refuse" in combat.
- Checks: tools/boki_follow_check.gd, tools/capture_check.gd; boki/teammate/archetype checks updated for the new default (state follow, not shoulder).
- Open: a Boki walking beside you counts as "with you" for the death-box rules (Life.kin_on_death), so the Dusk rules are unchanged.
