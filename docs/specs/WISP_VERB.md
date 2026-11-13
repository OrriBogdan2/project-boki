# The wisp's verb: one small thing it does between fights (spec, owner pick)

Docs only; no game code changed. Source: `reviews/DESIGN_REVIEW_1110_FUN.md` finding 6 ("the star is a dot for 85% of the
match") and `FUN_AUDIT_1111` gap 9 (neither file is in this tree; their claim is taken as given): the Boki rides as a wisp
and is summoned about one fight in six, so mid-run it gives few reasons to care. Binding: briefs/DECISIONS.md 2026-11-09
"Soul-linked Boki" (wisp is cheap to draw, has no walking AI, orbits at shoulder height, carry passive always on, critter
outline in the Boki's own colours, quick and bouncy, sparkle trail, chirps in its own voice; summon button on a long cooldown;
Hunter Wisp = round outline, never confused) and `docs/UI_FIRST15.md` (DECISIONS 11-08: about 5 HUD groups at once, one
"what to do next" prompt). Builds on `Kin.wisp`, `BokiWispLook`, `BokiChatter`, `docs/specs/TUTORIAL_WISP.md`.

## Rules every option shares
- **Wisp only.** The verb runs while the Boki is a wisp. Summoning ends it; it resumes when the wisp returns. It is not an
  ability: no damage, no cooldown, no key, no cost. Nothing the Boki's summon does changes.
- **No new HUD group.** The verb lives in the world (the wisp itself, a short line it draws, an existing pill/ping). The
  summon ring (one of the existing groups) may show one small cue chip at most.
- **Never a second prompt.** It must not compete with the single "what to do next" prompt: it only decorates things already
  there (a camp, a chest, a threat), and is silent while that prompt is up.
- **Own client, own look.** Computed locally from world state each client already has. Other players' wisps run it only
  within a short range (see perf). Nothing new is replicated in options A and C; B needs one tiny flag.
- **Personality = data.** Per-species and per-element verbs read `content/rules/` rows (like `boki_lines.json`,
  `wisp_looks.json`): a flick of the ears, a speed, a pitch, and a bark line from `BokiLines`. No per-species code.
- **Off switch.** One setting ("Boki cues" in Settings > Game) turns the verb to a plain orbit, for readability or low end.

## Option A. Scout: it points at wild Boki and nests
**Rules.** Within 28 m of a wild Boki (wild kin around a nest, `World.wild_spots`) the wisp drifts a short way (up to 2.5 m)
off its orbit toward it, turns to face it, and holds a gentle bob until you look or walk within 12 m, or 6 s pass. It then
tucks back. Each target gets one point per approach (no spam). Species it likes (matching element or egg line) get a bark
and a bigger lean; others just a glance. A rarer (shiny/legendary) wild Boki makes the lean quicker and adds one chirp
variant, so the cue is also a rarity hint, not only a location.
**Personality and type.** Shy species hang back and peek; bold ones lean hard; the type sets a tint pulse (fire warm
flicker, water slow ripple, wind quick sway) on the existing sparkle trail colour; voice is the Boki's own chirp.
**HUD/sound.** HUD: none (the wisp is the pointer). Sound: one quiet chirp, positional, at most once per 20 s.
**Perf.** Scan is one query of the pre-built wild-kin list every 0.5 s per local wisp, ~20 entries: negligible. For 30
Hunters, only wisps within 40 m of the camera run the lean; the rest orbit. No allocation, no meshes, no lights.
**Bots/online.** A bot's wisp runs the same code with no bark; the lean never changes bot decisions. Online: client-side
only; no Net change, no `VERSION` bump. Other players' wisps show the lean only if a wild Boki is already visible to you.
**Risk.** Weakest tie to the Boki's personality (it points at *other* Boki); mildly helps hunters who hunt Boki.

## Option B. Nose: it sniffs loot and chests
**Rules.** Within 20 m of an unopened chest or ground loot the wisp's sparkle trail brightens and it loops a small spiral
over it; it stays on the item until you are within 6 m or open it, then returns. Rarity sets the sniff: common loot gets
a nod, rare gets a hop and a chirp, epic/legendary a double hop and its own bark line. The wisp only reacts to what you
have seen on the minimap or in view (no wall-hack): a chest behind a wall inside 20 m does nothing until its line of sight
or a ping is clear. A Boki with the "finder" quirk (data flag) widens the range by a quarter. No bonus loot is created.
**Personality and type.** Greedy/curious species sniff longer; calm ones glance. Type sets the spiral colour (existing
`BokiWispLook` palette): the element reads in the trail. This is the strongest personality hook because every Boki
reacts differently to the same item.
**HUD/sound.** HUD: none; the existing loot ping/outline (one group) gets a faint tint while the wisp sniffs. Sound: a
short sniff + chirp, rarity-keyed, positional; 15 s per-wisp cooldown. Loot pickups already have sound, no new group.
**Perf.** One scan of chests/loot within 20 m every 0.5 s per wisp; ~10 candidates. 30 Hunters: only visible wisps run
it (cull by the camera frustum); cost is a handful of vector ops, no draw calls beyond the existing trail.
**Bots/online.** Bots do not need loot hints; their wisp plays the sniff for readability only. Online: loot visibility is
already per-client; a loot item an enemy has opened is gone from their list, so no information leaks. A "sniff" that
tells you an enemy is there (their wisp loops over a chest) is *useful public information* by design: others can read
it, so enemy wisps show the spiral only on chests you can already see.
**Risk.** Leakage: enemy wisps hovering on loot tell you someone is there. Capped by the visibility rule above.

## Option C. Ward: it reacts to danger
**Rules.** Before danger arrives it shows it. Triggers: an enemy Hunter comes within 35 m with a clear line, a Blight edge
is within 15 m, or a mob aggro starts nearby. The wisp snaps to the side facing the threat (about 0.3 s), flares its
colour, and gives one rising chirp; a Hunter ping adds a thin short line toward it (one frame-drawn arc, 1.2 m). It
settles back after 3 s without the trigger. Hunter vs mob vs Blight use three distinct chirps so the player learns them.
Optionally the cue repeats once if the same enemy closes under 15 m. It gives **no new info the player has not been
given** beyond what an attentive player would notice; it shows what the minimap and tracker already say, at the Boki's
shoulder where the eyes are. Real information is the direction in the player's peripheral vision.
**Personality and type.** Timid species flinch early and loudly; brave ones stay still and glow; the type colours the
flare. The wisp's voice warns in its own tone ("the Boki is scared of you" reads as trust).
**HUD/sound.** HUD: none new (the existing directional edge pip is one group; the wisp can nudge it). Sound: three short
chirps, the most audible of the options; capped 1 per 4 s and ducked under combat audio.
**Perf.** Reuses the threat query the Boki already runs (`Kin._wisp_threat` pattern) at 0.25 s; per Hunter it is one
distance check against a list of nearby enemies. 30 Hunters: 30 wisps x ~29 candidates every 0.25 s = under 4k distance
checks a second; cull to wisps within 40 m of the camera if needed. No draw cost.
**Bots/online.** Bots: the same flare for visual consistency; it must not alter bot targeting. Online: computed from the
enemy positions the client already receives (interest-managed snapshots), so a threat the client doesn't know about is
not shown. No Net change. Enemy Hunters can see your wisp flare, which marks you as "just spotted somebody", a small
information cost to you; the flare is subtle and has no sound for others.
**Risk.** Overlaps the minimap/edge-pip, so it can feel redundant; the most noisy of the three.

## Comparison
| | A Scout | B Nose | C Ward |
|---|---|---|---|
| Ties to Boki personality | medium | **high** (each reacts to each item) | medium |
| Gives the player a reason to care | wild Boki hunting | **loot, constantly** | safety |
| Frequency | low (wild Boki are sparse) | **high** (loot is everywhere) | medium |
| New HUD group | none | none | none |
| Perf, 30 Hunters | trivial | trivial | small |
| Leaks info online | no | capped, designed | slight |
| Overlaps existing UI | no | the loot ping | yes (pips) |
| Build size | smallest | small | medium |

## Recommendation: B, Nose
Loot is the thing a player looks for every minute, so the wisp's attention is on screen about as often as the player's
own. Each species can react in its own way, which is exactly the "care about this Boki" hook the finding asks for (the
Boki that always bounces on a chest becomes *yours*). It adds no HUD, no key and no new system, reads from the pickup
list that exists, and cannot hurt balance (no bonus loot). A is a good follow-up for the Boki-hunting loop; C duplicates
the minimap. Alternative if the owner prefers safety: C with only the three chirps and no line.

## Build tasks (for B, in order; each a small ext/ branch)
1. **Rows.** `content/rules/wisp_verb.json`: ranges (20 m seek, 6 m clear), per-rarity reaction (nod/hop/double hop), per-
   trait duration (curious, calm, finder), sound ids, cooldown. A species/element override table; defaults cover the rest.
2. **`scripts/match/wisp_nose.gd`** (`WispNose`, static): `update(k: Kin, dt)` picks the nearest visible loot via the
   existing loot list, drives the wisp's local offset and a `nose` state; wired by one call from the wisp's tick. No new
   god-file lines beyond that call.
3. **Look.** Extend `BokiWispLook` with the spiral hop in `pose` and a trail-brighten parameter (no new mesh/material).
4. **Sound.** Sniff + rarity chirp through `Sfx`/`BokiLines` trigger id `sniff`; 15 s cooldown; positional; ducked
   with the existing loot sounds. Add `sniff` lines to `boki_lines.json` for a few species (rest default).
5. **Visibility.** Line-of-sight/seen check (minimap-known or in view) so enemy wisps do not leak; enemy wisps use the
   same rule from their own position.
6. **Cull.** Only wisps within 40 m of the camera or the local hunter run the update; bots' wisps run a cheap version.
7. **Setting.** "Boki cues" toggle in Settings (default on), plain orbit when off.
8. **Check.** `tools/wisp_verb_check.gd`, registered: the wisp finds a chest, leans, hops, gives up at 6 m, cooldown,
   no sniff for an unseen chest, setting off = no change, and a 30-wisp frame budget row (extend `--wisp-check`).
9. **Docs.** `docs/HUD.md` note (no new group), `docs/decisions/0019` line, wiki regen. Net: no `VERSION` bump.
