# 17:16 ET 11-09 V2 style pass (STYLE_CANON_V2.md etc., proposal; not wired in yet). First job, per owner via the Fable session:
# Galleotter edit (RERENDER_PROMPTS.md section 7): move the ship deck and mast up onto its chest. Shown to the owner before its re-render.
SPECS.append({'id':'galleotter_edit_v2','name':'Galleotter (card edit: ship onto chest)','refs':['briefs/boki-art/cards/Galleotter.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Edit image 1: keep everything exactly the same: the same creature, design, colours, pose, style and plain pale grey background. Only change this: "
    "Move the ship deck and the mast up onto its chest and upper belly, so the deck lies between its front paws and its waist and the mast rises from the middle of its chest. "
    "Its lower belly, hips and hind legs are plain brown fur with nothing on or between them. The otter, its pose on its back, its face, the tail prow, the oars, the sail and every colour stay exactly the same. Do not add anything else.")})
# 17:3x ET: try 1 barely moved the ship (mast still rises at the hips in all 4). Stronger wording, try 2:
SPECS.append({'id':'galleotter_edit_v2b','name':'Galleotter (card edit try 2: ship onto chest)','refs':['briefs/boki-art/cards/Galleotter.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Edit image 1. Keep the same otter, face, colours, pose on its back, tail prow, oars, style and plain pale grey background. Change only where the ship sits: "
    "Take the mast and sail away from its hips and hind legs entirely. The ship deck becomes SHORTER and sits only on its chest and upper belly, from just under its chin down to its waist, held between its front paws. "
    "The single mast stands straight up out of the middle of that deck, at the centre of its chest, with the same sail. The oars stick out from the sides of that shorter deck. "
    "Below the waist there is no wood at all: its lower belly, hips and both hind legs are plain soft brown fur, clearly visible. Only one mast. Do not add anything else.")})

# 17:27 ET 11-09: OWNER APPROVED the V2 files and the whole hold list (RERENDER_PROMPTS s7) for redesign. Concept round, 4 runs each,
# image 1 = current card. Same rendering as the card so the owner judges construction only; the V2 style pass comes after his pick.
def _RD(n,problem,direction,extra='',tag='',runs=4):
    SPECS.append({'id':'rd_'+n.lower()+tag+'_v2','name':n+' (redesign concept'+(' '+tag if tag else '')+')','refs':['briefs/boki-art/cards/'+n+'.jpg'],'runs':runs,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one Boki (a stylised, cute but slightly dangerous creature-collector monster): "+n+", a REDESIGN of the creature in image 1. "
        "Keep from image 1: the same animal, the same colours and where they sit, the same eyes and face, the same core idea and signature parts, the same life stage and size, and the same rendering style, so the only change is how its body is built. "
        "The problem with image 1: "+problem+". Change it like this: "+direction+". "+extra+
        "Every part grows out of its body with a thick fused base, as if it was born with it: nothing strapped, belted, banded, buckled, bolted, riveted on, worn, carried, held or sat on. One way of moving only: legs, no wheels. "
        "Clearly an animal with Boki proportions (a slightly oversized head, bold simple shapes), never standing upright like a person. "
        "View: a gentle three-quarter view with both eyes showing. One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no glow, no text.")})
_RD('Gongrowl',"it wears a chest plate on straps, a shoulder strap, wrist cuffs and a back disc, and it is a semi-realistic gorilla with a small head",
    "the gong is a round bronze disc grown into its chest like a breastbone plate, and the same bronze shows again in its knuckles and a crest on its skull; no straps, cuffs or back disc",
    "Make its head bigger, about 22% of its height. Its fur is near black with one lighter lit shape on the upper left; the bronze is the lightest value. It faces the viewer, pounding its chest gong with one fist. ")
_RD('Anvilbrock',"bolted plates on its shoulders and legs, and an anvil sitting on its back","its back is one grown anvil slab rising out of its spine; the plates become patches of dark iron hide with no rivets and no raised edges")
_RD('Forgebrock',"bolted plates on its shoulders and legs, and an anvil and furnace sitting on its back","its back is one grown anvil slab rising out of its spine, with the furnace glow showing through cracks in that slab; the plates become patches of dark iron hide with no rivets and no raised edges")
_RD('Barostorm',"it stands upright like a person and wears bracers, greaves and a crown","a low, four-legged stance; the gold becomes horn growing at its brow and its tail tip; the barometer dial becomes a round marking on its belly")
_RD('Furnacowary',"banded furnace armour and anvil-shaped feet","the firebox is its own open ribcage, the ribs its own dark bone with the fire glowing between them; the chimney is its casque on top of its head; plain bird feet with thick claws")
_RD('Vaultara',"a vault door plus riveted leg armour with gold trim","the vault door is its own shell, with the hinge as a ridge along its spine; its legs get thick plain scale plates, no armour, no rivets, no trim")
_RD('Prowyak',"a riveted steel plate bolted over its face","the ship's prow is its own keeled skull boss, a bony ridge growing from its forehead between the horns, in the same steel colour")
_RD('Bastionpet',"riveted bands around its claws and legs","those bands become raised ridges of its own shell, fused to it, with no rivets")
_RD('Siegephant',"a tower, a face mask, wheels as well as feet, a chain and mace tail, and rivets on every plate",
    "legs only, no wheels; the tower is a crest grown from its head and back; the portcullis is its own row of teeth; the tail is a thick tail ending in a mace-shaped knob, no chain; at most 3 rivet bumps per plate")
_RD('Chuggamus',"a hippo wearing a locomotive: wheels as well as legs, and a riveted boiler shell",
    "the boiler belly is its own copper hide; the smokestack is a horn on its snout; four thick piston-shaped legs and no wheels; the cowcatcher is its lower jaw")
_RD('Tiltster',"a hamster inside a pinball machine with chrome arms and leg frames",
    "the pinball table is its own flat back shell; the bumpers are round knobs growing from that shell; the flippers are its own front paws; no frame, no chrome legs")
_RD('Canvastross',"a bird wearing a ship's hull, masts and rigging","the hull is its own keeled chest; the sails are its wings; the mast is one tall crest feather; no ropes or rigging")
_RD('Barrelmander',"a salamander wearing a hooped barrel","the cask is its own back, patterned like wooden staves; the hoops are ridges of its own skin")
_RD('Bucketmander',"a salamander sitting inside a bucket","the bucket is its own rounded back and belly, patterned like wooden staves, with the hoops as ridges of its own skin; it stands on its own legs, not inside anything")
_RD('Crofthollow',"a cottage with walls, a window and chimney smoke sitting on a yak","its hump is shaped like a thatched roof made of its own fur, with one chimney-shaped horn; no walls, window or smoke")
_RD('Pagoguana',"a pagoda building on its back, and it stands upright","the pagoda tiers are stacked plates growing along its spine; it stands on all four legs with its tail planted")
_RD('Pagoguana',"a pagoda building on its back","the pagoda tiers are stacked plates growing along its spine",
    "Keep its rearing stance from image 1 (the owner liked it standing up), but rearing like an animal on its hind legs with its tail planted, not standing like a person. ",tag='rear')
_RD('Domeleon',"a riveted dome and a telescope carried on its back","the dome is its own casque on its head; the telescope is one tube-shaped turret eye, like a chameleon's eye")
_RD('Stormit',"a crab carrying a glass case, with spring legs","the case is its own see-through shell; plain crab legs")
_RD('Maulangler',"a bolted trap jaw, a strap band and a hanging chain","the trap is its own toothed jaw with a knuckle joint at the hinge; the hook grows out of the end of its lure stalk; no chain, no strap")
_RD('Snapler',"a bolted trap jaw, a strap band and a hanging chain","the trap is its own toothed jaw with a knuckle joint at the hinge; the hook grows out of the end of its lure stalk; no chain, no strap")

# 17:29 ET 11-09: V2 PILOT, 12 Boki x both routes (RERENDER_PROMPTS s1/s1b). Interim anchors (no artist, owner 17:23) saved at
# style_refs/v2/anchor_<arch>.png from the s6 style-a runs; creepy and majestic darkened in post. Best pilot runs of the 6 anchor
# Boki become the final anchors. Route A = card + anchor, route B = sheet + anchor + pose in words. 3 runs each.
exec(open(HERE/'style_v2.py').read())
_C='briefs/boki-art/cards/'
_PILOT=[ # name, stage, arch, dark, furry, sheet, pose, cols, counts, fix
 ('Vespyx','baby','cute',False,True,'evolutions/Vespyx.jpg',"sitting curled up, its tail arched up over its back with the venom bead above its head",
  "plum-purple fur, pale lilac chest, muzzle and inner ears, darker plum ear tips and paws, a dark plum segmented tail, one lime-green venom bead, lime-green eyes",
  "four legs, two ears, one tail with the same number of segments as image 1, ending in one venom bead",
  "the tail segments are plain matte chitin with one shade each; only the venom bead has a highlight"),
 ('Coolatee','baby','cute',False,False,'turnarounds/Coolatee.jpg',"lying on its belly with its head up and front flippers out, happy open mouth",
  "creamy white body, pale ice-blue crystals on its back, green eyes, dark grey nose","two front flippers, two hind flippers, one cluster of ice crystals on its back",''),
 ('Chandelotl','final','pretty',False,False,'evolutions/Chandelotl.jpg',"raised up like a cobra with its crystal hood spread and its striped tail coiled beside it",
  "pink axolotl body, red, pale pink and mint-green candy stripes on the tail, red and green chevrons down the chest, pink-red feathery gills, a pale ice-blue crystal hood, brown-pink eyes",
  "four legs, six feathery gills (three each side), one crystal hood, one crystal crown",
  "its face is round-eyed with a small closed mouth (the hero card's face, not narrow eyes or a grin); the chest chevrons and tail stripes wrap round the body like rings"),
 ('Glassolotl','mid','pretty',False,False,'evolutions/Glassolotl.jpg',"mid-leap facing right, legs stretched and body arched, cocky open grin",
  "pale pink see-through body, red and mint-green stripes along its body, pink-red gills, pale crystal shards, dark eyes, rainbow colours on its tail fin only",
  "four legs, six feathery gills, one tail fin",
  "the rainbow sits only on the tail fin, as three flat pastel bands; the jelly body is a flat pale pink with a lighter flat inner shape"),
 ('Rimink','final','sleek',False,True,'evolutions/Rimink.jpg',"standing tall in a long elegant curve, head raised and turned toward the viewer",
  "white fur, a navy-black stripe down its chest and a navy-black tail tip, pale ice-blue crystals along its back and legs, dark blue eyes",
  "four legs ending in ice hooves, one long tail with a navy brush tip, about 12 crystals along its back",
  "the tail brush grows from the tail through a fur ruff (no metal ring)"),
 ('Glaivyx','final','sleek',False,True,'evolutions/Glaivyx.jpg',"standing four-square facing the viewer, its tail blade raised high over its back",
  "dark plum-purple fur, a lime-green curved tail blade, lime-green back spikes and a few drips, green eyes",
  "four legs, one tail ending in one curved blade, one row of green spikes along its back, two ears",
  "the blade grows from the tail bone with a fur ruff at the join; no gems scattered on its flank"),
 ('Lockatara','mid','tough',False,False,'evolutions/Lockatara.jpg',"low prowling crouch, head forward, key-shaped tail curled up behind",
  "olive-green scaly body, grey-steel back spikes and key tail tip, a brass dial on its shoulder, a brass keyhole plate on its brow, green eyes",
  "four legs, one tail ending in one key bit, one row of spikes along its back, one dial, one keyhole",
  "where the key meets the tail is a fused collar of the same grey metal; the dial runes are simple notches; scales as a few big patches"),
 ('Ringrove','final','tough',False,True,'turnarounds/Ringrove.jpg',"planted with its ringed bark back towering",
  "brown fur and bark, moss-green back, mint-green mushroom caps with purple undersides, small cream horns, teal-grey eyes",
  "four legs, mushroom caps in three big tiers on its back, two small horns",
  "group the small mushroom caps into three big tiers; the bear muzzle is simplified to match its body"),
 ('Lurklet','baby','cute',True,False,'evolutions/Lurklet.jpg',"sitting, smiling, its lure bulb glowing above its head",
  "near-black purple body, a lilac lure bulb on a stalk, lilac rings round its belly, big purple eyes, a lilac wispy tail tip",
  "two arms, two legs, one lure stalk with one bulb, one tail",''),
 ('Cindermaw','final','creepy',True,True,'evolutions/Cindermaw.jpg',"stalking forward with its skull head low and grinning",
  "dark purple hyena body (near black), a bone-white skull head and bone spurs, a black sludge mane, a hot-pink and white rib furnace on its flank, a few purple vein lines",
  "four legs, one skull head, open ribs on one flank, one row of spurs along its spine",
  "the eye sockets hold small pinpoint lights, with no blush on the skull; three or four vein lines from the ribs"),
 ('Sarcobra','final','majestic',True,False,'turnarounds/Sarcobra.jpg',"rearing up from its coils with its hood spread and both wings raised high",
  "near-black coils with a dark belly, a gold hood and gold wings with blue-purple feather tips, a blue-purple stripe on its head, golden-yellow eyes",
  "one snake body in coils, one hood, two wings with three rows of big feathers each","the gold is base, one shade and one flat band"),
 ('Aurostag','final','majestic',True,False,'turnarounds/Aurostag.jpg',"standing proud in profile, head turned toward the viewer, antlers spread",
  "deep navy-blue body, a flowing aurora pattern in purple and teal on its body, teal-to-lilac crystal antlers, blue eyes",
  "four legs, two antlers","the aurora is three flat colour ribbons that wrap round its body, with at most seven small flat four-point stars"),
]
import json as _json
_LM=_json.load(open(HERE.parent/'LIVE_MANIFEST.json'))
# Boki cut from the roster keep their old spec lines working: their sheet path falls back to turnarounds/<Name>.jpg (11-10: Coolatee line cut).
for _cut in ('Coolatee','Frigatee','Glaciatee'): _LM.setdefault(_cut,{'sheet':'briefs/boki-art/turnarounds/'+_cut+'.jpg','card':'briefs/boki-art/cards/'+_cut+'.jpg'})
for _n,_st,_ar,_dk,_fu,_sh,_po,_co,_ct,_fx in _PILOT:
    _sh=_LM[_n]['sheet']  # live sheet path wins over the guess in the table
    _anc=SRV2%('sleek' if _ar=='fast' else _ar)
    SPECS.append({'id':'v2a_'+_n.lower(),'name':_n+' (V2 pilot, route A: card + anchor)','refs':[_C+_n+'.jpg',_anc],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD(_n,_st,_ar,_co,_ct,_dk,_fu,_fx)})
    SPECS.append({'id':'v2b_'+_n.lower(),'name':_n+' (V2 pilot, route B: sheet + anchor)','refs':[_sh,_anc],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_B(_n,_st,_ar,_co,_ct,_po,_dk,_fu,_fx)})

# 17:32 ET 11-09: redesign round 1 kept the old build on 11 of 21 (the card as image 1 holds its construction, as with re-poses).
# Round 2 for those: the SHEET as image 1 for identity, and only what to draw (no list of objects to avoid; naming them adds them).
def _RD2(n,body,runs=4,tag=''):
    SPECS.append({'id':'rd2_'+n.lower()+tag+'_v2','name':n+' (redesign concept, round 2)','refs':[_LM[n]['sheet']],'runs':runs,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one Boki (a stylised, cute but slightly dangerous creature-collector monster): "+n+", a redesign of the creature shown from four sides in image 1. "
        "Keep from image 1: the same animal, the same colours, the same eyes and face, the same life stage and size, and the same rendering style. Draw the creature once, not four times. "
        "New design: "+body+" Every part of it grows out of its own body with a thick fused base, as if it was born that way. "
        "Clearly an animal with Boki proportions (a slightly oversized head, bold simple shapes). "
        "View: a gentle three-quarter view with both eyes showing. One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text.")})
_RD2('Barostorm',"it walks low on all four legs like a ferret, belly close to the ground, long tail out behind. The same storm-cloud mane round its neck. A round barometer dial is drawn as a marking in the fur of its belly. Its gold grows as horn: two curved gold horns at its brow and a gold arrow-head spike at the tip of its tail. Its legs are plain cream fur with the same blue swirl markings.")
_RD2('Vaultara',"a tortoise-like creature whose shell IS a round vault door, with the wheel handle in the middle of the shell and the hinge as a ridge running along its spine. Its four legs are thick and covered in plain olive scaly skin with a few big simple scale plates, the same olive as its head. Its key-shaped tail grows from its body.")
_RD2('Barrelmander',"a chunky dark brown salamander walking on four legs. Its back is a rounded cask shape made of its own thick skin, patterned with wooden stave lines, with two raised skin ridges running round it like barrel hoops. Two short stopper-shaped horns grow from the top of its back with one small spark between them.")
_RD2('Bucketmander',"a round baby salamander with feathery gills, standing on two stubby legs with its little tail out behind. Its round lower body is shaped like a little bucket: its own skin patterned with wooden stave lines, with one raised skin ridge round its middle like a hoop. Short stubby arms.")
_RD2('Pagoguana',"a dragon-iguana walking on all four legs, its body long and low and its tail planted behind it. Along its spine grow five stacked tiers of curved, roof-shaped dorsal plates, like the roofs of a pagoda, each tier one green scale plate with an upturned red edge, largest at the shoulders and smaller toward the tail.")
_RD2('Domeleon',"a chameleon whose head carries a big round bronze dome-shaped casque grown from its skull. One eye sits in a long bronze tube-shaped turret like a telescope, the other is a normal round eye. Its body is navy with pale crescent-moon spots; its tail curls into a bronze spiral. Nothing on its back but its own navy skin.")
_RD2('Stormit',"a crab whose whole shell is a clear glass dome grown from its body, with a small lightning storm crackling inside the dome and its face on the front of the dome. Plain orange crab legs and two orange claws. The same small storm cloud floats just above the dome.")
_RD2('Siegephant',"a mammoth-like elephant standing on four thick legs with big round feet. A grey stone castle-tower crest rises from its head and shoulders, grown like a horn. Its mouth is a row of square teeth shaped like a portcullis. Its hide is brown with a few big plates, each with at most three rivet-like bumps. Its tail is thick and ends in a spiked bone knob shaped like a mace. Ivory tusks, yellow eyes.")
_RD2('Anvilbrock',"a stocky orange-brown badger walking on four legs. Its back rises into one grey iron anvil shape grown straight out of its spine, the anvil's base melting into its fur with no gap. Flat dark grey iron patches in its fur on its shoulders and legs, smooth and level with the fur. Blue sparks crackle on the anvil top. Plain furry paws with claws.")
_RD2('Forgebrock',"a big orange-brown badger walking on four legs. Its back rises into one grey iron anvil shape grown straight out of its spine, the anvil's base melting into its fur with no gap, with orange furnace glow showing through cracks in the anvil and one short chimney horn on top. Flat dark grey iron patches in its fur on its shoulders and legs, smooth and level with the fur. Blue sparks crackle on the anvil. Plain furry paws with claws.")
_RD2('Chuggamus',"a purple hippo standing on four thick piston-shaped legs with flat round feet. Its belly and sides are smooth copper hide shaped like a locomotive boiler. A copper smokestack-shaped horn grows on its snout, puffing a little steam. Its lower jaw is shaped like a cowcatcher grille, with a glowing firebox mouth and two ivory tusks.")
# Gongrowl round 1 still reads as a bronze breastplate and keeps the small head: round 2 from the sheet too.
_RD2('Gongrowl',"a gorilla with Boki proportions: a big round head (about a quarter of its height) with a short bronze crest growing from its skull, broad shoulders and long arms. In the middle of its chest the skin itself is a round bronze gong, set into the chest like a breastbone, with dark fur all round its edge and nothing round its shoulders or back. Bronze knuckles grown from its fists. Near-black fur with a lighter grey lit shape on its shoulders. It faces the viewer, roaring, pounding the gong in its chest with one fist. Keep its curled tail.")

# 17:35 ET 11-09 pilot finding: the anchor creature bleeds in when the Boki is close to it in shape: Coolatee route A drew Vespyx's
# purple body behind the seal (3 of 3), Glassolotl drew Chandelotl's striped tail (A1, A2, B2). Retry route A with a one-creature lock.
_ONE=("Image 2 shows a different creature, used only as a style guide: draw no part of it anywhere, no body, tail, limbs, stripes or crystals from it. "
      "The image contains exactly one creature, the one from image 1, and nothing behind or beside it. ")
for _n,_st,_ar,_dk,_fu,_sh,_po,_co,_ct,_fx in _PILOT:
    if _n in ('Coolatee','Glassolotl'):
        SPECS.append({'id':'v2a2_'+_n.lower(),'name':_n+' (V2 pilot, route A + one-creature lock)','refs':[_C+_n+'.jpg',SRV2%_ar],'runs':3,'aspect':'1:1','size':'2K',
                      'prompt':RS_CARD(_n,_st,_ar,_co,_ct,_dk,_fu,_fx).replace("Change ONLY how it is drawn. ","Change ONLY how it is drawn. "+_ONE)})
# Domeleon round 2 still carries a shell and telescope on its back: round 3, the dome moves to the head.
_RD2('Domeleon',"a chameleon gripping with its four feet, body low. Its back and sides are plain bare navy skin with pale crescent-moon spots, low and smooth, with nothing on them. On its HEAD grows a tall rounded bronze casque, like a real chameleon's helmet-shaped head crest, shaped like an observatory dome with one slit line across it. One eye is set in a short bronze tube like a little telescope, the other is a normal round eye. Its tail curls into a bronze spiral.",tag="r3")

# 17:56 ET 11-09 owner: "take off 002's pincers since we took them off 001". Vespox: front scorpion pincers become fox front legs.
_VPX=("Replace its two front scorpion pincers with two ordinary fox front legs: slim furry plum-purple legs like its hind legs, with dark plum paws and small claws, planted on the ground in the same stance. "
      "No pincers or claws anywhere. Its head, face, frill, body, hind legs, segmented tail, stinger, green drips and every colour stay exactly the same.")
for _k,_ref in (('card','briefs/boki-art/cards/Vespox.jpg'),('portrait','briefs/boki-art/portraits/light/Vespox.jpg')):
    SPECS.append({'id':'vespox_nopincer_'+_k,'name':'Vespox (no pincers, '+_k+')','refs':[_ref],'runs':4 if _k=='card' else 3,'aspect':'1:1','size':'2K',
      'prompt':"Edit image 1: keep everything exactly the same: the same creature, design, pose, colours, style and plain background. Only change this: "+_VPX+" Do not add anything else."})
X('vespox_nopincer_sheet','Vespox (no pincers, sheet)','briefs/boki-art/evolutions/Vespox.jpg',_VPX.replace("in the same stance","in the same stance, in all four views"))
SPECS[-1].update({'aspect':'16:9','size':'2K'})

# 17:56 ET 11-09 owner: "tone down 003's gross stuff so it's a bit more neutral" (Glaivyx). Drop the dripping slime; the blade and spikes stay as clean
# lime-green shapes. Card, sheet, portrait, and the V2 pilot pick.
_GLV=("Remove all the dripping slime and goo: no drips hanging from the tail blade, the back spikes or the body, no slime pooling or trailing. "
      "The curved tail blade and the back spikes stay exactly the same shape and the same lime-green, but as clean, solid, smooth shapes with crisp edges. "
      "Its fur, face, pose, every other part and every other colour stay exactly the same.")
for _k,_ref,_r in (('card','briefs/boki-art/cards/Glaivyx.jpg',4),('portrait','briefs/boki-art/portraits/light/Glaivyx.jpg',3),('v2pilot','briefs/boki-art/batch/out/v2a_glaivyx_2.jpg',3)):
    SPECS.append({'id':'glaivyx_clean_'+_k,'name':'Glaivyx (no slime, '+_k+')','refs':[_ref],'runs':_r,'aspect':'1:1','size':'2K',
      'prompt':"Edit image 1: keep everything exactly the same: the same creature, design, pose, colours, style and plain background. Only change this: "+_GLV+" Do not add anything else."})
X('glaivyx_clean_sheet','Glaivyx (no slime, sheet)','briefs/boki-art/evolutions/Glaivyx.jpg',_GLV.replace("stay exactly the same.","stay exactly the same, in all four views."))

# 18:00 ET 11-09 owner: "008 doesn't match 007's style (probably same for 009)". Dex 007-009 = Mycroll > Sporcupine > Ringrove.
# Sporcupine and Ringrove are semi-realistic and scruffy with grey caps and purple gills; Mycroll is clean and cute with mint, cream-spotted caps.
# Redraw both as Mycroll's grown-up family: Mycroll (image 2) is the family and style reference. Route A = own card, route B = own sheet.
def _FAM(n,stage,ref,pose,body,tag,runs):
    SPECS.append({'id':'fam_'+n.lower()+'_'+tag,'name':n+' (match Mycroll, '+tag+')','refs':[ref,'briefs/boki-art/cards/Mycroll.jpg'],'runs':runs,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one Boki: "+n+", the creature in image 1, redrawn so it clearly belongs to the same family as image 2 (Mycroll, its baby form) and looks drawn by the same artist. "
        "Image 1 is its design: keep its animal, body plan, pose, size and signature parts. "+(("Draw it once, in this pose: "+pose+". ") if tag=='b' else "")+
        "Image 2 is the family and the style: use its exact colours and finish. Family colours: warm brown spines and back, cream face, muzzle and belly, mint-green mushroom caps with round cream spots and soft lavender gills underneath, teal eyes, a dark brown nose. "
        "Draw it in image 2's clean style: a bold clean dark brown outline, flat colours with one simple shade, a smooth cute face with big teal eyes and a friendly look, no scruffy fur strands, no realistic texture. "
        "It is the grown-up form of image 2, bigger and tougher, so its face is a little more serious than image 2's, with plain cheeks and no blush. "+body+
        " One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text. Draw no part of image 2's creature.")})
_SPB="It is a porcupine: its quills are about ten mushroom stalks in three sizes growing from its back, each topped with a mint cap; the big cap over its head grows from its brow like part of its skull. Fur is a few big clumps, not strands."
_RGB="It is a big bear-like final form: its back carries three big tiers of mint mushroom caps growing from mossy brown hide, its muzzle is simple and rounded like image 2's, its forelegs are plain brown fur."
for _t,_ref,_r in (('a','briefs/boki-art/cards/Sporcupine.jpg',4),('b',_LM['Sporcupine']['sheet'],3)):
    _FAM('Sporcupine','mid',_ref,'prowling forward, head low, quills raised',_SPB,_t,_r)
for _t,_ref,_r in (('a','briefs/boki-art/cards/Ringrove.jpg',4),('b',_LM['Ringrove']['sheet'],3)):
    _FAM('Ringrove','final',_ref,'planted and sitting tall, its mushroom tiers towering over its back',_RGB,_t,_r)

# ===== 19:56 ET 11-09: owner gave me full pick control (19:51). Owner notes on round 8b, 19:53-19:55 =====
_O='briefs/boki-art/batch/out/'
_PD={p[0]:p for p in _PILOT}
_EDIT="Edit image 1: keep everything exactly the same: the same creature, design, pose, colours, style, line and plain background. Only change this: "
# Glaivyx: the no-slime V2 is "great", only lighter inner fur
SPECS.append({'id':'v2g_glaivyx_white','name':'Glaivyx V2 (white inner fur)','refs':[_O+'glaivyx_clean_v2pilot_2.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"make its light fur almost white: the inner ears, the pale part of its face and muzzle, its chest ruff and the pale fur on its belly and legs become a soft clean white with only a faint lilac tint in the shade. The dark plum fur, the green blade and spikes and everything else stay exactly the same. Do not add anything else."})
# Ringrove (live card fam_ringrove_a_2): look at the camera with a tilted head, a signature expression
SPECS.append({'id':'v2g_ringrove_tilt','name':'Ringrove (head tilt to camera)','refs':['briefs/boki-art/cards/Ringrove.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"turn its head to look straight at the viewer and tilt it clearly to one side, about 20 degrees, like a curious, friendly bear sizing you up, with a small knowing smile. Its body, mushroom caps, colours and everything else stay exactly the same. Do not add anything else."})
# Cindermaw: starting to circle you (pose from the sheet, style from its V2 card)
def _POSE(id_,n,sheet,v2card,pose,runs):
    SPECS.append({'id':id_,'name':n+' (V2 new pose)','refs':[sheet,v2card],'runs':runs,'aspect':'1:1','size':'2K',
      'prompt':("POSE FIRST: "+pose+" "
        "Draw one single character illustration of "+n+". Image 1 shows it from four sides: use it to understand its body from every angle. "
        "Image 2 is the same creature in the final art style, and it is the truth for its design, colours, eyes, face, part counts, line and flat shading: draw it exactly the way image 2 is drawn, only in the new pose. Draw it once. "
        +FRAME_V2)})
_POSE('v2p_cindermaw_circle','Cindermaw',_LM['Cindermaw']['sheet'],_O+'v2a_cindermaw_2.jpg',
  "it is starting to circle the viewer like a predator: its body is side-on, walking slowly in a curve, one front paw lifted mid-step, shoulders low and head lower, and its skull head is turned to stare straight at the viewer.",4)
# Glassolotl: other directions and poses
for _k,_p in (('left',"swimming through the air facing LEFT, body in a long S-curve, tail fin trailing behind, looking ahead."),
              ('rear',"sitting up on its hind legs facing the viewer, front paws raised and curled, tail wrapped round its feet, head tilted, cheeky smile."),
              ('back',"walking away to the right and looking back over its shoulder at the viewer, tail fin swishing."),
              ('pounce',"crouched low facing the viewer, ready to pounce, front legs spread, tail fin raised high behind.")):
    _POSE('v2p_glassolotl_'+_k,'Glassolotl',_LM['Glassolotl']['sheet'],_O+'v2a2_glassolotl_3.jpg',_p,2)
# Chandelotl: other colour schemes on the V2 card
for _k,_c in (('mint',"mint green and soft lilac: a pale mint body, lilac and white candy stripes, mint and lilac chevrons, lilac gills, a pale lilac crystal hood"),
              ('gold',"white and warm gold: a creamy white body, gold and white stripes, gold chevrons, peach gills, a pale gold crystal hood"),
              ('night',"deep navy and silver: a deep navy body, silver and pale blue stripes, silver chevrons, pale blue gills, a silvery ice-blue crystal hood"),
              ('coral',"coral and teal: a coral-orange body, coral, cream and teal stripes, teal chevrons, coral-pink gills, a pale teal crystal hood"),
              ('amethyst',"dark plum and amethyst: a dark plum body, amethyst and pink stripes, amethyst chevrons, pink gills, a pale violet crystal hood")):
    SPECS.append({'id':'v2c_chandelotl_'+_k,'name':'Chandelotl colour scheme: '+_k,'refs':[_O+'v2a_chandelotl_1.jpg'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':_EDIT+"recolour it to a new colour scheme, "+_c+". Its eye colour, the line style, every shape, stripe and crystal stay exactly the same; only the colours change. Do not add anything else."})
# V2 stage B for the 7 pilot Boki the owner did not flag: sheet + portrait from the picked V2 card
_V2PICK={'Vespyx':'v2a_vespyx_1','Coolatee':'v2b_coolatee_1','Rimink':'v2a_rimink_2','Lockatara':'v2a_lockatara_1','Lurklet':'v2a_lurklet_3','Sarcobra':'v2a_sarcobra_2','Aurostag':'v2a_aurostag_1'}
for _n,_s in _V2PICK.items():
    _r=_PD[_n]; _st,_ar,_dk,_fu,_co,_ct=_r[1],_r[2],_r[3],_r[4],_r[7],_r[8]
    SPECS.append({'id':'v2s_'+_n.lower(),'name':_n+' (V2 sheet)','refs':[_LM[_n]['sheet'],_O+_s+'.jpg'],'runs':3,'aspect':'16:9','size':'2K','prompt':RS_SHEET(_n,_co,_ct)})
    SPECS.append({'id':'v2p_'+_n.lower(),'name':_n+' (V2 portrait)','refs':['briefs/boki-art/portraits/light/'+_n+'.jpg',_O+_s+'.jpg'],'runs':3,'aspect':'1:1','size':'2K','prompt':RS_PORTRAIT(_n,_st,_ar,_co,_ct,_dk,_fu)})

# ===== 19:57 ET 11-09: V2 ROLLOUT BATCH 1, stage A (cards): the 21 redesigned/family cards just made live + the 5 round-7 new Boki.
# Data rows written by eye from each card. New-Boki names are mine, pending owner review: Citadoad (Buckleron line final), Bastling (Bastionpet baby).
_B1=[ # name, image1, stage, arch, dark, furry, cols, counts, fix
 ('Gongrowl','cards/Gongrowl.jpg','final','tough',True,True,"near-black fur with grey lit fur on its shoulders, a bronze chest gong, bronze knuckles and skull crest, orange eyes","two arms, two legs, one curled tail, one chest gong, one crest",""),
 ('Anvilbrock','cards/Anvilbrock.jpg','mid','tough',False,True,"orange-brown fur, a grey iron anvil on its back, dark grey iron patches, pale blue eyes and sparks","four legs, one anvil, four iron patches","the iron patches are flat and level with the fur, with no edges"),
 ('Forgebrock','cards/Forgebrock.jpg','final','tough',False,True,"orange-brown fur, a grey iron anvil with orange lava cracks, dark grey iron patches, pale blue eyes and sparks","four legs, one anvil, one chimney horn, five iron patches","the iron patches are flat and level with the fur, with no edges"),
 ('Barostorm','cards/Barostorm.jpg','final','sleek',False,True,"cream fur with pale blue swirl markings, a grey storm-cloud mane, gold horns and gold tail spike, a gold-rimmed dial marking on its flank, amber eyes","four legs, two horns, one tail spike, one dial",""),
 ('Furnacowary','cards/Furnacowary.jpg','final','tough',True,False,"black feathers, a glowing orange-red rib firebox, a bronze casque and beak, brown legs, orange eyes","two legs, two wings, one casque, six ribs each side","no metal trim on its wings; the casque grows from its skull"),
 ('Vaultara','cards/Vaultara.jpg','final','tough',False,False,"olive-green scaly skin, a dark steel vault-door shell with brass wheel and rim, a brass key tail tip, yellow eyes","four legs, one vault shell, one key tail","the shell grows from its body with no straps or trim"),
 ('Prowyak','cards/Prowyak.jpg','mid','cute',False,True,"white shaggy fur, a grey bony prow ridge on its face, grey curled horns, pale ice-blue crystals, grey eyes","four legs, two horns, one prow ridge, about six crystals",""),
 ('Bastionpet','cards/Bastionpet.jpg','final','tough',False,False,"rusty brown crab shell with darker plates, pale grey barnacles, green-grey eyes","eight legs, two claws, one shell","no rivets"),
 ('Siegephant','cards/Siegephant.jpg','final','tough',False,False,"brown hide, grey stone tower crest, dark iron plates, ivory tusks and horn, a spiked iron tail knob, yellow eyes","four legs, two tusks, one horn, one tower, one tail knob","the tower grows from its back like a horn, with no gap; each plate has at most three rivet bumps"),
 ('Chuggamus','cards/Chuggamus.jpg','final','tough',False,False,"purple hippo hide, copper boiler band, copper smokestack horn and piston legs, a glowing orange firebox mouth, ivory tusks, orange eyes","four piston legs, one smokestack, two tusks","the copper band round its body is its own copper hide, with no seams or rivets"),
 ('Tiltster','cards/Tiltster.jpg','final','cute',False,True,"tan-brown fur, a wooden pinball-table back with yellow and red bumpers, a cream belly, brown eyes","four legs, one pinball back, two yellow and four red bumpers",""),
 ('Canvastross','cards/Canvastross.jpg','final','majestic',False,False,"cream-white feathers with pale blue swirl markings, a wooden keel chest, a red crown crest, a tall thin mast feather, blue eyes","two wings, two legs, one keel, one mast feather",""),
 ('Barrelmander','cards/Barrelmander.jpg','mid','cute',False,False,"dark grey-brown skin, a wooden cask back with stave lines, two wooden stopper horns, a small spark, yellow eyes","four legs, one tail, two stopper horns, two hoop ridges","the hoops are ridges of its own skin, not separate bands"),
 ('Bucketmander','cards/Bucketmander.jpg','baby','cute',False,False,"dark grey-brown skin, a wooden bucket-shaped lower body, grey-lilac feathery gills, yellow eyes","two legs, two arms, one tail, six gills, one hoop ridge","the hoop is a ridge of its own skin, not a separate band"),
 ('Crofthollow','cards/Crofthollow.jpg','final','majestic',False,True,"ginger shaggy fur, a straw thatched-roof hump, tree-root legs with moss, branch horns with small pink and red roses, brown eyes","four root legs, two branch horns, one thatch hump, one chimney horn",""),
 ('Pagoguana','cards/Pagoguana.jpg','final','majestic',False,False,"green scales, an orange-brown belly, green pagoda roof plates with red edges along its spine, brown horns, yellow eyes","four legs, two horns, five pagoda tiers, one tail",""),
 ('Domeleon','cards/Domeleon.jpg','mid','cute',True,False,"navy skin with pale crescent-moon spots, a bronze observatory dome casque, a bronze telescope eye and spiral tail, a yellow eye","four legs, one dome, one telescope eye, one spiral tail","the dome grows from its skull with no gap or rim"),
 ('Stormit','cards/Stormit.jpg','mid','cute',False,False,"orange-red crab body, a clear glass dome shell with a grey storm cloud and yellow lightning inside, a small grey cloud above, brown eyes","eight legs, two claws, one glass dome, one cloud above",""),
 ('Maulangler','cards/Maulangler.jpg','final','creepy',True,False,"dark charcoal-grey body, a glowing purple mouth, cream teeth, a dark lure stalk with a hook, purple eyes","four legs, one lure, one hook",""),
 ('Snapler','cards/Snapler.jpg','mid','creepy',True,False,"dark purple-grey body, purple smoke fins, cream teeth, a lure stalk with a glowing hook, purple eyes","two fins, two small legs, one lure, one hook",""),
 ('Sporcupine','cards/Sporcupine.jpg','mid','tough',False,True,"warm brown fur, cream face and belly, mint mushroom caps with cream spots and lilac gills, cream stalks, teal eyes","four legs, one head cap, about ten mushroom quills, one mushroom tail tip",""),
 ('Critwom','batch/out/c_critwom_gp_2.jpg','final','tough',False,True,"brown wombat fur, a cream dice-dome shell with black pips and cream spikes, cream dice plates on its legs and tail, brown eyes","four legs, one shell, one tail knob, four leg plates","the dice plates on its legs are shell grown from its legs, not cuffs"),
 ('Sirencada','batch/out/c_sirencada_gp_2.jpg','final','tough',False,False,"copper and bronze exoskeleton, a siren-horn body with a fan vent, bronze wings, red eyes","six legs, two wings, one horn, one fan vent","its engine parts are its own copper exoskeleton, with no rivets"),
 ('Chimelop','batch/out/c_chimelop_n2_1.jpg','final','pretty',False,True,"pale lilac fur, silver bell-shaped ear tips, small silver bells along its back, brown eyes","four legs, two long ears, five small bells","the gold sound-wave lines around it go: no effects"),
 ('Citadoad','batch/out/c_bulwartoad_t3n2_2.jpg','final','tough',False,False,"olive-green warty skin, a dark rusty iron spiked shell, dark iron horns, a spiked iron club tail, green eyes","four legs, two horns, one shell, one club tail","the metal leg cuffs become plates of its own warty hide, with no bands or rivets"),
 ('Bastling','batch/out/c_bastionpet_t1n2_2.jpg','baby','cute',False,False,"rusty brown crab shell, pale grey barnacles, big green eyes","eight legs, two claws, one shell","no bands on its claws; the plates are its own shell"),
]
for _n,_i,_st,_ar,_dk,_fu,_co,_ct,_fx in _B1:
    SPECS.append({'id':'v2a_'+_n.lower(),'name':_n+' (V2 card, batch 1)','refs':['briefs/boki-art/'+_i,SRV2%_ar],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD(_n,_st,_ar,_co,_ct,_dk,_fu,_fx).replace("Change ONLY how it is drawn. ","Change ONLY how it is drawn. "+_ONE)})

# 19:58 ET 11-09: female looks still missing (babies skipped by design): Arcestrel, Hourachnid, Pavonazar, plus Gongrowl and Furnacowary
# again because their male design changed today. Edit of the live card, so species, pose and style stay the same.
_FEM={'Arcestrel':"the female kestrel: a slightly bigger body, warmer brown plumage with fine dark barring across the wings and back, a shorter crest, and softer, less saturated accent colours",
      'Hourachnid':"the female spider: a bigger, rounder abdomen, the hourglass marking larger and brighter, slightly longer legs, and a calmer face",
      'Pavonazar':"the female, like a peahen: a shorter, rounder tail train with fewer eye-spots, softer muted green and bronze plumage, and the same crest a little smaller",
      'Gongrowl':"the female gorilla: a slimmer build with narrower shoulders, no grey on its shoulders, a smaller chest gong, a shorter bronze crest and a calmer, focused face",
      'Furnacowary':"the female cassowary: a slightly bigger body, a taller bronze casque, and brighter fire glowing between the ribs"}
for _n,_d in _FEM.items():
    SPECS.append({'id':'fem_'+_n.lower(),'name':_n+' (female look)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':4,'aspect':'1:1','size':'2K',
      'prompt':_EDIT+"turn it into "+_d+". Everything that defines the species stays: its signature parts, body plan, face, eye colour and type, so it reads instantly as the same creature. Same pose, view and plain background. Do not add anything else."})
# Retries: Ringrove's tilt came out too subtle; Glassolotl 'left' still faced right.
SPECS.append({'id':'v2g_ringrove_tilt2','name':'Ringrove (strong head tilt)','refs':['briefs/boki-art/cards/Ringrove.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"tilt its whole head strongly to one side, about 30 degrees, so one ear is clearly lower than the other, like a puzzled, friendly dog. Its eyes look straight at the viewer, with a small lopsided smile. Its body, mushroom caps, colours and everything else stay exactly the same. Do not add anything else."})
_POSE('v2p_glassolotl_left2','Glassolotl',_LM['Glassolotl']['sheet'],_O+'v2a2_glassolotl_3.jpg',
  "the mirror image of image 2: its head is on the LEFT side of the picture and its tail on the right, swimming through the air toward the left edge, body in a long S-curve.",3)

# ===== 20:08 ET 11-09: V2 batch 1 picks. Anchor bleed hit 9 of 26 (a white Rimink head beside Barostorm, Chandelotl beside Chimelop, black
# Cindermaw sludge over the anglers, purple fog under the cute ones). Clean picks go to stage B; the rest get an edit that removes the bleed.
_B1PICK={'Gongrowl':'v2a_gongrowl_1','Anvilbrock':'v2a_anvilbrock_1','Forgebrock':'v2a_forgebrock_2','Furnacowary':'v2a_furnacowary_2','Vaultara':'v2a_vaultara_2',
 'Prowyak':'v2a_prowyak_3','Bastionpet':'v2a_bastionpet_1','Siegephant':'v2a_siegephant_1','Chuggamus':'v2a_chuggamus_1','Tiltster':'v2a_tiltster_1',
 'Canvastross':'v2a_canvastross_2','Crofthollow':'v2a_crofthollow_1','Pagoguana':'v2a_pagoguana_3','Stormit':'v2a_stormit_2','Sporcupine':'v2a_sporcupine_2',
 'Critwom':'v2a_critwom_2','Sirencada':'v2a_sirencada_1','Citadoad':'v2a_citadoad_2','Snapler':'v2a_snapler_3','Bucketmander':'v2a_bucketmander_2'}
_B1FIX={'Barostorm':('v2a_barostorm_1',"remove the white ferret head with ice crystals floating beside it and the small ice shard below it"),
 'Maulangler':('v2a_maulangler_3',"remove the black smoke cloud floating above its back and the purple fog around its feet"),
 'Chimelop':('v2a_chimelop_1',"remove the pink axolotl head in the top right corner and every faint shape around its feet"),
 'Barrelmander':('v2a_barrelmander_1',"remove the purple cloud under its feet; its feet stand on nothing"),
 'Domeleon':('v2a_domeleon_2',"remove the purple blob under its feet; its feet stand on nothing"),
 'Bastling':('v2a_bastling_1',"remove the purple cloud under it; its legs stand on nothing")}
for _n,(_s,_w) in _B1FIX.items():
    SPECS.append({'id':'v2x_'+_n.lower(),'name':_n+' (V2 card, remove bleed)','refs':[_O+_s+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':_EDIT+_w+". The creature itself, its colours, line and flat shading stay exactly the same, and the plain pale grey background is empty around it. Do not add anything else."})
_B1D={r[0]:r for r in _B1}
def V2SHEET_NEW(n,card,cols,counts):
    SPECS.append({'id':'v2s_'+n.lower(),'name':n+' (V2 sheet from card)','refs':[card],'runs':3,'aspect':'16:9','size':'2K',
      'prompt':("Clean flat model sheet of exactly the creature in image 1: "+n+". Exactly four views of it in one single row: front, three-quarter, side and back, in that order, "
        "all the same height with the feet on one invisible baseline, all four in the same stance. The same design, proportions, colours, face, eyes, markings and part counts as image 1 in every view. "
        "Colours: "+cols+". Parts, the same in every view: "+counts+". Model-sheet finish: "+LINE_V2+"Flat colour fills only, using image 1's base colours, with no shading at all, in even neutral light. "
        "The only highlight is one crisp white highlight in each eye. The front, side and back are true front, side and back views, and the back shows how its signature part attaches. "
        "Background: one perfectly flat pale grey (#E8E8EE) and nothing else: no floor, no cast shadow, no text, no extra or faded copies of the creature.")})
def V2PORT_NEW(n,card,stage,arch,cols,counts,dark,furry,pose):
    SPECS.append({'id':'v2p_'+n.lower(),'name':n+' (V2 portrait from card)','refs':[card],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':("POSE FIRST: "+pose+". Official encyclopedia portrait of exactly the creature in image 1: "+n+". Image 1 is the truth for its design, colours, eyes, face, part counts, line and flat shading: "
        "draw it exactly the way image 1 is drawn, in this new pose, a natural three-quarter view with a clear silhouette. Colours: "+cols+". Parts: "+counts+". "
        +STYLE_V2(stage,arch,dark,furry).replace(FX_V2,"The air around the creature is empty: nothing drifts, sparks or trails. ")+FRAME_V2)})
_B1POSE={'Gongrowl':"knuckle-walking forward on all fours, head low, glaring up at the viewer",'Anvilbrock':"digging in its claws and lowering its head, ready to charge",
 'Forgebrock':"standing tall on its hind legs, front paws raised, roaring",'Furnacowary':"striding forward mid-step, one big foot raised, head high",
 'Vaultara':"turning its head back over its shell to look at the viewer, key tail curled",'Prowyak':"trotting forward happily, shaggy coat swinging",
 'Bastionpet':"raising both claws high in a defensive stance",'Siegephant':"rearing on its hind legs, trunk raised high",'Chuggamus':"charging forward head-down, mouth open",
 'Tiltster':"sitting back on its haunches, front paws raised like flippers, cheeky grin",'Canvastross':"gliding with wings spread wide, seen from slightly below",
 'Crofthollow':"lying down calmly with its legs folded, head turned to the viewer",'Pagoguana':"rearing up on its hind legs with its tail planted",
 'Stormit':"scuttling sideways with one claw raised",'Sporcupine':"curled half into a ball, quills raised defensively, peeking out",
 'Critwom':"rolling forward with its shell tucked, mid-tumble",'Sirencada':"wings spread, about to take off, horn raised",'Citadoad':"swinging its club tail over its back, mouth open",
 'Snapler':"swimming through the air, mouth wide open, lure glowing ahead of it",'Bucketmander':"waddling forward with its little arms out, happy",
 'Barostorm':"sitting up on its haunches like a meerkat, looking out over the horizon",'Maulangler':"lunging forward with its jaws wide open",
 'Chimelop':"sitting upright with its long bell ears hanging down, calm",'Barrelmander':"waddling forward, tail swaying",'Domeleon':"gripping with its feet and turning its telescope eye toward the viewer",
 'Bastling':"waving one claw happily"}
for _n,_s in _B1PICK.items():
    _r=_B1D[_n]; V2SHEET_NEW(_n,_O+_s+'.jpg',_r[6],_r[7]); V2PORT_NEW(_n,_O+_s+'.jpg',_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],_B1POSE[_n])

# 20:12 ET 11-09: METHOD TEST against anchor bleed. Image 2 = style_refs/v2/style_board.png: nine close-up patches cut from the six anchors
# (an eye, chitin, scales, a claw, ice crystals, white fur, black coils, feathers, dark fur), some rotated, so there is no whole creature to copy.
SRB='briefs/boki-art/style_refs/v2/style_board.png'
_BOARD=("Image 2 is a board of nine close-up samples cut from other drawings in the target art style. Use it only for the finish: the line weight and colour, "
        "the flat colour fills with one hard-edged shade, the eye finish and the amount of detail. It contains no creature to draw: never copy any shape, part, colour or object from it. ")
def RS_CARD_BOARD(name,stage,arch,cols,counts,dark=False,furry=False,fix=''):
    p=RS_CARD(name,stage,arch,cols,counts,dark,furry,fix)
    return p.replace("Image 2 is the style guide only: match its line, flat shading, eye finish and amount of detail exactly, but never copy its creature, face, colours or pose. ",_BOARD)
for _n in ('Barostorm','Chimelop','Maulangler','Bastling','Barrelmander'):
    _r=_B1D[_n]
    SPECS.append({'id':'v2t_'+_n.lower(),'name':_n+' (V2 card, style-board test)','refs':['briefs/boki-art/'+_r[1],SRB],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_BOARD(_n,_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],_r[8])})
SPECS.append({'id':'v2t_mycroll','name':'Mycroll (V2 card, style-board test)','refs':['briefs/boki-art/cards/Mycroll.jpg',SRB],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':RS_CARD_BOARD('Mycroll','baby','cute',"brown spiky back, cream face and belly, mint mushroom caps with cream spots, teal eyes, dark brown nose","four legs, two ears, three big and four small mushroom caps, one mushroom tail tip",False,True,"")})

# 20:24 ET 11-09 owner: "Effigeetle doesn't fit in super well with his group, he might need to be adjusted". Its line is Effigeetle > Effigoon (a marble-and-gold
# cocoon) > Mortarfly (a marble-and-gold moth), so the baby becomes the caterpillar that spins that cocoon. Also: its new name 'Marbeetle' is too close to
# the Pokemon Orbeetle, so it gets a new name with this design (proposal: Marbillar = marble + caterpillar).
for _k,_v in (('a',"plump and round, inching forward with its front half raised"),('b',"curled into a loose C shape, looking up at the viewer")):
    SPECS.append({'id':'rd_effigeetle_'+_k,'name':'Effigeetle (redesign: caterpillar baby)','refs':['briefs/boki-art/cards/Effigoon.jpg','briefs/boki-art/cards/Mortarfly.jpg'],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one baby Boki (a stylised, cute creature-collector monster): the caterpillar baby that later spins the cocoon in image 1 and becomes the moth in image 2. "
        "Same family look as images 1 and 2: polished white marble body segments with thin gold trim and soft grey veining, and a small serene carved-statue face like the moth's mask, with big friendly eyes. "
        "Six short stubby gold legs at the front and soft marble prolegs behind, two tiny gold antenna nubs, and one small gold spiral on its tail that matches the cocoon's spiral. "
        "Pose: "+_v+". Clearly a baby: small, round, simple shapes, a slightly oversized head. Draw it in the same rendering style as images 1 and 2. Never copy the cocoon or the moth themselves; only one creature. "
        "Whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text.")})

# 20:25 ET 11-09 owner: "run a check none are same as pokemon". Two designs read too close and get fixed now:
# Pinster = yellow electric rodent with a lightning-bolt stripe and glowing cheeks (reads as Pikachu); Bullpole = round tadpole with a spiral on its belly (reads as Poliwag).
SPECS.append({'id':'pk_pinster','name':'Pinster (move away from Pikachu)','refs':['briefs/boki-art/cards/Pinster.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"recolour its fur to a warm cinnamon-orange with a cream belly and face (no yellow anywhere on its fur), remove the lightning-bolt stripe completely, and give it plain fur cheeks with no glow and no red circles. "
    "Its electric power now shows only in two round pinball bumpers grown into its back, which glow white-blue, and a small silver ball-bearing tail tip. Same hamster body, pose and style. Do not add anything else."})
SPECS.append({'id':'pk_bullpole','name':'Bullpole (move away from Poliwag)','refs':['briefs/boki-art/cards/Bullpole.jpg','briefs/boki-art/cards/Bullsfrog.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Single character illustration of one baby Boki: Bullpole, the tadpole baby of the dart frog in image 2. Redesign the tadpole in image 1 so it is shaped like a throwing dart: "
    "a slim, pointed, bullet-shaped head and body (not round), the same glossy red with black markings, and a long tail ending in three red-and-green flight fins like a dart's fletching. "
    "The dartboard target rings appear only as small ring markings on its tail fins, never on its belly or body; its belly is plain red. Big friendly green eyes, a tiny smile. "
    "Same rendering style as image 1. One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text.")})
# Chimelop: the bleed-removal edit kept Chandelotl in all 3; the style-board run 3 is clean -> its card. Sheet + portrait from it.
_r=_B1D['Chimelop']; V2SHEET_NEW('Chimelop',_O+'v2t_chimelop_3.jpg',_r[6],_r[7]); V2PORT_NEW('Chimelop',_O+'v2t_chimelop_3.jpg',_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],_B1POSE['Chimelop'])

# 20:34 ET 11-09 owner on Bullpole: "distinct enough, just make his circle not a circle in the middle so it's even more distinct; other options in the middle
# of his chest but the same; don't make him a fish". Keep the round tadpole exactly; swap the two green spiral circles for other marks.
for _k,_m in (('star',"a bold green four-point star"),('diamond',"a bold green diamond with a smaller dark diamond inside it"),('arrow',"a bold green dart-arrow shape pointing forward, like a dart's flight seen from the side"),
              ('cross',"a bold green crosshair: a plus sign with short gaps in the middle, no circle"),('chevron',"two bold stacked green chevrons pointing forward, like dart fletching")):
    SPECS.append({'id':'pk_bullpole_'+_k,'name':'Bullpole (chest mark: '+_k+')','refs':['briefs/boki-art/cards/Bullpole.jpg'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':_EDIT+"replace each of the two green spiral circles on its body with "+_m+", the same size, the same green and the same places, one in the middle of its chest and one on its side. "
        "Keep its round body, face, eyes, tail fin, colours and pose exactly the same. No circles or spirals anywhere on its body. Do not add anything else."})

# 20:36 ET 11-09 owner: "Tiltster and Pinster are a bit weird; Tiltster's head looks not super attached to its body. Maybe redesign them?"
# One family: cinnamon hamster (the Pikachu-safe Pinster fix 1 is the colour/face reference). Tiltster's table grows from its own back; head part of the body.
_PIN=_O+'pk_pinster_1.jpg'
for _k,_p in (('a',"standing on all four legs, chest forward, cheeky grin"),('b',"rearing up on its hind legs, front paws raised like flippers, mid-tilt")):
    SPECS.append({'id':'rd_tiltster_'+_k,'name':'Tiltster (redesign)','refs':[_PIN],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one final-form Boki (a stylised creature-collector monster): Tiltster, the grown-up form of the baby hamster in image 1. "
        "Same family: the same cinnamon-orange fur, cream belly and cheeks, the same face and eyes, only bigger and stockier with a confident look. "
        "Its whole back is a sloped pinball-table shell that grows out of its own body from the back of its neck to its tail: a glossy wooden-and-glass playfield with a few lane lines, "
        "three round bumpers that glow white-blue and two small flipper paddles near its tail. Its big round hamster head sits at the front of the body with a thick fur neck, clearly attached, never tucked under the table. "
        "Its front paws are broad and flipper-shaped; its tail is a short coiled plunger spring with a silver ball-bearing tip. One body, one head, four legs. "
        "Pose: "+_p+". Draw it in the same rendering style as image 1. One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text.")})
SPECS.append({'id':'rd_pinster_b','name':'Pinster (redesign option)','refs':[_PIN],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':("Single character illustration of one baby Boki: Pinster, the hamster in image 1, redrawn as a rounder baby: curled almost into a ball like a pinball, the same cinnamon-orange fur, cream face and cheeks, "
    "the same eyes, two small glowing white-blue bumper studs on its back, tiny flipper-shaped front paws, and a silver ball-bearing tail tip. No yellow, no lightning bolt, no glowing cheeks. "
    "Same rendering style as image 1. One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text.")})

# 20:36 ET 11-09 owner: "the first one is trying to be an electric squirrel; try other versions that aren't like Pikachu but still electric, and fit the pinball machine better".
# Three new animals for the Pinster > Tiltster line, each built on a pinball part; baby + final each. No rodents, no yellow, no lightning bolts, no glowing cheeks.
_PB=" Electric type: its electricity shows as white-blue sparks inside glass bumpers or along chrome edges, never as yellow fur, lightning-bolt markings or glowing cheeks. Draw it in the same rendering style as image 1, never copying its creature. One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text."
_PBL={
 'roly':("a baby pill bug (roly-poly woodlouse) with glossy chrome-silver segmented plates that curls up into a perfect shiny ball, exactly like a pinball; shown half-uncurled with its cute face peeking out, big eyes, little legs, two short antennae",
         "a big final-form pill bug, standing tall on many legs: its segmented back plates are a glowing pinball playfield with lane lines, three glass bumpers and a ramp, its two front legs are broad flipper paddles, its antennae end in small lit bulbs, and a chrome ball rolls along its back as part of its body"),
 'jerboa':("a baby jerboa (tiny desert hopping mouse-like animal with huge hind feet and a long tufted tail) in steel-blue and white fur, its hind legs coiled like a pinball launch spring, ready to spring; the tail tuft is a chrome ball",
           "a big final-form jerboa standing upright on spring-coiled hind legs, steel-blue and white fur, its chest and back a pinball playfield shell with glass bumpers, its forepaws flat flipper paddles, its long tail a plunger rod ending in a chrome ball"),
 'seal':("a baby harp seal pup in silver-white and electric-blue fur with two broad front flippers shaped exactly like pinball flippers, a round glass bumper on its back, and a chrome ball balanced on its nose",
         "a big final-form seal whose whole back is a sloped pinball playfield with glass bumpers and lane lights, its two front flippers are big pinball flippers, silver-white and electric-blue, a chrome ball balanced on its nose")}
for _k,(_b,_f) in _PBL.items():
    SPECS.append({'id':'c_pinline_'+_k+'_baby','name':'Pinster line option: '+_k+' (baby)','refs':[SRA],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Single character illustration of one baby Boki (a stylised, cute creature-collector monster): "+_b+". Clearly a baby: small, round, simple shapes, a slightly oversized head."+_PB})
    SPECS.append({'id':'c_pinline_'+_k+'_final','name':'Pinster line option: '+_k+' (final)','refs':[SRA],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Single character illustration of one final-form Boki (a stylised creature-collector monster): "+_f+". Every part grows from its body; one head, clearly attached."+_PB})

# 20:43 ET 11-09 owner OK ("sure let's do that"): Pinster line = the pill bug (baby curls into a chrome pinball, final carries the table), Bullpole = chevron marks.
# Cards made live from the concepts; V2 cards now with the style board, 4 runs (board runs paste tiles about half the time; filtered by tile check).
_B2=[('Bullpole','cards/Bullpole.jpg','baby','cute',False,False,"glossy red skin with dark maroon patches, two green chevron marks (one on its chest, one on its side), a red and green tail fin, big green eyes","two front legs, two back legs, one tail fin, two chevron marks",""),
 ('Pinster','cards/Pinster.jpg','baby','cute',False,False,"chrome-silver segmented plates, a pale grey face, big dark eyes, small clear glass studs with white-blue sparks","seven body plates, two antennae, short legs, about six glass studs",""),
 ('Tiltster','cards/Tiltster.jpg','final','tough',False,False,"chrome-silver segmented plates, a glowing blue pinball playfield on its back with clear glass bumpers and silver balls, chrome flipper claws, small lit antenna bulbs","two flipper claws, about ten legs, two antennae, three bumpers","")]
for _n,_i,_st,_ar,_dk,_fu,_co,_ct,_fx in _B2:
    SPECS.append({'id':'v2t_'+_n.lower(),'name':_n+' (V2 card, style board)','refs':['briefs/boki-art/'+_i,SRB],'runs':4,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_BOARD(_n,_st,_ar,_co,_ct,_dk,_fu,_fx)+" Never paste the board's square samples into the picture."})

# 20:43 ET 11-09 owner: "make the pill bug just Steel and something else, and also include the jerboa, I like it a lot; it can lose the pinball concept,
# make the last one an Electric type with a thing on its back, maybe something different on its back". Jerboa = a new Electric line (baby + final).
_JB=_O+'c_pinline_jerboa_baby_1.jpg'
SPECS.append({'id':'c_jerboa_baby','name':'Jerboa line (baby, no pinball)','refs':[_JB],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"remove the chrome ball and the metal rod from its tail: the tail is now a long thin furry tail ending in a fluffy white tuft that crackles with small white-blue sparks. "
    "Keep the steel-blue and white fur, the big ears, the face, the coiled-spring hind legs and the pose exactly the same. Do not add anything else."})
for _k,_b in (('coil',"a tall copper coil grown along its spine like a ridge of rings, topped by a small glowing white-blue orb between its shoulders"),
              ('cells',"three rounded glass battery cells grown into its back in a row along the spine, each glowing white-blue, with copper caps"),
              ('crest',"a big crest of stiff, static-charged white fur standing up along its back like a dandelion puff, crackling with small white-blue sparks"),
              ('vanes',"two broad fan-like copper fins on its back, like a wind turbine's blades, that spin and throw sparks")):
    SPECS.append({'id':'c_jerboa_final_'+_k,'name':'Jerboa line (final, back: '+_k+')','refs':[_JB],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one final-form Boki (a stylised creature-collector monster), Electric type: the grown-up form of the baby jerboa in image 1. "
        "The same steel-blue and white fur, big ears and face, now bigger, leaner and confident, standing upright on long powerful coiled-spring hind legs, with a long tail ending in a white tuft that crackles with sparks. "
        "On its back: "+_b+". Everything grows from its body; nothing is strapped or worn. No pinball parts, no chrome balls, no yellow fur, no lightning-bolt markings, no glowing cheeks. "
        "Draw it in the same rendering style as image 1. One creature, whole body in frame with a small margin, plain flat pale grey background (#E8E8EE), no ground, no shadow, no text.")})

# 21:02 ET 11-09 owner: jerboa line = baby (c_jerboa_baby_3) > static fur crest (c_jerboa_final_crest_2) > copper fins (c_jerboa_final_vanes_2), Electric; "you can name it":
# Jerbit > Jerbolt > Dynaboa. V2 cards with the style board, 4 runs. Pinster/Tiltster (pill bug, Steel/Bug) V2 picks clean -> sheets + portraits.
# Bullpole: all 4 board runs pasted the board's tiles -> remove-tiles edit.
_B3=[('Jerbit','batch/out/c_jerboa_baby_3.jpg','baby','cute',False,True,"steel-blue and white fur, big pale-pink inner ears, teal eyes, a long thin tail with a fluffy white tuft crackling with white-blue sparks","two big hind feet with coiled-spring legs, two small front paws, two big ears, one tail",""),
 ('Jerbolt','batch/out/c_jerboa_final_crest_2.jpg','mid','sleek',False,True,"steel-blue and white fur, a big crest of static-charged white fur along its back, teal eyes, a white tail tuft crackling with white-blue sparks","two coiled-spring hind legs, two front paws, two big ears, one fur crest, one tail",""),
 ('Dynaboa','batch/out/c_jerboa_final_vanes_2.jpg','final','sleek',False,True,"steel-blue and white fur, two broad copper turbine fins on its back, teal eyes, a white tail tuft crackling with white-blue sparks","two coiled-spring hind legs, two front paws, two big ears, two copper fins, one tail","")]
for _n,_i,_st,_ar,_dk,_fu,_co,_ct,_fx in _B3:
    SPECS.append({'id':'v2t_'+_n.lower(),'name':_n+' (V2 card, style board)','refs':['briefs/boki-art/'+_i,SRB],'runs':4,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_BOARD(_n,_st,_ar,_co,_ct,_dk,_fu,_fx)+" Never paste the board's square samples into the picture."})
_B2D={r[0]:r for r in _B2}
for _n,_s,_pose in (('Pinster','v2t_pinster_4',"uncurling from its ball, peeking out with its antennae up"),('Tiltster','v2t_tiltster_4',"rearing its front up with both flipper claws raised, the playfield on its back tilted toward the viewer")):
    _r=_B2D[_n]; V2SHEET_NEW(_n,_O+_s+'.jpg',_r[6],_r[7]); V2PORT_NEW(_n,_O+_s+'.jpg',_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],_pose)
SPECS.append({'id':'v2x_bullpole','name':'Bullpole (V2 card, remove board tiles)','refs':[_O+'v2t_bullpole_2.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"remove the six square picture tiles in the corners and along the top and bottom edges (an eye, a purple shape, spines, black coils, feathers, pink ribs); the background behind the tadpole is one plain flat pale grey everywhere. The tadpole itself stays exactly the same. Do not add anything else."})
# Tiltster's V2 sheet/portrait ids were already used by the old hamster run: new ids for the pill bug.
_r=_B2D['Tiltster']
for _j in [s for s in SPECS if s['id'] in ('v2s_tiltster','v2p_tiltster')]: pass
_n0=len(SPECS); V2SHEET_NEW('Tiltster',_O+'v2t_tiltster_4.jpg',_r[6],_r[7]); V2PORT_NEW('Tiltster',_O+'v2t_tiltster_4.jpg',_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],"rearing its front up with both flipper claws raised, the playfield on its back tilted toward the viewer")
SPECS[_n0]['id']='v2s_tiltster_pb'; SPECS[_n0+1]['id']='v2p_tiltster_pb'

# ===== 21:55 ET 11-09: NEW ART SESSION (second account) takes over from ART_HANDOFF.md. =====
# Picks: Chimelop (v2t_3 / v2s_1 / v2p_3), Pinster (v2t_4 / v2s_2 / v2p_3), Tiltster pill bug (v2t_4 / v2s_pb_2 / v2p_pb_2) -> live.
# Clean V2 cards -> sheets + portraits: Barostorm, Maulangler, Bastling, Barrelmander, Jerbit, Jerbolt. Domeleon held (owner: looks flat, redesign).
_B3D={r[0]:r for r in _B3}
for _n,_s,_pose in (('Barostorm','v2t_barostorm_1',_B1POSE['Barostorm']),('Maulangler','v2t_maulangler_1',_B1POSE['Maulangler']),
                    ('Bastling','v2x_bastling_1',_B1POSE['Bastling']),('Barrelmander','v2x_barrelmander_1',_B1POSE['Barrelmander']),
                    ('Jerbit','v2t_jerbit_2',"mid-bounce on its coiled-spring legs, ears up, tail tuft high, happy"),
                    ('Jerbolt','v2t_jerbolt_4',"crouched low on its coiled-spring legs, about to leap, fur crest bristling, looking at the viewer")):
    _r=(_B1D.get(_n) or _B3D[_n]); V2SHEET_NEW(_n,_O+_s+'.jpg',_r[6],_r[7]); V2PORT_NEW(_n,_O+_s+'.jpg',_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],_pose)
# METHOD TEST 2 against board tiles: no style image at all, the written style only. The remove-tiles edit (v2x_bullpole) kept the tiles 3 of 3,
# and all 4 Dynaboa board runs pasted tiles.
def RS_CARD_TEXT(name,stage,arch,cols,counts,dark=False,furry=False,fix=''):
    p=RS_CARD(name,stage,arch,cols,counts,dark,furry,fix)
    return p.replace("Image 2 is the style guide only: match its line, flat shading, eye finish and amount of detail exactly, but never copy its creature, face, colours or pose. ",
                     "There is only one image. The art style is described in words below: follow it exactly. ")
for _r in (_B2D['Bullpole'],_B3D['Dynaboa']):
    SPECS.append({'id':'v2n_'+_r[0].lower(),'name':_r[0]+' (V2 card, text-only style)','refs':['briefs/boki-art/'+_r[1]],'runs':4,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_TEXT(_r[0],_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],_r[8])})

# ===== 22:40 ET 11-09: OWNER NOTES (22:15-22:35) on the dex: same-pose pairs, too-small evolution jumps, look-alikes, a few redesigns. =====
# All done straight in V2 with the written style only (no style image, so nothing can bleed). 3 runs each. ids on_<name>.
_TXT="There is only one image and no style image: the art style is described in words below, follow it exactly. "
def ON_POSE(n,ref,stage,arch,dark,furry,pose,keep):
    # new pose, same design. ref = sheet (old-style Boki) or its V2 card.
    SPECS.append({'id':'on_'+n.lower(),'name':n+' (owner note: new pose, V2)','refs':[ref],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':("POSE FIRST (the whole point of this image): "+pose+" Draw one single character illustration of "+n+", the creature in image 1. "
        "Image 1 is the design only: keep exactly the same creature, body plan, proportions, face, colours, markings and signature parts ("+keep+"), with nothing added or removed. "
        "Do not copy image 1's pose, views or layout, and ignore how it is painted: draw the creature once, in the new pose. "+_TXT
        +STYLE_V2(stage,arch,dark,furry)+FRAME_V2)})
def ON_CHANGE(n,ref,stage,arch,dark,furry,change,runs=3,tag=''):
    # design change. ref = current card.
    SPECS.append({'id':'on_'+n.lower()+tag,'name':n+' (owner note: design change, V2)','refs':[ref],'runs':runs,'aspect':'1:1','size':'2K',
      'prompt':("Draw one single character illustration of "+n+", a new version of the creature in image 1. Image 1 is the starting design: keep its species, face, colours and signature idea, "
        "and ignore how it is painted. DESIGN CHANGE (the whole point of this image): "+change+" Every part is grown from its own body: nothing strapped on, belted, bolted or worn. "+_TXT
        +STYLE_V2(stage,arch,dark,furry)+FRAME_V2)})
_C='briefs/boki-art/cards/%s.jpg'
# --- same-pose pairs: one of each pair gets a new pose ---
ON_POSE('Dreadnoyak',_LM['Dreadnoyak']['sheet'],'final','tough',False,True,"standing side-on in a three-quarter view facing left, all four legs planted wide, the whole body clearly visible from horns to tail: heavy shoulders, long back, belly, four legs and tail, head turned a little toward the viewer.","white frost hair, icicle horns and ice keel")
ON_POSE('Gloamspire',_LM['Gloamspire']['sheet'],'final','creepy',True,False,"facing LEFT, the front half of its body reared up tall off the ground, eye stalks spread wide apart, its purple crystal spire shell towering behind and above it.","purple body, dark purple crystal spire shell, two eye stalks")
ON_POSE('Effigoon',_C%'Effigoon','mid','majestic',False,False,"the cocoon stands upright on its pointed tip, leaning a little to one side like a spinning top coming to rest, seen from a low three-quarter angle. No rope, no thread, nothing above it.","white marble cocoon with gold bands and gold spiral trim, no face")
ON_POSE('Crofthollow',_C%'Crofthollow','final','majestic',False,True,"facing RIGHT in a side three-quarter view, head lowered and turned toward the viewer as if grazing, one root foreleg stepping forward, all feet planted.","ginger shaggy fur, straw thatched-roof hump, tree-root legs with moss, branch horns with small roses")
ON_POSE('Voltalon',_LM['Voltalon']['sheet'],'final','tough',True,False,"standing tall and upright facing LEFT, chest out, wings half spread behind it, head thrown back mid-screech, tail planted on the ground behind it.","dark blue-grey and orange-red scaly hide, antler crest with a spark, clawed wings")
ON_POSE('Pyrraven',_LM['Pyrraven']['sheet'],'final','creepy',True,False,"perched low and hunched forward facing LEFT, both wings folded tight against its body like a cloak, head lowered and glaring at the viewer.","black feathers with glowing orange lava cracks, a bone-white skull mask with horns")
ON_POSE('Scythant',_LM['Scythant']['sheet'],'mid','sleek',False,False,"reared up on its back four legs facing RIGHT, both scythe forelegs raised high and crossed above its head, ready to slash.","green leaf-armoured ant body, two curled fern antennae, two curved scythe forelegs, small leaf wings")
ON_POSE('Loafhopper',_LM['Loafhopper']['sheet'],'final','cute',False,False,"mid-leap facing RIGHT, seen from the side, long hind legs kicked out straight behind it, bread-crust wings spread wide above its back.","golden-brown baked-bread body, croissant-crust wings, long grasshopper legs")
ON_POSE('Parrywhal',_LM['Parrywhal']['sheet'],'final','sleek',False,False,"body upright and vertical like a fencer en garde, facing LEFT, its long horn held diagonally forward like a rapier, one blade fin stretched out behind for balance, tail curled under.","blue-grey and white narwhal body, one long spiral horn, blade-shaped fins, a gold band marking")
ON_POSE('Pagoguana',_C%'Pagoguana','final','majestic',False,False,"facing RIGHT in a front three-quarter view, head raised high and proud, front legs planted wide, its long tail curled round to the front.","green scales, orange-brown belly, five green pagoda roof tiers with red edges along its spine, brown horns")
# --- evolution jump too small: the later stage grows up ---
ON_CHANGE('Maracoil',_C%'Maracoil','final','tough',False,False,"it is a much larger, heavier adult snake, clearly two sizes up from a baby: a thick muscular body stacked in three big coils, a wide flared cobra hood painted with bold maraca zig-zag bands, a forked tail ending in two big maraca rattles, long fangs and narrow fierce eyes. No baby roundness and no smile.")
ON_CHANGE('Morelossus',_C%'Morelossus','final','majestic',False,False,"it is much bigger and older, mammoth-sized: four thick pillar legs planted on the ground (not rearing), two long curved tusks, a long heavy trunk, and a towering grove of tall morel mushrooms in three sizes growing along its whole back. Calm and immense.")
ON_CHANGE('Frigatee',_C%'Frigatee','final','majestic',False,False,"it is a big grown-up bull sea lion, clearly not a baby seal: a thick neck and heavy chest, propped upright on its front flippers, pale ice-blue grey hide instead of white, two short ice tusks, a proud stern face, and a tall jagged ridge of large ice crystals grown along its back from neck to tail. No lid, no latch, no mist.")
ON_CHANGE('Bulwartoad',_C%'Bulwartoad','mid','tough',False,False,"it is bigger and bulkier: broader shoulders, thicker forelegs, a taller and wider spiked iron-coloured shell, and it fills the frame. Same grumpy face and olive warty skin.")
# --- look-alikes ---
ON_CHANGE('Dribbara',_C%'Dribbara','baby','cute',False,False,"it is a tiny, round baby capybara, much smaller and cuter: a big head on a small chubby body, very short stubby legs, sitting on its bottom with open happy eyes, no tusks. The pond on its back shrinks to one small puddle-sized dimple holding a single lily pad and one water drop.")
ON_CHANGE('Bastionpet',_C%'Bastionpet','final','tough',False,False,"it becomes a clear sea creature of the tide: its shell is wave-worn blue-grey slate instead of rusty brown, with pale pink coral branches and bright green seaweed growing between the plates, a small tide pool of clear water in a hollow on top, the pale barnacles kept; its legs and claws are deep teal with cream undersides. No rust, no iron, no brown.")
ON_CHANGE('Domeleon',_C%'Domeleon','mid','sleek',True,False,"it is a bigger, leaner, cooler chameleon standing tall and alert: the bronze observatory dome is a large casque fused to its skull, with an open slit from which its long brass telescope eye extends and aims forward; a tall sail-like crest of night-sky navy skin dotted with pale constellation spots runs down its back; long gripping limbs; a strong spiral tail. A sharp, focused stare, not a round frog body.")
ON_CHANGE('Pawnfry',_C%'Pawnfry','baby','cute',False,False,"it is no longer bald: a short crest of carved-wood mane tufts, striped dark and light like a chess piece, runs from its forehead down the back of its neck, and it has two small rounded fin ears. Same baby seahorse-snake with a wood-grain body and big grumpy eyes.")
# --- Lanceron no longer looks like its line (Skidlet > Skateron are lilac skating herons): redraw as their final ---
SPECS.append({'id':'on_lanceron','name':'Lanceron (owner note: back in its family, V2)','refs':[_C%'Skateron',_C%'Lanceron'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Draw one single character illustration of Lanceron, the grown-up final evolution of the bird in image 1. Image 1 is the family: Lanceron is clearly the same species grown up, a tall elegant heron with the same "
   "soft lilac-grey plumage, the same curled head crest, the same face and the same ice-skate blade feet. From image 2 take only two ideas, not its body: a long lance-like beak of pale blue ice, and pale blue ice-crystal "
   "feathers at the wing tips and tail. It is twice as tall as image 1, long-necked and long-legged, standing proudly on one blade with the other leg tucked, wings half open. It is a bird, not a dragon: no scales, no horns, no claws, no armour. "
   "Ignore how both images are painted. The art style is described in words below, follow it exactly. "+STYLE_V2('final','majestic',False,False)+FRAME_V2)})
# --- same design, straight V2 card (Scopeleon's card had a dark backdrop that broke its dex cut-out; Wickapi "looks like it's from another game") ---
SPECS.append({'id':'on_scopeleon','name':'Scopeleon (V2 card, text-only style)','refs':[_C%'Scopeleon'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':RS_CARD_TEXT('Scopeleon','baby','cute',"navy skin with pale crescent-moon and star spots, a brass telescope eye, a tightly curled tail, a yellow eye","four legs, one telescope eye, one curled tail",True,False,"")})
SPECS.append({'id':'on_wickapi','name':'Wickapi (V2 card, text-only style)','refs':[_C%'Wickapi'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':RS_CARD_TEXT('Wickapi','baby','cute',"dark reddish-brown fur, cream-striped legs, a cream wax candle stub on its head with one small purple flame, purple eyes, a purple-black wispy tail","four legs, two big ears, one candle, one tail",True,True,
    "its proportions become a real okapi calf's: longer legs, a longer neck and a smaller head, standing on all four legs")})

# 23:05 ET 11-09: text-only style test = 8 of 8 clean (no tiles, no second creature) and the style holds. It is now the default card route.
# Picks live: Barostorm (v2t_1 / v2s_1 / v2p_2), Maulangler (v2t_1 / v2s_1 / v2p_1), Barrelmander (v2x_1 / v2s_1 / v2p_3),
# Jerbit (v2t_2 / v2s_1 / v2p_1), Jerbolt (v2t_4 / v2s_3 / v2p_3). Bastling waits for Bastionpet's new look (owner note).
for _n,_s,_pose in (('Bullpole','v2n_bullpole_1',"bouncing up off the ground, tail fin flicked to one side, cheerful"),
                    ('Dynaboa','v2n_dynaboa_1',"planted in a wide stance on its coiled-spring legs, copper fins fanned open, looking down at the viewer")):
    _r=(_B2D.get(_n) or _B3D[_n]); V2SHEET_NEW(_n,_O+_s+'.jpg',_r[6],_r[7]); V2PORT_NEW(_n,_O+_s+'.jpg',_r[2],_r[3],_r[6],_r[7],_r[4],_r[5],_pose)

# ===== 23:40 ET 11-09: owner-notes picks -> cards live (text-only route: 0 bleed in 64 images). Sheets (3 runs) + portraits (2 runs) from each pick. =====
_ON=[ # name, pick, stage, arch, dark, furry, cols, counts, portrait pose
 ('Dreadnoyak','on_dreadnoyak_1','final','tough',False,True,"white shaggy frost fur, a pale ice-blue bony skull face, pale blue icicle horns and curved ice tusks, dark blue-grey hooves","four legs, two tusks, two horns, one tail","head lowered, pawing the ground with one front hoof, about to charge, seen from a three-quarter side view with the whole body showing"),
 ('Gloamspire','on_gloamspire_2','final','creepy',True,False,"dusky purple snail body, a tall dark purple crystal spire shell, two eye stalks with pale purple eyes","two eye stalks, one crystal spire shell, no legs","gliding forward, eye stalks leaning toward the viewer, crystal spire tilted back"),
 ('Pyrraven','on_pyrraven_3','final','creepy',True,False,"black feathers with glowing orange lava cracks, a bone-white skull mask with two horns, orange eyes, bone-white talons","two wings, two legs, two horns, one skull mask","taking off, wings sweeping down, talons just leaving the ground"),
 ('Scythant','on_scythant_3','mid','sleek',False,False,"green leaf-armoured body, darker green segmented abdomen, two curled fern antennae, two curved scythe forelegs with red-brown blades, small leaf wings, brown eyes","two scythe forelegs, four walking legs, two antennae, two leaf wings","lunging forward low to the ground, one scythe swung out wide"),
 ('Loafhopper','on_loafhopper_1','final','cute',False,False,"golden-brown baked-bread body, croissant-crust wings, long orange-brown grasshopper legs, brown eyes","two long hind legs, four small legs, two antennae, four crust wings","standing planted with its wings open, looking up happily"),
 ('Parrywhal','on_parrywhal_1','final','sleek',False,False,"blue-grey back and white belly, one long pale spiral horn, pale blade-shaped fins, gold band markings, grey eyes","one horn, two blade fins, one tail fluke","diving forward horn-first, body in a smooth arc"),
 ('Maracoil','on_maracoil_1','final','tough',False,False,"cream and orange scales with teal zig-zag bands, a wide patterned cobra hood, two maraca rattles on a forked tail, amber eyes","one hood, two rattles, two fangs, no legs","coiled tight with its hood spread, both rattles raised and shaking beside its head"),
 ('Morelossus','on_morelossus_1','final','majestic',False,False,"brown mottled hide with a few gold rune marks, tall tan-and-brown morel mushrooms along its back, cream tusks, brown eyes","four legs, two tusks, one trunk, about eight morels in three sizes","walking forward slowly, trunk curled up, one front foot raised"),
 ('Frigatee','on_frigatee_3','final','majestic',False,False,"pale ice-white hide with pale blue shade, two short ice tusks, a ridge of pale blue ice crystals along its back, grey eyes","two front flippers, two tail flippers, two tusks, one crystal ridge","rearing its head back and bellowing, propped on its front flippers"),
 ('Bulwartoad','on_bulwartoad_1','mid','tough',False,False,"olive-green warty skin, a rusty dark iron-coloured spiked shell with pale barnacles, yellow-green eyes","four legs, one shell, about five shell spikes","crouched low and wide, glaring, about to hop"),
 ('Dribbara','on_dribbara_2','baby','cute',False,True,"warm brown fur, a darker brown muzzle, pink cheeks, a small blue-green puddle on its back with one lily pad and one water drop, brown eyes","four short legs, two small ears, one puddle, one lily pad","sitting and looking up at the viewer with its head tilted"),
 ('Bastionpet','on_bastionpet_3','final','tough',False,False,"blue-grey slate shell, pale pink coral and bright green seaweed on the shell, a small tide pool on top, pale barnacles, deep teal legs and claws with cream undersides","eight legs, two claws, one shell, one tide pool","raising both claws high in a defensive stance"),
 ('Domeleon','on_domeleon_2','mid','sleek',True,False,"dark navy skin, a sail crest with pale crescent-moon and star spots, a bronze observatory dome casque, a brass telescope eye, a navy spiral tail","four legs, one dome, one telescope eye, one sail crest, one spiral tail","reared up on its back legs, telescope aimed high at the sky"),
 ('Pawnfry','on_pawnfry_2','baby','cute',False,False,"light and dark wood-grain body in stripes, a striped carved-wood crest, big brown eyes, pink cheeks","one crest, two small fins, one coiled tail, no legs","bouncing upright on its coiled tail, grumpy"),
 ('Lanceron','on_lanceron_1','final','majestic',False,False,"soft lilac-grey plumage, a curled head crest, a long pale blue ice lance beak, pale blue ice-crystal wing tips and tail feathers, pale blue skate-blade feet, violet eyes","two wings, two long legs, two skate-blade feet, one crest, one lance beak","gliding forward on one blade in a long skating stride, neck stretched forward, wings swept back"),
 ('Scopeleon','on_scopeleon_3','baby','cute',True,False,"navy skin with pale gold crescent-moon and star spots, a brass telescope eye, a curled tail with a brass tip, pink cheeks","four legs, one telescope eye, one curled tail","sitting with its tail curled under it, telescope eye pointed up at the viewer")]
for _n,_s,_st,_ar,_dk,_fu,_co,_ct,_pose in _ON:
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_co,_ct); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_co,_ct,_dk,_fu,_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_on'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_on'; SPECS[_n0+1]['runs']=2
# Bastling (Crabulwark's baby) follows its parent's new tide look.
SPECS.append({'id':'on_bastling','name':'Bastling (tide colours like the new Bastionpet)','refs':[_O+'v2x_bastling_1.jpg','briefs/boki-art/cards/Bastionpet.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':"Redraw the baby crab in image 1 exactly as it is: the same creature, pose, face, big green eyes, proportions, line and flat shading. Change only its colours and shell growths so it is clearly the baby of the crab in image 2: a blue-grey slate shell instead of rusty brown, deep teal legs and claws with cream undersides, the pale barnacles kept, plus one small pink coral sprig and two small green seaweed leaves on its shell. No rust, no brown, no rivets or bands. One creature only. "+FRAME_V2})
# Retries: the pose did not change (card ref anchors it) -> sheet ref / stronger wording.
def _RETRY(n,ref,stage,arch,dark,furry,pose,keep):
    _n0=len(SPECS); ON_POSE(n,ref,stage,arch,dark,furry,pose,keep); SPECS[_n0]['id']='on2_'+n.lower()
    SPECS[_n0]['prompt']=SPECS[_n0]['prompt']+" The pose and facing direction must be clearly different from every view in image 1."
_RETRY('Crofthollow',_LM['Crofthollow']['sheet'],'final','majestic',False,True,"seen from the side, facing RIGHT, walking: its head is lowered to the ground as if grazing, and one root foreleg is lifted mid-step.","ginger shaggy fur, straw thatched-roof hump, tree-root legs with moss, branch horns with small roses")
_RETRY('Pagoguana',_LM['Pagoguana']['sheet'],'final','majestic',False,False,"reared up tall on its hind legs and planted tail, facing RIGHT, front claws raised, head turned to roar at the viewer, the pagoda tiers on its back seen from the side.","green scales, orange-brown belly, five green pagoda roof tiers with red edges along its spine, brown horns")
_RETRY('Voltalon',_LM['Voltalon']['sheet'],'final','tough',True,False,"seen from the side, facing LEFT, leaning forward on its two hind legs like a running raptor, body horizontal, tail straight out behind for balance, wings raised and half open, beak open in a screech. It is an animal, not a person: no human chest, arms or stance.","dark blue-grey and orange-red scaly hide, antler crest with a spark, clawed wings")
ON_CHANGE('Effigoon',_C%'Effigoon','mid','majestic',False,False,"the same white marble cocoon with gold bands and gold spiral trim, but it no longer hangs: there is no rope, cord or thread anywhere. It lies on its side, tilted, like a toppled statue, seen from a three-quarter angle with its pointed tip toward the viewer. It has no face.",tag='_lie')
ON_CHANGE('Wickapi',_C%'Wickapi','baby','cute',True,True,"it is a real okapi calf, standing on all four long thin legs, seen from the side in a three-quarter view: a long neck, a small head with a normal-sized face, big ears; natural animal proportions, not a big-headed chibi and not sitting. Same dark reddish-brown fur, cream-striped legs, a cream candle stub growing on its head with one small purple flame, purple eyes, a short purple-black wispy tail.",tag='_stand')

# ===== 21:50 ET 11-09 (real time; the two headers above are ~2h fast): V2 ROLLOUT BATCH 2, stage A (cards), dex order 2-53, text-only style, 3 runs. =====
# Skipped: already V2, waiting on an owner pick (Glaivyx, Glassolotl, Chandelotl, Ringrove), or being redesigned (Effigeetle, Effigoon, Wickapi).
_BT2=[ # name, stage, arch, dark, furry, cols, counts, fix
 ('Vespox','mid','sleek',False,True,"plum-purple fur, a lilac segmented scorpion tail, a lime-green venom bead on the stinger, lime-green ear tips, yellow-green eyes","four legs, one scorpion tail, one stinger","no dripping slime: one clean venom bead only"),
 ('Prismander','baby','cute',False,False,"pale pink body with red and mint candy-swirl stripes, pink feathery gills, brown eyes","four legs, six gills, one tail",""),
 ('Mycroll','baby','cute',False,True,"brown spiky back, cream face and belly, mint mushroom caps with cream spots, teal eyes, dark brown nose","four legs, two ears, three big and four small mushroom caps, one mushroom tail tip",""),
 ('Gravadillo','baby','cute',True,False,"dark plum-black armour plates, a purple curved horn, purple eyes, a few small grey pebbles close to its body","one horn, about six armour bands, two small paws, at most three pebbles",""),
 ('Gravitank','final','tough',True,False,"dark slate-grey hide, a huge cratered round moon-rock shell, one thin purple orbit ring, purple eyes","four legs, one nose horn, two ears, one shell, one ring",""),
 ('Mothlet','baby','cute',False,True,"lilac-grey and cream feathers, pale mint wing tips, two feathery antennae, a small crescent mark on its brow, yellow eyes","two wings, two feet, two antennae",""),
 ('Lunowl','mid','pretty',False,True,"cream-white feathers, large pale mint and cream luna-moth wings with gold eye-spots and long trailing tails, yellow eyes","two big wings with two long tails, two feet, two ear tufts",""),
 ('Eclipsowl','final','majestic',True,True,"near-black violet feathers and fur, gold crescent markings and gold trim lines, a gold crescent crest, yellow eyes","four legs, two wings, one crescent crest, two long ribbon tails",""),
 ('Echolop','baby','cute',False,True,"grey-mauve fur, a pale chest, big bat-wing ears with pink-mauve membranes, dark eyes","four legs, two bat-wing ears, two small side wings, one tail","no floating rings: the air is empty"),
 ('Howlop','mid','tough',False,True,"mauve-brown fur, big bat wings, purple eyes, cream fangs, two thin gold sound rings in front of its open mouth","four legs, two wings, one long tail, two sound rings",""),
 ('Moatpole','baby','cute',False,False,"tan sandy warty skin, a mossy grey broken castle-wall ridge on its back, pink cheeks, big yellow eyes","two front legs, two back legs, one short tail, one wall ridge",""),
 ('Rampartoad','mid','tough',False,False,"moss-green warty skin, a grey stone battlement wall along its back with moss, three arrow-slit marks on its side, yellow eyes","four legs, one battlement wall, three arrow slits",""),
 ('Zipling','baby','cute',True,False,"glossy black body, a purple zipper line over its head and back, purple eyes, a wispy black tail","two stubby feet, one zipper, one tail",""),
 ('Zippelith','mid','creepy',True,False,"glossy black snake body, a purple zipper running along its whole length, a zipper mouth with small teeth, purple eyes","one zipper, one zipper pull at the tail, no legs",""),
 ('Seamwyrm','final','creepy',True,False,"black scales, an open purple zipper down its front showing a glowing purple inside with cream teeth, black horns, purple eyes","two horns, one zipper, one zipper pull, no legs",""),
 ('Anchorbill','baby','cute',True,True,"charcoal-black feathers, a dark iron anchor-shaped beak, teal eyes, dark grey feet","two wings, two feet, one anchor beak","the anchor ring on its head is part of the beak, with no rope"),
 ('Anchorhorn','mid','tough',True,False,"dark teal-grey hide with rust-orange patches, a rusty iron harpoon horn, a rusty chain marking over its back, green eyes","two front flippers, two back flippers, one tail fluke, one harpoon horn","the chain is a raised chain-shaped ridge of its own hide, not a loose chain"),
 ('Bellowlet','baby','cute',True,True,"charcoal-black feathers, a glowing orange rib firebox on its belly, a small bronze casque on its head, a bronze beak, orange eyes, orange tail tips","two legs, two small wings, one casque, three ribs each side","the casque grows from its skull"),
 ('Snuffapi','mid','pretty',True,True,"dark brown fur, cream zebra-striped legs, gold candle-holder antlers with small purple flames, a purple flame mane and tail, gold hooves","four legs, two antlers, about six candles, one tail","the gold bands on its legs become gold hoof markings of its own, not cuffs"),
 ('Chandelapi','final','majestic',True,True,"dark brown fur, cream zebra-striped legs, tall gold chandelier antlers with small candle flames, a long purple flame mane and tail, teal eyes","four legs, two antlers, about ten candles, one tail",""),
 ('Glaciatee','final','majestic',False,False,"pale ice-blue and white hide, tall pale blue ice crystals along its back and head, a block of ice under it, grey eyes","two front flippers, one tail, one crystal crown, one ice block",""),
 ('Gongibbon','baby','cute',False,True,"dark grey-brown fur, a cream face, a small bronze gong on its belly, a round brown tail tip like a mallet, orange-brown eyes","two arms, two legs, one tail, one gong",""),
 ('Kayak','baby','cute',False,True,"white fluffy fur, pale blue ice horns and ice crystals on its back, blue eyes, grey hooves","four legs, two horns, about four crystals, one tail",""),
 ('Glintmole','baby','cute',False,False,"grey-brown skin, a grey rock shell cracked open to show a purple amethyst geode, pink crystal claws, a pink star nose, brown eyes","four legs, one geode shell, one star nose, pink claws",""),
 ('Geodemole','mid','tough',False,False,"grey-brown rocky hide, a purple amethyst geode on its back, long purple crystal claws, a pink star nose, purple tail spikes","four legs, one geode, one star nose, one tail","no motion lines"),
 ('Druzemole','final','tough',False,False,"grey-brown rocky hide, a huge open purple amethyst geode cavern on its back, long purple crystal claws, purple crystal spikes, brown eyes","two arms, two legs, one tail, one geode cavern",""),
 ('Gloamshell','baby','cute',True,False,"dusky purple snail body, a black spiked shell with one purple spiral, two eye stalks with purple eyes, pink cheeks","two eye stalks, one shell, no legs","no smoke and no slime trail"),
 ('Glomwort','baby','cute',False,False,"mustard-yellow slime-mould body with a cream belly, cream mushroom caps on its head and back, a mossy green mouth edge, brown eyes","four stubby legs, one tail, about eight mushrooms",""),
 ('Glomworth','final','creepy',False,False,"mustard-yellow and cream slime-mould body, cream mushrooms on its head, purple-capped mushrooms round its base, lime-green vein lines, purple eyes","one mound body, no legs, about six cream mushrooms, about eight purple mushrooms","no drips and no floating spores"),
 ('Mortarfly','final','majestic',False,False,"white marble body and wing panels, gold wing frames and gold legs, a calm marble mask face, gold eyes","four wings, six legs, two antennae",""),
 ('Crofthorn','mid','cute',False,True,"ginger shaggy fur, a grey slate-roof hump with moss and ivy, cream horns wrapped in ivy, green eyes","four legs, two horns, one roof hump, one tail",""),
 ('Skidlet','baby','cute',False,True,"soft lilac-grey feathers, a curled head crest, a pale grey beak, pale blue ice-skate blade feet, violet eyes","two wings, two legs, two skate-blade feet, one crest",""),
 ('Skateron','mid','sleek',False,True,"soft lilac-grey feathers, pale blue ice-crystal wing tips, a small head crest, a pale grey beak, pale blue ice-skate blade feet, violet eyes","two wings, two legs, two skate-blade feet, one crest",""),
 ('Ermink','baby','cute',False,True,"cream-white fur, black ear tips, black paw tips, a few black spots, a tan ringed tail with a black tip, dark eyes","four legs, two ears, one tail",""),
 ('Flarmink','mid','sleek',False,True,"grey-brown fur with orange lava cracks, a cream chest, a big flame tail of flat orange and yellow shapes, an orange flame crest, amber eyes","four legs, one flame tail, one flame crest","")]
for _n,_st,_ar,_dk,_fu,_co,_ct,_fx in _BT2:
    SPECS.append({'id':'v2c_'+_n.lower(),'name':_n+' (V2 card, batch 2, text-only style)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_TEXT(_n,_st,_ar,_co,_ct,_dk,_fu,_fx)})

# ===== 22:15 ET 11-09: picks. Full V2 sets live for the 16 owner-note Boki + Bullpole + Dynaboa (new). New cards: Crofthollow (on2_1),
# Pagoguana (on2_1), Voltalon (on2_2), Wickapi (on_wickapi_stand_3). Bastling: tide card on_bastling_1 -> sheet + portrait. Effigoon: run 1 lies
# down without a rope but has a cast shadow -> edit it out.
_n0=len(SPECS)
V2SHEET_NEW('Bastling',_O+'on_bastling_1.jpg',"blue-grey slate shell, pale barnacles, one pink coral sprig and green seaweed leaves on the shell, deep teal legs and claws with cream undersides, big green eyes","eight legs, two claws, one shell")
V2PORT_NEW('Bastling',_O+'on_bastling_1.jpg','baby','cute',"blue-grey slate shell, pale barnacles, one pink coral sprig and green seaweed leaves on the shell, deep teal legs and claws with cream undersides, big green eyes","eight legs, two claws, one shell",False,False,"waving one claw happily")
SPECS[_n0]['id']='v2s_bastling_tide'; SPECS[_n0+1]['id']='v2p_bastling_tide'; SPECS[_n0+1]['runs']=2
SPECS.append({'id':'on_effigoon_clean','name':'Effigoon (lying cocoon, no shadow)','refs':[_O+'on_effigoon_lie_1.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"remove the grey cast shadow on the ground beside and under the cocoon, and remove the short piece of rope at the top edge of the picture. The background is one perfectly flat pale grey (#E8E8EE) everywhere. The cocoon itself stays exactly the same."})

# ===== 22:30 ET 11-09: batch 2 cards: 105 of 105 clean. Picks live as cards (run numbers below). Stage B: sheet (old sheet + V2 card, 3 runs)
# and portrait (old portrait + V2 card, 2 runs); both images show the same creature, so nothing can bleed.
_BT2PICK="Vespox:1 Prismander:2 Mycroll:2 Gravadillo:1 Gravitank:2 Mothlet:1 Lunowl:2 Eclipsowl:1 Echolop:2 Howlop:1 Moatpole:1 Rampartoad:1 Zipling:3 Zippelith:2 Seamwyrm:3 Anchorbill:2 Anchorhorn:2 Bellowlet:2 Snuffapi:2 Chandelapi:1 Glaciatee:3 Gongibbon:2 Kayak:1 Glintmole:2 Geodemole:1 Druzemole:3 Gloamshell:2 Glomwort:2 Glomworth:2 Mortarfly:1 Crofthorn:1 Skidlet:2 Skateron:1 Ermink:1 Flarmink:2"
for _n,_st,_ar,_dk,_fu,_co,_ct,_fx in _BT2:
    _cd='briefs/boki-art/cards/'+_n+'.jpg'
    SPECS.append({'id':'v2s_'+_n.lower()+'_b2','name':_n+' (V2 sheet, batch 2)','refs':[_LM[_n]['sheet'],_cd],'runs':3,'aspect':'16:9','size':'2K','prompt':RS_SHEET(_n,_co,_ct)})
    SPECS.append({'id':'v2p_'+_n.lower()+'_b2','name':_n+' (V2 portrait, batch 2)','refs':['briefs/boki-art/portraits/light/'+_n+'.jpg',_cd],'runs':2,'aspect':'1:1','size':'2K','prompt':RS_PORTRAIT(_n,_st,_ar,_co,_ct,_dk,_fu)})

# 22:45 ET 11-09: stage B for the two owner-note cards that changed design or build: Voltalon (raptor run) and Wickapi (standing okapi calf).
for _n,_st,_ar,_dk,_fu,_co,_ct,_pose in (
 ('Voltalon','final','tough',True,False,"dark blue-grey scaly hide with orange-red markings, orange-red wing membranes, an antler crest with a small yellow spark, orange eyes","two hind legs, two clawed wings, one long tail, one antler crest","standing its ground on two legs, wings spread wide, head low and screeching at the viewer"),
 ('Wickapi','baby','cute',True,True,"dark reddish-brown fur, cream-striped legs, a cream candle stub on its head with one small purple flame, purple eyes, a short purple-black wispy tail","four long legs, two big ears, one candle, one tail","taking a wobbly step toward the viewer, ears up, curious")):
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_co,_ct); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_co,_ct,_dk,_fu,_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_on'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_on'; SPECS[_n0+1]['runs']=2

# ===== 23:15 ET 11-09: batch 2 stage B picks live (34 of 35) + Voltalon, Wickapi, Bastling (new). Kayak: all 3 sheets had a ghost row -> sheet
# from the V2 card instead. Effigoon: the shadow-removal edit kept the shadow -> 4 fresh runs.
_r=[r for r in _BT2 if r[0]=='Kayak'][0]; _n0=len(SPECS); V2SHEET_NEW('Kayak','briefs/boki-art/cards/Kayak.jpg',_r[5],_r[6]); SPECS[_n0]['id']='v2s_kayak_b2n'
ON_CHANGE('Effigoon',_C%'Effigoon','mid','majestic',False,False,"the same white marble cocoon with gold bands and gold spiral trim, drawn alone in empty space: it does not hang and nothing is attached to it, so the top of the picture is empty background. The cocoon is tipped over onto its side at a slant, pointed tip toward the lower right. It has no face. It casts no shadow at all: the background under and around it is the same flat pale grey as everywhere else.",runs=4,tag='_lie2')

# ===== 23:25 ET 11-09: V2 ROLLOUT BATCH 3, stage A (cards), next 40 in dex order that are not in tools/V2_DONE.txt. Text-only style, 3 runs. =====
_BT3=[ # name, stage, arch, dark, furry, cols, counts, fix
 ('Rippmink','mid','pretty',False,False,"pale aqua-blue body with a lighter belly, flowing wave-shaped fins and tail in deeper sea blue with white foam tips, blue eyes","four small legs, two ear fins, one long wave tail",""),
 ('Blossmink','mid','pretty',False,True,"cream-white fur with black ink-wash patches, a long tail like a black blossom branch with pink cherry flowers, dark eyes, pink cheeks","four legs, two ears, one branch tail, about twelve flowers",""),
 ('Voltmink','mid','sleek',False,True,"grey fur with dark grey spots and a cream chest, dark grey ear tips, thin yellow zig-zag markings, a black lightning-bolt tail, yellow-green eyes","four legs, two pointed ears, one bolt tail",""),
 ('Umbrink','mid','sleek',True,True,"pale grey-white fur with black ink-wash markings, a long flowing black ink mane and tail, purple eyes","four legs, two ears, one long ink tail","the ink is solid flat shapes, not drips"),
 ('Lunink','mid','pretty',False,True,"pale lilac-grey fur, long white feather-like ears, a tail ending in a large pale silver crescent brush, small silver crescent markings, violet eyes","four legs, two long ears, one crescent tail",""),
 ('Prismink','final','majestic',False,True,"white fur with pastel rainbow swirl markings, a mane and tail of big clear pastel crystals (lilac, pale pink, pale blue), lilac eyes","four legs, one crystal mane, one crystal tail","the crystals are a handful of big flat facets"),
 ('Wyrmink','final','majestic',False,True,"dark brown back and cream belly, gold antler horns, long cream whiskers, a red-orange flame-shaped tail tip, red eyes","four short legs, two antlers, two whiskers, one long coiled tail",""),
 ('Kestrike','baby','cute',False,True,"rust-red head and back, slate-blue wings and belly, a red feather crest, a cream face with dark eye stripes, a copper coil marking on its chest, orange eyes","two wings, two feet, three crest feathers, one tail",""),
 ('Arcestrel','mid','sleek',False,True,"rust-red head and neck, slate-blue wings and body, a red feather crest, long copper-coloured legs, long curled copper tail feathers, orange eyes","two wings, two long legs, one crest, three curled tail feathers","the copper coils on its body are copper-coloured markings and feathers of its own"),
 ('Tinbrock','baby','cute',False,True,"orange-brown fur, a dark mask band across its eyes, pale blue eyes, a few thin pale blue spark lines on its back","four paws, two small ears, one short tail",""),
 ('Kindlewren','baby','cute',True,True,"charcoal-black feathers with orange lava cracks on its belly, an orange flame tail, orange eyes, a dark beak","two small wings, two feet, one flame tail",""),
 ('Embrook','mid','tough',True,True,"charcoal-black feathers with orange lava cracks, an orange-yellow flame crest, orange-yellow flame wing tips and tail, orange eyes","two wings, two feet, one flame crest, one flame tail","no loose embers in the air"),
 ('Soakybara','mid','cute',False,True,"warm brown fur, a round hot-spring pool on its back with pale turquoise water, a rim of grey stones and green moss, two small blue crystals, brown eyes","four legs, two ears, one pool",""),
 ('Geysirbara','final','tough',False,True,"warm brown fur, a mound of orange rock with green moss on its back, three small white steam vents, brown eyes","four legs, two ears, one rock mound, three steam puffs","no dripping water or slime: dry fur and clean moss"),
 ('Buckleron','baby','tough',False,False,"olive-green warty skin, a dark iron-grey pointed shell with a rusty rim, one shell spike, pale barnacles, yellow-green eyes","four legs, one pointed shell, one spike","the rim is part of the shell, with no strap or buckle"),
 ('Lodestick','baby','cute',True,False,"dark brown twig-like body, small dark grey lodestones along its back, purple eyes, one thin purple orbit ring with two pebbles","six thin legs, two twig antennae, about five lodestones",""),
 ('Lodestaff','final','creepy',True,False,"dark slate-grey angular stone body with red line markings, purple eyes, a few dark stone shards close to its body","four legs, two blade arms, one horned head, at most four shards",""),
 ('Marchleaf','baby','cute',False,False,"green leaf-armoured ant body, two curled fern antennae, small clear wings, pink cheeks, brown eyes","six legs, two antennae, two small wings",""),
 ('Reapant','final','creepy',True,False,"dark plum-black armoured ant body, four dark plum blade wings, green eyes","six legs, four blade wings, two antennae, two scythe forelegs",""),
 ('Lanterloris','baby','cute',False,True,"cream and pale brown fur, a glowing red-orange paper-lantern body with pale crescent marks, big brown eyes, a small tassel tail tip","four legs, two small ears, one lantern body, one tail",""),
 ('Lanternlong','final','pretty',False,True,"cream fur, a long neck and body made of glowing orange paper-lantern segments, a long pink-cream tassel tail, brown eyes","four long legs, five lantern segments, one tassel tail",""),
 ('Mossgrade','baby','cute',False,False,"bright moss-green fuzzy back with a few tiny sprouts and grey pebbles, a pale cream belly and feet, green eyes","eight stubby legs, one snout, about three sprouts",""),
 ('Mossbastion','final','majestic',False,False,"dark green mossy back with cream flowers, ferns and pale mushrooms, a brown-green face, tree-trunk legs of brown bark, green eyes","six trunk legs, about three flowers, about five mushrooms",""),
 ('Moundlet','baby','cute',False,False,"terracotta-orange skin with paler spots, a small termite-mound hump on its back, small clear wings, big ears, green eyes","four legs, one long snout, two ears, one mound hump, two small wings",""),
 ('Spirevark','final','tough',False,False,"terracotta-red armoured hide, a tall dark red termite-spire on its back with a few holes, long claws, a segmented tail, amber eyes","four legs, one long snout, one spire, one tail","no loose crumbs in the air"),
 ('Murmurling','baby','cute',True,True,"black feathers with a green and purple sheen and tiny white speckles, a tan beak, a fan of tan pan-pipe tail feathers, dark eyes","two wings, two feet, about six pipe feathers",""),
 ('Murmuron','final','majestic',True,True,"black feathers with a purple sheen and white speckles, a gold pan-pipe collar on its chest, gold wing-tip feathers, a tail that breaks into small black bird shapes, dark eyes","two wings, two feet, one pipe collar, one flock tail","the flock at its tail is about eight small solid bird shapes, close to the body"),
 ('Spanglin','baby','cute',False,False,"soft pink skin, silver mirror-tile scales on its head, shoulders and back, a mirror-crystal tail tip, grey eyes","four legs, two ears, one tail, about twenty big mirror tiles","no sparkles: each tile is one flat pale shape"),
 ('Mirrolin','mid','cute',False,False,"dusty mauve-brown skin, a back of silver mirror tiles with small spikes, a round mirror-ball tail tip, grey eyes","four legs, one mirror-tile back, one mirror-ball tail","no sparkles: each tile is one flat pale shape"),
 ('Nettlynx','baby','cute',False,True,"tan-brown fur, big green leaf ears, a green leaf tail tip, big green eyes","four legs, two leaf ears, one tail","no drips on the leaves"),
 ('Thistlynx','mid','sleek',False,True,"tan-brown fur fading to olive green on its back, green leaf ears, a green thistle ridge along its spine, a long green thorny tail, green eyes","four legs, two leaf ears, one thorny tail",""),
 ('Briarlynx','final','tough',False,True,"brown fur, green leaf ears, green bramble vines grown round its chest and forearms, a long thorny green vine tail, green eyes","two arms, two legs, two leaf ears, one vine tail","the vines grow from its own fur, not wrapped on"),
 ('Fizzlet','baby','cute',False,True,"grey-brown feathers, slate-blue wings, a crest of copper wire coils, copper curl markings and curled copper tail feathers, amber eyes","two wings, two feet, one coil crest, three curled tail feathers",""),
 ('Boltstrich','mid','sleek',False,True,"dark grey storm-cloud body feathers with small yellow lightning marks, a pale pink-grey neck and head, copper-brown legs, grey eyes","two long legs, one long neck, one cloud body, one tail",""),
 ('Thunderstrich','final','tough',True,True,"a big dark grey storm-cloud body with yellow lightning forks, a rust-red spiky crest, a grey-brown face, copper-brown legs, an open beak","two long legs, one cloud body, one crest","the lightning is a few flat yellow forks on the cloud, not all around it"),
 ('Bubblisk','baby','cute',False,False,"pale lilac skin with a soft pastel sheen, a pink-lilac fin frill, a curled tail, one soap bubble at its mouth, grey-brown eyes","four legs, two frill fins, one curled tail, one bubble",""),
 ('Tidalisk','final','majestic',False,False,"pale lilac scales with pearl-white belly rings, a lilac fin crest and horns, one large pearl held in its coils, teal eyes","no legs, two horns, one fin crest, one pearl",""),
 ('Terrasloth','mid','cute',False,False,"sage-green skin, big pale cream scales each painted with a tiny green fern and pink flower, olive face, green eyes","four legs, one tail, about forty big scales, curled in a ball",""),
 ('Rimekit','baby','cute',False,True,"white fluffy fur, pale blue ice crystals on its back and tail tip, pink cheeks, blue eyes","four small paws, two round ears, about four crystals, one tail",""),
 ('Rimeshrew','mid','cute',False,True,"white fur, a pale ice-blue faceted ice shell on its back with crystal spikes, a pink nose, blue eyes","four legs, one ice shell, about six crystal spikes, one tail","no frost mist around it")]
for _n,_st,_ar,_dk,_fu,_co,_ct,_fx in _BT3:
    SPECS.append({'id':'v2c_'+_n.lower(),'name':_n+' (V2 card, batch 3, text-only style)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_TEXT(_n,_st,_ar,_co,_ct,_dk,_fu,_fx)})

# 23:40 ET 11-09 owner: "you have permission to change anything". Portraits redone from the V2 cards so they match them: Echolop without the
# floating rings, Anchorhorn without the loose chain.
_bt2={r[0]:r for r in _BT2}
for _n,_pose in (('Echolop',"hopping forward mid-bounce, big bat-wing ears spread wide, looking at the viewer"),('Anchorhorn',"swimming through the air in a rising arc, harpoon horn pointed up and forward, flippers swept back")):
    _r=_bt2[_n]; _n0=len(SPECS); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_r[1],_r[2],_r[5],_r[6],_r[3],_r[4],_pose); SPECS[_n0]['id']='v2p_'+_n.lower()+'_fix'

# ===== 00:05 ET 11-10: batch 3 cards: 120 of 120 clean, picks live. Stage B: sheet (old sheet + V2 card, 3 runs), portrait (old portrait + V2 card, 2 runs).
# Effigoon: live card is now the lying cocoon (on_effigoon_lie_1 with its cast shadow removed locally); its sheet + portrait come from that card.
for _n,_st,_ar,_dk,_fu,_co,_ct,_fx in _BT3:
    _cd='briefs/boki-art/cards/'+_n+'.jpg'
    SPECS.append({'id':'v2s_'+_n.lower()+'_b3','name':_n+' (V2 sheet, batch 3)','refs':[_LM[_n]['sheet'],_cd],'runs':3,'aspect':'16:9','size':'2K','prompt':RS_SHEET(_n,_co,_ct)})
    SPECS.append({'id':'v2p_'+_n.lower()+'_b3','name':_n+' (V2 portrait, batch 3)','refs':['briefs/boki-art/portraits/light/'+_n+'.jpg',_cd],'runs':2,'aspect':'1:1','size':'2K','prompt':RS_PORTRAIT(_n,_st,_ar,_co,_ct,_dk,_fu)})
_n0=len(SPECS)
V2SHEET_NEW('Effigoon','briefs/boki-art/cards/Effigoon.jpg',"white marble cocoon with gold bands and gold spiral trim","one cocoon, no face, no legs, no rope")
V2PORT_NEW('Effigoon','briefs/boki-art/cards/Effigoon.jpg','mid','majestic',"white marble cocoon with gold bands and gold spiral trim","one cocoon, no face, no legs, no rope",False,False,"the cocoon standing upright on its rounded end, seen from the front, nothing attached to it")
SPECS[_n0]['id']='v2s_effigoon_lie'; SPECS[_n0+1]['id']='v2p_effigoon_lie'; SPECS[_n0+1]['runs']=2

# ===== 00:35 ET 11-10 OWNER: "a lot of baby types look a different art style than their evolutions: make sure we get parity on style"
# (Chuggamus vs Teapotamus, Lockatara vs Latchling). The only real fix is finishing the pass, so BATCH 4 = ALL 99 remaining Boki, cards, text-only,
# 3 runs. To move fast the colour and count lines are generic (image 1 is the truth); only stage / face / dark / furry / one clean-up are by eye.
_GC="exactly the colours of image 1, each part keeping its own colour"; _GN="every part image 1 shows, the same number of each"
_BT4=[ # name, stage, arch, dark, furry, fix
 ('Rimefang','final','tough',0,1,""),('Teapotamus','baby','cute',0,0,"the spout, lid and handle are grown from its own body; one small flat steam puff"),('Selenfin','baby','cute',0,0,""),
 ('Selenwhale','final','majestic',0,0,""),('Barokat','baby','cute',0,1,"the brass horns and the dial are grown parts of its body; at most one small cloud"),
 ('Cisternmander','final','tough',0,0,"no dripping water and no puddle"),('Kerchick','baby','cute',0,1,""),('Jibbatross','mid','sleek',0,1,""),('Knotling','baby','cute',0,0,""),
 ('Knotwyrm','final','majestic',0,0,""),('Thrumbird','baby','cute',0,1,"no motion rings round its wings"),('Lyrewing','final','majestic',0,1,""),('Latchling','baby','cute',0,0,""),
 ('Parasolth','baby','cute',1,1,""),('Umbrathere','final','creepy',1,1,""),('Pipewurm','baby','cute',0,0,"no dripping slime and no puddle: its funnel snout is clean"),
 ('Pipeworth','final','creepy',0,0,"no dripping slime: the green frill is clean solid shapes"),('Oarlet','baby','cute',0,1,"no water drops"),('Oarter','mid','sleek',0,1,"no water drops"),
 ('Galleotter','final','majestic',0,1,""),('Kitlet','baby','cute',0,0,""),('Ribbonwyrm','mid','pretty',0,0,""),('Dragonkite','final','majestic',0,0,""),('Jarmit','baby','cute',0,0,""),
 ('Lanternmit','mid','tough',1,0,""),('Terrarimit','final','cute',0,0,""),('Bathilus','baby','cute',0,0,""),('Torpecone','mid','cute',0,0,""),('Dreadmonite','final','creepy',1,0,""),
 ('Pocketpus','baby','cute',0,0,""),('Bladypus','mid','cute',0,0,""),('Puffuse','baby','cute',1,0,""),('Blastopuff','final','tough',0,0,""),('Blotlet','baby','cute',1,0,""),
 ('Slog','mid','creepy',1,0,"no splatter drops around it: one solid body shape"),('Sloggoth','final','creepy',1,0,""),('Bullsfrog','final','tough',0,0,""),('Clinkpede','baby','cute',0,0,""),
 ('Chainipede','final','creepy',1,0,"no dripping venom"),('Cubbat','baby','cute',0,1,""),('Pipwom','mid','tough',0,1,""),('Grammite','baby','cute',1,0,""),('Dobsabre','final','tough',0,0,""),
 ('Lensling','baby','cute',0,0,""),('Fawngus','baby','cute',0,1,"no glowing wisp above it"),('Hatstag','final','majestic',0,1,""),('Foldbat','baby','cute',1,1,""),('Fanpire','final','sleek',1,1,""),
 ('Gilabacus','mid','tough',0,0,"no drool"),('Glaciammoth','final','majestic',0,0,""),('Olmlet','baby','cute',0,0,""),('Glazolm','mid','pretty',0,0,""),('Kintsuwyrm','final','majestic',0,0,""),
 ('Grainspin','baby','cute',0,1,""),('Sandwidow','mid','creepy',1,1,""),('Hourachnid','final','creepy',0,1,""),('Tootle','baby','cute',0,0,""),('Gramofrill','mid','sleek',0,0,""),
 ('Phonodrake','final','tough',0,0,""),('Gravigrub','baby','cute',0,0,""),('Orbitle','mid','tough',1,0,""),('Scarabit','mid','tough',1,0,""),('Meteorab','final','tough',1,0,"at most four chunky pebbles, close to its body"),
 ('Hydrangor','final','majestic',0,0,""),('Proofhop','baby','cute',0,0,""),('Malletary','mid','tough',0,1,""),('Rattlebub','baby','cute',0,0,""),('Polyshroom','baby','cute',0,0,""),
 ('Starcap','baby','cute',0,0,""),('Medushroom','mid','pretty',0,0,""),('Morelkin','baby','cute',0,0,""),('Truffapir','mid','cute',1,0,""),('Nymphane','baby','cute',0,0,""),
 ('Rosedart','final','pretty',0,0,""),('Gambitfin','mid','sleek',0,0,"the gold bands are gold ring markings of its own carved body, not collars"),('Checkmare','final','majestic',0,0,""),
 ('Pebblamb','baby','cute',0,1,""),('Reelacine','mid','sleek',0,1,""),('Scoopsy','baby','cute',0,1,""),('Sundormouse','mid','cute',0,1,""),('Bonsolith','final','majestic',0,0,""),
 ('Chiptero','baby','cute',0,0,""),('Pickadactyl','final','tough',0,0,""),('Harvantis','final','sleek',0,0,""),('Mumblet','baby','cute',0,0,""),('Klaxada','mid','cute',0,0,""),
 ('Narfoil','baby','cute',0,0,""),('Pagodito','baby','cute',0,0,""),('Pavonazar','final','majestic',0,1,""),('Quivertoad','final','tough',0,0,"no dripping slime"),
 ('Shinobant','mid','sleek',0,0,"the dark band across its eyes and neck is a marking of its own shell, not cloth"),('Cetorgan','final','majestic',0,0,""),('Ghoulamari','final','creepy',1,0,""),
 ('Sphinxblight','final','majestic',1,1,""),('Wayshell','final','majestic',0,0,"the compass and the gears are grown from its own shell"),('Glacione','baby','cute',0,0,"nothing under it: no pedestal and no ground"),
 ('Cairnback','final','majestic',0,0,""),('Hivara','final','sleek',0,0,""),('Zephyrak','final','majestic',0,0,"")]
for _n,_st,_ar,_dk,_fu,_fx in _BT4:
    SPECS.append({'id':'v2c_'+_n.lower(),'name':_n+' (V2 card, batch 4, text-only style)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_TEXT(_n,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_fx)})
# OWNER 00:35: "is it weird Anchorbill and Harpwhal are evo connected? one's a bird, one isn't". Yes. The baby becomes a pup of the same sea animal.
SPECS.append({'id':'on_anchorbill','name':'Anchorbill (owner note: a pup of Anchorhorn, V2)','refs':[_C%'Anchorhorn'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Draw one single character illustration of the BABY form of the sea creature in image 1. It is clearly the same species, newly hatched: a small, round, chubby pup about a third of the adult's size, "
   "with a big head, four short stubby flippers, a short tail fluke, the same dark teal-grey hide with a few rust-orange patches, and big teal-green eyes. Where the adult has a long harpoon horn, the pup has a short, blunt, "
   "anchor-shaped nose horn in the same rusty iron colour. It sits upright on its belly, looking up, friendly. No chain, no rope, nothing worn. It is not a bird: no feathers, no wings, no beak. "
   "Ignore how image 1 is painted. The art style is described in words below, follow it exactly. "+STYLE_V2('baby','cute',True,False)+FRAME_V2)})
# OWNER 00:35: "Thistlynx and Briarlynx look very similar, but their first evo looks different: make the difference more apparent" -> a bigger final.
ON_CHANGE('Briarlynx',_C%'Briarlynx','final','tough',False,True,"it is a much bigger, heavier final form that no longer looks like the slim middle form: a broad, powerful lynx standing planted on all four legs, twice as bulky, with darker brown fur, a thick mane of green bramble leaves round its neck and shoulders dotted with a few dark red roses, two curved thorn branches growing back from its brow like antlers, big leaf ears, heavy paws with thorn claws, and a long thorny vine tail held high. A stern, proud face.",runs=4,tag='_big')

# ===== 01:10 ET 11-10 OWNER: "review all of them and catch things like evolutions looking too similar or other stuff we should change".
# Line-by-line review of all 235 (strips of every line side by side). Clear problems get a fix now (4 runs each); softer ones go to the owner as a list.
# 1. Forgebrock = Anvilbrock again (same badger, same pose, same anvil).
ON_CHANGE('Forgebrock',_C%'Forgebrock','final','tough',False,True,"it is a much bigger final form, clearly not the middle stage again: reared up tall on its hind legs like a roaring bear, twice as heavy, with a broad barrel chest that is an open forge glowing orange between iron rib bars, the anvil grown wide across its shoulders with a short chimney horn behind its head, heavy iron-plated forearms and fists. Same orange-brown fur and pale blue eyes.",runs=4,tag='_big')
# 2. Shinobant is green, Reapant is plum-black: the middle should bridge them (owner: "the ninja black version that evolves to the big one").
ON_CHANGE('Shinobant',_C%'Shinobant','mid','sleek',True,False,"the same compact ninja ant in the same pose, recoloured to sit between a green baby and a plum-black final: its armour is dark plum-black, with only its leaf ear-tips, the small leaf wings and the scythe blades still green, and red eyes. The dark band across its eyes and neck is a marking of its own shell.",runs=4,tag='_dark')
# 3. Glaciatee reads smaller and cuter than Frigatee, and sits on a loose ice block.
ON_CHANGE('Glaciatee',_C%'Glaciatee','final','majestic',False,False,"it is the huge final form of a bull sea lion: far bigger and heavier than a seal, hauled up and planted on its front flippers, with two long curved ice tusks, a tall crown and back ridge of jagged ice crystals like an iceberg grown from its body, a thick frosted mane round its neck, and a calm, commanding face. Pale ice-blue and white. Nothing under it: no ice block and no ground.",runs=4,tag='_big')
# 4. Effigeetle (beetle) does not fit Effigoon (cocoon) > Mortarfly (moth): the baby is the caterpillar. Display name is already Sculptillar.
ON_CHANGE('Effigeetle',_C%'Effigoon','baby','cute',False,False,"this is the BABY that later spins the marble cocoon in image 1: a plump little caterpillar made of the same white marble with thin gold seams between its six round body segments, small stubby gold-tipped feet, two short gold antennae, and a simple cute insect face with two big round gold eyes and a tiny mouth (an animal face, not a human face or a mask). It inches forward with its front half raised. No floating pieces.",runs=4,tag='_cat')
# 5. Cisternmander is blue-green while Bucketmander and Barrelmander are dark grey-brown: it reads as another animal.
ON_CHANGE('Cisternmander',_C%'Cisternmander','final','tough',True,False,"it keeps its build and its mossy stone water-cistern back with reeds, but its skin becomes the same dark grey-brown as the rest of its family, with a paler belly, grey-lilac feathery gills and yellow eyes, and one wooden stave band of its own hide round the cistern. Bigger, heavier and grumpier. No dripping water and no puddle.",runs=4,tag='_fam')
# 6. Pickadactyl = Chiptero again (same small pterosaur, same stance).
ON_CHANGE('Pickadactyl',_C%'Pickadactyl','final','tough',False,False,"it is a much bigger final form: a heavy pterosaur planted on its hind legs and folded wing-knuckles, wings half spread wide, with a huge pickaxe-shaped head crest twice the size of its skull, a pick-tipped tail, and rough slate-and-amber rock plates down its back. Fierce, not cute.",runs=4,tag='_big')
# 7. Sirencada = Klaxada again (same beetle, same pose).
ON_CHANGE('Sirencada','briefs/boki-art/cards/Sirencada.jpg','final','tough',False,False,"it is clearly bigger than the middle form and in a new stance: reared up on its back four legs with its bronze wing-cases flared wide open like a siren's horn, the fan vent on its chest facing the viewer, forelegs raised. Same copper and bronze exoskeleton and red eyes.",runs=4,tag='_big')
# 8. Blastopuff is olive while its baby Puffuse is charcoal with yellow cracks and a cream belly.
ON_CHANGE('Blastopuff',_C%'Blastopuff','final','tough',True,False,"the same angry round bomb pufferfish in the same pose, in its family's colours: a charcoal-black upper body with a few thin yellow crack lines, a cream spiky belly, pale yellow fins, and a short fuse tail with one small flat spark.",runs=4,tag='_fam')
# The five pilot Boki that waited on an owner pick (he gave full control): straight V2 cards from their live cards.
for _n,_st,_ar,_dk,_fu,_fx in (('Glaivyx','final','sleek',0,1,"no dripping slime"),('Glassolotl','mid','pretty',0,0,""),('Chandelotl','final','majestic',0,0,""),('Ringrove','final','majestic',0,1,""),('Cindermaw','final','creepy',1,1,"")):
    SPECS.append({'id':'v2c_'+_n.lower()+'_b4','name':_n+' (V2 card, text-only style)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
                  'prompt':RS_CARD_TEXT(_n,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_fx)})

# 01:25 ET 11-10 OWNER: "Glassolotl needs a new pose" + "Lunowl should feel closer to Eclipsowl, it feels too far apart (some lines feel radically
# different, others too similar)". Rule of thumb from this: the middle stage carries one thing forward from the baby and shows one thing of the final.
ON_POSE('Glassolotl',_LM['Glassolotl']['sheet'],'mid','pretty',False,False,"reared up on its hind legs and tail, facing LEFT, front feet lifted, head turned to look at the viewer, its long glassy tail fins curling round in front of it.","pale pink glassy body with pastel rainbow fins, pink feathery gills, long ribbon tail fins")
SPECS[-1]['runs']=4
ON_CHANGE('Lunowl','briefs/boki-art/cards/Lunowl.jpg','mid','pretty',False,True,"the same moth-winged owl in flight, moved halfway toward its dark final form: its body feathers are dusk lilac-grey instead of cream, its big luna-moth wings shade from pale mint at the base to deep violet at the edges and tails, it carries bold gold crescent markings on the wings and chest and a small gold crescent crest between its ear tufts, and its two long wing tails are starting to curl like ribbons. A calmer, more serious face with gold eyes. A little bigger and stronger than a baby.",runs=4,tag='_dusk')

# ===== 01:50 ET 11-10: batch 4 cards: 297 of 297 clean, picks live -> every Boki except the 6 on hold has a V2 card. Stage B for all 99
# (sheet 3 runs, portrait 2 runs). Skipped here because their design is being redone: Cisternmander, Blastopuff, Pickadactyl, Shinobant.
_B4SKIP={'Cisternmander','Blastopuff','Pickadactyl','Shinobant'}
for _n,_st,_ar,_dk,_fu,_fx in _BT4:
    if _n in _B4SKIP: continue
    _cd='briefs/boki-art/cards/'+_n+'.jpg'
    SPECS.append({'id':'v2s_'+_n.lower()+'_b4','name':_n+' (V2 sheet, batch 4)','refs':[_LM[_n]['sheet'],_cd],'runs':3,'aspect':'16:9','size':'2K','prompt':RS_SHEET(_n,_GC.replace('image 1','image 2'),_GN.replace('image 1','image 2'))})
    SPECS.append({'id':'v2p_'+_n.lower()+'_b4','name':_n+' (V2 portrait, batch 4)','refs':['briefs/boki-art/portraits/light/'+_n+'.jpg',_cd],'runs':2,'aspect':'1:1','size':'2K','prompt':RS_PORTRAIT(_n,_st,_ar,_GC.replace('image 1','image 2'),_GN.replace('image 1','image 2'),bool(_dk),bool(_fu))})

# ===== 02:10 ET 11-10: line-review redesign picks live as cards: Forgebrock (big_4), Shinobant (dark_2), Glaciatee (big_1), Effigeetle caterpillar (cat_2),
# Cisternmander (fam_4), Pickadactyl (big_1), Sirencada (big_3), Blastopuff (fam_3), Anchorbill pup (on_anchorbill_2), Briarlynx (big_2),
# Glassolotl new pose (on_glassolotl_4), Lunowl dusk (dusk_2), Chandelotl (b4_3), Cindermaw (b4_1). Sheets + portraits from the new cards.
_RDP={'Forgebrock':('final','tough',0,1,"standing on all fours, head low, forge chest glowing, about to charge"),'Shinobant':('mid','sleek',1,0,"crouched low, scythe held back, ready to dash"),
 'Glaciatee':('final','majestic',0,0,"rearing its head back and bellowing, ice tusks raised"),'Effigeetle':('baby','cute',0,0,"curled into a loose C shape, looking up at the viewer"),
 'Cisternmander':('final','tough',1,0,"walking forward slowly, heavy, head turned to the viewer"),'Pickadactyl':('final','tough',0,0,"perched and leaning forward, wings folded, pickaxe crest lowered like a weapon"),
 'Sirencada':('final','tough',0,0,"standing on all six legs, wing-cases half open, facing the viewer"),'Blastopuff':('final','tough',1,0,"puffed up even rounder, spikes out, fuse sparking, glaring"),
 'Anchorbill':('baby','cute',1,0,"flopped on its belly, flippers out, looking up happily"),'Briarlynx':('final','tough',0,1,"sitting upright like a guardian statue, bramble mane full, vine tail curled round its feet"),
 'Glassolotl':('mid','pretty',0,0,"swimming through the air in a long S-curve, facing left, tail fins trailing"),'Lunowl':('mid','pretty',0,1,"perched with its moth wings folded down like a cloak, head turned to the viewer"),
 'Chandelotl':('final','majestic',0,0,"reared up tall with its crystal hood spread wide, coils planted"),'Cindermaw':('final','creepy',1,1,"starting to circle the viewer, head low, one paw forward")}
for _n,(_st,_ar,_dk,_fu,_pose) in _RDP.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_rd'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_rd'; SPECS[_n0+1]['runs']=2
# Glaivyx and Ringrove: the _b4 ids did not build (dropped); new ids.
for _n,_st,_ar,_dk,_fu,_fx in (('Glaivyx','final','sleek',0,1,"no dripping slime"),('Ringrove','final','majestic',0,1,"")):
    SPECS.append({'id':'v2k_'+_n.lower(),'name':_n+' (V2 card, text-only style)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K','prompt':RS_CARD_TEXT(_n,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_fx)})

# ===== 02:10 ET OWNER: "if you have any you're questioning, queue up a bunch of options, all different, and if none are better then leave it".
# OPTIONS: 3 different directions x 2 runs for each design I flagged. ids opt_<name>_<a|b|c>. Nothing changes unless an option clearly beats the live card.
def OPT(n,stage,arch,dark,furry,ref,opts):
    for _k,_d in zip('abc',opts): ON_CHANGE(n,ref,stage,arch,dark,furry,_d,runs=2,tag='_'+_k); SPECS[-1]['id']='opt_'+n.lower()+'_'+_k
OPT('Starcap','mid','cute',False,False,_C%'Polyshroom',[
 "this is the MIDDLE evolution of the jelly-mushroom creature in image 1: the same soft cream slug body and sleepy face grown bigger, its glassy mint dome cap now split into five rounded points like a star, with longer lilac gill tentacles under it. It drifts forward.",
 "this is the MIDDLE evolution of the creature in image 1: it has lifted off the ground and floats like a small jellyfish, its mint dome cap flattened into a five-pointed star seen from the side, its cream body shortened into a round core with its face on it, lilac tentacles trailing below.",
 "this is the MIDDLE evolution of the creature in image 1: it walks on four stubby cream legs like a starfish-footed animal, taller, with a wide five-lobed mint and lilac star cap worn like a sun hat grown from its head, awake curious eyes."])
OPT('Dynaboa','final','tough',False,True,_C%'Dynaboa',[
 "a much bigger, heavier final form: a tall powerful jerboa standing planted on huge thick spring legs, broad chest, the two copper turbine fins grown into a wide four-blade fan across its back, a thick mane of static-charged white fur, a long whip tail with a heavy sparking tuft. Fierce and proud.",
 "a different build: a long, low, fast runner on all fours like a hare at full stretch, with a row of five copper fins down its spine like a dynamo, ears swept back, tail streaming with sparks. Sleek and dangerous.",
 "a majestic final form: sitting tall and calm like a guardian, twice the size of the middle form, its copper fins curved up behind its head like a halo ring with small white-blue sparks inside it, long ears upright, a heavy fur collar."])
OPT('Galleotter','final','majestic',False,True,_C%'Oarter',[
 "this is the FINAL evolution of the otter in image 1, and its ship parts are all grown from its own body: a huge sea otter floating on its back, its broad belly and ribs shaped like a ship's hull of its own dark fur and hide, the spines on its back grown into two rows of oar-shaped fins along its sides, and one tall sail-shaped back fin of skin raised like a mast. No wood, no ropes, no separate boat.",
 "this is the FINAL evolution of the otter in image 1: a long sea-serpent otter rearing up out of nothing, its neck arched like a longship's prow with a curled figurehead crest grown from its skull, a row of oar-shaped fins down each side, and a wide tail like a rudder. All parts are its own body; no wood and no boat.",
 "this is the FINAL evolution of the otter in image 1: a massive, planted river-otter chief on all fours, shoulders like a galley's bow, with six long oar-shaped fin spines fanned out from its back and a broad paddle tail held high. All parts are its own body; no wood and no boat."])
OPT('Buckleron','baby','cute',False,False,_C%'Buckleron',[
 "a much smaller, rounder, simpler baby: a tiny round toadlet that is mostly head, big yellow-green eyes, stubby legs, wearing its shell like a small dented pot lid that only covers the top of its head, one tiny shell bump instead of a spike. Sitting.",
 "a tadpole-stage baby: a round olive tadpole body with a short tail and two tiny back legs, its small iron-grey shell just a domed cap on its back like a limpet, big curious eyes, bouncing.",
 "a small shy baby toad mostly hidden inside its pointed shell, only its big eyes and two front feet peeking out from under the rim, the shell clean and simple with one small spike."])
OPT('Wickapi','baby','cute',True,True,'briefs/boki-art/cards/Wickapi.jpg',[
 "the same standing okapi calf with more charm: a slightly bigger head and much bigger purple eyes with large highlights, pink cheeks, big soft ears, a short tufted mane of small purple flame shapes down its neck, knobbly knees, a tiny candle stub on its head with one purple flame.",
 "the okapi calf sitting down with its long striped legs folded under it, head tilted, big purple eyes, the small candle on its head with a wobbly purple flame, a wispy flame tail curled round it.",
 "the okapi calf mid-prance, front legs lifted, happy open mouth, big purple eyes, two tiny candle-stub horns each with a small purple flame, striped legs, a flame tuft tail."])

# ===== 02:30 ET 11-10 OWNER: "queue up the female versions and everything you could possibly need (not counting 3D)".
# FEMALE LOOKS in V2: image 1 = the male's live V2 card (design, pose and style), image 2 = the old female art (only what differs in the female).
# 13 Boki have a female look; babies have none by design. 3 runs. Sheets + portraits follow from the picked female card.
_FEMREF={'Arcestrel':'cards/Arcestrel_female.jpg','Eclipsowl':'cards/Eclipsowl_female.jpg','Furnacowary':'cards/Furnacowary_female.jpg','Gongibbon':'evolutions/Gongibbon_female.jpg',
 'Gongrowl':'cards/Gongrowl_female.jpg','Kestrike':'evolutions/Kestrike_female.jpg','Lunowl':'evolutions/Lunowl_female.jpg','Murmurling':'cards/Murmurling_female.jpg',
 'Murmuron':'cards/Murmuron_female.jpg','Sandwidow':'cards/Sandwidow_female.jpg','Voltalon':'cards/Voltalon_female.jpg','Hourachnid':'cards/Hourachnid_female.jpg','Pavonazar':'cards/Pavonazar_female.jpg'}
_FEMST={'Arcestrel':('mid','sleek',0,1),'Eclipsowl':('final','majestic',1,1),'Furnacowary':('final','tough',1,0),'Gongibbon':('baby','cute',0,1),'Gongrowl':('final','tough',1,1),'Kestrike':('baby','cute',0,1),
 'Lunowl':('mid','pretty',0,1),'Murmurling':('baby','cute',1,1),'Murmuron':('final','majestic',1,1),'Sandwidow':('mid','creepy',1,1),'Voltalon':('final','tough',1,0),'Hourachnid':('final','creepy',0,1),'Pavonazar':('final','majestic',0,1)}
for _n,_ref in _FEMREF.items():
    _st,_ar,_dk,_fu=_FEMST[_n]
    SPECS.append({'id':'fv2_'+_n.lower(),'name':_n+' female (V2 card)','refs':['briefs/boki-art/cards/'+_n+'.jpg','briefs/boki-art/'+_ref],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':("Draw the FEMALE of the creature in image 1 as one single character illustration. Image 1 is the male, and it is the truth for the species, body plan, signature parts, pose, view and the way it is drawn: "
        "keep all of that. Image 2 shows this species' female in an older painting style: take from it ONLY what makes the female different from the male (her own colours, markings, and any bigger, smaller or missing "
        "crest, mane, tail or ornament), and ignore its pose, layout and how it is painted. If image 2 shows several views, it is still one creature: draw her once. The result must read at a glance as the same species as "
        "image 1 and clearly as the other sex. "+_TXT.replace("There is only one image and no style image: the","The")+STYLE_V2(_st,_ar,bool(_dk),bool(_fu))+FRAME_V2)})
# More OPTIONS for things I or the owner questioned (3 directions x 2 runs; nothing changes unless one clearly wins).
OPT('Tiltster','final','tough',False,False,'briefs/boki-art/cards/Tiltster.jpg',[   # owner 11-09: "Tiltster's head is not very on"
 "the same big chrome pill bug with a blue pinball playfield on its back, but its head is clearly part of its body: a broad armoured head plate that is simply the first and largest of its body segments, flowing straight into the back with no neck and no gap, two big friendly eyes set into that plate, short antennae with small lit bulbs.",
 "the same big chrome pill bug, seen from the front three-quarter so its face leads the picture: a wide domed head fused into the front of the shell like a helmet visor, big eyes under the rim, flipper claws at its sides, the playfield rising behind it.",
 "the same big chrome pill bug, half curled, so its head tucks under the front rim of its own shell like a turtle's, peeking out with big eyes, the playfield curving over its back."])
OPT('Forgebrock','final','tough',False,True,'briefs/boki-art/cards/Forgebrock.jpg',[   # the new card's iron fists read as gauntlets
 "the same reared-up forge bear, but nothing looks worn: its forearms and paws are bare orange-brown fur with dark iron claws, the anvil is a grey horn-like growth across its shoulders, and the forge is a glowing orange hollow in its own chest between dark rib bones.",
 "the same forge bear standing planted on all fours instead of rearing: huge shoulders, an anvil-shaped hump of grey horn on its back with a short chimney horn, its chest and belly glowing orange through dark rib bones, bare furry paws with iron claws.",
 "the same forge bear rearing, its forepaws grown into heavy hammer-shaped hooves of dark iron-coloured horn (part of its body, with fur running onto them), an anvil hump on its shoulders and a glowing rib forge in its chest."])
OPT('Coolatee','baby','cute',False,False,'briefs/boki-art/cards/Coolatee.jpg',[   # nearest Pokemon look-alike on the roster (white seal pup)
 "the same baby seal, moved away from a plain white seal pup: its body is pale mint-blue with a white belly, it has a square boxy build like a little ice chest with rounded corners, a row of clear ice-cube crystals along its back, tiny flippers, big dark eyes.",
 "the same baby seal, moved away from a plain white seal pup: a round pup with a thick collar of frosty fur like a scarf of its own, pale blue speckles on its back like frost flowers, one big ice crystal on its tail tip instead of on its back, big dark eyes.",
 "the same baby seal, moved away from a plain white seal pup: it balances on its tail and belly like a wobbling toy, with two short ice-crystal ear tufts, a pale blue saddle patch, and a small clear ice dome on its back with a snowflake shape inside it."])

# ===== 03:00 ET 11-10 OWNER: "Prismander needs a bit softer colours, the change made him less cute" + "Crystalotl needs some colour exploration
# with the same everything else".
for _k,_d in (('a',"make all its colours softer and lighter, like the gentle pastel original: a pale blush-pink body, soft rose and pale mint candy stripes instead of strong red and green, soft pink gills, and warm brown eyes with big highlights. Thinner, softer-coloured outlines in a dusty rose shade. Rounder cheeks."),
              ('b',"make it softer and cuter: very pale pink body, wide gentle stripes in soft coral-pink and pale seafoam, fluffy pale pink gills, bigger eyes with two highlights, a tiny smile, outlines in soft plum instead of dark."),
              ('c',"soften the palette only: every colour moves halfway toward white (pastel pink, pastel coral, pastel mint), keeping the same stripes and the same flat style, with the outline in a mid rose-brown.")):
    SPECS.append({'id':'opt_prismander_'+_k,'name':'Prismander (softer colours '+_k+')','refs':['briefs/boki-art/cards/Prismander.jpg'],'runs':2,'aspect':'1:1','size':'2K','prompt':_EDIT+_d})
for _k,_d in (('pastel',"recolour it in soft pastels: pale pink body, soft rose and pale mint stripes, a pale pearly hood with pastel pink and mint facets"),
              ('berry',"recolour it in berry tones: a soft lilac-pink body, raspberry and cream stripes, a pale lilac crystal hood, magenta gills"),
              ('ocean',"recolour it in sea tones: a pale aqua body, teal and white stripes, a clear pale blue crystal hood, coral-pink gills"),
              ('sunset',"recolour it in sunset tones: a peach body, coral and cream stripes, a pale gold crystal hood, rose gills"),
              ('frost',"recolour it in winter tones: a white body, ice-blue and silver-grey stripes, a clear pale blue crystal hood, soft pink gills"),
              ('candy',"keep its red, white and green candy stripes but make the red a softer cherry-pink and the green a pale mint, with a pinker body and a pearl-white hood")):
    SPECS.append({'id':'opt_chandelotl_'+_k,'name':'Chandelotl/Crystalotl (colour '+_k+')','refs':['briefs/boki-art/cards/Chandelotl.jpg'],'runs':1,'aspect':'1:1','size':'2K','prompt':_EDIT+_d+". Nothing else changes: the same pose, shapes, stripes layout, face and line."})

# ===== 03:25 ET 11-10 picks. Cards live: Glaivyx (v2g_glaivyx_white_2, the white inner fur the owner asked for), Ringrove (v2g_ringrove_tilt2_1, head tilt),
# option winners Starcap (opt a_1: Polyshroom grown up with a star cap), Dynaboa (a_1: bigger, maned), Wickapi (a_1: house-style calf), Forgebrock (a_1: bare paws).
# Options NOT taken (owner to judge): Galleotter, Buckleron, Tiltster, Coolatee. Female V2 cards live for 12; Voltalon female redone below.
_LAST={'Glaivyx':('final','sleek',0,1,"prowling forward low, blade tail arched over its back"),'Ringrove':('final','majestic',0,1,"sitting upright, head tilted, looking at the viewer"),
 'Starcap':('mid','cute',0,0,"drifting forward, tentacle gills swaying, sleepy eyes on the viewer"),'Dynaboa':('final','tough',0,1,"mid-leap off its spring legs, fins spread, mane flying"),
 'Wickapi':('baby','cute',1,1,"sitting with its striped legs folded, head tilted, candle flame wobbling"),'Forgebrock':('final','tough',0,1,"standing on all fours, head low, forge chest glowing, about to charge")}
for _n,(_st,_ar,_dk,_fu,_pose) in _LAST.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_last'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_last'; SPECS[_n0+1]['runs']=2
SPECS[:]=[s for s in SPECS if s['id'] not in ('v2s_forgebrock_rd','v2p_forgebrock_rd')]
# Female sheets + portraits from the picked female V2 cards (ids fs_/fp_).
_FEMPOSE={'Arcestrel':"standing alert on one leg, head turned to the viewer",'Eclipsowl':"sitting like a sphinx, wings folded, calm",'Furnacowary':"standing tall, head turned to the viewer",'Gongibbon':"hanging by one arm, looking at the viewer",
 'Gongrowl':"sitting, one fist on the ground, calm and watchful",'Kestrike':"perched, head tilted, wings tucked",'Lunowl':"perched with wings folded down like a cloak",'Murmurling':"hopping forward, beak open in song",
 'Murmuron':"perched with wings half folded, head high",'Sandwidow':"creeping forward, front legs raised",'Hourachnid':"standing tall on its legs, facing the viewer",'Pavonazar':"walking, head high, tail trailing"}
for _n,_pose in _FEMPOSE.items():
    _st,_ar,_dk,_fu=_FEMST[_n]; _cd='briefs/boki-art/cards/'+_n+'_female.jpg'; _n0=len(SPECS)
    V2SHEET_NEW(_n+' female',_cd,_GC,_GN); V2PORT_NEW(_n+' female',_cd,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='fs_'+_n.lower(); SPECS[_n0+1]['id']='fp_'+_n.lower(); SPECS[_n0+1]['runs']=2
# OWNER 03:00: "Voltalon female looks cool but disconnected from the line". Her line is Kestrike > Arcestrel (rust-red and slate-blue kestrels):
# the female keeps the male's body and takes her colours from the female Arcestrel (image 2), not a new teal and gold scheme.
SPECS.append({'id':'fv3_voltalon','name':'Voltalon female (in her line\'s colours)','refs':['briefs/boki-art/cards/Voltalon.jpg','briefs/boki-art/cards/Arcestrel_female.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Draw the FEMALE of the creature in image 1 as one single character illustration. Image 1 is the male: keep exactly its species, body plan, pose, view, antler crest and the way it is drawn. "
   "Image 2 is the female of her younger form, and it gives ONLY her colours: warm sandy brown plumage and hide with fine dark brown barring, a cream chest, soft slate-blue on the wings, and a smaller, paler crest. "
   "So she is the same thunder-raptor as image 1 in those warmer, quieter colours, with a slightly bigger body and a shorter crest. No teal, no gold. "+STYLE_V2('final','tough',False,False)+FRAME_V2)})

# ===== 03:50 ET 11-10 OWNER on the strips: "the afters are all worse than the befores" -> Starcap, Dynaboa, Wickapi, Forgebrock reverted to their
# previous V2 cards; Glaivyx and Ringrove use the faithful V2 cards (v2k_*_1) instead of the white-fur / head-tilt versions. Sheets + portraits for those two:
for _n,(_st,_ar,_dk,_fu,_pose) in {k:_LAST[k] for k in ('Glaivyx','Ringrove')}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_k'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_k'; SPECS[_n0+1]['runs']=2
# OWNER on the females: Furnacowary loses its male/female difference (removed from the manifest). Gongrowl's female "looks male still: needs a
# different body type, and grey like its earlier version". Hourachnid "a bit more different". For the slight ones: "make the face slightly more
# feminine" and "change their body proportions a bit as well".
_FEMFACE=" Her face is a little softer than the male's: slightly larger eyes with one or two lash flicks, a finer muzzle or beak, a gentler brow. Still the same animal, never a human face and no make-up."
def FEM2(n,ref2,desc,runs=4):
    _st,_ar,_dk,_fu=_FEMST[n]
    SPECS.append({'id':'fv3_'+n.lower(),'name':n+' female (V2 card, round 2)','refs':['briefs/boki-art/cards/'+n+'.jpg']+([ref2] if ref2 else []),'runs':runs,'aspect':'1:1','size':'2K',
      'prompt':("Draw the FEMALE of the creature in image 1 as one single character illustration. Image 1 is the male: she is the same species with the same signature parts, drawn the same way, but she must be told apart from him at a glance. "
        +(("Image 2 is her younger form: take her colours from it. ") if ref2 else "")+"HOW SHE DIFFERS (the whole point of this image): "+desc+_FEMFACE+" "+STYLE_V2(_st,_ar,bool(_dk),bool(_fu))+FRAME_V2)})
FEM2('Gongrowl','briefs/boki-art/cards/Gongibbon_female.jpg',"a different body type from the bulky male: a tall, lean, long-armed ape with narrow shoulders and a slim waist, sitting upright with one long arm resting on her knee instead of pounding her chest; pale silver-grey and white fur like image 2 instead of black; a smaller, rounder bronze chest gong and a small neat head crest; calm watchful eyes, closed mouth.")
FEM2('Hourachnid',None,"a clearly different build and colours: a rounder, heavier abdomen, shorter thicker legs, a dark chocolate-brown body with cream bands on the legs where he is pale tan; her hourglass is wider and squatter with rose-red sand instead of pale sand, tilted the other way.")
FEM2('Eclipsowl',None,"different proportions: a slimmer, longer-legged body with a longer neck and a narrower chest, smaller wings held folded, a longer and thinner pair of ribbon tails; a pale silver-lilac chest and face mask where he is all dark, and a thin silver crescent crest instead of his heavy gold one.")
FEM2('Sandwidow',None,"different proportions: a larger rounder abdomen and a smaller head, longer more delicate legs; her body is deep plum instead of black, with lilac sand in a taller, narrower hourglass.")
FEM2('Arcestrel',None,"different proportions: a rounder, fuller body on slightly shorter legs, a shorter head crest and shorter curled tail feathers; warm sandy brown plumage with fine dark barring and a cream chest, with only a little slate-blue on the wings.")
FEM2('Lunowl',None,"different proportions: a rounder, fluffier body with a bigger head, shorter and wider moth wings and shorter tails; soft blush-pink and cream feathers with pale mint wings and small silver crescents where he is dusk lilac and gold.")

# ===== 04:05 ET 11-10 OWNER: "for a starter, Sporcupine and Ringrove both need to be much better and in line with Mycroll".
# Mycroll (image 1) is the family: cream face, brown spiky back, mint caps with cream spots, big teal eyes, round and clean. Options, owner picks.
_MYF=(" It is clearly Mycroll grown up: the same cream face and belly, the same warm brown spiky back, the same mint mushroom caps with cream spots, the same big teal eyes with large highlights, "
      "the same round friendly shapes and clean look. No grey, no purple gills, no scruffy fur, no moss, no realism.")
OPT('Sporcupine','mid','cute',False,True,_C%'Mycroll',[
 "this is the MIDDLE evolution of the hedgehog in image 1: twice its size, up on all four legs and trotting, with a longer body and a proud little chest; its back spikes have grown into a neat fan of taller brown quills, each tipped with a small mint mushroom cap, and one big mint cap sits on its head like a hat with its ears poking out. A confident happy face."+_MYF,
 "this is the MIDDLE evolution of the hedgehog in image 1: a sturdy young porcupine standing on its hind legs like a little brawler, fists up, cheeky grin; its back carries three big mint mushroom caps stacked like shoulder armour grown from its quills, and a mushroom-capped tail tip."+_MYF,
 "this is the MIDDLE evolution of the hedgehog in image 1: a sleek, quick porcupine mid-dash, low to the ground, its quills swept back like a mane with a row of mint mushroom caps along its spine from small to large, a long tail ending in one big cap. Determined eyes."+_MYF])
OPT('Ringrove','final','majestic',False,True,_C%'Mycroll',[
 "this is the FINAL evolution of the hedgehog in image 1: a big, calm, powerful guardian the size of a bear, standing planted on all fours; its back has grown into a wide ring of large mint mushroom caps like a crown round its shoulders, with long brown quills fanning out behind them; a broad cream chest, strong paws, a noble gentle face."+_MYF,
 "this is the FINAL evolution of the hedgehog in image 1: a tall, heroic beast rearing up on its hind legs, broad-shouldered, with one huge mint mushroom cap rising from its back like a shield or parasol and smaller caps down its arms; long swept-back quills like a cape; a brave, smiling face."+_MYF,
 "this is the FINAL evolution of the hedgehog in image 1: a majestic forest elder sitting upright, with a great tree-like cluster of tiered mint mushroom caps growing from its back and curving over its head like a canopy, a thick collar of cream fur, long quills, wise half-closed teal eyes."+_MYF])

# ===== 04:15 ET 11-10 OWNER picks from the options: Galleotter = C (planted otter, oar-fin spines, no boat), Tiltster = A2 (head part of the body).
# Cards live; sheets + portraits from them. Buckleron: owner asked whether A fits its evolution -> A redrawn in the line's own colours and shell.
for _n,(_st,_ar,_dk,_fu,_pose) in {'Galleotter':('final','majestic',0,1,"rearing up on its hind legs, oar-fin spines fanned wide, paddle tail planted"),'Tiltster':('final','tough',0,0,"half curled, flipper claws raised, the playfield on its back tilted toward the viewer")}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_pick'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_pick'; SPECS[_n0+1]['runs']=2
SPECS.append({'id':'opt_buckleron_d','name':'Buckleron (round baby in the line\'s colours)','refs':[_O+'opt_buckleron_a_1.jpg','briefs/boki-art/cards/Bulwartoad.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':"Redraw the round baby toad in image 1 exactly as it is: the same tiny round body that is mostly head, the same big eyes, pose, line and flat shading. Change only this, so it is clearly the baby of the toad in image 2: its skin is the same dull olive green with a few small warts, its eyes are the same yellow-green, and the little cap on its head is a small dented dome of the same dark rusty iron-grey shell as image 2's, with one tiny shell spike and one pale barnacle, grown from its head. One creature only. "+FRAME_V2})

# ===== 04:50 ET 11-10: female round 2 picks live as cards (Voltalon 1, Gongrowl 2, Hourachnid 2, Eclipsowl 2, Sandwidow 2, Arcestrel 3, Lunowl 1);
# their sheets + portraits (ids fs2_/fp2_). Prismander: softer card (opt_prismander_a_1) live; its sheet + portrait.
_FEMPOSE['Voltalon']="standing tall on two legs, wings folded, head turned to the viewer"
for _n in ('Voltalon','Gongrowl','Hourachnid','Eclipsowl','Sandwidow','Arcestrel','Lunowl'):
    _st,_ar,_dk,_fu=_FEMST[_n]; _cd='briefs/boki-art/cards/'+_n+'_female.jpg'; _n0=len(SPECS)
    V2SHEET_NEW(_n+' female',_cd,_GC,_GN); V2PORT_NEW(_n+' female',_cd,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_FEMPOSE[_n])
    SPECS[_n0]['id']='fs2_'+_n.lower(); SPECS[_n0+1]['id']='fp2_'+_n.lower(); SPECS[_n0+1]['runs']=2
_n0=len(SPECS); V2SHEET_NEW('Prismander','briefs/boki-art/cards/Prismander.jpg',_GC,_GN); V2PORT_NEW('Prismander','briefs/boki-art/cards/Prismander.jpg','baby','cute',_GC,_GN,False,False,"sitting up, head tilted, tail curled round its feet")
SPECS[_n0]['id']='v2s_prismander_soft'; SPECS[_n0+1]['id']='v2p_prismander_soft'; SPECS[_n0+1]['runs']=2

# ===== 05:10 ET 11-10 OWNER picks: Buckleron = D (round olive baby, iron cap), Crystalotl = candy colours, Ringrove option A2 "decent" -> live.
# Sheets + portraits from the new cards.
for _n,(_st,_ar,_dk,_fu,_pose) in {'Buckleron':('baby','cute',0,0,"mid-hop, tiny legs out, cap wobbling"),'Chandelotl':('final','majestic',0,0,"reared up tall with its crystal hood spread wide, coils planted"),
                                   'Ringrove':('final','majestic',0,1,"sitting upright, calm, looking at the viewer")}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_p2'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_p2'; SPECS[_n0+1]['runs']=2
# OWNER: "the middle of the line looks the same as the beginning one, which we said is bad". Sporcupine round 2: a NEW BODY, not Mycroll bigger.
# Image 1 = Mycroll (baby), image 2 = the new Ringrove (final). The middle keeps the family colours and face but changes build and stance.
_SP2=(" It belongs between the baby in image 1 and the final form in image 2: the same cream face, warm brown quills, mint mushroom caps with cream spots and teal eyes, but its BODY is new, "
      "not the round baby made bigger and not the bulky final made smaller. A teenager's face: narrower eyes than the baby, a confident look, no pink cheeks.")
for _k,_d in (('d',"a lanky, long-legged adolescent porcupine standing tall on all fours like a young wolf, slim waist, long neck, its quills grown into a tall mane-crest from head to tail with small mint caps at the tips, and a long tail ending in one big cap it swings like a mace. Mid-stride."),
              ('e',"a rolling attacker: curled most of the way into a spiked wheel, mid-roll, with its face and one arm showing at the front, long quills sticking out all round like spokes, and mint mushroom caps on the rim like studs."),
              ('f',"a low, long digger built like a badger: flat wide body close to the ground, big shovel front claws, a broad wedge head, and a single ridge of large mint mushroom caps down its back like plates on a stegosaur, quills swept back along its sides. Prowling forward."),
              ('g',"an upright, long-armed climber like a young sloth-bear, standing on its hind legs, long quills hanging down its back like a spiky cloak, a cluster of mint mushroom caps growing from each shoulder, big clawed hands held ready. Wiry, not chubby.")):
    SPECS.append({'id':'opt_sporcupine_'+_k,'name':'Sporcupine (new body, option '+_k+')','refs':[_C%'Mycroll',_C%'Ringrove'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the MIDDLE evolution of a creature line: "+_d+_SP2+" Ignore how the images are painted. "+_TXT.replace("There is only one image and no style image: the","The")+STYLE_V2('mid','sleek',False,True)+FRAME_V2})

# 05:20 ET 11-10 OWNER: "female and male Lunowl look way too different / not related" (he is dusk lilac and gold now, she was still pink and mint).
# Female = the male's own design and palette, one step lighter, with silver where he has gold.
SPECS.append({'id':'fv4_lunowl','name':'Lunowl female (same family as the dusk male)','refs':['briefs/boki-art/cards/Lunowl.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Draw the FEMALE of the creature in image 1 as one single character illustration. She is unmistakably the same species: the same moth-winged owl, the same wing shape and tails, the same pose and view, "
   "the same dusk colour family, drawn the same way. She differs only like this: her body feathers are a paler lavender-grey with a cream chest; her wings keep the mint centre and violet edges but one step lighter; "
   "every marking that is gold on him (the crescents and the small crest) is silver on her; her body is a little rounder and her wing tails a little shorter."+_FEMFACE+" No pink. "+STYLE_V2('mid','pretty',False,True)+FRAME_V2)})

# 05:25 ET 11-10 OWNER: "same with Murmuron" (male black with a purple sheen, female was crimson). Same rule: his design and palette, one step apart.
SPECS.append({'id':'fv4_murmuron','name':'Murmuron female (same family as the male)','refs':['briefs/boki-art/cards/Murmuron.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Draw the FEMALE of the creature in image 1 as one single character illustration. She is unmistakably the same species: the same great starling with the same wings, pipe collar, flock tail, pose and view, "
   "drawn the same way. She differs only like this: her dark feathers carry a warm bronze-brown sheen where his is purple, with larger cream speckles on her chest and wings; her pan-pipe collar and wing tips are copper "
   "instead of gold and a little smaller; her body is slightly rounder and her head crest shorter."+_FEMFACE+" No red and no crimson: she stays a dark bird. "+STYLE_V2('final','majestic',True,True)+FRAME_V2)})

# 05:35 ET 11-10 OWNER: "Pangolith (Terrasloth) looks too big in his portrait and I don't like the straight-up look: his circular pose but on the side".
for _k,_pose in (('a',"curled into its ring shape and seen from the SIDE, lying on the ground like a wheel tipped over, nose tucked to its tail, one eye open looking at the viewer"),
                 ('b',"half uncurled on its side, body in a loose C shape, head lifted and turned toward the viewer, tail curling round in front"),
                 ('c',"rolling along as a ring seen in three-quarter side view, leaning into the roll, face peeking out at the front")):
    _n0=len(SPECS); V2PORT_NEW('Terrasloth','briefs/boki-art/cards/Terrasloth.jpg','mid','cute',_GC,_GN,False,False,_pose)
    SPECS[_n0]['id']='v2p_terrasloth_side_'+_k; SPECS[_n0]['runs']=2
    SPECS[_n0]['prompt']=SPECS[_n0]['prompt'].replace("with about 8 percent empty margin on every side","small in the frame, with about 20 percent empty margin on every side")

# 05:45 ET 11-10 OWNER: "Canvastross should borrow his face look from his T1 evo" (Kerchick: grumpy half-lidded eyes, big hooked orange beak, wispy head tuft).
for _n,_who in (('Canvastross',"the final form"),('Jibbatross',"the middle form")):
    SPECS.append({'id':'face_'+_n.lower(),'name':_n+' (Kerchick\'s face)','refs':['briefs/boki-art/cards/'+_n+'.jpg','briefs/boki-art/cards/Kerchick.jpg'],'runs':4 if _n=='Canvastross' else 3,'aspect':'1:1','size':'2K',
      'prompt':("Redraw the bird in image 1 exactly as it is: the same body, wings, pose, view, colours, markings, line and flat shading. Change only its FACE, so it is clearly "+_who+" of the chick in image 2: "
        "give it that chick's face grown up: the same grumpy, unimpressed half-lidded eyes with heavy upper lids, the same big hooked orange-yellow beak, and the same wispy windswept white tuft on its head. "
        "Its head keeps the size and angle it has in image 1. Nothing else changes. One bird only. "+FRAME_V2)})

# 05:55 ET 11-10 OWNER: "Oarter needs a new position because it's the same as Galleotter" (both prowl on all fours, facing left).
ON_POSE('Oarter',_LM['Oarter']['sheet'],'mid','sleek',False,True,"mid-dive, swimming through the air facing RIGHT: body stretched long in a smooth arc, front paws tucked to its chest, its big oar-shaped tail swept up behind it like a paddle mid-stroke, a cheeky grin back at the viewer.","dark brown fur with a tan throat and belly, a row of small oar-shaped spines along its back, a broad tan oar tail, blue eyes")
SPECS[-1]['id']='on_oarter_dive'; SPECS[-1]['runs']=4

# 06:00 ET 11-10 OWNER: "Ribbonwyrm too" (new position).
ON_POSE('Ribbonwyrm',_LM['Ribbonwyrm']['sheet'],'mid','pretty',False,False,"flying upward on a diagonal, facing LEFT, its long body stretched out in one loose open wave like a ribbon caught in the wind (no coils, no figure-eight, no knot), head high at the top left, tail streaming away at the bottom right, whiskers and ribbon fins trailing.","coral-red and cream striped body, pale blue swirl markings, small horns, long thin ribbon whiskers and fins, a tufted tail")
SPECS[-1]['id']='on_ribbonwyrm_wave'; SPECS[-1]['runs']=4
