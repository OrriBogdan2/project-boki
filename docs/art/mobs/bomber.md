# Puffbomb (bomber): design card + turnaround prompt

Renders: `renders/bomber_views.png`, `renders/match_far.png`.
Format: `TURNAROUND_SPEC.md`.

## Design card
- **Role:** fodder suicide runner. Fast (4.4), 26 HP, explodes for 16 in r 2.5. Teaches "kill it before it reaches you, or step out".
- **Telegraph:** stops, **inflates to about 1.5x**, all spines stand straight out, the belly sac glows **#FF8A2A** through its skin, ground circle r 2.5 in #FF8A2A, then bursts.
- **Silhouette idea:** a **puffer-toad**: a round body on four stubby frog legs, with a swelling throat-and-belly sac that is the bomb. An ember crest (three glowing vents) on its back replaces the cartoon fuse. Round + spikes + legs = nothing else on the roster.
- **Shape keywords:** round, swelling, spiked.
- **Size:** 0.5 H (fodder), about 0.75 H when inflated.
- **Palette:**

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #E07A3A | back and head | regional |
| dark | #3A2220 | spines, legs, mouth line | regional |
| belly | #F2D6B0 | belly sac (thin, pale) | regional |
| ember | #FFD25A | 3 back vents | fixed |
| eyes | #FFE25A | 2 angry slit eyes | fixed |
| telegraph | #FF8A2A | belly glow (charge, not painted on the sheet) | fixed |

- **Materials:** taut leathery skin (matte), dark horn spines, ember vents (flat bright, no halo).
- **Keep:** round body, dark spines, angry eyes, orange base, the "it's going to pop" read.
- **Weak now:** a round bomb with a lit fuse and angry eyes is close to a famous walking-bomb enemy (IP risk); no legs, so it slides; the swell telegraph has no body part to show it.
- **Must not:** a fuse, a wick, a metal cap, a key on its back, black round bomb body, cartoon feet with shoes.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K. Attach: image 1 = `docs/art/mobs/renders/bomber_views.png`, image 2 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 3 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

**Prompt:**
```
Use image 1 only for the creature's colours and spines; redesign the body as described; ignore how it is rendered. Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 3 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><MOB_RULES>
The creature: a small, round, angry puffer-toad monster that explodes. A nearly round body, slightly wider than tall, sitting on four short thick frog legs with wide flat toes. The head is part of the body, with a wide flat mouth line and two narrow angry glowing yellow slit eyes under a heavy brow ridge. Twelve short, thick, dark cone spines stick out of the back and sides, folded back slightly. A big pale swollen belly-and-throat sac fills the front and underside, tight like a balloon. On the top of its back, three small round vents in a row, glowing ember yellow, like hot coals in the skin.
Its face: tough and angry, mouth a flat tight line.
Palette: hot orange back and head, very dark red-brown spines, legs and mouth line, pale cream belly sac, ember yellow vents, glowing warm yellow eyes.
Taut matte skin, no shine. No fuse, no wick, no metal parts, no black bomb body.
```
**Steps:** as in `skitter.md`; scale column at 0.5 H.

**Checks:** spec section 8, plus: four legs visible in front and side · no fuse or wick anywhere · belly sac visible in front, 3/4 and side · spines countable (about 12) · fresh-eyes reviewer does not name a walking-bomb enemy.
