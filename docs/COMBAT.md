# Combat rules: what crowd control forbids

How long each status lasts is in `docs/KIT_PARITY.md` (Crowd control). This file covers **what each status
forbids**. The rule is data: `content/rules/cc_lockouts.json`, read by `CcLockout.blocks()`
(`scripts/combat/cc_lockout.gd`). The gates that ask it: `Hunter.do_jump`, `do_dash`, `can_glide` and the
held-glide opener, the crouch and walking lines, `can_fire` (LMB), `ArchKit.busy()` (RMB, E, R), the belt
press (`UtilityBelt.press`), Ryzz's dash and wire, and Zedran's chain pull (a move that travels).

Sources: `[D]` the game card text (`briefs/supervive-data/supervive_kits.md`), `[W]` the wiki table in
`docs/SUPERVIVE_DATA.md` §4, `[F]` the hero-ref footage (5 fps). Order: owner > data > wiki > footage.

| Status | Source rule | Walk | Dash | LMB | RMB/E/R | Jump | Glide | Crouch | Drink | Was (main d255acbee) |
|---|---|---|---|---|---|---|---|---|---|---|
| Stun (also Spike, Dunk) | "No movement, no air control, no abilities" [W] | no | no | no | no | no | no | **no** | **no** | crouch and belt items were allowed |
| Daze | "Ghost's version of stun", 1.2 / 2.0 s [W]; card: "dazes", bonus damage [D] | **no** | **no** | **no** | **no** | **no** | **no** | **no** | **no** | a damage window only, nothing forbidden |
| Root | "Can't move" [W] | no | no | yes | yes | **no** | **no** | yes | yes | Space still jumped; a held glide opened in a fall |
| Grounded | "no jumping/dashing up" [D]; "can't use movement abilities" [W] | yes | no | yes | yes (not a move that travels) | no | **no** | yes | yes | a held glide still opened in a fall |
| Slow | movespeed only [W] | slower | yes | yes | yes | yes | yes | yes | yes | match |
| Knock-up / knockback | "you can steer it with WASD" [W] | steer | yes | yes | yes | yes | after 0.4 s (ours, glider feel) | n/a | yes | match |
| Static | stacks to a charge, no lockout [D,F] | yes | yes | yes | yes | yes | yes | yes | yes | match |
| Chill | stacks for Shatter, no lockout [D] (our 15% slow is an ours-only rider, KIT_PARITY #19) | yes | yes | yes | yes | yes | yes | yes | yes | match |
| Silence | "No abilities, powers or consumables" [W] | | | | | | | | | not in our game (no kit applies it) |

Bold = changed on 11-09; each change has one assert in `--air-limits-check` (section 4).

Notes and calls made without the owner:
- **Drink under a stun.** The wiki's stun row lists abilities, not consumables; Silence, a lighter status,
  already forbids consumables, so a stun forbids the belt too. Alternative: allow the belt under a stun.
- **Daze.** The card only says "dazes" with a damage bonus; the wiki defines it as Ghost's stun, and its
  1.2 / 2.0 s durations match ours (1.4 s, +0.6 s on a wall). Wiki outranks a silent card, so a Daze now
  locks like a stun (no slow). A Daze already running doesn't cancel a cast in progress (a stun does).
  Alternative: the old damage-window-only Daze; delete the `daze` row in the JSON.
- **Root and glide.** "Can't move" covers opening a glider; a rooted glider closes like a stunned one.
- **Grounded and abilities that move.** "Movement abilities" are blocked by the `travel` act; only Ryzz's
  dash and Zedran's chain pull ask it today. Other kits' moving abilities are in `docs/DEBT.md`.
- Hex (ours) and a Dredge's own reel are not source CC; they keep their own gates.
