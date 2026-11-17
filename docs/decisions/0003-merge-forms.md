# 0003: Merge forms, a kit swap with a transformation and an ultimate

- **Status:** accepted; the kit swap (LMB/RMB/E, MergeHolds) was replaced by augments on Nov 2 2026, see [0004](0004-merge-augments.md) (owner design of Nov 1 2026; supersedes the merge-tier parts of [0001](0001-boki-merge-and-commands.md))
- **Date:** 2026-11-01
- **Area:** combat / networking / UI (the Merge, hunter inputs, Net)

## Problem
The merge was a stat buff with a tier ladder (Bonded/Fused/Ascended, scaled by Boki level, trust and forms) and a new look. It does not feel like becoming something, favours high-level Boki, and teaches nothing: every merge plays the same.

## Options
1. Keep the stat merge and tune the tiers: rejected, nothing to learn and a rich-get-richer ladder.
2. A form per hero x Boki pair: rejected (6 x 9 kits), as in 0001.
3. A form per Boki species (decided), the same for everyone. While merged, LMB, RMB and E are replaced by the form's kit (slot grammar: LMB main attack, RMB a hold mechanic, E movement or utility), R fires the form's ultimate and separates you. Shift (flavoured), Q and the bar stay. Boki without a form yet keep the stat merge, tier-free, with R ending it in a basic burst.

## Decision
- **Flow** (`KinMerge`): R with a full meter starts a ~0.7s transformation (invulnerable; the Boki leaps into you, a light spiral, a flash, the silhouette pops in: `MergeXform`, `MergeLook`). Then ~10s live (data per form). R again after ~1.5s fires the ultimate (wind-up >= 0.4s with a ground marker), which ends the merge: the Boki pops out beside you in Follow, not downed. If unused, the merge times out and separates. C is unavailable while merged; G and the order wheel are inert (the Boki is inside you).
- **Data:** `content/merge_forms/<merge id>.json` holds one form (palette, look, weight-class baseline, dash flavour, the four slots). Slots are the ability grammar (`Effects`: cone, projectile, chain, pull, wall, zone, leap, area...) plus three reusable primitives in `MergeHolds`: boulder (a held armoured roll), hover (a held slow fall that crosses gaps) and the held prism (a frontal `Verbs` mirror that sends shots back at the shooter), and a swept blink. The runtime is `MergeKit`.
- **No tiers:** `tiers`, `forms_bonus`, per-power scaling and rank scaling are deleted. A form is identical for everyone; only the shield and speed baseline follow the weight class (light/medium/heavy).
- **Clarity:** a rival's merge plays the same transformation with a loud sound, the form name and a draining bar float over the head, the feed says "<name> became <Form>", every ultimate telegraphs for at least 0.4s.
- **Net:** the form id, kit casts (`kcmd` mcast) and the ultimate tell reach other games; `Net.VERSION` 0.10.0 to 0.11.0. No save change.

## Consequences
- New: `merge_kit.gd`, `merge_holds.gd`, `merge_forms` data, `merge_xform.gd`, `merge_parts.gd`, `merge_moves.gd`, `tools/merge_form_check.gd`. Rewritten: `merge_form.gd`, `merge_look.gd`, `kin_merge.gd`. Wiring only in hunter.gd, kin.gd, match.gd, hud.gd, bot.gd.
- Removed: the tier table and its text, `KinMerge.growth` use, the giant mount for formed merges.
- Debt: the six other Boki keep the stat merge until they get forms (docs/DEBT.md).
