# How a hold ends: release, stun, another key, down

PARITY FIRST (briefs/DECISIONS.md 2026-11-07, "the source decides"). Five holds: Kael's RMB Lunge, Lace's Heavy
Shot and bow draw, Sparkle's Skycall drag, Albert's Crushing Blow whirl, Tenzo's Basalt Spine drag. Asserted in
`tools/hold_release_check.gd`, run from each hero's `--<hero>-combo-check`.

**Evidence:** [D] game data (briefs/supervive-data/supervive_kits.md), [F] footage (briefs/hero-ref), [O] owner
note. `[?]` = the source shows nothing for that ending, so it is ours and unsettled.

## The rule

| Ending | Rule | Source |
|---|---|---|
| Let go | The hold's move fires. A tap under the threshold is the tap move (or nothing, for the bow). | [D] [F] per hold, below |
| Stunned or downed mid-hold | The hold drops: nothing fires, nothing is spent, the pose and telegraph go. Holding on through the stun does not restart it; a fresh press is needed. | [D] Elluna R "Canceled if Elluna is stunned, knocked, or moves too far"; Soulpack drops on a stun; [W] Brall's chain "breaks only on a stun" (docs/heroes/juggernaut.md). No hold-specific footage: **[?]** for what a stun does to a hold that has already committed |
| Another key | Not a source rule for any of these five. Ours, per hero, in the table. | **[?]** |
| A hold animation | Never shows without the hold input (DECISIONS, Movement and combat feel). | [O] |

## The table (current, after this pass)

| Hold | Let go | Stunned mid-hold | Another key | Down | Source |
|---|---|---|---|---|---|
| Kael RMB (Lunge) | fires; a release in a perfect window goes 20% further | **drops** (was: fired the Lunge while stunned) | E: the charge goes on and lunges at let go **[?]** | **drops** (was: fired) | [D] Brall "Fiery Lunge (HOLD): charge and release a dash attack"; [O] held indefinitely, perfect release (item 113.3) |
| Lace RMB (Heavy Shot) | looses; a tap (under the hold threshold) looses nothing | **drops** (was: loosed while stunned) | E: the draw goes on **[?]** | **drops** (was: loosed) | [D] Myth "Heartpiercer: HOLD to charge, RELEASE to fire"; [F] pin.md "hold to charge, release (tap fires uncharged)" |
| Lace LMB (bow draw) | looses at the stage reached | drops (`Hunter._trigger_bow`) | RMB or E: the draw goes on **[?]** | drops | [D] "HOLD to charge, RELEASE to fire"; [F] pin.md 36 "Hold to draw. Release to fire." |
| Albert LMB (whirl) | swings the Crushing Blow | drops (`BulwarkKit._hold_interrupted`) | RMB, E or a Q glove: **cancels**, no swing (Shift and jump keep it, owner #51) **[?]** | drops | [D] Oath "HOLD to charge a swing"; [F] bjorn.md 69 "Hold to charge. Release swings." |
| Sparkle E (Skycall drag) | fixes the drag; the strike lands 0.8 s later | the circle is already placed, so the drag goes on and commits at let go **[?]** | RMB: both go **[?]** | as stunned **[?]** | [D] Joule "PRESS to strike target location; HOLD AND DRAG before release to aim the knockback direction" |
| Tenzo X (Basalt Spine drag) | the ridge rises, X is spent | **drops**, X refunded (already so) | RMB or E: the aim goes on and casts at let go **[?]** | **drops**, X refunded; the aim pose now goes with it (was: stayed up) | [F] breah.md 374-379 "hold and drag ... She can move while aiming. The cast itself is instant on release." |

## What changed

- `ArchKit.tick` released a held RMB the moment the hunter was stunned or downed, so every kit's RMB hold fired
  its move for a hunter who could not act (Kael's Lunge, Lace's Heavy Shot, and every other kit's RMB release).
  It now drops the hold (`ArchKit._drop_rmb`: hold off, telegraphs cleared, `_rmb_dropped()` for the kit's own
  state). Kael and Lace override `_rmb_dropped()`; the rest need nothing beyond the shared clear.
- Lace's Heavy Shot draw pose (`arc_heavy_wind`) and Tenzo's `breah_spine_aim` pose stayed up after a stun
  dropped the hold. Both now end with it.

## Not built (ideas, for the owner)

- vireo.md 264 suggests refunding a spent charge when a cancel (stun, root, Grounded) hits a running move; not
  asked here, and Sparkle's Skycall is spent at the press, as in the source.
- Whether a stun should cancel a Skycall circle that is already placed is not in the data. Left as it is.
