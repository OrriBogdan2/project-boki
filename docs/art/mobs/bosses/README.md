# Lair boss turnaround sheets (2026-11-10)

Owner 11-10 ~12:50 PM EST: the 7 mobs and the 3 lair bosses get final 3D before new Boki. These cards use the mob sheet format (`../TURNAROUND_SPEC.md`) with the boss changes below. Sheets go to the owner; Meshy waits for each sheet's approval.

## Files
- `colossus.md` (The Stone Colossus, lair: The Sunken Forge), `serpent.md` (Stormcoil, Stormcrown Eyrie), `brood.md` (The Brood Mother, The Thornhive). Each: design card + turnaround prompt card.
- Sources: `scripts/match/boss_models.gd` (current bodies), `scripts/match/boss.gd` (attacks, telegraph colours), `scripts/core/data.gd` (stats), `scripts/match/lairs.gd` (lair colours), the egg kin in `content/kin_v2/` (each boss drops the egg of its own kin).

## Boss changes to the mob spec
- **Size tier "boss":** taller than 2 H or longer than 3 H. The scale column shows the hunter figure next to the boss at true scale; the views still fill 70% of the view-row height.
- **Detail budget:** up to 24 countable parts in at most 3 sizes (mobs: 16). Bosses are landmarks, seen up close in a closed arena; the face, the signature part and one pattern still carry the detail, and 40% of the body stays plain.
- **Glow accent:** each boss has one fixed glow colour as its 5th swatch (Colossus forge amber = its lair colour in `Lairs.SPRITE`; Stormcoil pale static cyan; Brood Mother egg gold). Where the lair colour is also the telegraph colour (Stormcoil #7FE8FF, Brood Mother #B6FF6A) it stays on the charging part only, as on the mobs.
- **No regional repaint:** lairs are not repainted per region, so every boss swatch is fixed.
- **Family look:** each boss is the grown, wild parent of the Boki its egg hatches (Cairnback, Zephyrak, Hivara): same animal family and signature idea, never cute. A player who hatches the egg should see the boss in it.
- **Not humanoid** (spec section 4) applies. The current Colossus is a humanoid stone warrior with an axe on a skeleton rig; it is redesigned as a beast (see its card). Alternative noted: keep a biped stone giant and its current rig and clips; rejected because humanoid mobs read as hunters and the brute and Watcher already own the "big stone brawler" look.
- **Not the Wyrm:** no boss may read as the villain (Malgrave, a dragon queen; the Wyrmheart is a crimson glass heart). No crimson glass, no heart motif, no four-legged winged dragon. Stormcoil is a legless eel-serpent for this reason.
- **Prompt blocks:** SHEET + MOB_RENDER + MOB_LINE + BOSS_RULES + the design paragraph. There is no current-render image 1 (all three are redesigned and the primitive bodies would only pull the model back): image 1 = the sheet layout (`briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`), image 2 = the finish (`briefs/boki-art/style_refs/boki_style_ref_2d.png`). Regens from 11-10 drop the layout ref (it bled a ghost of its person into the Colossus and Brood Mother first runs) and attach the finish ref only, with "exactly four views, nothing else" in the prompt.

```
BOSS_RULES = "This is a lair boss: a huge, ancient hostile monster from the same world as stylised hunter heroes and cute companion creatures, drawn in the same game style but clearly the most dangerous thing in the area, grand and memorable like a landmark. Its eyes are flat glowing warm yellow with a paler core, no pupils and no shine, under a heavy brow. No blush, no clothes, no armour pieces, no human pose, nothing held. Simple bold shapes that read from far away; detail only on the face, one signature part and one pattern. "
```

## Size and silhouette against the mobs
| Boss | Silhouette family | Keywords | Size |
|---|---|---|---|
| Stone Colossus | dome on four pillars, horns sweeping back | domed, pillared, horned | 2.5 H tall, 3.5 H long |
| Stormcoil | S-coil standing on its tail, wings at the neck | coiled, swept, crackling | 2.2 H tall coiled, about 7 H long |
| Brood Mother | low wide body, huge raised sac behind, legs splayed | splayed, swollen, crowned | 1.7 H tall, 3.5 H long |

None shares a family with a mob: the brute is a trapezoid knuckle-walker, the Watcher a tall gate with a stone halo, the spitter the only stalk.
