# Boki as the star: design proposals (item 187)

Proposals only, no code. The owner picks before anything is built. Read against origin/main 7907d9af (Net 0.24.1), DECISIONS (Boki rules of 2026-11-05/06) and briefs/BOKI_PLAYER_AUDIT.md (item 186).

**The problem in one line:** today most of a Boki's value goes into your hero (dash riders, +move speed, +dodge charge, +fire rate, mount handling). So a Boki feels like gear, and when it misbehaves it feels like a bug in your hero (181, 184). The audit cuts most of that. These proposals put the value back **in front of the Boki**, where the player can see it.

**Two tests every proposal passes:**
- **184b (agency):** the Boki acts on foes, the world, information, or plain stats (heal, shield). It never moves, steers, roots or swaps your hero, and never casts anything big without a reason the player can read. Fusion stays the single player-commanded change to your hero.
- **186 (fewer riders):** each proposal **deletes** hero-side riders (rows of the audit) and moves that value into something the Boki visibly does. Net hero riders after all five: plain HP/shield/regen (B6/B7) and the Fusion window only.

Costs are rough worker-days for one Sonnet/Opus lane, plus what each one touches. God files get wiring only (AGENTS 2). Each proposal ships with a check.

---

## 1. Mark and cash in: the Boki starts the play, you finish it (fights)

**What changes**
- The bond mark already exists but is invisible: a Boki hit marks a foe for 4 s, and your hits on it fill the bond meter 2x (scripts/combat/bond.gd:34-50, rules/bond.json). Make it the core fight verb:
  - **Visible:** a ring in the Boki's type colour on the marked foe, plus a small Boki icon on the foe's plate. It is the same language as the item-96 clarity pass.
  - **Cash-in:** your next hit on a marked foe uses up the mark for a short payoff themed on the species (one per type, all on the foe). Echo: the hit crits and the foe is revealed for 3 s. Venom: poison bursts. Gravity: a short slow. Lunar: Moon Mark, the 184b replacement for Moon Swap (+15% damage from you for 4 s). Spore: a small spore cloud on the foe. And so on.
  - The cash-in pays a bond chunk, so the "Boki then you" rhythm is what earns the Fusion.
- **Riders it replaces:** B3 owner_move_speed, B4 fire_rate/reload, B8 on_shot slow. Their damage budget moves into the cash-in.

**Why it makes the Boki central:** every fight has a beat the Boki started, and you can see it start it. Good players learn to fight next to their Boki instead of ignoring it.

**184b / 186:** the payoffs act only on the foe. Hero riders shrink by three rows.

**Cost:** about 3-4 days. One new module `scripts/combat/kin_mark.gd` (mark look, cash-in table) and a `mark` block in each content/kin_v2 file (data). bond.gd is extended, not duplicated. The mark becomes visible to every client, so it must be synced through Net; a mark status on the foe probably means a **Net.VERSION bump**. Check: for each species, a Boki hit and then a hero hit → payoff fires once, bond goes up, and the hero's position and velocity are unchanged.

**Alternative noted:** keep the mark invisible and only tune numbers. Cheaper, but players never learn it, so the Boki stays invisible too.

---

## 2. Fusion is the climax: the per-type Fusion spec, as the payoff for 1 (fights, identity)

**What changes**
- Finish the pending "per-type Fusion spec" (PRIORITIES step 4, DECISIONS Boki: "every Fusion should feel like an event"). Today 3 merges have their own kit form (stormwing, titan, tidal_shell) and the others use the stat fallback (rules/merge_forms.json `fallback`). Give **all 9 species** a form with one signature ability. The ability should be what the Boki already does, made bigger: Echolop's form is a pulse that reveals and staggers, Cairnback's a boulder throw, and so on.
- The Fusion takes over the stat budget the audit removes: no hero-side jump, glide, dash or dodge_regen changes outside the window (audit A13, A14, B10). Inside the window, the form's movement is capped at the shared 15%.
- Make the build-up visible: the bond ring on the right-side Boki box fills mostly from proposal 1's cash-ins. When it's full, the Boki glows and says a short line (existing BokiLines), so pressing X feels earned.

**Why:** the moment you become your Boki is the moment players remember. Right now 6 of 9 species give you a generic stat boost.

**184b / 186:** it is the one change to your hero, and only by command (X). The audit already marks this as LIMIT with these caps. No auto-Fuse, ever (audit E2).

**Cost:** about 1 day for the spec (one page per species, for owner approval), then about 1.5 days per form after that. Mostly data in content/merge_forms plus small parts of merge_kit.gd. The slice only needs the **6 starter species** first (scripts/core/data.gd:192), minus any that already have a form. Check: each form's ability fires, the window ends on time, and the hero's own dash is unchanged before and after the window.

---

## 3. Your Boki finds things: senses for exploration (exploration)

**What changes**
- Today a Boki does nothing between fights except follow you. Give each species one **sense** that points at something in the world, shown as a small world ping plus a Boki bark:
  - Echo hears hidden rivals through walls (pings their direction, not their exact spot).
  - Lunar sees chests and deathboxes at night or in the Blight.
  - Spore and Venom smell wild Boki and their lairs, which feeds capture.
  - Gravity feels breakables and buried caches.
  - Tempest senses the nearest exit and incoming storms.
- **Seek** is a choice on the G wheel: the Boki runs toward the nearest find, stops, looks back and waits. This is the "Boki physically leads" rule (DECISIONS, first 10 min) used in the match. **You choose whether to follow.**
- **Riders it replaces:** B1 dodge charge and B2 glide (Lunowl). Lunowl's value becomes "sees in the dark" instead of changing how your hero moves.

**Why:** extraction is about finding things. If the Boki is the best way to find them, you keep it out, protect it, and look at it.

**184b / 186:** only information and the Boki's own movement. Your hero is never moved, so the player decides everything. Two hero movement riders are cut.

**Cost:** about 4-5 days. New `scripts/match/kin_sense.gd`, a `sense` block in each kin_v2 file, and one G-wheel entry (kin_command.gd). The pings reuse the HUD marker code. Pings are local to the owner, so Seek's Boki movement already syncs as Boki movement, and likely **no Net bump**. Check: a Boki with each sense, placed near a seeded find → ping within N s, and the owner's input and position untouched.

**Alternative noted:** a passive mini-map radar. Cheaper, but it hides the Boki behind a UI element, which goes against the point.

---

## 4. Your Boki grows from what you did together (progression)

**What changes**
- Today the Boki's stat points can go into your hero (`owner_*` stats, parts.gd:323-327; audit B3). **All points become the Boki's own** (kin_hp, kin_damage, kin_speed, sense range, mark strength).
- Bond deeds in a match give the Boki XP: cash-ins (1), finds (3), Fusions (2), and rescues after a loss. At milestones the Boki learns a **second ability** or a **stronger cash-in or sense**. You pick between two at home, like a perk. This uses the existing evolution data (kin_v2 `evolution`, scripts/core/evo.gd) and doesn't add a second system.
- The end-of-match screen says what your Boki did ("Pip marked 14, found 2 chests, saved you once") and what it learned.
- Boki loss at tier 2 and above (DECISIONS: guards the deathbox, Ransom) now hurts for the right reason: this specific Boki has grown with you (it has its uid and lineage, docs/BOKI_IDENTITY.md).

**Why:** progression that belongs to the Boki makes it the thing you invest in and are afraid to lose. That is what "Boki loss that hurts and can be recovered" (PRIORITIES 4) needs.

**184b / 186:** no hero stat growth from Boki at all except HP/shield (B6). Everything you invest shows up on the Boki.

**Cost:** about 5-6 days, the largest. Points move from owner stats to Boki stats (parts.gd, kin_spec.gd). Boki XP and choices go on the Boki record, which is a **save change: needs a Save.VERSION bump and a migration** (owner points are refunded into Boki points). The end-of-match card is in scripts/ui. Check: old saves load with points remapped, deeds award XP, and no `owner_*` stat is left in the kin data (also a schema fence, audit finding 3).

**Alternative noted:** keep owner points but cap them. Cheaper, but it keeps the "Boki = gear" feel the owner is reacting against.

---

## 5. The Boki has a temperament you can see (identity)

**What changes**
- Every species already has a `personality` block (bravery, loyalty, temper, curiosity), and kin_tactics.gd reads it. But in a fight all Boki look alike. Make temperament **visible and readable**:
  - **Brave or hot-tempered** Boki dive first, show a short "on it!" pose and bark, and mark more often.
  - **Loyal** Boki stay close and cast their shield or heal sooner.
  - **Curious** Boki sense further (proposal 3) and wander toward finds.
- One-line personality on the new-Boki screen (item 82) and the Boki page. Barks for 4-5 fight moments (marked a foe, got hurt, you went down, Fusion ready, won the fight). These use the existing BokiLines rules: at most 6 words, cooldowns, no repeats.
- Wild rolls (Unique dna) nudge temperament inside the species range, so two Echolop don't play quite alike.

**Why:** a Boki you can describe ("mine is reckless") is a character, not a stat stick. It is also the cheapest of the five.

**184b / 186:** temperament changes only how the Boki behaves. It never casts anything that touches your hero. A loyal Boki shields you sooner, which is a stat, and that's allowed. No riders at all.

**Cost:** about 2-3 days. Weights in content/rules/kin_ai.json, a few lines in kin_tactics.gd, poses and barks in kin_puppet.gd and boki_lines.json. **No Net or save change**: the puppet state already syncs and the dna is already saved. Check: two Boki with opposite temperaments in the same scripted fight → measurably different engage distance or cast timing, and the owner is untouched.

---

## Recommendation for the vertical slice

1. **Do first: 1 (Mark and cash in) and 5 (Temperament).** About 6 days together. Both work on the starter species and the Hollow Crown, and both make the Boki visible in the 10-minute playtest. They can start as soon as the audit cuts (186) land, because they fill the hole those cuts leave.
2. **Next: 2 (Fusion spec, starter species).** The spec page goes to the owner while 1 is being built.
3. **After the slice playtest: 3 (Senses), then 4 (Progression).** 4 needs a save migration and should wait for the loss/Ransom loop to be playable.

**One fence for all five:** the schema check from audit finding 3 (no `owner` target for move effects outside `owner_falling`, no dash, glide, jump or move-speed fields in kin data). It goes in with the first one built, so none of these can bring a rider back.

**How we'll know:** the Boki column in briefs/FUN_SCORES.md (item 189) and two session stats to add with the playtest tools: share of hero damage dealt on Boki-marked foes, and Fusions per match. Target for the slice: the owner's and testers' Boki score is above their combat-feel score.

Not proposed, on purpose: anything that moves the hero, any new hero-side passive, auto-Fuse, or a new Boki key (G stays the single Boki button; X stays Fuse).
