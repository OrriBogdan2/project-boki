# Re-review (round 2): Zedran (`juggernaut`), origin/ext/kitfix-dancer-juggernaut @ dcad1777

**Verdict: PASS (minor nits).** All 8 round-1 items are done; two were reshaped by the source (the crash became the sweet-spot reset). The Warchain is now a striped orange and iron link chain, and the Searing Wave is a red flame crescent. The Enraged ground disc is gone, and the Rampage has its crouch and flame streaks. The owner's RMB hold reads well: a crouch, a lane that grows red then magenta with a flash at full, jump allowed, and a 4.5 to 7.5 m fling. Gilded Riposte matches its reference section in his gold.

Shots: /home/claude/review-v4/zedran/v2/ (polish/ is current, from 9d94dfd7, taken on this head; the v2 root and anim/anim are older).

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Warchain look | Done. Alternating orange and dark links, readable at gameplay zoom, with a CHAINED word on the hook. In flight it is the same striped chain; no zig-zag shows in the still (nit). | polish/dj_chain_game.png, dj_chain_fly_game.png, dj_chain_fly_close.png |
| 2 | Searing Wave as a red flame crescent | Done. A red crescent with an orange inner edge and a red flame head, no white core. | polish/dj_wave_game.png, dj_wave_close.png |
| 3 | Slash crescent and tip star | Mostly done. The magenta-edged, yellow-filled crescent is about 2.2 m and reads at gameplay zoom in strip frames 4-5. Two weak spots: the gameplay still catches only a faint tan arc, and strip frames 2-3 show a near-white swoosh (probably the shared melee trail). There is still no tip-star shot. | polish/anim_jug_slash_game.png, dj_slash_close.png, dj_slash_game.png |
| 4 | Pale disc under him | Done. Enraged is embers on his body and the ENRAGED word, with no ground disc. | polish/dj_enraged_game.png |
| 5 | Jump-while-charging evidence | Done. The air-lunge strip shows the coil, the lane, the full-charge flash and the fling. From the top-down camera the height itself is hard to read. | polish/anim_jug_lunge_air_game.png / _close.png, dj_lunge_air_game.png |
| 6 | Rampage flame streaks | Done. Orange flame streaks and a flame crescent, a crouch before the drive, and TIP 21 on the tip hit. | polish/dj_rampage_game.png, anim_jug_dash_close.png |
| 7 | Crash ring | Done (reshaped). The crash fold is gone (docs/heroes/juggernaut.md). The sweet spot now has a red-orange shock ring with a spark. | polish/dj_sweet_game.png |
| 8 | Execute red outline | Done as a red ring at the wounded foe's feet (`_tick_tells`, juggernaut_kit.gd:851). It reads in close-up but blends with the dummy's own pink ring at gameplay zoom. | polish/dj_exec_close.png, dj_exec_game.png |

## New checks
- **Ultimate (Gilded Riposte).**
  - It matches the reference: tap, a 0.65 s planted invulnerable guard with a gold body shell and the blade upright, and a gold 1.8 × 3.6 m strip shown to everyone. Then a 1.8 m lunge and an upward cleave for 34 that heals 80%. Blocked hits add +20% each (two at most), and a knock resets it. The bond is fed through `HeroUlt.landed`.
  - Telegraph: polish/riposte_game.png shows the guard and the strip clearly.
  - Impact: ult/zedran_impact.png has a strong gold-white flash, but in polish/ripostehit_game.png the cleave barely shows.
  - The colour is gold rather than the source's red, which is correct for the clean room.
- **Body and dash.**
  - Body: `body.size` 0.95 on heavy (about 1.12 of a medium), plate 2.75 m, hit_r unchanged, and run pitch about 0.35 (hunter_anim.gd:826). All match the sheet.
  - Rampage: a 0.15 s crouch, then 4.5 m in 0.3 s through `travel()`, so ×0.85 / ×1.15 applies (about 3.8 m). The direction is `dash_dir()` taken at the press (dcad177, and `--dash-dir-check` covers it).
  - The Lunge lane applies the `dash_feel` multiplier (juggernaut_kit.gd:546), so the preview matches the real travel.
  - Run cadence is unchanged; that stays main's global call.
- **Readability at zoom.** Good for the chain, wave, Rampage, lunge lane, slam lane, sweet ring and guard. The slash is fainter (item 3).
- **Effects.** Orange, red, magenta and gold, with no white defaults, apart from two exceptions:
  - The full-charge Lunge flash is a white-cored orb at his hand (anim_jug_lunge_close.png frame 3; see Vireo's identical nit).
  - The near-white swoosh on the first slash frames.
- **Bugs.**
  - Words overprint:
    - "BOND +60%" lands on the damage number (polish/ripostehit_game.png, _close.png). That toast is main's `kin_bond.gd:54`, so it is pair-wide, not this kit.
    - SWEET SPOT over its 26 (dj_sweet_game.png).
    - CRUSHED partly over STUNNED in the Meteor strip.
  - The arena intro panel still says "X · RESET" (`scripts/match/arena.gd:387`, main's text; linwick-dredge fixes it).
  - No tipping, and no ground disc.
- **Hard-coded keys.**
  - None for X, R or C. kit_card.gd uses `Settings.key_cap("ultimate")` / `hunter_ult`, and d3a9b460 removed the Merge letter.
  - "Press E again" in juggernaut.json (card `e` and E `desc`) is the convention main and every branch share. Flag it to main if E text must also go through `key_cap`.
- **Clean room.** OK. The horned helm, orange pauldrons, the striped chain and the gold Riposte are our own.

## Nits (non-blocking)
1. Hold the slash crescent a little longer, or retime dj_slash_game so the gameplay still shows it, and tint or hide the shared white swing trail under it. Add a tip-star shot.
2. Tint the white core of the full-charge Lunge flash magenta.
3. Offset SWEET SPOT and CRUSHED from the damage numbers. The BOND toast is for main.
4. A thicker or brighter execute ring so it separates from team rings at gameplay zoom.
