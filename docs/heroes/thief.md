# Thief (archetype id `thief`, light)

Branch history: kits2 ported the kit from the source hero, kits2-nor (Nov 2) removed its R. Player-facing
names and text are ours; the source is named only in this research section, in docs/ARCHETYPES.md and in
docs/wiki/Inspirations.md.

## Research summary

- **Source hero:** Shiv, from SUPERVIVE (supervive.wiki.gg ability text, levels 2-4 and the patch history per
  ability). Version chosen: the wiki's current page as read on Nov 1, with the patch notes' shapes where the
  header and the notes disagree.
- **Patches that shaped it:** *Patch Week 1 Open Beta* (LMB range 800 -> 850, empowered 925 -> 950), *Patch
  Open Beta* (the dagger sticks to dynamic objects, +30 health for all).
- **Disagreements:** the wiki lists the dagger's Quickflip reset at level 3 in the patch note and level 4 in
  the tooltip (ours: rank 3, our last rank). No source gives Malice's stack cap or duration (ours: 5 Marks, 4s).
  gamerblurb's Shiv page and esports.gg's hunter list failed to load, so nothing rests on them.
- **Not reproduced:** mana (the game has none), the dagger sticking to moving props other than hunters and
  monsters, the Bolas hitting destructibles.

## Scaling

Shiv's scale (LMB 58, a stack about 15% of a shot, empowered attack 50, bolas 23 (+53 with two), ult shot 25)
is kept as ratios on our weapons: blades 7 / SMG 4.6 a hit, +8% a Mark, Primed +10, Bola 6 (+13 tangled),
Jackpot 4.5 a knife. A medium hunter (145) falls in about 4s of steady fire with two Primed hits. Rank 2 is
the shared step (cooldown -10%, damage +15%); rank 3 carries the source's level 3-4 specials.

## Per-slot table

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Marks | none | Every weapon hit puts a Mark on the target (one per 0.3s, max 5, 4s, refreshed); +8% weapon damage per Mark. The fifth Mark sets off Jackpot. A knock heals 15% on top of the shared 10% (25% in all); an assist heals 25% | Malice and Resolve: consecutive hits stack bonus damage; a knock or assist heals 25% | Gold diamonds over the target make the stack readable. The cap and time are ours (the wiki gives none) |
| Trigger, Jackpot | the fifth Mark | 4 knives at that foe over 0.45s (4.5 each, in sight within 14m); each refreshes every Mark; one free Vault for 4s; rests 8s | Fusillade (R): after a delay up to 5 shots at each nearby enemy over 2s, each resetting stack durations; the outer ring takes bonus damage and anti-heal; 2 weaker dashes | R is the Boki Merge now, so the ult becomes a payoff of the Marks loop. Refresh and the free dash are kept; the all-foes volley, rim ring and blight are dropped (a trigger on one foe cannot also be an area ult) |
| LMB | tap, hold | Twin Blades (3-hit combo, hold for a spin) or SMG; every hit Marks | Arcslinger, one stack per hit | Weapons are our shared ones |
| Dash, Vault | Shift | A 3.4m flip, +30% speed until the next hit (2s max); the next hit within 3s is Primed: +10, 2 Marks, Shred (+15% damage taken for 3s); landing it resets Vault | Quickflip: a short dash and speed; the next LMB is empowered; landing it resets the cooldown | As the source |
| RMB, Bola | tap | 10m, 6 and a Mark; the first foe is Grounded 1.5s (no dash, jump or glide; slowed 25%) and the Bola flies on 5m; a second foe: both stunned 0.9 and +13 (TANGLED) | Chain Bolas | As the source; rank 3 flies 1m further and pools two foes' Marks |
| E, Shadow Knife | tap, recast | 12m, sticks in the first foe (8, slow 50% for 2.5s) or a wall; recast to step to it; after 5s you step anyway | Farstep Dagger: sticks, slows 50% for 4s, recast to teleport, auto after 6s | Shorter slow and fuse for our TTK; rank 3 refunds 25% (50% in a foe) and a knife in a foe resets Vault |
| R | none | None. Press R for the Boki Merge | Fusillade | See "Ult choice" |

## Ult choice

R is the Boki Merge for every hero (owner, Nov 1), so the Fusillade became the **fifth-Mark trigger**:
the Thief's whole loop already builds toward five Marks, and a payoff at the top of the stack rewards the same
play the ult used to ask for, without a button.

## Combinations

All are scripted in `--kit-combo-check` (which also runs inside `--archetype-check`); the check names are the
strings it prints.

| Sequence | Result | Check |
|---|---|---|
| Vault, then a weapon hit | Primed: +10, 2 Marks, Shred; Vault resets; the speed ends | `combo thief: Vault > hit = Primed + Vault reset` |
| Shadow Knife into a foe (rank 3) | Vault resets; half the Knife's cooldown back | `combo thief: Knife in a foe (rank 3) = Vault reset + refund` |
| Shadow Knife, then E | step to them | `combo thief: Knife > E = step to them` |
| Bola catches two (rank 3) | their Marks pool | `combo thief: Bola on two (rank 3) = pooled Marks` |
| Bola, then Grounded | no dash, jump or glide | `combo thief: Bola > Grounded = no dash` |
| Primed hit on 3 Marks | the fifth Mark: Jackpot goes off | `combo thief: Primed hit on 3 Marks = the fifth Mark = Jackpot` |
| Fifth Mark | 4 knives, every Mark refreshed, rests 8s | `combo thief: 5th Mark = Jackpot burst, Marks refreshed` and `thief Jackpot: resting, a second fifth Mark does nothing` (--archetype-check) |
| Jackpot, then Vault | a free Vault (no charge) that Primes | `combo thief: Jackpot > Vault = free Vault that Primes` |
| Jackpot, free Vault, then a hit | Primed hit; Vault resets | `combo thief: Jackpot > free Vault > hit = Vault reset` |
| Knock or assist | heal (25% in all) | `thief passive: a knock heals (25% in all)` |

## Animation moves

`HunterAnim.KMOVES`: `thf_vault_f/b/l/r` (a tucked flip by the dash direction), `thf_primed`, `thf_bola`,
`thf_knife`, `thf_arrive`, `thf_volley` (0.7s, the Jackpot burst: the free hand slings the knives, the body
snapping round). `thf_volley_wind` went with the R. Strips: `--arena-demo=anim_<move>`.

## Engine notes

- Jackpot lives in `ThiefKit._jackpot` / `_jackpot_knife`; numbers in content/archetypes/thief.json
  `"jackpot"`. It is triggered from `add_mark` / `set_marks` when a count crosses from below 5 to 5.
- Knives use `src: abil`, so they never stack Marks themselves; the free Vault reuses the `quick` path of
  `on_dash` (no charge, 2.8m).
- No `"r"` in the JSON: `ArchKit.use_r` refuses the press, the kit card's R page is the Merge, and the wiki
  generator shows "Boki Merge" for the R slot.
- Net: the kit move id rides the hunter snapshot from Net 0.10.1, so remote players see the flips and the burst pose.
