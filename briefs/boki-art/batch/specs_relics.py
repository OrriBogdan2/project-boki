# Relic art (coordinator order, briefs/boki-art/relics/RELIC_PROMPTS.md). Runs after every Boki job (build_jobs sorts relic_* last).
# One 2D sheet per relic now; the 512 px transparent icon is made from the approved sheet afterwards.
_R='briefs/art-refs/'
_RELIC_STYLE=("Stylized chunky game prop, hand-painted texture with soft painterly shading and a clean, fairly thin dark outline, toy-like proportions, "
 "worn and dug up from ruins (grime, small chips, faint cracks), one saturated hero colour plus a thin warm gold filigree accent, "
 "and a faint porcelain-white glow hint along its edges. ")
_RELIC_LAYOUT=("A relic sheet of ONE object, nothing else: on the left a big three-quarter view of it, and on the right, smaller, a straight front view, "
 "a straight side view and a close-up of its most worn detail, all the same object at the same design, neatly spaced in a clean layout. "
 "Flat neutral light grey background, soft rim light, no text, no labels, no logos, no hands, no people, no characters, no creatures. ")
def RL(hero,ref,desc):
    SPECS.append({'id':'relic_'+hero,'name':'Relic: '+hero.capitalize(),'refs':[_R+ref],'runs':2,'aspect':'16:9',
      'prompt':("Image 1 is the hero this relic belongs to: use it only for colour palette and motifs. Do NOT draw the hero, any person or any part of a body. "
                +_RELIC_LAYOUT+"The object: "+desc+" "+_RELIC_STYLE)})
RL('vex','vex_FINAL_sheet.png',"A thick worn brass coin, crude eye stamped on its face, one nick on the rim, a short scratched bounty tally along its edge, shown mid-flip above a small dust puff, dull brass with teal tarnish.")
RL('kael','kael_FINAL_sheet.png',"A pair of heavy rusted iron shackle cuffs joined by four chain links, the last link snapped open, flecks of wall mortar clinging, dark iron and rust.")
RL('cinder','cinder_FINAL_sheet.png',"An empty stoppered glass vial with dried dark blood residue streaks, a cracked lip and a cork stopper, a single bright red-orange ember glowing at the bottom only; smoked glass, black and red-orange.")
RL('meeko','pip_FINAL_sheet.png',"A palm-size glass globe on a small wooden base holding a tiny smiling sun and a puffy raincloud that drips a few raindrops, the sun glowing warmly inside; warm yellow and soft grey-blue.")
RL('tenzo','tarek_FINAL_sheet.png',"A smooth slate river-stone with a carved open-eye ring, moss in the groove, a faint green glow in the eye ring; slate and green.")
RL('lace','hem_FINAL_sheet.png',"A cracked white porcelain half-face mask with red thread stitched across the cracks and hollow eyes; white with red thread.")
RL('grimble','grimble_FINAL_sheet.png',"A thick brass monocle with a round pale-blue lens, a short chain and tiny loot-price tick marks engraved around the rim.")
RL('neve','claire_FINAL_sheet.png',"A pair of old figure skates tied together by their laces, frosted blades with a faint frost shimmer, one lace frayed; pale ice-blue and tan leather.")
RL('sparkle','ryzz_FINAL_sheet.png',"A short iron lightning rod from a spire top with an ornate finial, fused-glass scars and a scorch spiral where the bolt hit, a small electric-yellow arc on its tip only.")
RL('albert','mossy_v2/mossy_v2_master_sheet.jpg',"A brass ship's compass with cracked glass, its needle fixed on one heading, barnacles crusting the case; brass and sea-green.")
RL('sable','sable_FINAL_sheet.png',"A slim dagger whose blade is shaped like a moth wing with a dusty scale pattern and a hooked cross-guard; charcoal and muted lilac.")
RL('motley','motley_v2/motley_v2_master_sheet.jpg',"A small faded-purple jack-in-the-box with a crank, its lid popped open and a painted jester head on a coiled spring, chipped gold paint.")
