# Round 7 (01:35 UTC 11-09): Teapotamus redo (owner 7.1, "Can be cuter"; bar 8.5). Rejected sheet: evolutions/Teapotamus.jpg.
# Fixes: cuter first (rounder, chubbier, bigger head, shorter snout, bigger wide-set eyes, happy face); the kettle IS the body,
# no riveted bands or straps around it (the old sheet read as a shell strapped on); still Puffamus/Chuggamus family (plum grey,
# brass porthole eyes), still a little bite (two tiny tusks). r2 = baby of Puffamus, r2b = cuter redesign of the old sheet.
_TEA_BODY=("A tiny, chubby hippo calf, about half the size of image 1, whose round body IS a little copper teakettle: its whole torso "
"is one smooth, shiny, round copper kettle belly, like a plump teapot, with the plum-grey hippo head, four short stubby legs and "
"rump growing straight out of the copper, the copper fading into its plum-grey skin at the neck and legs with no seam, band or "
"strap. A small domed copper kettle lid with a round brass knob sits on top of its round back, tilted a little, with a thin "
"line of warm orange glow and a tiny curl of steam escaping under it. Its short tail is a little curved copper kettle spout "
"that puffs steam. Tiny round ears, stubby legs with round hippo feet and little brass toenails, a few water droplets of "
"condensation beading on the copper.")
_TEA_FACE=("a big round head, a short, soft, rounded snout, rosy cheeks, two big, wide-set, sparkling brass-rimmed porthole "
"eyes with large dark pupils and bright highlights, a happy closed-mouth smile showing two tiny tusk nubs, little puffs of "
"steam from its nostrils")
_TEA_COLS="shiny copper and soft plum grey, with a brass and warm orange accent"
_TEA_AVOID=("riveted bands, belts, straps or harnesses around its body, a shell or armour sitting on its back, a long snout, "
"small eyes, a grumpy or angry face, a handle on its back, standing upright, anything held")
V('teapotamus_r2','Teapotamus (redo, cuter)',E+'Puffamus.jpg','baby',_TEA_BODY,_TEA_FACE,_TEA_COLS,_TEA_AVOID,'ember','cute')
SPECS.append({'id':'teapotamus_r2b','name':'Teapotamus (redo, cuter, from old sheet)','refs':[E+'Teapotamus.jpg',SR3],'runs':3,
 'prompt':"Creature-collector monster design for a fantasy action game. Redesign the creature in image 1 so it is MUCH cuter and "
 "more lovable, keeping its idea (a baby hippo fused with a copper teakettle, brass porthole eyes, a spout tail, a lid with a brass "
 "knob) and its main colours, but changing its shapes as written here. "+STYLE2+CORE+RENDER+SHEET+
 desc(_TEA_BODY,_TEA_FACE,_TEA_COLS,_TEA_AVOID,'ember','cute')})
