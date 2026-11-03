# Kit re-review, round 2: summary (2026-11-02)

Per-hunter files: REVIEW2_<name>.md in this folder. Sources: the branch heads below, the round-1 fix lists in review-v2, the hero-ref ultimate and body sections, the INBOX owner notes from 22:35 onward, the review-v3 shots, and one own capture of Venator on bdebfb1e (at /tmp/claude-0/-home-claude/8d7770c0-fbec-571e-85de-44fde799926f/scratchpad/shots-ven/).

## Verdicts
- **Pin:** PASS (minor nits). All 9 round-1 items are done. Starpiercer is right (teal piercing beams, our own fletch perfect-flash).
- **Bjorn:** PASS (minor nits). The REWORK is resolved: crescent, aegis slab with sigil, upright planted hammer and beam, no toppling in the Smash. Faultline reads well. Nits: the spin trail is faint, and the ult slam bends head-down.
- **Vireo:** PASS (minor nits). All 8 items are done. Kitefall has a ring, a bracket reticle and a pillar landing.
- **Venator:** **FIX.** The round-1 list is done and Cinderfall is strong, but the Slipstep ember after-image is an opaque salmon blob over his body.
- **Linwick:** PASS (minor nits). Fire holds its colour on grass. The owner's ram and air poof are distinct, and Flue Flight steers. It has a hard-coded "X" in its card text (pair-level).
- **Dredge:** **FIX.** The round-1 list is done (anchor, stacked words, rock grab, barge bursts), but the Broadside's two waves of slugs are invisible at gameplay zoom, and the fan is near-white. It also has a hard-coded "X" in its card text.
- **Moosh Moosh:** PASS (minor nits). She is small, weaponless and casts from her palms. Coloured Hearthlight, violet Burrseed, a glide air dash, and Hearth Call works. The ember in flight is faint.
- **Tamsin:** **FIX.** The skate pose stacks the move's lean on the light dash lean (about 60° forward: tipping). The Ice Spear still reads white. Shatter, the darts and Rimelock are good.

## Pairs
- **pin-bjorn (2b3476d6):** **Ready to merge after a one-line text fix.** In `scripts/ui/kit_card.gd:309`, "ready for the Merge on R" should use `Settings.key_cap("ultimate")` (Merge is on T).
- **vireo-venator (bdebfb1e):** **Not ready.** It needs Venator's after-image fix.
- **linwick-dredge (7d96b6df):** **Not ready.** It needs the Dredge Broadside wave visuals and fan colour, and the "X" letters removed from ashwick.json (lines 8, 26) and dredge.json (line 8).
- **moosh-tamsin (4aad615e):** **Not ready.** It needs Tamsin's skate tipping fix and spear colour, and the same "Merge on R" line at kit_card.gd:308.

Merge notes:
- Each branch is up to date with origin/main and merges cleanly into it on its own.
- The branches conflict *with each other*, mostly in docs/wiki/Classes.md and in shared files (hunter_anim.gd, models.gd, kit_card.gd, hunter.gd). All four carry a byte-identical `scripts/arch/hero_ult.gd`.
- There are three different per-hunter nameplate hooks: `Models.hero_body().nameplate` (vv), `Arch.body().plate` (pin-bjorn, moosh-tamsin) and `HeroGearPair.plate_lift` (ld). Main should unify them when merging the second pair.
- Main's own `arena.gd` still says "X reset" / "X · RESET" while the reset key is Backspace; only linwick-dredge fixed it.

## Best shots for the owner
- **Pin**
  - /home/claude/review-v3/pin/v2/polish/pin_perfect_close.png
  - /home/claude/review-v3/pin/v2/polish/pin_super_flight.png
  - /home/claude/review-v3/pin/v2/polish/ult_pin_impact.png
- **Bjorn**
  - /home/claude/review-v3/bjorn/v2/polish/bjorn_slam.png
  - /home/claude/review-v3/bjorn/v2/polish/bjorn_aegis_block_close.png
  - /home/claude/review-v3/bjorn/v2/polish/ult_bjorn_impact.png
- **Vireo**
  - /home/claude/review-v3/vireo/v2/ult/vireo_ult_aim.png
  - /home/claude/review-v3/vireo/v2/ult/vireo_ult_impact.png
  - /home/claude/review-v3/vireo/v2/polish/vireo_e_count.png
- **Venator**
  - /home/claude/review-v3/venator/v2/ult/venator_ult_aim.png
  - /home/claude/review-v3/venator/v2/ult/venator_ult_impact.png
  - /home/claude/review-v3/venator/v2/ult/venator_ult_anim.png
- **Linwick**
  - /home/claude/review-v3/linwick/v2/polish/lw_lance_stream_game.png
  - /home/claude/review-v3/linwick/v2/polish/lw_anim_cloak.png
  - /home/claude/review-v3/linwick/v2/ult/linwick_ult_impact.png
- **Dredge**
  - /home/claude/review-v3/dredge/v2/polish/dr_anim_barge.png
  - /home/claude/review-v3/dredge/v2/polish/dr_grapnel_over_rock_game.png
  - /home/claude/review-v3/dredge/v2/polish/dr_anim_air_anchor.png
- **Moosh Moosh**
  - /home/claude/review-v3/moosh-moosh/v2/polish/tender_rmb_root_game.png
  - /home/claude/review-v3/moosh-moosh/v2/polish/tender_air_strip_close.png
  - /home/claude/review-v3/moosh-moosh/v2/polish/tender_ult_strip_game.png
- **Tamsin**
  - /home/claude/review-v3/tamsin/v2/polish/rimewright_shatter_game.png
  - /home/claude/review-v3/tamsin/v2/polish/rimewright_ultkey_game.png
  - /home/claude/review-v3/tamsin/v2/polish/rimewright_ult_crash_game.png
