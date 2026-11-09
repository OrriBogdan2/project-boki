# Combat rules: status stacking

What happens when two casters put the same status on one body. Parity with the source first (DECISIONS
2026-11-07): owner > data > wiki > footage. The numbers are in `content/rules/status_stacking.json`, the code
is `scripts/combat/stacks.gd` (stack counts, merge rules) and `Ent.add_slow` / `Ent.add_burn` / `Ent.hurt`
(crowd control), and `--status-stacking-check` has one case per kind with two casters on one dummy.

## What the source says

The data and the footage are thin here. Nothing in `supervive-data` or the `hero-ref` strips shows two
casters on one body, and no source text gives a stacking or refresh rule for slows or stuns. What they do
settle:

- **Counts belong to the target.** Static, Shatter and Burning are statuses *on the body*: "Attacks and spells
  apply Static. At 4 stacks the target is fully Static Charged" (Vireo [D]); Thunderstorm "spreads its Static
  stacks to nearby enemies" ([D] kits); "hits add Shatter; at 8 stacks it detonates", the ult's slow "stacks
  for up to 3.5 s" (Tamsin [D]); "push Burning into Blazing" (Linwick [F]). One marker over the head, one
  count, whoever put it there [F].
- **Marks belong to the caster.** The Thief's passive is the caster's own: "deal +16 dmg for each Arcslinger
  hit (stacking)" ([D] kits, Malice and Resolve); the footage shows no counter on the target (Dancer [F]).
- **Stuns and slows show once.** One STUNNED word and one SLOWED word per body [F]; a stun reads about 1 s
  (Breah, Bjorn, Dredge [F]) and is not seen to grow when a second hit lands.

Where the source is silent (slow strength, stun time) we took the simplest rule that never makes two
casters stronger than one: the strongest wins. Alternative if the owner finds otherwise: add the
durations (stun) or multiply the speeds (slow); both are one word in the JSON (`combine`, `time`).

## The rules

| Kind | Two casters give | Count shared? | Time |
|---|---|---|---|
| Slow | the stronger slow; never added, never multiplied | one slow per body | the longer of what is left and the new time |
| Stun | (no strength) | one stun per body | the longer of the two: a stun **refreshes** to the longer, it never **extends** (1.0 s left + 1.5 s lands as 1.5 s) |
| Root | as stun | one per body | the longer |
| Burn | the stronger damage per second; the one who set the strongest is credited | one burn per body | the longer; a burn that ran out leaves no strength behind |
| Static (Sparkle) | counts add, up to 4 | **yes**, one count on the body | each hit resets it to 4.5 s |
| Shatter darts (Tamsin) | counts add, 8 bursts | **yes** | each dart resets it to 3 s |
| Chill (Tamsin) | one status | **yes** | each hit resets it to 4 s |
| Char (Cinder) | amounts add; at the top the foe is Ablaze and the Char is spent | **yes** | each add resets it |
| Ignite (Cinder) | the higher stage (Ablaze, Flashover); a stoke from either caster raises the shared stage | **yes** | the longer |
| Marks (Thief) | each caster's Marks add to her own | **no**, one count per caster | each hit refreshes hers |

Whoever lands the hit that completes a shared count gets its payoff (the sky bolt on the 4th Static, the
Shatter burst on the 8th dart, the Ablaze on the top Char).

Diminishing returns (`KinRules.DR_STEPS`) are per body, not per caster, and still apply on top for
ability crowd control; they are ours, not from the source (see DEBT).

## Net

The body's own game applies every status. A remote body is a proxy in the caster's game, so shared stack counts
are shared among the casters in *one* game; across two games each keeps its own view of a remote body until the
body's game sends the count. The Net shape is unchanged (`kst`, `hit`), so `Net.VERSION` is not bumped.
