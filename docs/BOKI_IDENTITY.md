# Boki identity: every Boki is its own

Every Boki (called "kin" in the code) has a lasting identity: an id that never changes, a set of
inborn rolls that make it look, sound and act unlike any other of its species, and a record of where
it came from. This is the groundwork for limited editions, supply caps and trading later (see
ROADMAP §7 on the `design` branch): the good part of collectibles, with the game's own server as the
record instead of a blockchain.

Code:

| What | Where |
|---|---|
| Inborn rolls, size, the model dressing, the match trade-off | `scripts/core/unique.gd` (`Unique`) |
| Ids, provenance, the event log, save migrations | `scripts/core/save.gd` (`Save`) |
| Breeding (lineage, inherited rolls), Rare Eggs (origin) | `scripts/core/care.gd` |
| Coat marks | `shaders/toon.gdshader` (`mark_*` uniforms) |
| Idle habits, girth | `scripts/match/kin_puppet.gd` |
| Hitbox and stat trade-off | `scripts/match/kin.gd` `init_kin` |
| Wild and bot seeds, where a Boki was caught | `scripts/match/match.gd` (`kin_seed`, `where_at`), `spawn_plan.gd` |
| The About tab, Nesting Nook and Burrow lines | `scripts/ui/about_view.gd` (`AboutView`) |
| Species base sizes | `content/kin/<id>.json` `"size": {"cm", "kg"}` |
| Tests | `tools/unique_check.gd` (`--unique-check`), `tests/save_fixtures/v1_save.json` |

## The record

New fields on every Boki record (save version 2):

| Field | Meaning |
|---|---|
| `uid` | The lasting id. `"b"` + creation time in ms (9 base-32 characters, so ids sort by age) + 64 random bits from the system's random bytes (13 characters), 23 characters in all. Never the global random stream. Kept forever: a Boki keeps it when caught, when revived at the Soul Shrine, and through every upgrade. |
| `legacy_uid` | The old `k...` id of a Boki from a version 1 save. |
| `born` | Unix time it was made (0 when unknown). |
| `dna` | Its inborn rolls (below). |
| `origin` | `{how, where, t}`. `how`: `wild`, `egg`, `boss_egg`, `starter`, `event` (reserved), `taken` (a rival's, taken home), `market`, `unknown` (from before records). `where`: `{map, island, biome, tier, tier_name}` for a catch, `{place: "home"}` for eggs, plus `lair` for a Rare Egg. `t`: unix time. `from`: the rival or seller. |
| `ot` | Original trainer: `{id, name}` of the save profile that first registered it. |
| `serial` | Its number within its species **on this save** ("#0042 of Vespyx"), handed out once and never reused. With a server this becomes a global serial, minted by the server. |
| `lineage` | `{parents: [uid, uid], names: [name, name], gen}`. Wild and starter Boki are generation 0; an egg is one more than its older parent. The old `parents` (names) stays for display. |
| `edition` | `null` for now. Reserved for limited editions: `{id, kind, serial, cap}` ("#12 of 500"), set only by a server. Not heritable. |

On the save: `profile` `{id, name}` (the trainer, `"p..."` id), `serials` `{species: last serial}`,
and `log`, an append-only list of `{t, ev, uid, sp, name, ...}` capped at `Save.LOG_CAP` (200),
oldest dropped first. Events: `caught`, `hatched`, `traded` (placeholder: `Save.log_trade`, and
market purchases), `evolved`, `renamed`, `released`, `died`, `revived`, `registered` (a Boki that
arrived without an origin) and `migrated`.

`Save.register(rec)` gives a Boki joining the collection its origin, `ot`, serial, lineage and
edition slot, and logs it. It runs where Boki are made (catch at extraction, hatch, the starter)
and as a sweep over the roster on every load and save, so nothing is ever left without them.

## Save migrations

`Save.VERSION` is 2. `Save.load_from()` upgrades an older save through `Save.MIGRATIONS`
(`{1: "_migrate_1_to_2"}`, one step per version) after writing the untouched file beside it as
`<save>.bak-v<n>`. A save from a **newer** game is not loaded and is marked never to be overwritten
(`Save.newer`), so going back to an older build can't wipe it.

v1 to v2, for every Boki in the roster, the Ransom House and the graves:

1. Its tastes and IVs (which v1 worked out from the old id) are written down, and its inborn rolls
   are made from the old id (`Unique.legacy_seed`), so the same v1 save always migrates to the same
   Boki and nothing about one changes.
2. It gets a new id; every string in the save equal to an old id (values and keys: partner, second,
   the nest egg's parents, buy-back offers, lost Boki, graves) is rewritten; the old id is kept as
   `legacy_uid`. Item ids are untouched.
3. Its origin is told from the old record (starter flag, Rare Egg, parents, a "caught", "taken" or
   "market" memory; otherwise `unknown`, time 0), and serials are handed out in the order they were
   got.

## The inborn rolls (`rec["dna"]`)

All of them come from one seed (`dna.seed`) through their own `RandomNumberGenerator`, never the
global stream. A Boki made at home gets a fresh seed from the system's random bytes. Wild and bot
Boki get theirs from the match seed (`Match.kin_seed`), so a seeded match spawns the same Boki every
run. `Save.new_kin` still takes exactly the global rolls it always did (its traits, plus one roll the
old id used), so seeded checks see the same global stream as before.

| Roll | Odds | Shown as | Effect |
|---|---|---|---|
| `size` | z-score, normal, clamped to ±3. Height = base × (1 + 0.07 z) | cm and a tag: **XS** (z ≤ −2, about 1 in 44), S (z ≤ −0.8), M, L (z ≥ 0.8), **XL** (z ≥ 2, about 1 in 44) | model scale, hitbox, a small stat trade-off |
| Giant / Tiny | the existing rare mutations (1 in 150), ×1.32 / ×0.7 | "Giant on top" | the extreme tier above XL / below XS |
| `girth` | 1 ± normal(0.035), max ±9% | weight, "stocky" / "slender" | weight; a touch of width on the model |
| `head`, `limb`, `tail`, `ear` | 1 ± normal(0.04), max ±10% | "long legs, big ears" | eye size, leg length (stands taller), tail and ear/horn scale |
| `hue`, `sat`, `val` | normal(0.016) hue, (0.06) saturation, (0.05) value | | a small shift of the body, belly and dark colours (shimmers and ghosts keep their hand-picked palette exactly) |
| `mark` | plain 14%, spots 26%, stripes 20%, patches 22%, freckles 18% | "Spotted (dark)" | a coat pattern on the body |
| `mark_col` | dark 55%, pale 38%, glowing 7% | | its colour (glowing ones shine faintly) |
| `mark_seed` | 31 random bits | | where the marks sit: no two Boki wear the same pattern |
| `eye` | classic (the species' own) 40%, then amber, sky, hazel, moss, violet, rose, gold, jet, ice, ember | name and a swatch | iris colour |
| `ears` | standard 50%, splayed 20%, tufted 18%, folded 12% | "Tufted ears" | the ear/horn group (Cairnback's horns count as ears) |
| `tailv` | standard 55%, tufted 20%, kinked 15%, bobbed 10% | "Kinked tail" | the tail |
| `quirk` | chases its tail, tilts its head, bounces, sways, sneezes, stretches, flicks its ears, looks around | "Habit" | an idle animation now and then (`KinPuppet`) |
| `voice` | 1 ± normal(0.07), 0.82 to 1.2 | deep / ordinary / high | pitch of its sounds (home, matches, the hatch and reveal) |
| `birth` | shape (star, heart, crescent, diamond, dot, swirl) × place (cheeks, brow, flanks, back, chest) | "a heart-shaped mark on its left flank" | a small mark on the model for the body places |

Also part of who it is, from before: personality traits, nature, likes (its favourite food fills
it 15% more, on top of the joy it already gave), IVs, shimmer and mutations.

A record with no `dna` (another player's Boki, a very old record) reads the rolls its id gives
without being changed (`Unique.of`); `Care.ensure` writes them down for your own. A look-only model
(`Models.kin(species, {})`, the galleries) keeps the species' plain look.

## Inheritance (`Unique.inherit`)

An egg's rolls come from its own seed plus both parents:

- **Size**: z = 0.4 × (z of one parent + z of the other) + normal(0.82). The spread across a
  population stays about the same, big parents have big young (two z = 1.5 parents average 1.2),
  and extremes drift back toward the middle.
- **Girth, proportions, colour shift, voice**: the parents' average plus a little noise.
- **Coat pattern, its colour, eye colour**: 45% from each parent, 10% new.
- **Ear and tail shapes**: 40% from each parent, 20% new.
- **Habit**: 25% from each parent, 50% its own.
- **Where its marks sit and its birthmark**: always its own.

Eggs keep their old rules for IVs (3 of 5 from the parents), shimmer and mutations. Edition and
serial are never inherited.

## Size in a match, and normalizing it

- Health × (1 + 0.04 t), speed × (1 − 0.04 t), with t = clamp(z / 2.5, −1, 1): never more than ±4%.
  Most Boki are within ±1.5%.
- The hitbox radius scales with the whole size (roll × Giant/Tiny), clamped to 0.7 to 1.4.
- **Normalize**: `Unique.normalized(match)` is true when `Unique.normalize` is set or the match
  options have `"normalize_size": true`. Then size changes neither stats nor the hitbox (looks stay).
  This is the hook for ranked play or lower tiers to neutralize size later: set the option when
  starting those matches.

## Showing it to the player

Following docs/POSITIONING.md (design branch): rarity shows in the Boki itself (its size, coat,
eyes, shape and habits on the model), never in rarity-coloured UI. The kin card's **About** tab
reads as field notes, plain sentences in the card's normal ink: "Stands 45 cm and weighs 5.6 kg.
Very large for a Vespyx (XL): few grow this big." and "Spotted with pale spots", then where it's
from (origin, date, who first raised it, parents, its number "#0042 of Vespyx"). No gold serials,
no coloured size badges. The Nesting Nook and Kin Burrow side panels show a three-line version.
With two Boki picked, the Nook's preview card (`NookPreview`) shows what their egg would be, read from
`Care.breed`'s inputs: both possible kinds pictured in the blended look (`Unique.blend_center`: the look
`Unique.inherit` rolls around, plain coat), its size, the coats it can take, the lean head start
(`Care.head_start`) and a note on an unstable mix. `--nest-demo=pair` opens it; `--nook-check` holds it to
20 of 20 hatched babies.
Player-facing words say *scanned* (the box and the Field Book say *caught*), not tamed (internal event names stay `caught`).

Screenshot hooks: `--kinbox-demo=unique` (eight Echolop from XS to XL, every coat), `--nest-demo=card-about`
(the About tab), `--nest-demo=kin` (the Nook panel), `--training --no-drop --size-demo` (an XS and
an XL Vespyx in a match, their rings showing the hitbox). `--normalize-size` sets `Unique.normalize`.

## Later, with a server

- The server mints ids, serials and editions; the client never does. Today's ids are made on the
  client and serials count per save, so nothing about an offline Boki can be trusted for trading.
- Serials become global per species (and per edition); a released limited Boki's serial is retired.
- Provenance moves to the account service; the local log stays as a cache.
- Importing offline Boki (ROADMAP §7g) keeps looks (`dna`) and memories but treats them as untradeable
  heirlooms.
