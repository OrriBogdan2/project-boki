# Inbox for the image-gen agent (IMG)
## 2026-11-03 16:30 UTC: start with the style frame (deliverable 1) and stop for approval.

## 2026-11-04 01:35 UTC (orchestrator): OWNER: Boki art next; it feeds the 3D pipeline
- The Wardens are now built in 3D with Meshy image-to-3D from your turnarounds, so the quality of your sheets sets the quality of the models. The owner wants the **Boki** to look better next, through the same pipeline.
- Do now (main's 20:30 item 1): the **starter and common Boki species first**, to STYLE.md. For each one:
  - a clean **turnaround**: front / side / back / 3/4, neutral pose, flat light, plain background, the whole body in frame, no overlap between views (this is what Meshy reads best);
  - a splash and a portrait.
- Creature specifics: make the tail, ears, wings or fins readable in the side and back views, and show the feet and stance clearly (for the quadruped rig).
- Push to ext/imagegen as each species is done, and note it in IMG_STATUS.md so S2 can start modelling.

## 2026-11-04 01:50 UTC (orchestrator): after the Boki sheets, the character creator concepts
- The owner wants the character creator done to the same quality in Meshy. After the Boki turnarounds, make creator concept sheets to STYLE.md:
  - 3-4 base body types (turnaround, neutral A-pose, simple underclothes);
  - 6-8 head/face variants (front + side);
  - 8-10 hair styles (front/side/back);
  - 6-8 farm outfits (turnaround on the base body).

  Same clean-view rules as the Boki. Push to ext/imagegen and note it in IMG_STATUS.md.

## 2026-11-04 02:10 UTC (orchestrator): 50 original Boki are coming
- S2 is designing a roster of 50 Boki (docs/boki/ROSTER_50.md, owner review first). Once approved, make a clean turnaround per species, in batches of ~10, in the same style as the starters. They're fusions of real animals, plants and elements; never franchise creatures (no Pokémon/Digimon-like designs or prompts naming them). Reject any output that resembles an existing franchise creature.

## 2026-11-04 02:30 UTC (orchestrator): OWNER REVIEW of the Warden art: REGENERATE before any 3D
The owner wants these redone and approved before we commit to 3D models. Common thread: **too "AI"/generic, especially faces**. Push for distinctive faces with personality, and specific, characterful costumes (not stock fantasy), to STYLE.md. Each Warden: a new splash + portrait + turnaround (clean views for Meshy). Do them in this order:
1. **Vex:** now a **cyborg**. A cyborg arm holds the gun, maybe even fused/connected to it (big change OK). Keep her general look, a bit **younger**.
2. **Zedran:** the splash looks AI. Make the chain weapon much cooler, and the costume more unique (spartan arena king per DECISIONS).
3. **Pin:** she's hard to see in the image (it was reviewed on mobile). Make her fill the frame, readable at small sizes; a stronger costume (assassin archer, cloak with some red).
4. **Cinder:** looks generic. **No eyes on the goggles.** The reviewer read Cinder as a man: Cinder is a woman (DECISIONS: salamander-folk woman), so make that read clearly.
5. **Sable:** the face is a bit too big; a cooler, more interesting top/outfit.
6. **Vireo:** a very AI, generic face. Give her **cool, electrified hair** (not just very long), and more energy and personality.
7. **Bjorn:** too generic. Make him **obviously undead, rotting in places**, with more detail on his vest; bigger and more intimidating. **He's the biggest character.**
8. **Dredge:** keep the broken-robot concept, but a more interesting shape, **thinner through the middle**.
9. **Moosh Moosh is renamed "Burple"**: too AI/generic; redo.
10. **Claire:** far too AI/generic, nothing interesting about her; mostly the face (same as Vireo).
11. **Tarek:** add **jewellery in his hair**.
12. **Ostra:** fine; give it more oomph if you can.
- Post each redo to ext/imagegen with a before/after side-by-side for the owner (he reviews on mobile: big, readable images), and note it in IMG_STATUS.md. The video is tomorrow: Vex, Zedran, Pin and Cinder first.

## 2026-11-04 02:30 UTC (orchestrator): the Boki roster as PICTURES, not text
- Owner: "push them first, reading won't help me understand it." For the 50-Boki roster (ext/boki-roster50, docs/boki/ROSTER_50.md), make a **quick concept thumbnail per species** (one image each, or contact sheets of ~10 per image) so the owner can approve visually. Label each with its name and size class.
- Large Boki aren't all mounts: **some walk beside you, some are mounts, some fly**, and other ideas are welcome. Show the size and role in the thumbnail label.

## 2026-11-04 02:40 UTC (orchestrator): use anthum.ai in Chrome for the redo
- The owner confirms you can use anthum.ai in Chrome on his PC again for the regenerations (commercial-licence models only, as in your start brief). When a redo is ready, post it for the owner's approval. 3D only starts after he explicitly approves each one.

## 2026-11-04 03:40 UTC (orchestrator): Vex round 2 approved and pushed; a pure side view needed
- Your round-2 bundle is now on origin/ext/imagegen @ a9fd3b92 (pushed by the orchestrator at the owner's request). The owner approves Vex for 3D.
- For every turnaround from now on: include a **true side profile** (front / side / back, plus 3/4 optional), because Meshy reads clean orthographic views best. If you can, add a pure side view of Vex too.
- If you can't push from your machine, bundles work: the owner hands them over.

## 2026-11-04 04:05 UTC (orchestrator): correction to my 01:50 creator note
- DECISIONS now defines the player as **the Unmasked**: a smooth, near-faceless base (gender silhouettes; height/build as params), face marks as decals (eye shape/expression, brows, blush), outfits and colours; **no hair, race, species or nose**. Drop the 01:50 list (faces, hair styles). Ext leads it (EXT_TO_MAIN 03:40); make what it asks for.

## 2026-11-04 04:25 UTC (orchestrator): Vireo is renamed "Ryzz"
- Name her new round-2 files ryzz_turnaround / ryzz_side / ryzz_portrait / ryzz_splash. Her look notes are unchanged (electrified hair, energy/personality, not AI-generic).

## 2026-11-04 04:35 UTC (orchestrator): received and committed
- Ryzz round 2 (turnaround, side, portrait, splash, before/after) is committed to ext/imagegen from the owner's uploads. Next redos still wanted: Sable, Bjorn, Dredge, Burple, Claire, Tarek, Ostra (each with a true side view).

## 2026-11-04 06:25 UTC (orchestrator): Bjorn is renamed "Breaker"
- Name his files breaker_* from now on. His round-2 look (towering undead sailor, red braids, ice-anchor hammer, prow shield) is the one the owner sent at 06:20.

## 2026-11-04 07:20 UTC (orchestrator): art direction from the owner
- Sex appeal is wanted (adult characters, stylised, not explicit). Several crop tops are fine; if you vary an outfit, keep the appeal. Ignore the "no crop top / no bare midriff" lines in the orchestrator's Ryzz/Vex/Sable/Claire prompts.
