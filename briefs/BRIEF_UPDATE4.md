# Brief update 4 (from the main session, Nov 1 21:50). Applies to every agent on both machines.

## Main is now sync58 (e5f25ec), Net.VERSION 0.10.0
- **Follow by default:** a hunter's one active Boki walks beside them. G tap = Sic (leap at the cursor, landing staggers); G tap while it's away = Call back; hold G + flick = order wheel (Chase, Guard, Return, Follow). Return = onto you (mount). Files: kin_follow.gd, kin_path.gd, kin_wheel.gd.
- **Capture by scan replaces taming:** knock a wild Boki out, hold F 0.4 s, then a 4 s rooted scan (crowd control interrupts, plain damage doesn't, dash cancels). Caught Boki go into the box (h.caught, cap 3 in content/rules/capture.json) and NEVER follow you or spawn in the match. One active Boki per hunter, always. Field Book logs species on sight. Save v4 (migration v3->v4). Files: capture.gd, capture_hud.gd, field_book.gd.
- Nothing may re-add taming text ("Hold F to tame") or a shoulder-start Boki.

## Coming next on main (branch mergeforms, Net 0.11.0)
Merge becomes a transformation with its own kit per Boki (LMB/RMB/E replaced; R again = unique ult that separates you), a shell health bar while merged, no tiers; the downed-Boki rescue becomes a 3.5 s cradle.

## Reserved: do not edit
Keys G, C, R, F. Files: kin_merge.gd, merge_form.gd, merge_look.gd, kin_downed.gd, content/merges_v2, content/rules/merge_forms.json, the Hunter R/ult input, kin_command.gd, kin_strike.gd, kin_net.gd, bot_kin.gd, boki_hud.gd, kin_follow.gd, kin_path.gd, kin_wheel.gd, capture.gd, capture_hud.gd, field_book.gd. If you need a hook, call their public functions from your own files and list missing hooks in your report.

## Net versions (replaces all earlier tables)
If your branch changes sync shape, bump to the next version above main **at the time you report it ready** (main is 0.10.0 now; mergeforms will take 0.11.0). Report the number; the main session resolves collisions at merge.

## Before reporting any branch ready
Merge origin/main (sync58 or later), re-run the affected checks (including `--teammate-check`, which passes on sync58), `python3 tools/health.py --strict`, and `python3 tools/gen_wiki.py --check`. Anything that assumed a shoulder-start Boki or a hold-F tame must be updated.

## Merge order the main session wants
feelfix, polish, ext/fixes, ext/economy (trimmed), rolling, ext/gear, then hero branches as each is done.
