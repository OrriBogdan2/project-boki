# Dancer (archetype id `thief`, light)

Branch history: kits2 ported the kit from the source hero, kits2-nor (Nov 2) removed its R, and
ext/kitfix-dancer-juggernaut (Nov 2, server update 5) matched it to the gameplay footage and renamed the hero
from Thief to Dancer. Player-facing names and text are ours; the source is named only in this research
section, in docs/ARCHETYPES.md and in docs/wiki/Inspirations.md. Ids and file names stay `thief`.

## Research summary

- **Source hero:** Shiv, from SUPERVIVE. The kit now follows the footage reference sheet
  (`briefs/hero-ref/dancer.md`, frames at 5 fps) where it disagrees with the wiki text.
- **The big change:** the source's left click is a ranged bolt from alternating hands that stops at the
  cursor. Our old signature (Twin Blades, a melee combo) is replaced by **Arc Bolts** (our name, our model).
- **Not reproduced:** mana (the game has none), the dagger sticking to moving props.

## Scaling

Ratios, not raw numbers: a bolt is 9 (the source basic attack, 137), the empowered bolt is 3.5x (474),
a Mark is +12% of a bolt (the +17 steps on 137), the Bola is 5 (74) and +13 for a pair (199), a Jackpot blade
is 5, +4 at the rim (88-108 close, 151-236 at the edge). Cooldown ratios: Vault 4.5s (Cartwheel 4.2),
Bola 7s (Trickshot 6.7), Shadow Knife 15s (Phantom Dagger 15).

## Per-slot table

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| LMB, Arc Bolts | hold | A spinning gold chakram from alternating hands every 0.45s, 34 m/s; it flies to the cursor (12m at most) and fizzles there in a blue-violet puff. A thin white aim line to the cursor with an arrow tick, gold while the next bolt is empowered | Arcslinger: the same, cursor-placed, 0.45s | Range 12m (the footage shows at least 7 bh); no magazine |
| Passive, Marks | none | Every bolt that hits adds a Mark (up to 8, 4s, refreshed): +12% bolt damage per Mark. A knock heals 15% on top of the shared 10% (25% in all) with a crimson star on the knocked and a green pillar on her | Malice: about +12% of a shot per consecutive hit, still climbing at 8; knock heal with a green pillar | Gold diamonds over the target keep the stack readable (ours) |
| Trigger, Jackpot | the fifth Mark | A cyan 6.3m ring grows out from her (0.4s), then for 1.2s a blade every 0.2s at each foe inside: 5, +4 past 4m; each blade refreshes every Mark; the Vault comes back; she keeps moving and shooting; rests 10s | Death Blossom (R): a 3.5 bh ring, a blade at every enemy inside every 0.2s for 2s, bonus near the edge, resets Cartwheel | R is the Boki Merge, so it fires off the fifth Mark (kits2-nor's design), shorter |
| Dash, Vault | Shift | A 2.4m cartwheel (0.25s) the way you move, a white arc traced by hands and feet; +30% speed until the next hit; the next bolt within 3s is empowered: a big blue chakram in a gold lightning streak, 3.5x, 2 Marks, Shred; landing it gives the Vault back | Cartwheel: a short sideways cartwheel, the next LMB empowered, a hit resets it | As the source |
| RMB, Bola | tap | A 0.4s wind-up (whirled overhead) with a chevron lane showing (1.4m wide, 10.8m long) that follows your aim, then the Bola flies 7m: 5 and a Mark, the first foe Grounded 1.5s with yellow binding rings, and it flies on 3.8m; it bounces once off a wall; a second foe: both stunned 0.9 and +13 | Trickshot: the lane for 0.4-0.6s, Grounded on the first, Stunned on two, bounces off terrain | As the source |
| E, Shadow Knife | tap, recast | A dagger to the cursor (14m at most): it sticks in the first foe on the way (8, slowed 50% for 2.5s) or lands where you aimed; a white circle marks it; recast blinks you there through 5 cyan afterimages; after 6s you step anyway | Phantom Dagger: sticks or lands, recast teleports with a ghost chain | As the source |
| R | none | The Boki Merge | Death Blossom | See Jackpot |

## Assumptions (where the footage is silent; easy to change in content/archetypes/thief.json)

1. **Trickshot input:** a fixed 0.4s cast with the lane, not a hold-and-release. The lane follows the aim during the cast.
2. **Trickshot stun:** only a second foe stuns; a wall bounce does not count as a second target.
3. **Arcslinger range:** 12m (about 6.7 bh), clamped; the cursor point is the landing point.
4. **Mark cap and time:** 8 Marks, 4s each, refreshed by every hit (the footage still climbed at 8). Jackpot fires at 5.
5. **Cartwheel direction:** the movement direction (WASD), the aim when standing still; the cartwheel turns in the plane of travel.
6. **Phantom Dagger timer:** 6s, then you step to it anyway (the wiki's rule); no target: it lands at the cursor.
7. **Death Blossom (Jackpot) and Marks:** its blades refresh Marks but do not add them, and do not count as bolt hits.
8. **An empowered bolt that misses** is spent (no Vault reset).
9. **Malice** has no stack cap or duration in any source; ours are 8 and 4s (see 4).

## Small mechanics

From the wiki's ability page and patch notes (https://supervive.wiki.gg/wiki/Shiv), two guides
(https://gamerblurb.com/articles/supervive-how-to-play-shiv) and the footage sheet. "Built" means it is in the kit
and asserted in `--dancer-combo-check` / `--kit-combo-check`.

| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| The empowered shot flies further than a normal bolt (850 -> 950 units) | wiki patch 26.11.2024 | yes (0143, long streak) | Built: 12% further; asserted at 13.4m |
| The speed boost ends when the empowered shot is used (fired, not landed) | wiki Shift | n/a | Built; asserted |
| Landing the empowered shot resets Quickflip | wiki Shift | yes (0187-0193) | Built; asserted (and the loop twice) |
| The bolas fly on after hitting an enemy **or a destructible** | wiki RMB | n/a | Built: a crate counts as the first catch; asserted |
| Two targets caught: both stunned, bonus damage; top rank pools their stacks | wiki RMB | yes (0117) | Built; asserted |
| The bolas bounce off terrain | footage 0103-0105 | yes | Built (once); asserted |
| The dagger sticks to any surface or character, and to shields and barricades | wiki patch 20.11.2024 | yes | Built for hunters, monsters and the ground; shields: not yet (our walls are terrain) |
| After 6s she teleports to the dagger anyway; recast to go early | wiki Q | yes (0237) | Built; asserted |
| A dagger in an enemy slows them 50% | wiki Q | yes (0258) | Built (2.5s, our TTK) |
| A dagger in an enemy at the top rank resets Quickflip; terrain refunds 25%, characters 50% | wiki Q levels 3-4 | n/a | Built at rank 3; asserted |
| The ult's outer ring deals bonus damage and anti-heals | wiki R | yes (0344, numbers) | Built on Jackpot's rim (blight 4s); asserted |
| Every ult shot refreshes all stacks | wiki R | n/a | Built; asserted |
| LMB keeps firing during the ult | wiki R, gamerblurb | yes (0299-0302) | Built (Jackpot doesn't stop the bolts) |
| The ult grants dashes while active | wiki R | yes (0193) | Built as a Vault reset on Jackpot |
| A knock or assist heals 25% | wiki passive | yes (0063) | Built; asserted |

## Combinations

All are scripted in `--kit-combo-check` (also inside `--archetype-check`) and `--dancer-combo-check`
(tools/dancer_jug_check.gd); the check names are the strings it prints.

| Sequence | Result | Check |
|---|---|---|
| Vault, then a bolt that hits | empowered: 3.5x, 2 Marks, Shred; Vault back; the speed ends | `combo dancer: Vault > bolt = empowered hit + Vault reset` |
| Vault > bolt > Vault > bolt | the reset loop | `combo dancer: the reset loop (Vault > bolt > Vault > bolt)` |
| Vault, then a bolt that misses | spent, no reset | `combo dancer: an empowered bolt that misses is spent` |
| Shadow Knife into a foe (rank 3) | Vault back; half the Knife's cooldown back | `combo dancer: Knife in a foe (rank 3) = Vault reset + refund` |
| Shadow Knife, then E | step to them | `combo dancer: Knife > E = step to them` |
| Bola catches two (rank 3) | their Marks pool | `combo dancer: Bola on two (rank 3) = pooled Marks` |
| Bola, then Grounded | no dash, jump or glide | `combo dancer: Bola > Grounded = no dash` |
| Empowered bolt on 2 Marks | 5 Marks: Jackpot | `combo dancer: empowered bolt on 2 Marks = 5 Marks = Jackpot` |
| Jackpot | blades refresh the Marks, the Vault is back, it rests | `combo dancer: Jackpot blades refresh the Marks and resets the Vault`, `combo dancer: Jackpot rests (no second burst at once)` |
| Knock or assist | heal (25% in all), star and pillar | `dancer passive: a knock heals (25% in all), star + pillar` |

## Animation moves

`KMovesDJ` (scripts/match/kmoves_dj.gd): `thf_lmb_r` / `thf_lmb_l` (the body for each throw: release at
0.08s, follow-through to 0.22, back by 0.42; the arm is the twin-hold swing), `thf_primed`, `thf_vault_r` /
`thf_vault_l` (a cartwheel, legs split, 0.55s), `thf_bola` (whirl overhead through the 0.4s lane, sling at
0.42), `thf_knife` (a spin into a side-arm throw, released at 0.12), `thf_arrive`, `thf_volley` (Jackpot, no
leg keys so she walks).

## Look and sound (all ours)

- Arc Bolts model: two dark ring blades with swept spikes and a gold inner edge (scripts/match/hero_arms_dj.gd).
- Effects: scripts/arch/kits/dj_fx.gd and shaders/dj_fx.gdshader, every node pooled: the gold chakram and its
  comet trail, the empowered blue chakram in a lightning streak, the fizzle puff, the Bola's two weights, the
  dagger, the cyan afterimage chain, the knock star and heal pillar, the cartwheel arc.
- Sounds: tools/gen_dj_sfx.py (`dj_*`), synthesized.

## Engine notes

- Bolts are weapon shots (`h.fire()` with `h.shot_aim = AimMode.CURSOR`); the kit then moves the start to the
  throwing hand, re-aims at the clamped cursor point, and hangs a `kx` end callback for the impact and the
  empowered hit. The empowered damage is on the shot itself.
- The Bola is kit-run (it flies on through its first foe and bounces), with the stage's effects applied on the wrap.
- Holds cleared by `_drop_holds()` on a merge: `bola_cast`, `jp`.
