# 0022: A raised lean shapes the wisp's kit

- **Status:** proposed (spec only, no code)
- **Date:** 2026-11-09
- **Area:** Boki, wisps, garden

## Problem
GARDEN.md section 2 promises "a lean that shapes its kit". Food gives a Boki a second element (its lean) and a small stat nudge, but nothing says what the lean does in a match. The wisp rules (DECISIONS 2026-11-09) give a Boki an always-on carry passive and a timed summon. The lean must change both without a new stat ladder, a new economy, or any control over the player (DECISIONS 2026-11-06: Boki never move, swap, launch, root or steer the player).

## Options
1. Lean adds raw stats. Simple, but it is a grind ladder and duplicates the Play levers.
2. Lean is a flavour tag plus a small capped rider on things the kit already does. Readable, bounded, no new buttons.
3. Lean swaps the summon's active for the lean element's active. Too big: it breaks per-species identity and balance.

## Decision
Option 2. A lean has a **strength L from 0 to 1** (the raising progress for that element, shown on the Boki card). Every effect below scales with L and is hard-capped.

**On the carry passive (the wisp, always on).**
- The passive keeps its species effect and its numbers unchanged.
- It gains a **tag**: the lean element's name and tint on the HUD source line and wisp glow ("Water Boki, Fire lean").
- It gains one **small rider**, taken from the lean element's table row (one line each, content/rules/boki_lean.json): an element-matched resist or a status edge on enemies or on the player's own stats. Size: **at most +10% of the passive's own value** (= 0.10 x L). Example riders: Fire = +burn chance on your hits, Water = soak clears 1 s sooner, Grass = tiny regen while standing still.
- Riders only touch enemies, the world or the player's stats. No rider moves, pulls, launches, roots, slows by force or steers the player.

**On the summon (the full Boki, short window).**
- **Damage-type tag:** the summon's active deals its normal damage with the **lean element added as a second tag**. Type effectiveness uses the better of the two tags against the target (never both multiplied). The species element stays the primary tag for visuals and sound.
- **Element rider:** one small on-hit effect of the lean element on the summon's active, e.g. Fire = ember burn, Ice = frost mark. The rider's damage is **at most +10% of the active's damage** (0.10 x L) and sits **inside the summon damage band** from the wisp design pass (WISP_DESIGN_OPEN): a leaned summon with L = 1 reaches the top of the band and never leaves it. The band's top is raised by nothing in this spec.
- **No change** to summon duration, cooldown, hp, or the number of summons. Those stay per-species identity (owner addendum 11-09).
- Stolen wisps use the thief's rules: the lean tag and rider still show, at the stolen Boki's own L, capped the same way.

**Total cap.** Everything a lean adds (stats from raising, passive rider, summon rider) is counted inside the same **+10% raising cap** (Care.IV_BONUS style), never on top of it. A fully raised Boki is about 10% better than a fresh one in its lean's lane, and no more.

## Worked examples
1. **Fire-lean Water Boki** (a Puddlet, L = 0.8). Carry passive is its Water effect, with an ember tint and the tag "Fire lean"; rider: your hits have +8% of the passive's value as burn chance. Summon: Water splash active, tagged Water + Fire; against a Grass target it counts as Fire (super effective), and against a Fire target it counts as Water (the better tag wins).. Rider: embers add 0.08 x the active's damage as burn damage over 3 s, still inside the band.
2. **Grass-lean Rock Boki** (a Pebbit, L = 0.5). Passive: its Rock guard unchanged, plus a mossy tint and +5% of the guard as slow regen while you stand still. Summon: Rock slam tagged Rock + Grass; rider: seed mark that heals the player for 0.05 x the active's damage when it hits (a heal, not a move).
3. **Ice-lean Electric Boki** (a Zapple, L = 1.0, fully raised). Passive: its Electric effect, frost-blue sparks, and +10% of the passive's value as status resist against Fire-tag hits. Summon: Electric chain tagged Electric + Ice; rider: a frost mark on the target that adds 0.10 x damage on the next hit by anyone on your team. Top of the band, never above it. The frost mark never slows the player and only marks enemies.

## Consequences
- **Files a build would touch:** `content/rules/boki_lean.json` (new: element to rider table, caps), a focused `scripts/match/boki_lean.gd` (new: reads L, applies tag and rider), `scripts/core/care.gd` (expose the saved lean strength; no format change if it is already stored), wisp carry-passive and summon code in `scripts/match/` (a few lines of wiring each), the HUD source line and Field Book card in `scripts/ui/`, `tools/boki_lean_check.gd` (new, registered), and `docs/` wiki via `tools/gen_wiki.py`. The god files (`match.gd`, `hunter.gd`, `hud.gd`) get wiring only.
- **PvP fairness:** the lean is capped at +10% and applies only to the summon's own damage and to the passive's own value, so a raised Boki is a sidegrade you can read on the HUD, never a power tier over a fresh one.
- Needs the wisp design pass to fix the summon damage band numbers before the rider values are final.
- Alternative kept open: option 3 (lean swaps the active) for a later "evolved lean" form, only with an owner decision.
