# Wisp design pass: the open logic questions (recommendation + one alternative each)

Owner decision: briefs/DECISIONS.md "2026-11-09 owner: Soul-linked Boki ride with you as wisps" and its
addendum. Art side: WISP_ART_BRIEF.md. Tutorial side: TUTORIAL_COMBAT_V2.md. Written 2026-11-09 by a
worker session (synth), from the game repo at main d255acbee.

What this pass read in the game: docs/decisions/0019-downed-wisp.md (the Hunter Wisp), docs/BOKI_IDENTITY.md,
docs/KIN_GRAMMAR.md (KinSpec, carry passives, the merge, KinRules), docs/KINFALL_CLASSES.md, docs/wiki/Lore.md,
docs/wiki/Rules.md (down, death and revive), content/kin_v2 (50 species: `body.size`, `ai.role`, `carry`),
content/merges_v2 (durations 6 to 10 s), content/rules/kin_ai.json (leash), capture.json, revive.json, bond.json,
scripts/kin/parts.gd (`OWNER_STATS` carry caps), scripts/core/settings.gd (the key list).

## Facts the answers lean on

| Fact | Value | Where |
|---|---|---|
| Downed Hunter bleeds out in | 15 s | Rules.md, `Life.R.bleed_out` |
| Teammate revive / Boki revive | 4 s / 8 s | Rules.md, Expeditions.md |
| Merge (R, the bond ultimate) lasts | 4 to 10 s (6 to 10 in data) | KinParts.MERGE, content/merges_v2 |
| Kin ability cooldowns | 1 to 60 s | AbilitySpec `cooldown` |
| Kin AI leash today | 9 + 8 x aggression - 4 x loyalty m (5 to 17) | content/rules/kin_ai.json |
| Carry caps (own Boki) | per stat, e.g. move_speed 0.15, damage_reduction 0.15, regen 3 hp/s | KinParts.OWNER_STATS carry_max |
| Carried kin lends its E at | 85 % power (100 % when out) | KIN_GRAMMAR "Who performs it" |
| Boki roles | bruiser, skirmisher, trickster, controller, tank, support | KinSpec `ai.role` |
| Body sizes | small (shoulder), medium (perch), large (mount) | KinSpec `body.size`, `carry.style` |
| Boki key | `throw`: tap = send/recall, hold = order wheel (C or middle mouse) | settings.gd ACTIONS |
| Run box | 3 captured wild Boki per run | capture.json `box_capacity` |

## Principles (so every answer below pulls the same way)

1. **One button, one ring.** Everything about your Boki in a match is the Boki key and one ring on the Boki slot.
   Nothing new on the HUD (owner: "show only what's needed right now").
2. **Short and strong vs long and supportive is the Boki's identity.** The numbers are data on the species, shown
   on its Field Book card, never a hidden formula.
3. **Nothing is ever lost.** Every steal rule ends with "goes home at match end".
4. **Round = Hunter, critter = Boki.** Any new state (guardian, stolen, killed summon) must keep that readable.
5. **Cheap.** A wisp is a sprite plus a few motes. The full Boki exists only while summoned.

---

## Q1. Per-Boki summon duration and cooldown

**Recommend: data per species, derived from role and size, inside a checked uptime band.**

Add to KinSpec: `"summon": {"duration": s, "cooldown": s}` (bounds in KinParts: duration 5 to 24 s, cooldown 40
to 100 s). `--grammar-check` enforces an uptime band: `duration / (duration + cooldown)` between 0.09 and 0.20.
Short and strong Boki sit at the bottom of the band, long and supportive at the top. A species file that leaves
`summon` out gets the role x size default below, so the 50 existing species need no edits to prototype.

Tempo word for the Field Book card (derived, not data): **Burst** (duration <= 9 s), **Steady** (10 to 14 s),
**Long** (>= 15 s). Card line: "Burst: out for 8 s, rests 60 s."

### Default table (role x size). Cells are duration s / cooldown s, with the range a species may tune inside.

| Role | small (shoulder) | medium (perch) | large (mount) | What the window is for |
|---|---|---|---|---|
| bruiser | 8 / 60 (6-10 / 55-65) | 10 / 65 (8-12 / 60-70) | 12 / 70 (10-14 / 65-75) | hit hard, then gone |
| skirmisher | 7 / 55 (6-9 / 50-60) | 9 / 60 (7-11 / 55-65) | 11 / 65 (9-13 / 60-70) | one dive or one chase |
| trickster | 8 / 55 (6-10 / 50-60) | 10 / 60 (8-12 / 55-65) | 12 / 65 (10-14 / 60-70) | a swap, a blink, an escape |
| controller | 11 / 65 (9-13 / 60-70) | 13 / 70 (11-15 / 65-75) | 15 / 75 (13-17 / 70-80) | hold a zone for one fight |
| tank | 14 / 75 (12-16 / 70-80) | 16 / 80 (14-18 / 75-85) | 18 / 85 (16-20 / 80-90) | a wall you fight behind |
| support | 16 / 80 (14-18 / 75-85) | 18 / 85 (16-20 / 80-90) | 20 / 90 (18-22 / 85-95) | heal and buff the whole fight |

Uptime runs from 11 % (small skirmisher) to 18 % (large support). A Boki is out for roughly one fight in six,
which keeps the summon a decision, like a flash, not a toggle.

### Ten example species (all exist in content/kin_v2)

| Species | theme / role / size | duration | cooldown | tempo | Why |
|---|---|---|---|---|---|
| Cindle | venom bruiser small | 8 | 60 | Burst | Stinger Hook pulls one foe in, bites, leaves |
| Zapple | echo skirmisher small | 7 | 55 | Burst | Chain Spark on a pack, then back to your shoulder |
| Opalisk | prism trickster small | 8 | 55 | Burst | Moon Swap: one escape or one gank |
| Glintmole | stone controller small | 11 | 65 | Steady | lays Puffcap Mines across a lane |
| Nimbostrich | storm skirmisher large (mount) | 11 | 65 | Steady | summon, hop on, Thunder Run across a gap |
| Nacrolin | prism tank medium | 16 | 80 | Long | Prism Wall you fight from behind |
| Puddlet | prism support small | 16 | 80 | Long | Glimmer regen for a whole fight |
| Cairnback | titan tank large (mount) | 18 | 85 | Long | Boulder Heave, Rock Guard, a rideable wall |
| Moonloris | lunar support medium | 18 | 85 | Long | Night Eyes: reveals and heals while it's out |
| Lilybara | bloom support large (mount) | 20 | 90 | Long | Lily Raft: a mobile healing platform |

Mounts: a summoned large Boki kneels for the first second; press the Boki key again to ride it for the rest of the
window (today's `carry.mount` speed/jump/turn, no gliding while mounted). When the timer ends you slide off and it
shrinks back. So "mount" stays part of a large Boki's identity without ever being a permanent ride.

Ranks and levels: **don't touch the summon numbers.** The card says 8 s / 60 s and it is always 8 s / 60 s. (Kin
slot ranks keep shortening ability cooldowns 10 % a rank as today.) Reason: the owner wants the duration readable
as identity, and a number that drifts with rank stops being one.

**Alternative:** three fixed tempo presets only (`"summon": "burst" | "steady" | "long"` = 8/60, 12/70, 18/85),
no per-species numbers. Simpler to balance and to read, but every small bruiser is identical and the "10 example
species" column collapses to three rows. Pick this if the prototype shows players never read the seconds.

---

## Q2. Ultimate (R, the merge) interaction

**Recommend: R stays the merge, independent of the summon, and it always works from the wisp.**

- Wisp + R (bond full): the wisp blooms straight into the merged form (today's fuse, 0.7 s invulnerable
  transformation). Merge duration from content/merges_v2 as now. When the merge ends the Boki is a wisp again.
  The summon cooldown is **not** touched by a merge: R and the Boki key are two separate resources.
- Summoned + R: the Boki leaps to you and fuses (today's leap-merge from out). The summon window ends there and
  its cooldown starts at once. Press R mid-summon only if you want the merge now; otherwise let the summon finish.
- The "longer summon" the owner floated is what the **stat merges** already are for the six Boki whose merge
  forms aren't built (KIN_GRAMMAR: "the other six keep the stat merge"): for them, R reads on the HUD as "SOUL
  SURGE: <name> out for 10 s, stronger", runs as a summon of merge length with the merge passives on you, and
  needs no new system.
- Guardian summon (Q4) never consumes the bond meter.

**Alternative:** R = a long summon (2 x duration) for everyone and the merged form is cut. Removes a system but
throws away content/merges_v2, the three built merge forms and decision 0001/0003. Not recommended.

---

## Q3. Multiple Boki: how many out at once

**Recommend: one summoned Boki at a time, per Hunter, in every tier. More Boki means more summons, never more
bodies.**

- Your soul-linked Boki, a stolen wisp (Q6) and any future second slot all share **one summon lane**: the Boki key
  summons whichever wisp is selected, and the lane is busy until that form ends.
- Selecting: tap cycles nothing. The Boki key always summons **your own** Boki when it is ready; **hold** opens the
  order wheel as today, and stolen wisps appear on that wheel as extra slices ("Summon stolen <name>"). One
  button, no new binding, no HUD slot per wisp.
- **Wild Boki caught mid-run** (the run box, 3 capsules) are **not summonable**: they are scanned, not soul-linked.
  Lore: "a linked soul takes form when called"; an unlinked one can't. They stay capsules and go home at
  extraction as today. This also avoids a run where a lucky early catch of a tank doubles your kit.
- **Early recall:** tapping the Boki key while your Boki is out recalls it early; the cooldown is the full one
  either way. (You'd recall to stop it chasing into a bad fight, not to cheat the clock.)
- **Dungeon tier:** no second lane at any tier for the prototype. Deeper tiers already raise the level cap
  (KinRules.LEVEL_CAP 15/25/35 %); a second body on screen is the single most expensive thing for the 60-character
  perf budget and the hardest to read.

**Alternative:** two lanes in the Hollow tier only (own + one stolen at once). Gives the deepest tier a reward
and a reason to steal. Cost: double the animated Boki in the worst fights, and the tutorial can't teach it.
Revisit after the perf numbers from the prototype.

---

## Q4. Summon while downed, and the guardian summon

**Recommend: you can't press Summon while downed. The guardian summon does it for you. Yes to the guardian, with
these numbers.**

- **Trigger:** the moment you are knocked, if your Boki's summon is **ready** (not on cooldown, not already out).
  It bursts out beside your Hunter Wisp. If the summon is on cooldown, nothing happens and your Boki wisp breaks
  loose at once (owner's base rule). That makes "did I waste my summon?" a real decision before a fight.
- **Window:** the species' own duration, clamped to 8 to 15 s (a 7 s Zapple guardian gets 8; a 20 s Lilybara
  guardian gets 15, because 15 s is the whole bleed-out). It uses the summon and starts the full cooldown.
- **What it does:** fights within 6 m of your Hunter Wisp (leash, Q7), uses its auto skill, and pulls you up in 8 s
  **only if no teammate is standing on you**: a teammate on you is always the faster revive (4 s) and the Boki
  guards instead. An enemy stomp (hold interact on your wisp) breaks the Boki's revive channel, as today.
  Guardian form is AI only (no E from the downed player).
- **Stealing interaction:** while the guardian window is open your Boki wisp is **not loose**: it is the guardian.
  Your wisps scatter when the window ends (timer, or the Boki is killed) with you still downed, or when you die.
  If you are revived inside the window, the Boki finishes its window beside you, then returns as a wisp on
  cooldown. One body, one rule: a Boki is a wisp, a summon, a guardian or loose, never two at once.
- **Duos/trios strength check:** in solos the guardian is today's "your Boki pulls you up in 8 s" with a cooldown
  attached, so it is **weaker** than live. In duos it adds a body that can hold a stomper off for up to 15 s while
  the partner revives in 4 s. Limits so it isn't a free win: guardian form takes +25 % damage and the kill of a
  guardian gives the killer's squad the normal takedown heal; a stomper who is already on you is not knocked off
  by the burst (the burst has no knockback). If duo data still shows it too strong: cap the guardian window at
  10 s in squads (one number).
- **Readability:** same bloom as a summon, framed white: the Boki lands with a white guardian ring on the ground
  around your round Hunter Wisp, the HUD ring turns white and reads GUARDIAN with the seconds, and the Boki barks
  one `guard` line (BOKI_TALK triggers). Enemies see the white ring too, so "kill the Boki or stomp fast" is legible.

**Alternative:** no guardian; downed Hunters' wisps always scatter at once, and the Boki's 8 s revive is cut.
Simplest rule set and the most readable. It loses the fantasy the owner leans to and makes solos strictly worse
than live. If the duos check fails twice, fall back to this rather than tuning forever.

---

## Q5. Damage to the summoned form

**Recommend (owner's lean, with numbers): damage never ends a summon; death does. A killed summon turns back into
a wisp and flies home, revealing you for 2 s. It is stealable only if you are downed or dead.**

- Summoned Boki health: `kin_hp` as today (budget points, level growth, IVs). No change.
- **Killed while you stand:** it pops to a wisp at the spot, flies to you in a straight line at 25 m/s (a visible
  streak), and for 2 s you are **revealed** to the squad that killed it (the outline the reveal passives already
  use). Its cooldown is the full cooldown **x 1.25** (the "longer cooldown" the owner asked about): a 60 s Boki
  comes back in 75 s. Letting it die should cost more than recalling it.
- **Killed while you are downed or dead:** it becomes a **loose wisp** at the spot (stealable, Q6 rules). This is
  also how a beaten guardian ends.
- **Timer ran out or early recall:** full cooldown, no penalty, no reveal.
- The wisp itself has **no hitbox** and can't be damaged, only grabbed when loose.

**Alternative:** a killed summon is stealable wherever its owner is. Harsher, more hunting of the Boki, and it
makes the Boki a liability the owner didn't ask for. Not recommended for the default; possible in the later
hardcore tier.

---

## Q6. Stolen wisps: grabbing, summoning, length

**Recommend: stolen wisps can be summoned once, for half their duration, and then ride as passive-only.**

- **Loose wisp:** floats 10 s at shoulder height where it broke loose (bouncy, in the Boki's colours). Anyone
  within 2 m holds interact 0.6 s to grab it (the owner too, if revived in time). Ungrabbed after 10 s it flies back
  to its owner if alive or downed; if its owner is dead it fades home (gone for this match, back at match end).
- **Carry limit:** a Hunter carries at most **2** stolen wisps. A third grab is refused ("Hands full").
- **Summon:** each stolen wisp has **one** summon this match: half its species duration, rounded up, minimum 5 s
  (Cindle 4 -> 5 s, Lilybara 10 s). It uses the one summon lane (Q3), is **AI only** (auto skill and melee; its E
  is not on your keys, so the HUD stays the same), and when it ends the wisp stays with you dim and passive-only.
  Killed while summoned: it is loose again at the spot (anyone can grab it back, including its owner).
- **Passive:** the stolen Boki's carry passive at **50 % strength** (Q8). Lore: the bond is loose in a stranger's
  hands.
- **Visible target:** thief-team colour ring and a tether line to the carrier (art brief). If the thief dies,
  every stolen wisp is loose again where they fell.
- **Match end:** all stolen wisps go home. Thief keeps the **soul echo** (species unlocked in the Field Book,
  better find/hatch odds, a small chance to roll a stolen rare mutation or shiny on the next hatch), and extracting
  alive with stolen wisps pays the bonus. Needs a Save field `echoes` (species -> count) and a v2 -> v3 migration.

**Alternative:** stolen wisps can't be summoned at all: passive at 50 % plus the extraction bonus and the echo.
Cleaner (one summon source per Hunter, nothing AI-only to build), and stealing is still worth it. Pick this if
the prototype shows stolen summons confuse people about whose Boki is whose.

---

## Q7. AI leash and control of the summoned form

**Recommend: the summoned Boki is on a short, fixed leash and is controlled exactly as the "out" Boki is today.**

- **Leash:** 10 m from its Hunter (today's formula gives 5 to 17 m by personality; a timed window can't afford a
  Boki that wanders 17 m). Personality still shifts it +-2 m. Past 20 m (you dashed, glided or got pulled) it
  **re-wisps and re-blooms** beside you in 0.4 s instead of walking: the window keeps running, so the long dash is
  the player's choice. Guardian leash: 6 m from your Hunter Wisp.
- **Orders:** hold the Boki key = the order wheel, as today (sic a target, come here, hold). The ordered E active
  is cast by the Boki when out, at full power, aimed within `range` (KIN_GRAMMAR). No new AI.
- **While a wisp:** your E is the Boki's active at the carried 85 % power, exactly today's carried rule. The wisp
  is "carried"; the summon is "out". The grammar's two modes already exist, so the executor needs no change.
- **Pathing:** while summoned the Boki uses today's `Kin` movement and KinTactics. While a wisp it has no AI at
  all: position = owner shoulder + a cheap orbit (time-hashed, no physics).

**Alternative:** summon is fire-and-forget (no order wheel, no E while out: the Boki does its own thing for the
window). Fewer inputs to teach, but it removes the one skill-expression the kin grammar was built for. Not
recommended.

---

## Q8. Carry-passive stacking caps

**Recommend: your own passive at 100 %, each stolen at 50 %, same-stat sums clamped at the carry cap.**

- Your Boki's `carry.passives` are **always on** in a match (wisp or summoned; a mount's passives also run while
  it is a wisp, which is new and good for large Boki).
- Stolen wisp passives add at 50 %. The sum per stat is clamped at `KinParts.OWNER_STATS` carry_max (e.g.
  damage_reduction 0.15: Cairnback 0.15 + half a Basaltoad 0.05 = 0.15, clamped). Different stats stack freely,
  which is why the carry limit is 2 (Q6): at most three passives on one Hunter.
- `on_shot` riders: only **your own** Boki's riders apply. Stolen wisps never add shot riders (two slows on every
  bullet is the kind of stacking the grammar bans for merges too).
- Merge passives on top keep today's rule: merge caps replace carry caps while merged.

**Alternative:** stolen passives at 100 %, carry limit 1. Same ceiling, fewer moving parts, but the second steal
(and the "1-2" the owner wrote) disappears, and a single stolen tank passive on a bruiser Hunter is a big swing.

---

## Q9. PvE vs PvP

**Recommend: one rule set everywhere, with two PvE exceptions.**

- Stealing exists only between Hunters. Monsters and bosses never grab wisps.
- A summon killed by a **monster** (no rival Hunter involved) returns to its owner with **no reveal** and the plain
  cooldown (x 1.0), whatever the owner's state: PvE deaths punish the clock, not the position.
- The Meadow tier (where Boki are never lost) keeps stealing on: it was never a loss. The echo bonus is small,
  so a Meadow thief gains little and nobody loses anything.
- Bots: summon on the same cue they already press E on (a foe in range), never in the last 5 s of a fight, and
  grab a loose wisp if within 6 m and nobody hostile is within 10 m.
- Ranked / normalize_size lobbies: summon numbers unchanged (they're identity, not rarity).

**Alternative:** PvE-only modes shorten every summon cooldown by 20 % so the Boki is out more against monsters.
Fun, but it breaks "the card number is always true". Only if PvE testers say the Boki is out too rarely.

---

## Other things this pass settles (recommend / alternative)

**Input binding.** Reuse the Boki key (`throw`, C or middle mouse): tap = Summon when ready, Recall when out; hold
= order wheel. No new action, no new tutorial key cap, and the tutorial already calls it "your Boki button".
*Alt:* a new `summon` action on G. Only if playtests show mis-taps between summon and the wheel.

**HUD ring timer.** The Boki slot on the ability bar shows the wisp's critter icon in the species' glow colour.
Out: the ring drains clockwise with the seconds in the middle. Cooldown: dim icon, ring refills grey, seconds
shown. Ready: bright icon, one chirp, a 0.3 s pulse. Guardian: white ring, GUARDIAN. Stolen wisps: small dim
icons stacked beside the slot, each with its one-summon dot. The same drain ring sits on the ground under the
summoned Boki (same language as the two-step-ability ring, decision 2026-11-08). *Alt:* a ring around the Boki
nameplate instead of the ability bar. Harder to read mid-fight; the ability bar is where the eye already is.

**Audio.** Bloom: a species-flavoured burst (petals, sparks, water, shadow) plus the Boki's own chirp at its
`voice` pitch (BOKI_IDENTITY). Shrink: the same reversed and softer. Ready: two notes in its voice. 3 s warning
tick before the window ends (the two-step rule's "warning tick"). Your wisp stolen: a thin alarm tone and a
"Stolen!" toast; the thief hears a soft catch. Loose wisps hum in their species' colour-coded pitch so you can
find one by ear. *Alt:* one shared summon sound. Cheaper, but the voice pitch is already per Boki and free.

**Performance budget.** A wisp is 1 draw call: one glow-shader quad (the `WispLook` builder from 0019, critter
outline texture per species) plus a mote emitter capped at 16 particles, no shadow, no skeleton, no physics; it
sleeps at 10 Hz beyond 40 m and is culled by the normal visibility range. Budget: 30 wisps <= 30 draw calls and
<= 480 particles. The full Boki is **pooled**: one hidden instance per Hunter is created at match start (so the
bloom is show/hide, never an instantiate), animation LOD as planned in the perf decision, and at most 1 animated
Boki per Hunter. Proof: `--perf-bench` with the `boki_wisps` setting on and off on a real GPU, posted in the READY.
*Alt:* a real small 3D model for the wisp. Prettier, three to six draw calls each, and it fights the "critter
outline" readability rule. No.

**Field Book card.** One line under the carry passive: "Burst: out 8 s, rests 60 s." and the guardian note on the
About tab in field-notes voice ("Bursts out to guard you if you fall with its summon ready.").

**Net.** New `ev` events: summon, recall, summon_end (reason: timer, recall, killed, killed_loose), guardian,
wisp_loose, wisp_grab, wisp_home. Wisp positions are not synced (derived from the owner). Summoned Boki sync as
kin do today. `Net.VERSION` bump. Stolen wisp ownership rides on the carrier's `st` snapshot as a small list.

**Save.** No save change for summon data (species data). Soul echoes: `Save.d["echoes"]` and a v3 migration.

**Checks.** `--summon-check` (duration, cooldown, early recall, killed x1.25, guardian trigger and no-trigger on
cooldown, one lane, stolen half duration, loose 10 s, grab, carry limit 2, passive 50 % clamped), `--grammar-check`
uptime band, `--wisp-check` extended with the Boki wisp looks, `--perf-budget-check` wisp draw calls.

## Open after this pass (needs the prototype, not more design)

- Whether 10 s of loose float is too long in trios (every down becomes a wisp scramble).
- The exact reveal length on a killed summon (2 s recommended; 1 s if it feels like a wallhack).
- Whether early recall should refund part of the cooldown. Recommended no; revisit if nobody ever recalls.
