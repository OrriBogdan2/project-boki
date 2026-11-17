# Re-review (round 2): Dancer (`thief`), origin/ext/kitfix-dancer-juggernaut @ dcad1777

**Verdict: PASS (minor nits).** All 8 round-1 items are done or superseded. The owner's LMB is right: ranged bolts from alternating hands that land at the cursor, with a readable arm whip and a gold muzzle flash. The bolas are right too: a gold two-weight whirl overhead, a lane, then Grounded on the first foe and a stun on two. Encore matches its reference section in her violet. The open points are readability nits: overprinted status words on the Bola, a milky Encore fill, and a small bolt.

Shots: /home/claude/review-v4/dancer/v2/ (polish/ is current, from 9d94dfd7, taken on this head; the v2 root and anim/anim are older). The branch has no bolt-in-flight still ("bolt still timing", dcad177), so I took one on dcad1777: /home/claude/review-v4/dancer/v2/reviewer/rr_lmb_bolt_1.0.png (gameplay zoom).

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Readable alternating throw | Done. The arm whips to full extension with the torso turned and a gold muzzle star (frames 2-3), then the other hand (frames 4-6). Small but visible at gameplay zoom. | polish/anim_thf_lmb_close.png, anim_thf_lmb_game.png |
| 2 | Bola whirl overhead | Done. Two gold weights orbit the raised hand during the lane, then the sling. | polish/anim_thf_bola_close.png (frames 1-4), dj_bola_whirl_game.png |
| 3 | Knife spin and blink chain | The spin is done: a back-turned spin, then a side-arm release with a violet streak and a gold flash. The blink chain is partial: cyan round discs trail for about 0.1 s, not silhouettes, and the still catches only one faint disc. | polish/anim_thf_knife_close.png, anim_thf_blink_game.png, dj_blink_game.png |
| 4 | The bolt looks thin | Done, small. In flight it is a gold comet head with a short orange tail, no white, but only about 0.3 m on screen at gameplay zoom. The fizzle at the cursor is a lilac ring in close-up and a pale grey ring at gameplay zoom, with no real puff. | reviewer/rr_lmb_bolt_1.0.png; polish/dj_fizzle_close.png, dj_fizzle_game.png |
| 5 | Gold empowered aim line | Done. A solid gold line with EMPOWERED; the shared pale aim line is hidden (ad601dd7). | polish/dj_primed_game.png |
| 6 | Knock feedback evidence | Done. A crimson four-point star on the foe, green heal rings on her, and +119. | polish/dj_knock_game.png, anim_thf_flourish_close.png |
| 7 | Jackpot volley pose | Superseded. Jackpot is removed: Encore on X replaced it (docs/heroes/thief.md:137), and `thf_volley` went with it. | — |
| 8 | Base long dash | Done. The air move is now the sideways cartwheel, as in the source, not a tumble. | polish/anim_thf_exdash_close.png, anim_thf_vault_close.png |

## New checks
- **Ultimate (Encore).**
  - It matches the reference. A self-centred ring grows 2.3 to 5.4 m (3 bh) over 0.4 s and rides with her. For 2 s a blade flies every 0.4 s at each foe inside (5 at most) for 8 damage, and for 12 from the outer band past 75% of the radius, which also blights for 6 s. She moves and fires freely, and the cast gives the Vault back.
  - Visuals: three violet blades orbit her, the outer band is marked with a gold dashed circle, and it ends in a plain fade.
  - The colour is violet and gold rather than the source's cyan, which is correct for the clean room.
  - Evidence: polish/encore_game.png, encorehit_game.png, anim_thf_encore_close.png, ult/dancer_impact.png.
  - Readability nits:
    - The ring interior is a milky pale lilac wash on the grass. The source tints the interior dark.
    - Blades in flight read as thin near-white streaks at gameplay zoom (ult/dancer_impact.png).
- **Body and dash.**
  - Body: `body.size` 1.11 on light (about 0.95 of a medium), plate 2.15 m, hit_r 0.35 kept, and run pitch about 0.57 (hunter_anim.gd:824). All match the sheet.
  - Vault: 4.5 m in 0.42 s, and from the air 8 m in 0.95 s with the speed carried, both through `travel()`. So the ×0.85 / ×1.15 dash feel applies (about 3.8 m / 0.48 s; the card says "about 4m" and "about 7m"). The burst curve peaks near 0.15 s.
  - Haste +18% (sheet 15-20%).
- **Readability at zoom.** Good for the throw arm, the Bola whirl and lane, the cartwheel, the gold empowered line, the knife marker and the Encore ring. The bolt itself and the fizzle are small and faint (item 4).
- **Effects.**
  - In her violet, gold and cyan, with no white defaults on her projectiles.
  - The knife marker is now a violet ring with ticks, no longer the white circle.
  - The Encore fill and blade trails lean pale (see above).
- **Bugs.**
  - **Bola words overprint.** TANGLED is drawn large across both caught dummies, on top of their stacked STUNNED / GROUNDED words and the damage numbers (polish/dj_bola_game.png, dj_bola_close.png). The owner's 22:55 lesson says status words must not overprint.
  - BLIGHT lands on the Encore damage number (ult/dancer_impact.png).
  - The arena intro panel still says "X · RESET" (polish/dj_primed_game.png; `scripts/match/arena.gd:387`, main's text, fixed on linwick-dredge).
- **Hard-coded keys.**
  - None for X, R or C. d3a9b460 removed the Merge letter, and kit_card.gd uses `Settings.key_cap`.
  - "Press E again" in thief.json (card `e` and E `desc`) is main's shared convention. Flag it to main if E text must go through `key_cap` too.
- **Clean room.** OK. The orange hood, ring blades, gold weights, violet Encore ring and gold band are our own.

## Nits (non-blocking)
1. Move TANGLED above the two stacks (or put it on the cord between them, smaller), and offset BLIGHT from the damage numbers.
2. Grow the bolt head to about 0.45 m with a longer tail, and give the fizzle a real lilac puff that holds about 0.2 s.
3. Make the blink ghosts short silhouettes or streaks that hold about 0.3 s, rather than cyan discs.
4. Darken or tint the Encore interior violet, and give the blade trails her violet instead of near-white.
