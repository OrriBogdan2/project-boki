# Utility item art cards (2D first, then 3D), Nov 9 2026

For the art lane (Vertex). Owner ask 11-09: copy the source's utility items over and "do our own
artwork and 3d work for it". Items are ours (names, text, designs); no franchise names anywhere.
Data: `content/utility/*.json` on ext/utility-parity (the `icon` field today points at placeholder
glyphs; these cards replace them). Style: briefs/boki-art/STYLE_CANON.md words (soft hand-painted
shading, clean thin dark outline, rounded toy-like shapes, two main colours plus one accent, flat pale
grey #E8E8EE background, no shadow, no glow halo, no text) and the prop finish from
briefs/boki-art/relics/RELIC_PROMPTS.md. Order: after the Boki batch and the relics, unless the owner
pulls it forward. Do not spend on Meshy until a 2D card is approved.

## Shared spec
- **Per item:** one 2D sheet (the object alone, 3/4 view big, plus front and side and one close-up of
  its telling detail) and one 512x512 transparent 3/4 icon crop. Save to
  briefs/art-refs/utility/<id>_sheet.png and <id>_icon.png on ext/agent-briefs.
- **Look:** chunky toy-like prop that reads at 48 px, hand-painted, lightly worn (one chip, one scuff),
  never realistic. Each item's `col` from its JSON is the main colour; one accent. Glow only where the
  card says, small and on the object (type glow is added by the UI, STYLE_CANON "Glow").
- **Prompt suffix for every card:** "stylized chunky game prop, hand-painted texture, soft shading,
  clean thin dark outline, lightly worn, single object centred, flat pale grey background, no text,
  no hands, no characters, no shadow".
- **Style refs:** image 1 = style_refs/boki_style_ref_2d.png (finish), image 2 = the nearest approved
  relic sheet named on the card (prop scale and wear). Never a photo, never another game's icon.
- **Checks (grade bar 8/10, like the Boki batches):** reads as the item at 48 px; silhouette unique
  among the 28 (the slot grid shows six at once); main colour matches `col`; outline thin and even;
  no text, letters, hands, characters, floor shadow or halo; background one flat grey; 3/4 view;
  nothing cropped. Post `ART utility <id> <file> grade X/10` in briefs/EXT_TO_MAIN.md.
- **3D (after 2D approval, one line per card):** Meshy image-to-3D from the sheet, GLB under 1.5k
  tris, one 512 px albedo, no rig, about 0.3 m across, pivot bottom centre, saved as
  assets/utility/<id>.glb. Pickups on the ground and belt previews use it.

## Cards

### 1. Tonic (`tonic`), heal, slot 1
- **Design (ours):** a squat round-bellied glass flask with a cork, filled with glowing mint-green tonic, three fizz bubbles rising inside, a tiny leaf tag tied to the neck. Main colour 8ff0a0 mint green; accent a warm brass or dark wood. Glow: venom green glow inside the liquid only.
- **Prompt:** "A squat round-bellied glass flask with a cork, filled with glowing mint-green tonic, three fizz bubbles rising inside, a tiny leaf tag tied to the neck, main colour mint green, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (filled with glowing mint-green tonic).
- **Refs:** boki_style_ref_2d.png; cinder_relic sheet (glass and ember).
- **Checks:** grade bar 8/10; silhouette distinct from the Deep Draught and Swift draught; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 2. Armor kit (`armor_kit`), armor repair, slot 2
- **Design (ours):** a small canvas roll-kit half open, showing a bent steel plate, a stubby riveting hammer and a coil of wire, a leather strap buckle. Main colour dfe9f7 steel white; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A small canvas roll-kit half open, showing a bent steel plate, a stubby riveting hammer and a coil of wire, a leather strap buckle, main colour steel white, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (showing a bent steel plate).
- **Refs:** boki_style_ref_2d.png; grimble_relic sheet (brass and metal).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 3. Deep Draught (`deep_draught`), full heal, slow drink
- **Design (ours):** a tall narrow bottle of deep blue liquid with a long thin neck and a cloth-wrapped grip, slow heavy drops at the lip, a sleeping-moon stamp on the label. Main colour 6fd0ff tide blue; accent a warm brass or dark wood. Glow: faint tide-blue glow in the liquid.
- **Prompt:** "A tall narrow bottle of deep blue liquid with a long thin neck and a cloth-wrapped grip, slow heavy drops at the lip, a sleeping-moon stamp on the label, main colour tide blue, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (slow heavy drops at the lip).
- **Refs:** boki_style_ref_2d.png; cinder_relic sheet (glass and ember).
- **Checks:** grade bar 8/10; silhouette distinct from the Deep Draught and Swift draught; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 4. Mending kit (`medkit`), instant heal + armor
- **Design (ours):** a chunky square tin with a rounded lid, a green cross-shaped clasp, a bandage end and a tiny armor shard poking out. Main colour 8fe0a0 soft green; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A chunky square tin with a rounded lid, a green cross-shaped clasp, a bandage end and a tiny armor shard poking out, main colour soft green, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a green cross-shaped clasp).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 5. Shield cell (`shield_cell`), 8 s shield
- **Design (ours):** a hexagonal crystal cell in a brass cradle, a soft blue bubble skin just lifting off its surface. Main colour 7ac8ff sky blue; accent a warm brass or dark wood. Glow: frost-blue sheen on the bubble.
- **Prompt:** "A hexagonal crystal cell in a brass cradle, a soft blue bubble skin just lifting off its surface, main colour sky blue, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a soft blue bubble skin just lifting off its surface).
- **Refs:** boki_style_ref_2d.png; grimble_relic sheet (brass and metal).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 6. Swift draught (`stim`), +35% speed 6 s
- **Design (ours):** a slim stoppered vial of fizzing yellow liquid shaped like a teardrop leaning forward, two speed-streak ribbons painted on the glass. Main colour ffd76a storm yellow; accent a warm brass or dark wood. Glow: storm-yellow fizz at the top.
- **Prompt:** "A slim stoppered vial of fizzing yellow liquid shaped like a teardrop leaning forward, two speed-streak ribbons painted on the glass, main colour storm yellow, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (two speed-streak ribbons painted on the glass).
- **Refs:** boki_style_ref_2d.png; cinder_relic sheet (glass and ember).
- **Checks:** grade bar 8/10; silhouette distinct from the Deep Draught and Swift draught; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 7. Smoke bomb (`smoke`), hiding cloud 8 s
- **Design (ours):** a round clay pot with a fuse string and a wax seal, a soft puff of lilac-grey smoke curling out of one crack. Main colour b8b0c8 dusty lilac; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A round clay pot with a fuse string and a wax seal, a soft puff of lilac-grey smoke curling out of one crack, main colour dusty lilac, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a soft puff of lilac-grey smoke curling out of one crack).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 8. Seeker flare (`scanner`), reveal 26 tiles 3 s
- **Design (ours):** a short stubby flare tube with a pull ring, a ring of small eye-marks painted around its top, a faint blue spark at the tip. Main colour 9ab4ff periwinkle; accent a warm brass or dark wood. Glow: small blue spark only.
- **Prompt:** "A short stubby flare tube with a pull ring, a ring of small eye-marks painted around its top, a faint blue spark at the tip, main colour periwinkle , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a ring of small eye-marks painted around its top).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 9. Hawk Whistle (`hawk_whistle`), whole-map reveal 4 s
- **Design (ours):** a carved bone whistle shaped like a diving hawk, gold wing-tips, a leather cord loop. Main colour ffd27a warm gold; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A carved bone whistle shaped like a diving hawk, gold wing-tips, a leather cord loop, main colour warm gold, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (gold wing-tips).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 10. Spring pad (`jump_pad`), launch pad 30 s
- **Design (ours):** a round wooden pad on three fat coil springs, a painted seafoam up-arrow on top, scuffed edges. Main colour 8ff0c8 seafoam; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A round wooden pad on three fat coil springs, a painted seafoam up-arrow on top, scuffed edges, main colour seafoam , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a painted seafoam up-arrow on top).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 11. Cloud Raft (`cloud_raft`), air platform 30 s
- **Design (ours):** a folded puffy cloud-cushion tied with a rope and a wooden toggle, one corner already lifting and fluffing out. Main colour bfe9ff pale sky; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A folded puffy cloud-cushion tied with a rope and a wooden toggle, one corner already lifting and fluffing out, main colour pale sky, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (one corner already lifting and fluffing out).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 12. Gust Fan (`gust_fan`), launch fan 60 s
- **Design (ours):** a stout wooden fan housing with three fat rounded blades, a hand crank on the side, a couple of ribbon streamers blowing off the front. Main colour 9fe8ff ice blue; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A stout wooden fan housing with three fat rounded blades, a hand crank on the side, a couple of ribbon streamers blowing off the front, main colour ice blue, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a hand crank on the side).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 13. Twin Gate (`twin_gate`), paired swap gates
- **Design (ours):** two small matching stone arch-stones bound together with a violet thread, each with a tiny swirl carved in the middle. Main colour c9a0ff soft violet; accent a warm brass or dark wood. Glow: shadow-violet swirl glow.
- **Prompt:** "Two small matching stone arch-stones bound together with a violet thread, each with a tiny swirl carved in the middle, main colour soft violet, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (each with a tiny swirl carved in the middle).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 14. Warp Seed (`warp_seed`), random warp 30 s
- **Design (ours):** a fat acorn-like seed with a split shell, violet light leaking out of a spiral crack, a curled root tip. Main colour b48cff violet; accent a warm brass or dark wood. Glow: shadow-violet light in the crack.
- **Prompt:** "A fat acorn-like seed with a split shell, violet light leaking out of a spiral crack, a curled root tip, main colour violet , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (violet light leaking out of a spiral crack).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 15. Lostway Scroll (`lostway_scroll`), random teleport, 4 s read
- **Design (ours):** a rolled parchment scroll tied with a frayed cord, the visible edge painted with a wandering dotted path and a question-mark compass rose. Main colour f0e0a0 parchment; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A rolled parchment scroll tied with a frayed cord, the visible edge painted with a wandering dotted path and a question-mark compass rose, main colour parchment , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (the visible edge painted with a wandering dotted path and a question-mark compass rose).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 16. Bounty Banner (`bounty_banner`), 2 min bounty
- **Design (ours):** a short banner pole with a torn red pennant, a painted gold coin-and-crown crest, the pole top a brass spike. Main colour ff6a5a ember red; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A short banner pole with a torn red pennant, a painted gold coin-and-crown crest, the pole top a brass spike, main colour ember red, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a painted gold coin-and-crown crest).
- **Refs:** boki_style_ref_2d.png; grimble_relic sheet (brass and metal).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 17. Hearth Lamp (`hearth_lamp`), revive beacon
- **Design (ours):** a small iron lantern with a round glass belly, a heart-shaped ember glowing inside, a hooked handle. Main colour ffb070 hearth orange; accent a warm brass or dark wood. Glow: ember glow inside the glass.
- **Prompt:** "A small iron lantern with a round glass belly, a heart-shaped ember glowing inside, a hooked handle, main colour hearth orange, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a heart-shaped ember glowing inside).
- **Refs:** boki_style_ref_2d.png; cinder_relic sheet (glass and ember).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 18. Revive Ember (`revive_ember`), squad revive, boss drop
- **Design (ours):** a palm-sized egg-shaped ember with a cracked gold shell, warm light seeping through the cracks, resting in a nest of ash. Main colour ffe08a pale gold; accent a warm brass or dark wood. Glow: ember glow through the cracks.
- **Prompt:** "A palm-sized egg-shaped ember with a cracked gold shell, warm light seeping through the cracks, resting in a nest of ash, main colour pale gold, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (warm light seeping through the cracks).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 19. Skyfall Charge (`skyfall_charge`), 5 s lethal blast + fire
- **Design (ours):** a stubby rocket-shaped canister with three fins, a painted falling-star mark, a lit fuse ring at the nose. Main colour ff7a3a ember orange; accent a warm brass or dark wood. Glow: small ember spark at the fuse.
- **Prompt:** "A stubby rocket-shaped canister with three fins, a painted falling-star mark, a lit fuse ring at the nose, main colour ember orange, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a painted falling-star mark).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 20. Shatter Charge (`shatter_charge`), armor strip + slow
- **Design (ours):** a round grenade like a cracked clay sphere bound in copper bands, a hairline shatter pattern across the shell. Main colour ff9a5a orange; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A round grenade like a cracked clay sphere bound in copper bands, a hairline shatter pattern across the shell, main colour orange , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a hairline shatter pattern across the shell).
- **Refs:** boki_style_ref_2d.png; grimble_relic sheet (brass and metal).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 21. Blight Flask (`blight_flask`), 40 s blight patch
- **Design (ours):** a bulbous dark glass flask with a ragged cloth stopper, thick purple liquid, drips down one side, three spore motes. Main colour 7a4a9a blight purple; accent a warm brass or dark wood. Glow: venom-purple sheen on the drips.
- **Prompt:** "A bulbous dark glass flask with a ragged cloth stopper, thick purple liquid, drips down one side, three spore motes, main colour blight purple, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (thick purple liquid).
- **Refs:** boki_style_ref_2d.png; cinder_relic sheet (glass and ember).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 22. Thorn Wall (`thorn_wall`), thorn wall 20 s
- **Design (ours):** a bundle of thorny vine cuttings tied with twine, a few bright red thorn tips, one green sprout. Main colour 7fd06a leaf green; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A bundle of thorny vine cuttings tied with twine, a few bright red thorn tips, one green sprout, main colour leaf green, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a few bright red thorn tips).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 23. Lookout Lantern (`lookout_lantern`), reveal ward 60 s
- **Design (ours):** a paper lantern on a short hook, a big painted open eye on the paper, pale blue light inside. Main colour 9ae0ff pale blue; accent a warm brass or dark wood. Glow: frost-blue light inside.
- **Prompt:** "A paper lantern on a short hook, a big painted open eye on the paper, pale blue light inside, main colour pale blue, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a big painted open eye on the paper).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 24. Omen Draught (`omen_draught`), see Wardens 30 s
- **Design (ours):** a round crystal-ball bottle on a tiny tripod, swirling lavender mist inside, a clock-hand stopper. Main colour c0a0ff lavender; accent a warm brass or dark wood. Glow: prism-lavender swirl inside.
- **Prompt:** "A round crystal-ball bottle on a tiny tripod, swirling lavender mist inside, a clock-hand stopper, main colour lavender , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (swirling lavender mist inside).
- **Refs:** boki_style_ref_2d.png; cinder_relic sheet (glass and ember).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 25. Pilfer Pouch (`pilfer_pouch`), raccoons steal gems
- **Design (ours):** a lumpy drawstring pouch with a raccoon-paw print patch, two gem tips poking out of the top, a striped tail tassel on the cord. Main colour d0b080 sand; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A lumpy drawstring pouch with a raccoon-paw print patch, two gem tips poking out of the top, a striped tail tassel on the cord, main colour sand , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (two gem tips poking out of the top).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 26. Toss Satchel (`toss_satchel`), thrown heal pack
- **Design (ours):** a small round satchel with a shoulder strap wound around it, a green heart-leaf badge, a bandage tail trailing. Main colour 8fe0a0 soft green; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A small round satchel with a shoulder strap wound around it, a green heart-leaf badge, a bandage tail trailing, main colour soft green, hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a green heart-leaf badge).
- **Refs:** boki_style_ref_2d.png; motley_relic sheet (painted wood and cloth).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 27. Chest Key (`chest_key`), opens locked chests
- **Design (ours):** a chunky gold key with a chest-shaped bow and two fat teeth, a small worn ribbon. Main colour ffd27a gold; accent a warm brass or dark wood. Glow: none.
- **Prompt:** "A chunky gold key with a chest-shaped bow and two fat teeth, a small worn ribbon, main colour gold , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (a small worn ribbon).
- **Refs:** boki_style_ref_2d.png; grimble_relic sheet (brass and metal).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

### 28. Rift Key (`rift_key`), opens a rift hatch
- **Design (ours):** a chunky dark-iron key with a jagged rift-crack bow, violet light in the crack, a chain link. Main colour b98aff violet; accent a warm brass or dark wood. Glow: shadow-violet light in the crack.
- **Prompt:** "A chunky dark-iron key with a jagged rift-crack bow, violet light in the crack, a chain link, main colour violet , hand-painted toy-like game item icon, three-quarter view" + suffix.
- **Sheet:** 3/4 big, front, side, close-up of the telling detail (violet light in the crack).
- **Refs:** boki_style_ref_2d.png; grimble_relic sheet (brass and metal).
- **Checks:** grade bar 8/10; silhouette distinct from its neighbours; no text; flat grey; icon crop 512x512.
- **3D:** Meshy image-to-3D from the sheet, under 1.5k tris, pivot bottom centre, about 0.3 m: after 2D approval.

## Grouping for the batch
- Drinks and flasks (7): tonic, deep_draught, stim, blight_flask, omen_draught, shield_cell, scanner.
  Keep the bottle shapes different (squat, tall, teardrop, bulbous, round, hexagon, tube).
- Kits and pouches (5): armor_kit, medkit, toss_satchel, pilfer_pouch, lostway_scroll.
- Placed things (8): jump_pad, cloud_raft, gust_fan, twin_gate, warp_seed, thorn_wall, lookout_lantern, hearth_lamp.
- Thrown charges (3): skyfall_charge, shatter_charge, smoke.
- Keys and tokens (5): chest_key, rift_key, hawk_whistle, bounty_banner, revive_ember.

## Open notes
- The in-game `icon` glyph names stay until the icons land; swapping them is a one-line JSON change per item.
- Tonic and Armor kit are always on the belt (slots 1 and 2), so they are seen most: do them first.
- Revive Ember and Hearth Lamp both glow warm; keep the Ember egg-shaped and the Lamp a lantern so they never read alike.
