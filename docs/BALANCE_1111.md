# Duel balance, 12 x 12 (2026-11-11, base ext/release-integ-0245 92df78ce4)

PARITY FIRST (briefs/DECISIONS.md 2026-11-07): the numbers below are read against the source before
any tuning. Two kinds of finding are kept apart:
- **differs from source**: our number or rule is not the source's. Fix: back to the source.
- **source-faithful but broken in our build**: our kit matches the source and still comes out
  lopsided here. Fix: none in the kit; the cause is said and left for the owner.

## The simulator

`godot --headless -- --duel-sim --sim-n=12 [--sim-diff=hard] [--sim-out=fights.jsonl] [--sim-arch=a,b]`
(`tools/duel_sim.gd`, registered in the check registry). Every ordered pairing of the 12 launch
Hunters, mirrors included, fights n times in the Duel room: 144 x 12 = 1,728 fights.

- **Same skill tier:** both fighters are fresh bots with the same `Data.BOT_DIFF` row (hard) and
  the same mind (the per-mind skill jitter of +-0.1 is seeded). The difficulty's damage multiplier
  is set to 1.0 on both: the game only applies it to bots, never the player, and here it would only
  shrink everyone.
- **Kits only:** rank 1 in every slot, level 1, full health, no Boki (its random species, level and
  owner health bonus would tilt a pairing), no belt (tonics, armour kits), no gear, truces off.
- **Fair sides:** odd fights swap the two spawn spots and which bot steps first. The matrix pools
  a-vs-b and b-vs-a, so what is left of the side bias cancels. The run prints the bias.
- **End:** the first knock, or a draw at 60 s. Time to knock is the winner's fight length.
- **Damage by ability:** hits tagged primary/shot/melee count as LMB, ult tags as R/X, dash/dodge
  tags as the dash; any other hit goes to the slot whose cooldown last started (`ArchKit.cd`,
  an RMB charge spent). DoTs and zones that outlast the next cast can land in the wrong slot.
- **Checks:** exit 1 if a Hunter never lands damage or over a third of fights time out.

### What had to be fixed before the numbers meant anything
The first version reused the player (on autopilot) as fighter a against the Duel room's bot, and
the player's side won 72 to 100% of mirror fights. Causes found, in order:
1. The player starts with 2 tonics and 2 armour kits on the belt; the sparring bot gets none
   (`Duel.spawn_bot` sets `tonics = 0`). Bots drink mid-fight.
2. A knock gives the winner XP: the reused player levelled (health, power, ranks) fight to fight.
3. Damage dealt fills the armour tier (`Hunter.armor_gain`), which also carried over.
4. With the tier reset, the two bot "squads" agreed a **Truce** (`truce.gd`) and stood still for
   the rest of the run: the pact lasts 180 s and outlived the respawn.
5. What was left (about 70%) came with the reused entity (facing, statuses, update order). Both
   fighters are now fresh bots built the same way; the residual bias is in the results.

Items 1 and 4 also touch the real Duel room (a human must accept a truce, so 4 needs a bot-only
duel; 1 gives the human the tonics). Not changed here: the Duel room is a practice space.
Also seen: shots and delayed callbacks of a freed bot still fire (`Match._shot_apply` "previously
freed instance", `_run_later` freed lambda capture); in the Duel room this happens when the bot is
changed mid-shot. The sim clears the shots; the game is unchanged (filed below).
