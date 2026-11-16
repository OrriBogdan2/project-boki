# Glimmerkin (glimmer): design card + turnaround prompt

Renders: `renders/glimmer_views.png`, `renders/match_far.png`.
Format: `TURNAROUND_SPEC.md` (with its own rules line instead of MOB_RULES).

## Design card
- **Role:** treasure runner. Harmless (0 dmg), fast (5.9), 110 HP, flees; staggerable; drops 22 gems. A chase reward that pulls hunters off their route (and into each other).
- **Telegraph:** none (it never attacks). Flee cue: ears flatten, gem crust flashes. Stagger: purple ring #C47AFF + stars, it sits down dizzy.
- **Silhouette idea:** a round little body with **two tall crystal ears** (gem spikes, not soft rabbit ears) and a glittering gem crust on its back, on short quick legs, tail a gem cluster. The only mob with friendly eyes and the only one that sparkles: "loot", not "threat".
- **Shape keywords:** round, glittering, skittish.
- **Size:** 0.55 H (fodder size, not fodder).
- **Palette:**

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #F4E6C4 | cream fur body | fixed (treasure must read the same in every region) |
| gold | #FFD25A | gem crust base, ear bases, feet | fixed |
| dark | #2B2A33 | eyes, nose, mouth, inner ear | fixed |
| gem cyan | #8FF0FF | crystal ears, half the gems | fixed |
| gem pink | #FF8AD8 | other half of the gems | fixed |
| sparkle | #FFF4C0 | crystal highlights (spec 1 per part, max 3) | fixed |

- **Materials:** soft fur (matte), crystal (hard highlights, max 3), gold crust (one flat band).
- **Keep:** gem colours cyan + pink, big friendly dark eyes, small and round, gems on the back, sparkle (as highlights, not particles).
- **Weak now:** a glossy round yellow body with long ears and dark eyes sits close to a famous yellow electric mascot (IP risk); yellow body competes with the hostile yellow eyes; gloss breaks the matte rule.
- **Must not:** yellow body, red cheeks, lightning tail, rabbit ears with black tips, a smile with a tongue.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K. Attach: image 1 = `docs/art/mobs/renders/glimmer_views.png`, image 2 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 3 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

**Rules line (replaces MOB_RULES):**
```
GLIM_RULES = "This is a harmless wild treasure creature from the same world as stylised hunter heroes and cute companion creatures, drawn in the same game style. It runs away and is worth chasing. Big friendly dark glossy eyes with one small white highlight each, no blush, no clothes, no human pose. Simple bold shapes that read from far away. "
```

**Prompt:**
```
Use image 1 only for the gem colours and the small round body; redesign it as described; ignore how it is rendered. Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 3 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><GLIM_RULES>
The creature: a small, round, quick treasure critter. A round cream-furred body with the head part of the body, on four short quick legs with gold feet. Two tall pointed crystal ears made of pale cyan gem, standing straight up, with gold bases. A crust of gold set with six chunky gems, cyan and pink, covers the top of its back like a saddle. A short tail ending in a small cluster of three gems. Big round dark glossy eyes, a tiny dark nose and a small closed mouth.
Its face: cute and nervous, eyes wide, about to run.
Palette: warm cream fur, gold crust and feet, very dark grey-violet eyes, nose and inner ears, pale cyan and pink gems.
Matte fur; each crystal part gets one hard pale highlight, three in total; the gold gets one flat band. No yellow body, no red cheeks, no rabbit ears, no sparkles floating around it.
```
**Steps:** as in `skitter.md`; scale column at 0.55 H. In game the body colour must stay fixed (the biome repaint should skip it; a code note for the model session, not this job).

**Checks:** spec section 8 (eyes are the friendly exception), plus: body is cream, not yellow · ears are crystal spikes, not soft ears · gems on the back visible in 3/4, side and back · max 3 highlights · fresh-eyes reviewer does not name a mascot.
