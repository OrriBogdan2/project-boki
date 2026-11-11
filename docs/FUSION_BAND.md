# Fusion band

DECISIONS (Boki): a Fusion (X) should feel like an event, with its own ability, dash and passive. It must not beat a
Hunter's ultimate (R). `--fusion-band-check` (tools/fusion_band_check.gd) measures both on the training strip and
fails when a Fusion leaves the band. The band comes from the ultimates and is set in `content/rules/merge_forms.json` `band`.
The pattern follows the summon band (Boki summons vs a Hunter's LMB) and the glove band (gloves vs the kits' E).

## How it is measured

- **Strip:** the archetype check's flat training strip, level 6. Two idle dummies stand side by side, 2 m ahead and
  2 m apart, pinned in place and refilled every frame. Each has a medium Hunter's health, because some burns hit a share of max health.
- **Who:** every ultimate is cast by its own Hunter. Every Fusion is worn by Vex (rifle held) and Kael (slashes
  tapped), and its figure is their mean.
- **Added, not total:** every run is set against the same Hunter with the same Boki on the shoulder, LMB only, over
  the same 6 s. Only what the ultimate or the Fusion adds counts. LMB stays on all through: held for guns and streams,
  tapped for swings and charged draws. R is pressed again every 0.5 s for second stages.
- **burst:** the most added damage in any one second. Fusion run: X at 0, then X again (the release) as soon as the
  1.5 s lock lets it.
- **sust:** added damage per second over 6 s. Fusion run: worn from the moment it is live, with no release. Ultimate
  run: cast at 0.
- **ehp:** extra raw damage the Hunter soaks before going down under a steady 60 dps (about two Hunters' LMB), from
  no attacker. This counts the shell, damage reduction, shields, heals and untouchable time.
- **Band:** at most the ultimates' maximum on each figure. At least `lo_k` of their median: burst 1.0, so a release
  is at least a typical ultimate, and sust 0 and ehp 0, because a defensive form may add none.
- **Ends:** the length (timeout run), the Boki's rest after a timeout (10 s) and after a release (6 s), and the
  afterglow (3 s of speed and shield). A timeout must rest longer than a release.
- **Built Fusions:** the three forms with their own file (titan, stormwing, tidal_shell), and each fallback merge
  once per Boki type that gives it (`merge/type`), because a fallback's rider and dash come from the type. 19 rows.

## Hunter ultimates (the band)

| Ultimate | burst | sust /s | ehp |
|---|---:|---:|---:|
| Vex Cinderfall | 66 | 15.0 | 2 |
| Kael Gilded Riposte | 33 | -13.6 | 46 |
| Ashwick Flue Flight | 5 | -19.8 | 0 |
| Tender Hearth Call | 0 | 0.0 | 8 |
| Dolm Basalt Spine | 5 | 0.8 | 0 |
| Archer Starpiercer | 40 | -4.8 | 0 |
| Dredge Brass Broadside | 43 | 2.0 | 0 |
| Rimewright Rimelock | 132 | -22.7 | 168 |
| Mage Kitefall | 56 | 3.3 | 141 |
| Bulwark Faultline | 36 | 3.3 | 0 |
| Thief Encore | 44 | 13.3 | 0 |
| Ostra Nightwell | 21 | 4.2 | 0 |
| **band** | **38 to 132** | **0 to 15.0** | **0 to 168** |

Negative sust means the ultimate stops or moves the Hunter's own LMB for a while: flights, statues and guards.

## Fusions, before and after

Every Fusion lasts its merge's `duration`: 6 s (stormcoat), 7 s (blaze_mantle, hive_crown, tempest), 8 s
(cairn_colossus, thornwake) or 10 s (the three forms). Every one rested the Boki 10.0 s after a timeout and 6.0 s
after a release, plus 3.0 s of afterglow, both before and after the tuning.

| Fusion (species) | burst before → after | sust before → after | ehp before → after |
|---|---:|---:|---:|
| titan, Heavy Star (casquebill) | **211** → 108 | **54.8** → 7.9 | **210** → 146 |
| stormwing (cindowary) | 100 → 93 | **23.7** → 12.7 | 104 |
| tidal_shell (floenatee) | 106 | 0.0 | 61 |
| cairn_colossus/stone (basaltoad) | 97 → 91 | **29.5** → 11.2 | 130 |
| cairn_colossus/titan (cairnback) | 97 → 74 | **29.5** → 11.2 | 154 |
| cairn_colossus/bloom (heatherhorn) | 97 → 74 | **29.5** → 11.2 | 144 |
| thornwake/spore (burrlet) | 77 → 70 | **16.6** → 12.0 | 101 → 130 |
| thornwake/stone (glintmole) | 77 → 67 | **16.6** → 12.0 | 101 → 130 |
| thornwake/shadow (gloamshell) | 77 → 70 | **16.6** → 12.0 | 101 → 130 |
| blaze_mantle/venom (cindle) | 89 → 75 | **21.1** → 10.8 | 130 |
| stormcoat/echo (gibbelle) | 93 → 71 | **34.0** → 11.5 | 130 |
| stormcoat/storm (kestrike) | 100 → 72 | **38.8** → 10.2 | 130 |
| hive_crown/swarm (hivara) | 101 → 73 | **35.0** → 7.5 | 130 |
| hive_crown/frost (rimeshrew) | 99 → 79 | **19.2** → 5.4 | 130 |
| hive_crown/venom (velvorm) | 91 → 76 | **24.5** → 12.6 | 130 |
| tempest/shadow (caecilith) | 69 | 4.5 | 130 |
| tempest/gravity (lodestick) | 63 | 4.5 | 130 |
| tempest/lunar (moonloris) | 62 | 4.5 | 66 |
| tempest/prism (opalisk) | 79 → 67 | **23.7** → 9.2 | 130 |

Bold marks a figure that was outside the band: 18 failures before, 0 after. Before the fix, Kael's LMB did nothing
while fused (see below), so his half of the "before" sust figures is from after that fix.

## What moved (data only)

- **Heavy Star** (`content/merge_forms/titan.json`): the slam is still every 3rd attack, but its damage went from 14
  to 2, so it is mostly a knockback. Collapse went from 18 + 48 to 12 + 34. The shell went from x1.3 to x0.9. Its 20%
  damage reduction stays: it has to beat a carried Boki's 15% (`--merge-form-check`), and it still makes Heavy Star
  the hardest form to break.
- **Stormwing:** Chain Lightning arcs for 30% of the hit, down from 50%.
- **Type riders** (`content/rules/merge_forms.json` `types`): the chain riders were the biggest source of sustained
  damage, because each one is a second hit on every attack. prism went from 0.35 to 0.08, echo from 0.3 to 0.06, storm
  from 0.4 to 0.06 and swarm from 0.25 to 0.05.
- **Merges** (`content/merges_v2`):
  - cairn_colossus: the stomp pulse went from 15 dmg every 1.5 s to 5 every 2 s, and the rise from 24 to 16.
  - thornwake: the pulse went from 10 to 6.
  - blaze_mantle: +20% damage became +8%, and the rise went from 18 + 18 to 12 + 12.
  - stormcoat: +15% damage became +5%, and the rise went from 12 to 6.
  - hive_crown: +20% damage became +5%, and the rise went from 16 + 15 to 6 + 6.
  - The flavour lines that quoted the old numbers now quote the new ones.

## Code fixed on the way

Kael's greatsword and Sable's Arc Bolts still swallowed LMB while fused. That was left over from 0003, when a form
replaced your attacks. Decision 0004 says you keep LMB, RMB and E. The leftover lock is removed. The merge start
still drops any charge you were holding, through `ArchKit.drop_holds` and Kael's merge hook.
