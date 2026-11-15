# TITLE: UI merge lane 2 (1115): squad killer disc + colourblind SideColor fix, rest of the ui branches skipped (conflicts)

## What this merges (by unique patch, not whole branches)
- ext/ui-squad-killer 6d4960b2c4: a dead teammate's squad row shows the Hunter who finished them in a red disc (hand-resolved onto main's reformatted squad_frames.gd / HUD.md).
- ext/ui-colourblind-sides 141d63f24d: HudStyle.ALLY/FOE users in mate_alerts.gd / team_boki.gd read SideColor. Its second commit (f34492c00) is skipped: it only edits a registry comment for tools/colour_vision_check.gd, which main deleted. The deleted file's part of the first commit was dropped too.

## Skipped (not merged), with reasons
Method: `git cherry origin/main <branch>` `+` commits cherry-picked oldest first, atomic per branch, with ignore-space and a "ours + only the lines theirs added" union for check_registry.gd and docs/*.md. Any code conflict reverts the whole branch.
Stacked / bad base, not attempted (their own commits cannot be separated from 133-140 foreign patches inside the time box; same base drift as below): ui-aspect-sweep, ui-banner-queue-calm, ui-loot-compare, ui-next-form-port, ui-w0246-layout-reds, ui-summon-card.
Originals of -rebased pairs, skipped by decision: ui-text-chat, ui-belt-six.
Code conflicts on the first or an early unique patch (main moved 2000-10000 commits since their bases; main's .gd files were gdformat-reformatted, and several files were rewritten):
- touching core/net.gd + settings.gd + match/kin.gd (shared base, Net-rule files, need a real port): ui-portal-boki-card, ui-ride-pick, ui-hud-reveal-1110, ui-stolen-wisps, ui-text-chat-rebased, ui-stomp-picker, ui-stomp-state, ui-stomp-ring, ui-belt-six-rebased
- hud.gd / hud_panels.gd / armor_hud.gd / hud_vitals.gd rewritten on main: hud-g-armor-1111, hud-ref-copy-2, ui-bonus-column, ui-overhead-ref, ui-hudref-verify, ui-hud-scale, ui-text-size, ui-safe-area-one
- archetype JSON + kits (ability text tokens, tooltips, declutter touch ~30 files): ui-ability-text-one, ui-tooltip-from-data, ui-declutter-1111, ui-plate-status-row, ui-loading-bar-steady
- home.gd / lobby.gd / prematch_view.gd: ui-mode-cards, ui-zone-next, ui-solos-hud, ui-trios-only-text, ui-expedition-first, ui-base-hud, ui-prematch-margin
- UiTorn / ui_theme house-look retirement (main still has these files changed): ui-simplify, ui-simplify-1111, ui-pro-1111
- match.gd / msg_lane / tutorial: ui-banner-queue, ui-steal-callout, ui-knock-callout, ui-tip-card-one-prompt
- other: ui-audio-buses (settings.gd/sfx.gd), ui-dex-legendary-order + ui-dex-filters (data.gd, dex_view.gd), ui-first15-leftovers (save.gd), ui-results-first (results.gd), ui-settings-trim (overlay.gd), ui-level-gap (drop_*.gd mid-branch; first commit clean)
Each of these needs the feature re-ported on current main (own task), not a cherry-pick.

## Checks
godot --headless --import clean. suite-fast is hetzner-only; ran --hudref-check (squad rows) on the touched files.
