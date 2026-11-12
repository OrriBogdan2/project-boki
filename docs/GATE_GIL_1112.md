# Gil train gate (ext/gil-train-1112)

Base: origin/main fb360f614. Built by job 20261112-145022-a6: the 19 Gil branches folded into one branch.
Not tagged; Net.VERSION unchanged.

## Merged (first-parent order: merge, branch tip, branch)
- 6d924006e ddd859b96 ext/sfx-gil-set (carries ext/gil-rework-1111 1eb7d007b and ext/sfx-gil-kit 4b39823df)
- 623762b42 e6202dc18 ext/vfx-gil-bar (rider: ext/vfx-rescore)
- 59c77d5d5 7481e5b96 ext/vfx-gil-aimkit
- 62327748b 2b0a2e98e ext/anim-gil-grabbag (carries ext/anim-gil-clips a437b2a17)
- 7c53035b2 caf3b252d ext/feel-gil-sweeps (carries ext/feel-gil-flow a5a1f5b63; riders: feel-cast-lock-buffer,
  feel-one-buffer, feel-low-fps-input)
- 717178e12 942d3c719 ext/combat-gil-sweeps
- 9537a2afa a128b42ee ext/tut-gil-howto (carries ext/tut-gil-howto-card 355f02bee and ext/tut-gil-howto-drill 0c729a8e0)
- 0d94b92cc 4113135df ext/ui-gil-keys (ext/ui-gil-everywhere has the same tip)
- f586ac960 5024f4146 ext/gil-kit-doc, in part: the --gil-kit-check to --gil-combo-check rename (the old name still
  works) and the dash-flow rows. Its gil.md and table checks were left out because they describe the kit before the
  rework. Follow-up: write gil.md again from the reworked kit.
- 0c16ccf34 a63502c45 ext/combat-gil-ttk (rider: ext/combat-ttk-parity-1112 5f01e4cf3). Conflicts with main's text
  were merged word by word: main's wording, parity's numbers. docs/TTK.md and the wiki were regenerated.
- 510b784b1: the style ratchet fix (a history_comment in tools/gil_combo_check.gd)

## Dropped (superseded)
- ext/vfx-gil-colour 4489183fc: ext/gil-rework-1111 redoes the colours.
- ext/sfx-gil-dash-air 50396951c: the rework already has gil_dash and gil_dash_air (content/sfx/gil.json, dash.json).

## Gate (job 20261112-154019-a3, rpc7: the Godot here has no queue)
- `godot --headless --import`: rc 0, on the branch and on a main tree (origin/main fb360f614).
- Full suite on 9264042a7: all 288 registered `-check` flags plus `--bot-kit-use`, headless, 10 at a time, 420 s cap.
  There were 21 reds. 15 of them are on GATE_1112c2's list of reds main already had: --boki-hit-table --grammar-runtime
  --hitch --load --load-trim --merge-form --new-player-flow --pack-ui --pip-live --rate-card (timeout) --revive-net
  --rolling --stretch --ttk --warden-clips (Breaker's hammer, the same on main). The other six:
  - --cliff-mantle-check, --toy-check: they ran past the 420 s cap under load and pass alone (408 s and 10 s). Main
    passes alone too.
  - --tutorial-fight-check: Kael and Vex beats; red on main too when rerun alone.
  - --hold-pose-check NEW-RED, fixed: the Tidal Wave surf (gil_surf) is the ultimate's own run, and the Riptide spin
    is a timed cast. Both now sit in NOT_HELD, the list already used for the Mage's ult and Bulwark's wind. Green.
  - --clip-check NEW-RED, Gil rows fixed: once Gil had a KMovesGil table, the clips and the keys no longer matched in
    length. The spin is now a held move (hold_from), and the surface, spout and wave_land keys end with their clips.
    The Ostra row that is left depends on which models were built first. It was bisected to the Gil clip merge, but
    it is not a Gil defect (docs/DEBT.md).
  - --crouch-check NEW-RED, left in: three pose rows on Gil's new crouch clips. A re-key needs Blender
    (docs/DEBT.md).
- --ttk-check: Gil's rows were "never", because the table held LMB and a held LMB is now the Tide Lunge. The row is
  now clicked ("tap"). LMB measured 1.22, outside the 0.85 to 1.15 bar, so the thrusts went from 7/7/11 to 8/8/13: LMB
  now 1.06. The combo rows (1.12 to 1.27) are left to the combat lane (DEBT). Main's --ttk-check has 20+ reds; on the
  branch, Gil's combo rows are the only ones.
- Gil checks on the final tree: --gil-combo-check, --bot-kit-use=gil, --dash-flow-check, --hold-pose-check,
  --kit-drill-check, --kit-parity-check, --recast-cue-check, --feel-golden-check, --cast-lock-buffer-check,
  --low-fps-input-check, --hit-shape-check, --warden-glb-check and --warden-model-check pass. --clip-check passes
  every Gil row.
- Bot match: a temporary probe (not committed) played Gil as a bot in 3 duels (seeds 3, 5, 9, 120 s) and two
  10-trio matches (seeds 4 and 7, 240 s, every Gil in the match). It showed no script errors and no stop (0.25 s or
  more of a move input with no motion, outside a stun or root). There were 2 sharp brakes in all. Every cast played
  its move, and only the dive (under the ground, by design) has no clip. `--simtest` ends at about 35 s ("team wiped"
  by a mob) on main too, so it was not used.
- Export dry-run: `godot --headless --export-pack "Linux"`: rc 0, 0 errors, 488 MB pck.
- `tools/health.py --strict`: HEALTH OK, STYLE OK.

## Fixed on this branch after the merge
- Bots never chose Ground Swim: 7 to 8 dashes per 120 s duel set, the fewest of the 13. His bot_use now swims in at
  3.5 to 7 m, which gives 14 to 20.
- The clip and key lengths above, the hold-pose list and the TTK row and number, all as listed in the Gate section.

## Still rough (not fixed here)
- The crouch pose: a shallow dip, flat feet, no lead foot (needs Blender).
- Bots never use the Tide Lunge (DEBT), so a bot Gil plays only half of his LMB.
- The rank-0 combo knocks slowly (1.2 times the roster median), and it moves with the bag's order (DEBT).
- A dash pressed during the Riptide spin or the wave does nothing and gives no cue. This is by design
  (content/dash_flow/gil.json: lock), but it reads as a dead key.
- The air long dash plays no Gil clip, only the dust trail. Ground Swim's dive and the Tide Lunge wind and lunge use
  the rig's keyed poses, not hand-keyed clips.
- docs/heroes/gil.md still describes the kit before the rework (the gil-kit-doc follow-up).
