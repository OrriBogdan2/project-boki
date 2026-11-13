# 0008: Losing a Boki

- **Status:** accepted (owner decisions of Nov 2 2026)
- **Date:** 2026-11-02
- **Area:** match flow / networking / save (Boki side only; the market UI is another team's)

## Problem
Boki dropped into the deathbox and were looted or teleported home. The owner wants loss to be visible, in the world, and recoverable by play, and only at the high tiers.

## Options
1. Keep the box: Boki sit in the deathbox, a looter takes them. Rejected: invisible, and a free steal.
2. Boki stays where it fell and guards; a scan takes it; a bond pull lets the owner hunt it (decided).

## Decision
Code: `scripts/kin/kin_loss.gd` (rules, drop, save hook), `scripts/kin/kin_track.gd` (the pull), `scripts/ui/bond_hud.gd`. Numbers: `content/rules/boki_system.json` "loss".
- **Safe tiers.** Tiers below `loss_min_tier` (2, so 0 and 1) cannot lose a Boki: on death it keeps out of sight ("away") and goes home with its owner.
- **Higher tiers.** When a hunter dies their Boki drops dazed and guards. One that was on them stands beside the deathbox; one that was out fighting stays where it stood. Nothing teleports, and reviving the owner does not call it back. The owner runs into it and the existing 3.5s cradle (`KinDowned`) starts: they pick it up into their arms and carry it while it fills, and it is theirs again at the end. An enemy scans it with the normal capture (it is a dazed Boki with an owner); the owner and teammates cannot scan it.
- **Bond pull.** While an enemy carries your captured Boki, you and your squad, once up, see "<Boki> is this way" at the captor and their spot pings on the squad map every `bond_ping_s` (15). The captor sees "Tracked". Knocked or killed, the captor drops it dazed on the spot (before their box is made) and the owner can cradle it. The pull ends when the captor extracts.
- **After the match.** `KinLoss.after_match(save, boki, outcome)` writes the result on the Boki's record: "home" clears flags; "ransom" (nobody took it) sets `ransom: {match, t}`; "captured_by:<name>" sets `lost_to: {by, match, t}`. Both fields are optional, so old saves load unchanged. A flagged Boki is skipped by `Save.active_kin()` and `second_kin()` until `KinLoss.clear()`. `Game.apply_result` calls it, then still files the Boki at the Ransom House as before; `Ransom.restore` clears the flags. A Boki left guarding when its owner extracts is ransomed too.

- **Carrying while you rescue.** The cradle no longer roots you (a downed Boki is rescued the same way). You walk at `carry_speed_k` (0.9) of normal speed with the Boki in your arms (its spot follows you; the render holds it at chest height). Jump, glide, firing and every ability are blocked while you carry (pressing them does nothing). Shift (dash) or interact (F) puts it down where you stand on purpose: that press is spent on the drop (no dash happens), the progress is lost, and it is not picked up again until you step away from it or press interact. Running into it picks it up only when no foe is within 6m (else press interact) and not in the middle of a scan, a box revive, a drink/kit/base channel or while carrying a teammate. The HUD shows "Carrying <name> · Shift to drop". Hard crowd control (stun, root, Grounded, a launch or a real knock) drops it: it falls back down where you stand, still downed or guarding, and the progress is lost. Shots and the small shove of most hits do not. An enemy within `contest_r` (1.2m) pauses the progress and blocks a new pick-up. The progress drain (`rescue_drain_s`) and the kneel pose are gone; `rs_carry` replaces them.

## Consequences
- Net.VERSION 0.17.0 to 0.18.0: a new "guard" event (a client's Boki now guards: uid and record, so the host's copy of it is scanned as the real Boki), the "caught" event carries the Boki's owner (that starts the bond in every game), kcmd "unbond", and a new "gdrop" event (a captor fell: the owner's own game stands the Boki up again, reusing its original id so the owner's game owns it). Guard state rides the ordinary kin snapshot (state "dazed" plus an owner). The drop itself is run by the owner's game; the online death path now also respects the tiers (it used to leave Boki at every tier).
- Removed: Boki inside deathboxes (`Life._kin_from_box`, `Data.TIERS` flags `risk_kin`/`kin_drop`/`loose_capture`), the "loose kin comes running back" teleport in `bring_back`, the random "someone nearby grabs it" at match end, `Match._leave_one_kin`.
- Online: the captor's own game adds the bond when it hears "caught" and sends "unbond" when it lets go; the owner's game records who holds the Boki and stands the dropped one up again. A carried Boki rides its owner's position in the ordinary kin snapshot (progress already rides it), so other players see it in their arms with no new field. `--kin-loss-check` drives those handlers by hand (no sockets).
- Open: the market UI should read `ransom` / `lost_to` and call `KinLoss.clear`.

## Leaving from the Esc menu (2026-11-08)
`LeaveMatch` (scripts/match/leave_match.gd) makes the Leave dialog say what really happens, by match type. Training Area, Arena, duel room and tutorial: plain "Leave?", nothing changes. Expeditions below `loss_min_tier` (the "early" matches: The Meadow, Dusk Isles): the Boki come home but each loses `leave_trust_loss` (6) trust and remembers it ("left" on the kin card), on top of the usual -1 for a lost match. The Hollow and up: the Boki are left behind through the same `KinLoss.on_owner_out` path as going down, so they end up ransomed. Leaving used to leave nothing behind at any tier, so the old warning was false.
