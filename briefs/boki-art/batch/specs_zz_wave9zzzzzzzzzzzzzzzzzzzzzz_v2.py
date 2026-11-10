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

# 06:10 ET 11-10 OWNER: "we have a dragon and a dragon-flying line of 3 and they look somewhat similar: one of them needs another typing and some
# changes to colour etc". The two: Kitlet > Ribbonwyrm > Dragonkite (kite dragon, cream and coral-red) and Olmlet > Glazolm > Kintsuwyrm (porcelain
# olm, white and red). The kite line stays the dragon. The olm line becomes what it is, a cave salamander of mended porcelain: new colours, gills
# instead of horns, and a proposed type change Dragon -> Water/Crystal. Two colour schemes, owner picks.
_OLM={'jade':("pale celadon jade-green porcelain with gold mending seams, a soft cream belly, and deep teal for every part that is red now","celadon"),
      'blue':("white porcelain painted with cobalt-blue brush patterns, with gold mending seams, and cobalt blue for every part that is red now","blue-and-white")}
for _n,_extra in (('Olmlet',""),('Glazolm'," Its small horns become three pairs of soft feathery gills, like an axolotl's or an olm's."),
                  ('Kintsuwyrm'," It is a great cave salamander, not a dragon: its horns and spikes become three pairs of large feathery gills and a low smooth back fin, its muzzle is rounder and blunter, and it has no wings.")):
    for _k,(_c,_lab) in _OLM.items():
        SPECS.append({'id':'olm_'+_n.lower()+'_'+_k,'name':_n+' ('+_lab+' porcelain)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':_EDIT+"recolour it as "+_c+"."+_extra+" The pose, body, face, line and flat shading stay the same. No red anywhere."})

# 06:20 ET 11-10 OWNER: "Cubwom line needs different poses" (Cubbat, Pipwom and Critwom all stand on all fours facing the same way).
# Stance ladder: the baby sits, the middle moves, the final is planted.
ON_POSE('Cubbat',_LM['Cubbat']['sheet'],'baby','cute',False,True,"sitting on its bottom like a plush toy, facing the viewer, short hind legs sticking out in front, front paws resting on its belly, sleepy contented smile.","a cube-shaped brown wombat with dark round pip spots, a big dark nose, small round ears")
SPECS[-1]['id']='on_cubbat_sit'
ON_POSE('Pipwom',_LM['Pipwom']['sheet'],'mid','tough',False,True,"mid-tumble, rolling forward like a thrown die, facing LEFT: body tipped up on one corner of its dice shell, hind legs in the air, front paws reaching for the ground, determined face.","a tan and cream wombat with dark spots, carrying a big cream dice shell with black pips on its back")
SPECS[-1]['id']='on_pipwom_roll'
ON_POSE('Critwom',_LM['Critwom']['sheet'],'final','tough',False,True,"reared up on its hind legs facing LEFT, front paws raised, spiked dice-dome shell towering behind its shoulders, tail knob planted on the ground, roaring.","brown wombat fur, a cream dice-dome shell with black pips and cream spikes, cream dice plates on its legs and tail knob")
SPECS[-1]['id']='on_critwom_rear'

# 06:30 ET 11-10 OWNER: "Checkmare is cool but kind of messy; there's a few like that: they need a good reason to be messy".
# CLEAN-UP options (same design and pose, fewer and bigger shapes). Shown to the owner next to the live card; nothing changes unless he picks.
_TIDY={'Checkmare':"its spikes: instead of dozens of thin spines all over, it has one clean row of about seven large chess-piece-shaped back plates (like rook tops) from neck to tail and one spear tail tip; its striped body shows clearly between them",
 'Dragonkite':"its wings and trim: two big clean kite-panel wings with one bold swirl each, a plain red body with a cream belly, a short mane, and one ribbon tail; no tattered edges, no extra streamers or small spikes",
 'Terrarimit':"its garden: instead of many small flowers and leaves, its cracked clay pot back holds one small bonsai tree and three big flowers, with plain moss between; four clear root legs",
 'Knotwyrm':"its rope body: one thick rope tied in a single clear big knot, with its head at one end and a frayed tail at the other, three mushrooms and one patch of moss; no extra loops or loose strands",
 'Scarabit':"its rings: one bold orbit ring round its body instead of several crossing ones, with two small moons on it; the beetle's shell is plain dark with three orange lines",
 'Quivertoad':"its back: about six big arrow-shaft quills in one neat row instead of a thicket, bold red target rings on its side kept, plain green skin elsewhere, no drips",
 'Lyrewing':"its feathers: each wing is one clean harp shape with about eight strings and a gold frame, the tail is five big lyre feathers instead of many, and the body is plain green with a gold chest mark"}
for _n,_d in _TIDY.items():
    SPECS.append({'id':'tidy_'+_n.lower(),'name':_n+' (clean-up option)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':_EDIT+"simplify "+_d+". Everything is drawn as few, large, readable shapes with plain flat areas between them. The creature, pose, face, colours and size stay the same."})

# 06:40 ET 11-10 OWNER: "are Siegephant and Glaciammoth legendaries? They don't seem it, and they seem the same with a typing change."
# Both are Boss-tier legendaries and both are tusked giants. Options: Siegephant made legendary-grade; Glaciammoth moved off the elephant body.
OPT('Siegephant','final','majestic',False,False,'briefs/boki-art/cards/Siegephant.jpg',[
 "a true legendary war-beast, far grander than an ordinary elephant: a colossal ancient elephant whose whole back has grown into a ruined stone fortress with three towers and a gate arch, moss in the cracks, four long curved tusks like battering rams, a trunk plated like a drawbridge chain, glowing amber eyes, standing planted and calm like a walking castle.",
 "a legendary siege titan: a towering elephant rearing on its hind legs, its skull grown into a stone battering-ram crown, two huge tusks crossed like gate bars, its back a single tall watchtower with a banner-shaped ear on each side, cracks of amber light in the stone.",
 "an ancient living citadel: a huge kneeling elephant so old that a walled keep has grown over its shoulders and head like a helmet, only its amber eyes, tusks and trunk showing under the battlements, small stone bridges linking its towers."])
OPT('Glaciammoth','final','majestic',False,False,'briefs/boki-art/cards/Glaciammoth.jpg',[
 "no longer an elephant shape: a legendary glacier beast built like a giant musk-ox carved from blue ice, with a huge curtain of icicle hair hanging to the ground, two massive down-curved ice horns, and a frozen amber heart glowing inside its chest. Planted and immense.",
 "no longer an elephant shape: a legendary woolly rhinoceros of ancient ice, with one enormous flat blade horn like an ice-breaker's prow, a shaggy frost mane, and small creatures frozen in amber inside its translucent blue flanks.",
 "kept as a mammoth but made unmistakably legendary and unlike a stone elephant: a ghostly mammoth of clear glacier ice, its skeleton faintly visible inside, with four spiralling tusks sweeping forward like a sleigh, a trailing cloak of frozen fur, and drops of glowing amber set along its spine."])

# 06:55 ET 11-10 OWNER: "Sirencada, Quivertoad, all same pose" (each stands like the stage before it: Klaxada, Bullsfrog).
ON_POSE('Sirencada',_LM['Sirencada']['sheet'],'final','tough',False,False,"taking off straight at the viewer, facing LEFT in a rising three-quarter view: body tilted up at 45 degrees, wing-cases flung wide open, clear wings spread, all six legs lifted off the ground and tucked, siren horn aimed forward and up.","copper and bronze exoskeleton, a siren-horn body with a fan vent, bronze wing-cases, red eyes")
SPECS[-1]['id']='on_sirencada_fly'; SPECS[-1]['runs']=4
ON_POSE('Quivertoad',_LM['Quivertoad']['sheet'],'final','tough',False,False,"reared up on its hind legs facing LEFT, front legs raised, throat puffed out in a huge bellow, the arrow quills on its back fanned out behind it like a peacock tail, tail planted on the ground.","red and green skin with red target rings on its sides, green arrow-shaft quills on its back, small horns, a red tail")
SPECS[-1]['id']='on_quivertoad_rear'; SPECS[-1]['runs']=4

# ===== 07:15 ET 11-10 OWNER: "their lines are all the same pose, we need to review for this more". POSE REVIEW of every line (strips of all stages
# side by side): a stage that stands the same way as its neighbour gets a new pose. Stance ladder: babies sit or bounce, middles move, finals are planted.
# Same design, pose only; 3 runs; ids pose_<name>. Already queued before this pass: Oarter, Ribbonwyrm, Cubbat, Pipwom, Critwom, Sirencada, Quivertoad.
_KEEPALL="everything image 1 shows, in the same colours"
for _n,_st,_ar,_dk,_fu,_pose in (
 ('Rampartoad','mid','tough',0,0,"mid-hop facing RIGHT, back legs kicked out behind it, front legs reaching forward, the stone wall on its back tilted with the jump."),
 ('Furnacowary','final','tough',1,0,"striding forward toward the viewer on a diagonal, facing LEFT, one big foot raised mid-step, head lowered and thrust forward, firebox chest leading."),
 ('Prowyak','mid','cute',0,1,"trotting straight toward the viewer in a front three-quarter view, head down so its bony prow leads, shaggy coat swinging, one front hoof lifted."),
 ('Bastling','baby','cute',0,0,"sitting back on its shell and waving one claw high in the air, other claw on the ground, legs splayed, happy."),
 ('Canvastross','final','majestic',0,1,"standing planted on the ground facing LEFT, tall and proud, wings folded half open like furled sails, mast feather upright, head turned to the viewer."),
 ('Latchling','baby','cute',0,0,"sitting on its bottom facing the viewer, front feet together, key tail curled round to the front, looking up."),
 ('Fawngus','baby','cute',0,1,"lying down with its legs folded under it, head up and tilted, mushroom-cap ears perked."),
 ('Wickapi','baby','cute',1,1,"sitting on its haunches like a dog, front legs straight, facing RIGHT, head turned to the viewer, candle flame upright."),
 ('Chandelapi','final','majestic',1,1,"facing the viewer head-on, standing square and planted, head lowered slightly so its chandelier antlers frame its face, flame mane flowing to both sides."),
 ('Sandwidow','mid','creepy',1,1,"reared up on its back four legs facing LEFT, front four legs raised in a threat display, hourglass tilted back above it."),
 ('Scarabit','mid','tough',1,0,"rearing up on its back legs facing LEFT, pushing its orbit rings up over its head like a dung beetle rolling a ball, front legs braced."),
 ('Truffapir','mid','cute',1,0,"head down, snuffling at the ground with its long snout, front legs bent, rump in the air, facing RIGHT, tail up."),
 ('Gambitfin','mid','sleek',0,0,"mid-leap in an arc facing LEFT, like a knight jumping on a chessboard: body stretched, tail uncoiled and trailing behind, head high."),
 ('Stormit','mid','cute',0,0,"scuttling sideways toward the LEFT with both claws raised high over its head, legs mid-step, the storm dome on its back tilted."),
 ('Dynaboa','final','sleek',0,1,"crouched low on all fours facing LEFT, spring legs coiled tight under it, copper fins fanned wide and raised, tail whipping, about to launch.")):
    _n0=len(SPECS); ON_POSE(_n,_LM[_n]['sheet'],_st,_ar,bool(_dk),bool(_fu),_pose,_KEEPALL); SPECS[_n0]['id']='pose_'+_n.lower()

# ===== 07:50 ET 11-10 OWNER on Mossbastion, Maracoil, Blastopuff: "all 3 evolutions can be better and more interesting and tie into their earlier one better".
# Options built FROM THE BABY's card (image 1), so the tie is real. 3 directions x 2 runs.
def OPTB(n,baby,stage,arch,dark,furry,opts):
    for _k,_d in zip('abc',opts):
        ON_CHANGE(n,_C%baby,stage,arch,dark,furry,"this is the evolved form of the creature in image 1, clearly the same animal grown up, keeping its colours, face and signature idea: "+_d,runs=2,tag='_'+_k); SPECS[-1]['id']='opt_'+n.lower()+'_'+_k
OPTB('Mossbastion','Mossgrade','final','majestic',False,False,[
 "a giant water-bear the size of a hill, the same eight stubby legs and round snout, its fuzzy moss back grown into a whole little landscape: a small hill with one tree, a pond and a few standing stones, sprouts turned into saplings. Slow, gentle, immense, walking.",
 "a huge armoured water-bear whose moss has thickened into overlapping mossy stone plates like a fortress wall along its back, with the same round snout poking out under a mossy brow ledge and the same pebbles now boulders set in the moss. Braced low and wide, facing the viewer.",
 "a towering water-bear reared up on its back four legs like a living standing stone, its belly pale cream as in image 1, its back a cloak of long hanging moss and ferns, the same round snout raised to the sky, small sprouts on its head grown into a crown of ferns."])
OPTB('Maracoil','Rattlebub','final','tough',False,False,[
 "a big festival serpent mid-strike, body stretched out long and low in a lunge toward the left, the same cream scales with red and teal diamond patterns, its tail split into two large painted maraca rattles held up behind it, a feathered-looking frill of bright scales round its neck instead of a plain hood.",
 "a large snake dancing upright like a charmed cobra but swaying in a big S, the same diamond-pattern scales, with a row of rattle beads down its spine and four maraca rattles on a fanned tail, eyes half closed, a showman's grin.",
 "a heavy coiled drum-snake: its coils are stacked into a round drum shape with the same painted diamond bands, its head resting on top looking at the viewer, and its tail raised beside it ending in one huge maraca like a drumstick."])
OPTB('Blastopuff','Puffuse','final','tough',True,False,[
 "a big sea-mine pufferfish seen from the side, swimming left: the same charcoal body with glowing yellow cracks and cream belly, now covered in short thick contact-horn spikes like a naval mine, its fuse tail longer and lit, small angry eyes, cheeks puffed.",
 "a long torpedo-shaped pufferfish, no longer a ball: the same charcoal back with yellow cracks and cream belly stretched into a sleek rocket body with fin-like tail vanes, the fuse now a sparking crest along its back, darting forward with a fierce grin.",
 "a huge pufferfish mid-explosion pose: fully inflated and rearing back, spikes shot out long like a firework burst, the yellow cracks blazing wide across its charcoal skin, fuse burnt down to a stub, eyes wide and furious. All spikes attached to its body."])

# ===== 08:20 ET 11-10: pose/face picks live as cards (22 Boki, list below). Sheets (3 runs) from each new card so sheet and card agree; portraits keep
# their current pose where the design did not change, so only Canvastross and Jibbatross (new face) get new portraits.
_POSED="Oarter Ribbonwyrm Cubbat Pipwom Critwom Sirencada Quivertoad Canvastross Jibbatross Rampartoad Furnacowary Prowyak Bastling Fawngus Wickapi Chandelapi Sandwidow Scarabit Truffapir Gambitfin Stormit Dynaboa".split()
for _n in ('Canvastross','Jibbatross'):
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg','final' if _n=='Canvastross' else 'mid','majestic' if _n=='Canvastross' else 'sleek',_GC,_GN,False,True,"standing on the ground, wings folded, grumpy sideways look at the viewer")
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_face'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_face'; SPECS[_n0+1]['runs']=2

# 08:40 ET 11-10: Lunowl female (fv4_2) and Murmuron female (fv4_4) cards live: same palette as the male, one step apart. Their sheets + portraits.
for _n in ('Lunowl','Murmuron'):
    _st,_ar,_dk,_fu=_FEMST[_n]; _cd='briefs/boki-art/cards/'+_n+'_female.jpg'; _n0=len(SPECS)
    V2SHEET_NEW(_n+' female',_cd,_GC,_GN); V2PORT_NEW(_n+' female',_cd,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_FEMPOSE[_n])
    SPECS[_n0]['id']='fs3_'+_n.lower(); SPECS[_n0+1]['id']='fp3_'+_n.lower(); SPECS[_n0+1]['runs']=2
# Pangolith portrait: the card as reference kept the card's pose 6 of 6. Retry from the SHEET with the pose first.
for _k,_pose in (('a',"curled into a ring lying flat on its side, seen from a low side angle so the ring looks like a wide oval, head resting on its tail, one eye open"),
                 ('b',"walking on all fours in a side view facing RIGHT, back arched, long scaled tail trailing, head turned to the viewer")):
    ON_POSE('Terrasloth',_LM['Terrasloth']['sheet'],'mid','cute',False,False,_pose+". It is small in the frame, with about 20 percent empty margin on every side.",_KEEPALL); SPECS[-1]['id']='v2p_terrasloth_new_'+_k; SPECS[-1]['runs']=2

# ===== 09:00 ET 11-10 OWNER picks: Sporcupine = D2 mirrored (faces the other way from Mycroll); olm line = blue-and-white; Siegephant = A2;
# clean-ups Dragonkite 2, Terrarimit 1, Lyrewing 1. Names: Sphinxblight -> Enigmane, Anchorbill -> Anchorpup (display names).
# Checkmare: clean-up 1 "without the needle thing on its mouth". Knotwyrm: clean-up 3 "has no contrast without the wood thing: give him contrast".
# Glaciammoth: "merge the two so the 2nd has the 1st's tusk" = the ice musk-ox (A1) with the ice rhino's blade horn (B1).
SPECS.append({'id':'fix_checkmare','name':'Checkmare (clean-up, no beak needle)','refs':[_O+'tidy_checkmare_1.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"remove the long thin needle or spear point sticking out from the front of its mouth: its head ends in a normal short seahorse-horse muzzle with a closed mouth. Do not add anything else."})
SPECS.append({'id':'fix_knotwyrm','name':'Knotwyrm (clean-up with contrast)','refs':[_O+'tidy_knotwyrm_3.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"give it contrast, because it is all one pale tan now: the inside of the big knot becomes dark brown weathered wood like an old mooring post that the rope is tied round, the rope gets alternating light tan and darker brown twist bands, the frayed tail end is dark, two patches of bright green moss sit on the knot, and its three mushrooms get rust-red caps. The shape and pose stay the same."})
SPECS.append({'id':'fix_glaciammoth','name':'Glaciammoth (ice musk-ox with the blade horn)','refs':[_O+'opt_glaciammoth_a_1.jpg',_O+'opt_glaciammoth_b_1.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':"Redraw the ice musk-ox in image 1 exactly as it is: the same body, long icicle hair, glowing amber heart, face, colours, pose, line and flat shading. Change only this: in place of its two curled horns it has ONE enormous flat curved blade horn of clear blue ice on its nose and brow, like the horn of the creature in image 2, sweeping forward and up like an ice-breaker's prow. Take only that horn from image 2. One creature only. "+FRAME_V2})
_PK={'Sporcupine':('mid','sleek',0,1,"trotting toward the viewer, head high, mushroom tail swinging"),'Olmlet':('baby','cute',0,0,"curled in a loose loop, looking up"),
 'Glazolm':('mid','pretty',0,0,"swimming through the air in an open S, gills flared"),'Kintsuwyrm':('final','majestic',0,0,"coiled and rearing, gills spread wide, looking down at the viewer"),
 'Siegephant':('final','majestic',0,0,"standing square to the viewer, trunk raised, fortress towering behind its head"),'Dragonkite':('final','majestic',0,0,"wings spread wide like a kite catching the wind, rearing"),
 'Terrarimit':('final','cute',0,0,"scuttling sideways, peeking out from under its garden"),'Lyrewing':('final','majestic',0,1,"standing on the ground with its harp wings folded upright, head turned to the viewer")}
for _n,(_st,_ar,_dk,_fu,_pose) in _PK.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_p3'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_p3'; SPECS[_n0+1]['runs']=2

# 09:10 ET 11-10 OWNER: "Ringrove could get a bit of an upgrade too, and definitely a better way of standing / portrait".
# Same bear-sized Mycroll-family final (image 1), upgraded and in a stronger stance; 3 directions x 2 runs. Image 2 = the new Sporcupine, so the line connects.
for _k,_d in (('u1',"rearing up on its hind legs like a great bear, front paws raised, its quills flared out behind it like a lion's mane and a full ring of big mint mushroom caps crowning its shoulders and head; a longer tail ending in one huge cap, like the middle form's tail grown up. Powerful and proud."),
              ('u2',"standing side-on on all fours, facing RIGHT, head turned to look at the viewer, one front paw raised on a step: longer legs than now, a thick cream chest ruff, a tall crest of quills from brow to tail with tiers of mint caps along it from small to huge, and a heavy cap-tipped tail held high."),
              ('u3',"seated upright like a guardian statue facing the viewer, broad chest forward, front paws planted, a wide halo of mint mushroom caps fanned behind its head and shoulders like a ring, long quills sweeping down its back to the ground, calm noble eyes.")):
    SPECS.append({'id':'opt_ringrove_'+_k,'name':'Ringrove (upgrade '+_k+')','refs':[_C%'Ringrove',_C%'Sporcupine'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of an upgraded version of the creature in image 1, the final evolution of the creature in image 2: the same cream face, warm brown quills, mint mushroom caps with cream spots and teal eyes, bigger and more impressive. NEW STANCE AND UPGRADE (the whole point): "+_d+" Ignore how the images are painted. "+_TXT.replace("There is only one image and no style image: the","The")+STYLE_V2('final','majestic',False,True)+FRAME_V2})

# ===== 09:40 ET 11-10: owner asleep, "rank your own choices and try to finish for morning". My picks, live as cards: Mossbastion = a_1 (water-bear
# carrying a little landscape), Blastopuff = c_2 (spike burst in family colours), Ringrove = u1_1 (rearing, mane of quills, cap tail), Checkmare = fix 1,
# Knotwyrm = fix 2, Glaciammoth = merge 2 (ice musk-ox, one blade horn). Maracoil: no option beat the live card (all read as the baby again) -> kept.
# Pangolith portrait = v2p_terrasloth_new_a_2 (ring lying on its side). Rankings are in LINE_REVIEW_1110.md for the owner's morning review.
_PM={'Mossbastion':('final','majestic',0,0,"walking slowly toward the viewer, the little landscape on its back tilted with each step"),'Blastopuff':('final','tough',1,0,"seen from the side, puffed up, spikes out, glaring"),
 'Ringrove':('final','majestic',0,1,"standing on all fours side-on, head turned to the viewer, cap tail held high"),'Checkmare':('final','majestic',0,0,"coiled upright like a chess knight on its base, head high"),
 'Knotwyrm':('final','majestic',0,0,"uncoiling, head raised from the knot, looking at the viewer"),'Glaciammoth':('final','majestic',0,0,"head lowered, blade horn forward, icicle hair swaying, about to charge")}
for _n,(_st,_ar,_dk,_fu,_pose) in _PM.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_m'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_m'; SPECS[_n0+1]['runs']=2
# COORD 03:07 ET, owner order: the olm line is now typed Water/Crystal and must read as both: keep blue-and-white porcelain, gold seams and gills;
# add Water (fins, flowing frill and tail) and Crystal (clear faceted growths), more on each stage.
for _n,_d in (('Olmlet',"add a small soft water-blue fin along its back and tail tip, and two tiny clear crystal nubs on its head"),
              ('Glazolm',"add a flowing translucent water-blue fin frill along its back and a wide fan tail fin, and a few clear faceted crystals growing along its spine and at its elbows"),
              ('Kintsuwyrm',"add a tall flowing water-blue sail fin from neck to tail and a broad fan tail, and big clear faceted crystal clusters on its shoulders, back and tail tip, with crystal-tipped gills")):
    SPECS.append({'id':'wc_'+_n.lower(),'name':_n+' (Water/Crystal read)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':_EDIT+_d+". The crystals are a handful of large flat-shaded facets with one highlight each; the fins are flat shapes. Its blue-and-white porcelain pattern, gold seams, gills, face and pose stay the same. No red."})

# 10:20 ET 11-10: olm line Water/Crystal cards live (wc_*_2 each: fins + clear crystals, more each stage). Sheets + portraits from them.
for _n,(_st,_ar,_pose) in {'Olmlet':('baby','cute',"swimming forward through the air, little fin rippling, looking at the viewer"),'Glazolm':('mid','pretty',"rearing up with its fin frill spread like a fan, gills flared"),
                           'Kintsuwyrm':('final','majestic',"coiled high like a fountain, sail fin raised, crystals catching the light, looking down at the viewer")}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,False,False,_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_wc'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_wc'; SPECS[_n0+1]['runs']=2

# 11-10 morning OWNER: Mossbastion = 2nd pick (opt_mossbastion_b_1, mossy stone-plated water-bear; "the tree on top is overdone"). Rest of the overnight picks stand.
_n0=len(SPECS); V2SHEET_NEW('Mossbastion','briefs/boki-art/cards/Mossbastion.jpg',_GC,_GN); V2PORT_NEW('Mossbastion','briefs/boki-art/cards/Mossbastion.jpg','final','majestic',_GC,_GN,False,False,"walking slowly side-on, head turned to the viewer, heavy and calm")
SPECS[_n0]['id']='v2s_mossbastion_b'; SPECS[_n0+1]['id']='v2p_mossbastion_b'; SPECS[_n0+1]['runs']=2

# 11-10 morning OWNER: Pipwom's new pose "looks bad, keep the OG" (reverted). Arcestrel female "legs glitch" (redo). "Canvastross needs a rework".
SPECS.append({'id':'fv5_arcestrel','name':'Arcestrel female (clean legs)','refs':['briefs/boki-art/cards/Arcestrel.jpg'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':("Draw the FEMALE of the creature in image 1 as one single character illustration. She is the same species with the same signature parts, drawn the same way, in a calm standing pose seen from the side, facing LEFT. "
   "She has exactly TWO legs, both clearly drawn, both feet flat on the same level, each with three front toes and one back toe; no extra legs, toes or claws anywhere. How she differs from the male: a slightly rounder body, "
   "a shorter head crest and shorter curled tail feathers; warm sandy brown plumage with fine dark barring and a cream chest, with a little slate-blue on the wings."+_FEMFACE+" "+STYLE_V2('mid','sleek',False,True)+FRAME_V2)})
# Canvastross rework: 3 directions x 2 runs, built from its own line (image 1 = Kerchick the baby, image 2 = Jibbatross the middle).
for _k,_d in (('a',"a great sail-winged albatross standing tall on the ground like a ship at anchor: enormous wings held half open like two full square sails with pale blue swirl markings, a deep keel-shaped chest of cream feathers, one tall mast-like crest feather, a long rudder tail. Proud, weathered, a captain's grumpy stare."),
              ('b',"a huge albatross gliding straight toward the viewer, seen from the front and slightly below: an immense wingspan filling the frame, wings shaped like spread sails with swirl markings, chest out like a ship's prow, mast crest feather upright, feet tucked."),
              ('c',"a heavy sea-bird in full sail seen side-on, facing RIGHT, skimming forward: three tiers of wing feathers stacked like the sails of a tall ship, a long streaming tail like a pennant, a strong hooked beak and windswept tuft, small swirl clouds painted on its wings.")):
    SPECS.append({'id':'opt_canvastross_'+_k,'name':'Canvastross (rework '+_k+')','refs':[_C%'Kerchick',_C%'Jibbatross'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the FINAL evolution of the bird in images 1 and 2 (image 1 is the baby, image 2 the middle form): clearly the same bird grown huge, with the same grumpy half-lidded eyes, big hooked orange beak, windswept white tuft, cream-white feathers and pale blue swirl markings. All its ship-like parts are feathers and body, nothing built or worn: no wood, ropes or cloth. THE DESIGN: "+_d+" Ignore how the images are painted. "+_TXT.replace("There is only one image and no style image: the","The")+STYLE_V2('final','majestic',False,True)+FRAME_V2})

# Arcestrel female: fv5_arcestrel_1 live (two clean legs). Sheet + portrait from it.
_st,_ar,_dk,_fu=_FEMST['Arcestrel']; _n0=len(SPECS)
V2SHEET_NEW('Arcestrel female','briefs/boki-art/cards/Arcestrel_female.jpg',_GC,"two wings, exactly two legs, one crest, curled tail feathers"); V2PORT_NEW('Arcestrel female','briefs/boki-art/cards/Arcestrel_female.jpg',_st,_ar,_GC,"two wings, exactly two legs, one crest, curled tail feathers",False,True,"standing still, head turned back over her shoulder to the viewer, both feet on the ground")
SPECS[_n0]['id']='fs4_arcestrel'; SPECS[_n0+1]['id']='fp4_arcestrel'; SPECS[_n0+1]['runs']=2

# 11-10 OWNER: "your picks go" -> Canvastross = opt_canvastross_a_1 (standing, sail wings, mast feather). Sheet + portrait.
_n0=len(SPECS); V2SHEET_NEW('Canvastross','briefs/boki-art/cards/Canvastross.jpg',_GC,_GN); V2PORT_NEW('Canvastross','briefs/boki-art/cards/Canvastross.jpg','final','majestic',_GC,_GN,False,True,"gliding side-on, facing RIGHT, wings spread flat like sails, mast feather streaming back")
SPECS[_n0]['id']='v2s_canvastross_r'; SPECS[_n0+1]['id']='v2p_canvastross_r'; SPECS[_n0+1]['runs']=2

# ===== 11-10 midday OWNER NOTES =====
# Wickapi "looks good but Snuffapi doesn't look older by much: Wickapi probably needs to be aged down / smaller". 3 takes, 2 runs each.
for _k,_d in (('y1',"a newborn calf, much younger and smaller than now: a big round head, huge eyes, very short neck, short wobbly legs with knobbly knees, a tiny candle stub on its head with one small purple flame, a stubby tail. Standing unsteadily."),
              ('y2',"a tiny round calf sitting with its legs folded under it, head too big for its body, enormous sleepy eyes, tiny ears, a short candle stub melted a little down one side, flame small."),
              ('y3',"a small chubby calf mid-hop, short legs, round belly, big head, stubby striped legs, candle stub leaning, happy open mouth.")):
    ON_CHANGE('Wickapi','briefs/boki-art/cards/Wickapi.jpg','baby','cute',True,True,"the same okapi calf with the same dark red-brown fur, cream-striped legs, candle and purple eyes, but clearly a baby: "+_d,runs=2,tag='_'+_k); SPECS[-1]['id']='opt_wickapi_'+_k
# New poses: Candelapi ("straight up staring"), Dribbara ("looks a bit weird"), Spirevark ("same as evo 1"). 2 poses x 2 runs each; sheet as reference.
for _n,_st,_ar,_dk,_fu,_poses in (
 ('Chandelapi','final','majestic',1,1,("walking side-on, facing LEFT, head held high and turned slightly toward the viewer, one foreleg lifted, flame mane and tail streaming behind","rearing up on its hind legs, facing RIGHT, forelegs tucked, chandelier antlers thrown back, flame mane flaring")),
 ('Dribbara','baby','cute',0,1,("standing on all four stubby legs, facing LEFT, looking back over its shoulder at the viewer, the little puddle on its back catching a drop","lying flat on its belly with its chin on the ground and legs splayed out, eyes looking up, puddle on its back")),
 ('Spirevark','final','tough',0,0,("head down, digging with its big front claws, facing LEFT, tail raised, the termite spire on its back tilted forward","standing tall on its hind legs and tail like a meerkat, facing RIGHT, long snout raised sniffing the air, spire rising behind its shoulders"))):
    for _k,_p in zip('ab',_poses):
        _n0=len(SPECS); ON_POSE(_n,_LM[_n]['sheet'],_st,_ar,bool(_dk),bool(_fu),_p+".",_KEEPALL); SPECS[_n0]['id']='pose2_'+_n.lower()+'_'+_k; SPECS[_n0]['runs']=2
# Coolatee line is NOT cut after all (owner: "looks okay... maybe we work on it a bit to give it something extra and keep it"). Restored to the manifest.
# Two ideas per stage, 2 runs each. A = the names' own idea (cooler > frigate > glacier). B = aurora seals.
_COOL={'Coolatee':('baby','cute',("its back is a little hollow ice-chest grown from its own body: a square block of clear ice with rounded corners, holding two tiny frozen fish and a snowflake, with a small lid of frost; a round white seal pup under it, pale mint flippers.",
                                  "its white fur carries soft aurora bands of pale green and pink along its back, and one small ice lantern crystal glows on its forehead; round pup, big dark eyes.")),
       'Frigatee':('mid','sleek',("a sea lion built like a small ice frigate: two tall sail-shaped back fins of thin clear ice, a pointed ice ram on its nose, a row of round frost portholes along its sides, swimming forward fast.",
                                  "a sleek sea lion with bright aurora ribbons of green and pink flowing from its neck like a scarf of light drawn as flat bands, ice crystal ridge, leaping.")),
       'Glaciatee':('final','majestic',("a colossal sea lion that carries a glacier ship: three ice masts with frozen sails grown from its back, a prow-shaped ice crest on its head, long ice tusks, small ice floes fused to its flippers. Planted and immense.",
                                  "a huge bull sea lion crowned with an ice crown, with a full aurora curtain in green, pink and violet rising from its back like a mane of light drawn as flat bands, long ice tusks, calm and regal."))}
for _n,(_st,_ar,_ds) in _COOL.items():
    for _k,_d in zip('ab',_ds):
        ON_CHANGE(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,False,False,"the same ice seal, given one strong idea of its own: "+_d,runs=2,tag='_x'+_k); SPECS[-1]['id']='cool_'+_n.lower()+'_'+_k
# Canvastross is typed Water/Flying but shows nothing of water (owner asked). Option: sea read added to the new design. 3 runs.
SPECS.append({'id':'sea_canvastross','name':'Canvastross (sea read)','refs':['briefs/boki-art/cards/Canvastross.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"give it a clear sea look: its wing tips and tail feathers end in white foam-curl shapes like breaking waves, the swirl marks on its wings become deeper sea-blue wave curls, its belly feathers are tipped sea-blue, and it has webbed orange feet. Everything else stays the same."})
# Missing female forms the owner asked about: Mothlet (Lunowl line) and Grainspin (Sandwidow line) are flagged male/female but had no female art.
_FEMST['Mothlet']=('baby','cute',0,1); _FEMST['Grainspin']=('baby','cute',0,1)
FEM2('Mothlet',None,"a paler lavender-grey body with a cream chest, wing tips one step lighter, the brow crescent in silver, a slightly rounder body.",runs=3)
FEM2('Grainspin',None,"a deep plum body where he is tan, with lilac sand in her glass globe instead of gold, slightly longer legs and a rounder abdomen.",runs=3)

# ===== 11-10 afternoon OWNER NOTES (2) =====
# Cubwom (Cubbat): back on its standing card ("I liked the old Cubwom a lot"); Pipwom tries sitting instead.
ON_POSE('Pipwom',_LM['Pipwom']['sheet'],'mid','tough',False,True,"sitting back on its haunches like a bear, facing LEFT, front paws resting on its knees, its big dice shell behind it like a backpack, grumpy sideways look at the viewer.",_KEEPALL); SPECS[-1]['id']='pose2_pipwom_sit'; SPECS[-1]['runs']=3
# Kitedrake (Dragonkite): "a cooler position/card, too close to Ribbonwyrm's". Checkmare: "new posing style, same as the T1". 2 poses x 2 runs.
for _n,_st,_ar,_poses in (('Dragonkite','final','majestic',("diving down from the top right toward the lower left, wings swept back like a stooping falcon, jaws open, tail streaming straight behind","perched upright on its hind legs facing the viewer, both kite wings spread fully open to the sides like a banner, head lowered and glaring")),
                          ('Checkmare','final','majestic',("lunging forward in a long low line, facing LEFT, body stretched out almost straight with only the tail curled, head thrust forward like a knight charging","reared straight up tall like a chess piece standing on its coiled base, seen from the front three-quarter, head turned sharply to the right in profile"))):
    for _k,_p in zip('ab',_poses):
        _n0=len(SPECS); ON_POSE(_n,_LM[_n]['sheet'],_st,_ar,False,False,_p+".",_KEEPALL); SPECS[_n0]['id']='pose2_'+_n.lower()+'_'+_k; SPECS[_n0]['runs']=2
# Grammite "has a lack of detail and Dobsabre has a lot": bring them toward each other. 3 runs each.
SPECS.append({'id':'det_grammite','name':'Grammite (more detail)','refs':['briefs/boki-art/cards/Grammite.jpg','briefs/boki-art/cards/Dobsabre.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"give it more to look at, so it clearly belongs with its evolution in image 2: each shell segment gets a darker rim and one row of small pale dots, the yellow side stripe becomes a bold zig-zag, its two crossed sabre mandibles get a pale edge and a darker base like image 2's, and its face gets bigger amber eyes like image 2's. Take only those details from image 2. The pose, shape and colours of the creature in image 1 stay the same."})
SPECS.append({'id':'det_dobsabre','name':'Dobsabre (a little simpler)','refs':['briefs/boki-art/cards/Dobsabre.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"simplify it a little: the wings lose their fine scale pattern and become flat wing shapes with three or four bold veins, and the body's small plates merge into a few large ones. Everything else stays the same."})
# Scopeleon: "has a scope in its eye and its eye is open: it needs to be mostly closed like he's squinting".
SPECS.append({'id':'eye_scopeleon','name':'Scopeleon (squinting)','refs':['briefs/boki-art/cards/Scopeleon.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"its normal eye (the one that is not the brass telescope) is squinted almost shut, like someone peering through a telescope with one eye closed: a curved lid line with only a thin sliver of eye showing, and a small concentrating frown. The telescope eye stays as it is. Nothing else changes."})
# Snapler: "kind of random: first isn't clearly a fish, then a fish, then a fish with legs. Closer to fish but less fish face; make sense as the
# middle stage for the two around it". Image 1 = Lurklet (baby), image 2 = Maulangler (final). 3 directions x 2 runs.
for _k,_d in (('m1',"the baby's round dark body grown longer, with the baby's big round purple eyes and soft face (not a fish face), two stubby front legs just sprouting like the final form's, a short tail fin, the purple smoke fins of the baby grown into longer wisps, and a lure stalk that now ends in a small glowing hook. Its mouth is a wide closed grin showing a few cream teeth."),
              ('m2',"a tadpole-like in-between: a plump dark body with the baby's face and big eyes, a wide mouth just starting to show the final form's teeth, a long finned tail it swims with, tiny hind leg buds, purple smoke trailing from its back, and a lure with a small hook held forward like a fishing rod."),
              ('m3',"a hunched little prowler: the baby's dark round head on a longer body carried on two front legs, dragging a finned tail behind it, mouth half open with a faint purple glow inside like the final form's, eyes still big and round, lure hook swinging in front.")):
    SPECS.append({'id':'opt_snapler_'+_k,'name':'Snapler (middle-stage rework '+_k+')','refs':[_C%'Lurklet',_C%'Maulangler'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the MIDDLE evolution between the baby in image 1 and the final form in image 2, so the three read as one line: the same dark purple-grey body colour, purple glow and lure. THE DESIGN: "+_d+" Ignore how the images are painted. "+_TXT.replace("There is only one image and no style image: the","The")+STYLE_V2('mid','creepy',True,False)+FRAME_V2})

# ===== 11-10 afternoon picks (1st of each, shown to the owner with 2nd/3rd): cards live for Wickapi (y1_2), Candelapi (pose a_2), Dribbara (a_1),
# Spirevark (a_1), Pipwom (sit_2), Kitedrake (dive a_2), Checkmare (lunge a_2), Scopeleon (squint 1), Snapler (m1_2), Grammite (detail 1);
# female cards Mothlet (2), Grainspin (3). NOT changed, owner to choose: Coolatee line (cool_*), Canvastross sea look, Dobsabre simpler.
for _n,(_st,_ar,_dk,_fu,_pose) in {'Wickapi':('baby','cute',1,1,"sitting with its short legs folded, head tilted, candle flame wobbling"),'Snapler':('mid','creepy',1,0,"swimming forward through the air, lure held out in front, grinning"),
                                   'Grammite':('baby','cute',1,0,"uncurled and trundling forward, sabre mandibles raised"),'Scopeleon':('baby','cute',1,0,"sitting with its tail curled under it, squinting through its telescope eye up at the viewer")}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_q'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_q'; SPECS[_n0+1]['runs']=2
_FEMPOSE['Mothlet']="perched, head tilted, wings tucked"; _FEMPOSE['Grainspin']="scuttling forward, front legs raised"
for _n in ('Mothlet','Grainspin'):
    _st,_ar,_dk,_fu=_FEMST[_n]; _cd='briefs/boki-art/cards/'+_n+'_female.jpg'; _n0=len(SPECS)
    V2SHEET_NEW(_n+' female',_cd,_GC,_GN); V2PORT_NEW(_n+' female',_cd,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_FEMPOSE[_n])
    SPECS[_n0]['id']='fs5_'+_n.lower(); SPECS[_n0+1]['id']='fp5_'+_n.lower(); SPECS[_n0+1]['runs']=2

# ===== 11-10 OWNER on the strips: agrees with the other 1sts. Changes:
# Seals = the aurora route (cool_*_b_2 live). Snapler = 2nd (m2_1) but "still a bit baby, maybe needs more". Spirevark's new pose "messed up his eyes,
# try new prompts" (reverted). Wickapi's fur must match Snuffapi and Chandelapi. Checkmare "needs new poses that are more thought out" (reverted).
# Scopeleon: "something to attach the end of the scope to his eye, like a base: it looks like it's magically floating there".
_EYES=" Its eyes are small, round and amber with a dark pupil and one white highlight, both clearly drawn and matching, set on the sides of its long snout exactly as in image 1."
for _k,_p in (('c',"digging: front half lowered, big front claws scooping forward, hind legs braced, facing LEFT, tail raised for balance, the tall termite spire on its back leaning forward"),
              ('d',"walking side-on, facing RIGHT, long snout low to the ground sniffing, one front foot lifted, tail trailing, spire upright"),
              ('e',"turned three-quarters away from the viewer, looking back over its shoulder, facing LEFT, so the spire on its back is the nearest thing to the viewer")):
    _n0=len(SPECS); ON_POSE('Spirevark',_LM['Spirevark']['sheet'],'final','tough',False,False,_p+"."+_EYES,_KEEPALL); SPECS[_n0]['id']='pose3_spirevark_'+_k; SPECS[_n0]['runs']=2
SPECS.append({'id':'fur_wickapi','name':'Wickapi (fur matches its line)','refs':['briefs/boki-art/cards/Wickapi.jpg','briefs/boki-art/cards/Snuffapi.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"recolour its fur so it is clearly the baby of the creature in image 2: the same dark chocolate-brown coat as image 2 (not red-brown), the same cream zebra stripes on its legs, the same purple for its eyes and candle flame, and a small tuft of purple flame-fur at the back of its neck like the start of image 2's mane. Take only the colours and that tuft from image 2. Its body, pose, face and size stay the same."})
SPECS.append({'id':'base_scopeleon','name':'Scopeleon (scope attached to its eye)','refs':['briefs/boki-art/cards/Scopeleon.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"attach the telescope to its head properly: where the telescope meets its face there is a raised cone-shaped eye turret of its own navy skin, like a real chameleon's eye cone, with a brass ring collar at the tip that the telescope tube grows out of. The telescope clearly comes out of that eye socket, with no gap. Its other eye stays squinted shut. Nothing else changes."})
SPECS.append({'id':'older_snapler','name':'Snapler (a bit less baby)','refs':['briefs/boki-art/cards/Snapler.jpg',_C%'Maulangler'],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"age it up so it sits halfway to the adult in image 2: its eyes become smaller and narrower with a heavier brow, its mouth is wider with a row of uneven cream teeth showing, its body is longer and leaner with a ridge of small fin spikes along the back, its front legs are longer and stronger, and the pink cheek marks are gone. It keeps its colour, lure and purple smoke. Take only the mood and teeth from image 2."})
# Checkmare poses, thought through: it is a chess knight sea-dragon, so the poses come from chess.
for _k,_p in (('k1',"the knight's move: body bent in a sharp L shape, neck and head upright on the left, the long striped body turning at a right angle along the ground to the right, tail tip raised; proud profile facing LEFT"),
              ('k2',"standing guard like a chess piece on its square: coiled into a tight round base at the bottom, neck rising straight up from the centre, head in strict profile facing RIGHT, the row of chess-piece plates running down the back of the neck like a mane"),
              ('k3',"rearing like a warhorse: front of the body thrown up and back, head tossed high, facing RIGHT, the long body sweeping down and round in one big open curve to a raised spear tail")):
    _n0=len(SPECS); ON_POSE('Checkmare',_LM['Checkmare']['sheet'],'final','majestic',False,False,_p+".",_KEEPALL); SPECS[_n0]['id']='pose3_checkmare_'+_k; SPECS[_n0]['runs']=2
# Sets for the picks that are final: seals (aurora) and Canvastross (sea look).
for _n,(_st,_ar,_pose) in {'Coolatee':('baby','cute',"rolling onto its back, flippers up, aurora bands showing"),'Frigatee':('mid','sleek',"leaping in an arc, aurora ribbons trailing"),
                           'Glaciatee':('final','majestic',"head raised, bellowing, aurora curtain rising behind it"),'Canvastross':('final','majestic',"gliding side-on, facing RIGHT, wings spread flat like sails, foam-curl tips trailing")}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,False,_n=='Canvastross',_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_z'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_z'; SPECS[_n0+1]['runs']=2
SPECS[:]=[s for s in SPECS if s['id'] not in ('v2s_wickapi_q','v2p_wickapi_q','v2s_snapler_q','v2p_snapler_q','v2s_scopeleon_q','v2p_scopeleon_q')]

# 11-10 redo picks live: Spirevark pose3 d_1, Checkmare knight's-move k1_1, Wickapi fur 1, Scopeleon base 3, Snapler older 4. Sets from the new cards.
for _n,(_st,_ar,_dk,_fu,_pose) in {'Wickapi':('baby','cute',1,1,"sitting with its short legs folded, head tilted, candle flame wobbling"),'Snapler':('mid','creepy',1,0,"swimming forward through the air, lure held out in front, jaws half open"),
                                   'Scopeleon':('baby','cute',1,0,"sitting with its tail curled under it, squinting through its telescope eye up at the viewer")}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_r2'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_r2'; SPECS[_n0+1]['runs']=2

# 11-10 OWNER: Grammite portrait 1 "has 2 heads" (two faces, four sabres). Portrait 2 live for now; clean retries with the head count spelled out.
_n0=len(SPECS); V2PORT_NEW('Grammite','briefs/boki-art/cards/Grammite.jpg','baby','cute',_GC,"exactly ONE head with one face and two eyes, exactly TWO sabre mandibles crossed in front of the face, one segmented body, short legs",True,False,"uncurled and trundling forward to the left, head up, its two sabre mandibles raised")
SPECS[_n0]['id']='v2p_grammite_one'; SPECS[_n0]['runs']=3

# ===== 11-10 OWNER on the Kitlet line: "they don't look that related, and Kitedrake doesn't look much further along than Ribbonwyrm as an evolution.
# I also don't see the kites in the last two, just the first one." Rework the middle and the final FROM KITLET (image 1): the kite is the line's idea,
# so it must be visible at every stage and grow. Same cream body, coral-orange kite panels with a cross-frame, bow-tie ribbon tail.
_KITE=(" It is clearly the baby in image 1 grown up: the same cream-white body and belly, the same soft face and small horns, the same coral-orange diamond KITE panels with a visible cross-shaped frame "
       "and pale blue swirl marks, and a kite tail of ribbon bows. The kite parts are its own wings, fins and tail, grown from its body. Red or coral only on the kite panels and bows, never the whole body.")
for _k,_d in (('r1',"a long slender serpent dragon whose body IS the kite tail: a row of four diamond kite-panel fins runs down its back from large to small, each with a cross-frame, and its tail ends in a string of ribbon bows; two small diamond kite wings at the shoulders. Flying in a loose open wave, facing LEFT."),
              ('r2',"a slim young dragon with one big diamond kite on its back like a sail, twice the size of the baby's wings, held up by its two wing arms as the cross-frame; a very long tail of ribbon bows streaming behind it; longer neck and legs than the baby. Leaping into the wind, facing RIGHT."),
              ('r3',"a ribbon-bodied dragon flying like a box kite: two pairs of square kite panels, front and back, joined along its long cream body, with a bow-tie ribbon tail; small horns, longer whiskers. Gliding level, seen from the side, facing LEFT.")):
    SPECS.append({'id':'kite_ribbonwyrm_'+_k,'name':'Ribbonwyrm (kite rework '+_k+')','refs':[_C%'Kitlet'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the MIDDLE evolution of the creature in image 1: "+_d+_KITE+" Ignore how image 1 is painted. "+_TXT+STYLE_V2('mid','pretty',False,False)+FRAME_V2})
for _k,_d in (('f1',"a great dragon whose wings are two enormous diamond kites, each with a bold cross-frame and swirl marks, spread wide; a broad cream chest, a long neck, a proud horned head with a short mane, and a very long tail made of a chain of five smaller kites and ribbon bows. Twice the size and weight of a middle stage, rearing with wings open."),
              ('f2',"a majestic festival-kite dragon: a long powerful cream body with a huge fan of five kite panels rising from its back like a sail-crest, a kite-shaped frill round its neck, clawed legs planted, and a streaming tail of ribbons. Standing side-on, facing RIGHT, head turned to the viewer."),
              ('f3',"a storm-kite colossus seen from below as it soars: one vast delta-shaped kite wing span with a cross-frame across its whole back and arms, cream belly toward the viewer, long whiskers and horns, two long ribbon tails with bows whipping behind.")):
    SPECS.append({'id':'kite_dragonkite_'+_k,'name':'Dragonkite/Kitedrake (kite rework '+_k+')','refs':[_C%'Kitlet'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the FINAL evolution of the creature in image 1, big and impressive: "+_d+_KITE+" Ignore how image 1 is painted. "+_TXT+STYLE_V2('final','majestic',False,False)+FRAME_V2})

# 11-10 OWNER: "these are good, your choices" -> Kitlet line rework live: Ribbonwyrm = kite_ribbonwyrm_r1_2, Dragonkite = kite_dragonkite_f1_2. Sets.
for _n,(_st,_ar,_pose) in {'Ribbonwyrm':('mid','pretty',"rising in a steep climb, facing RIGHT, kite fins fanned, bow tail trailing below"),'Dragonkite':('final','majestic',"gliding side-on, facing LEFT, both kite wings spread flat, kite-chain tail streaming behind")}.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,False,False,_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_kite'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_kite'; SPECS[_n0+1]['runs']=2

# ===== 11-10 OWNER: "do a review of everything and see if any can be improved". Second full pass over all 235 by line. Options only (rv_*); nothing
# changes unless an option clearly wins and the owner agrees. Recolours are edits (3 runs); redesigns are 3 directions x 2 runs built from the baby.
def RV_EDIT(n,tag,text,ref2=None,runs=3):
    SPECS.append({'id':'rv_'+n.lower()+'_'+tag,'name':n+' (review: '+tag+')','refs':['briefs/boki-art/cards/'+n+'.jpg']+([ref2] if ref2 else []),'runs':runs,'aspect':'1:1','size':'2K','prompt':_EDIT+text})
def RV_NEW(n,baby,stage,arch,dark,furry,opts):
    for _k,_d in zip('abc',opts):
        ON_CHANGE(n,_C%baby,stage,arch,dark,furry,"this is the evolved form of the creature in image 1, clearly the same animal grown up, keeping its colours, face and signature idea: "+_d,runs=2,tag='_'+_k); SPECS[-1]['id']='rv_'+n.lower()+'_'+_k
# 1. Polyshroom > Starcap > Medushroom: three unrelated bodies and palettes. Both later stages rebuilt from Polyshroom.
RV_NEW('Starcap','Polyshroom','mid','cute',False,False,[
 "the same cream slug body and sleepy face, now lifted off the ground and floating like a small jellyfish: its mint dome cap has grown wider and scalloped into five soft lobes, with long lilac gill ribbons trailing below. Drifting.",
 "the same creature grown taller, rearing up on its cream body like a little walking mushroom, with its mint dome cap doubled in size and a second smaller cap budding beside it, lilac gills frilled like a collar. Awake, curious eyes.",
 "the same creature swimming through the air on its side, body stretched long, its mint dome cap pulsing open like a jellyfish bell with lilac frilled edges and four short tentacle gills. Half-open eyes, a small smile."])
RV_NEW('Medushroom','Polyshroom','final','pretty',False,False,[
 "a large graceful mushroom-jellyfish: a wide mint and lilac dome bell with cream spots, the same cream face under its rim grown calm and elegant, and a long curtain of lilac and cream tentacle gills flowing below. Floating upright, serene.",
 "a tall queenly form: three tiers of mint dome caps stacked like a pagoda, the same cream face in the lowest tier, long lilac gill ribbons trailing like a gown, two ribbon arms held out. Floating.",
 "a big drifting bloom: one huge mint dome cap with a ring of smaller caps round its edge like a crown, the cream body below it long and tapering into a spiral of lilac tentacles. Gentle half-lidded eyes."])
# 2. Dynaboa: its fins read as planks stuck on, and it looks smaller than the middle stage.
RV_NEW('Dynaboa','Jerbit','final','sleek',False,True,[
 "a big powerful jerboa standing tall on long spring legs, twice the baby's size, with a fan of four copper fins grown from its spine like a turbine, each fin curved and joined to the fur by a copper ridge, a thick static mane, and a long whip tail ending in a sparking tuft.",
 "a long-legged racer on all fours like a hare at full stretch, with a low row of six small copper fins down its back like a dynamo, huge ears swept back, static sparks along its tail. Lean and fast.",
 "a heavy-shouldered jerboa crouched to spring, with two broad copper fins folded back along its sides like a beetle's wing-cases, a ruff of white static fur, and big coiled hind legs."])
# 3. Bellowlet > Furnowary is the same bird, bigger.
RV_NEW('Furnacowary','Bellowlet','final','tough',True,False,[
 "a towering cassowary with a deep barrel chest that is an open furnace: glowing orange between dark rib bars, a tall bronze casque shaped like a chimney with one flat flame, heavy scaled legs with big claws, a long neck. Twice the height of a middle stage, planted.",
 "a broad, low forge-bird built like a boiler on two thick legs: round furnace belly glowing through rib bars, short wings held out like bellows, a wide bronze casque, tail feathers like tongues of flat flame.",
 "a lean running cassowary mid-stride, neck stretched forward, its rib firebox streaming a ribbon of flat flame behind it, a swept-back bronze casque, long powerful legs."])
# 4. Fizzlet (copper-coil songbird) barely ties to Boltstrich/Thundrich (storm-cloud ostriches), and those two share a pose.
RV_EDIT('Fizzlet','cloud',"so it is clearly the chick of a storm-cloud ostrich: its body becomes a small round puff of dark grey cloud feathers with one tiny yellow lightning mark, on two long thin copper-brown legs, with a longer pale pink-grey neck. It keeps its copper coil crest and big eyes.")
_n0=len(SPECS); ON_POSE('Thunderstrich',_LM['Thunderstrich']['sheet'],'final','tough',True,True,"running flat out, facing LEFT, neck stretched low and forward, one leg kicked far back, storm-cloud body streaming behind it.",_KEEPALL); SPECS[_n0]['id']='rv_thunderstrich_run'
# 5-7. Colour breaks inside a line (edits).
RV_EDIT('Voltalon','family',"recolour it so it belongs with the rust-red kestrels it evolves from (image 2): rust-red head and back, slate-blue wings, a cream chest with dark barring, copper-coloured legs and crest. No navy and no black. The body and pose stay the same.",ref2='briefs/boki-art/cards/Arcestrel.jpg')
RV_EDIT('Phonodrake','family',"recolour it so it belongs with the tan frilled lizards it evolves from (image 2): warm sandy-tan scales with brown spots and a cream belly, brass horn-frills, amber eyes. Keep only a little dark red on its back spines. The body and pose stay the same.",ref2='briefs/boki-art/cards/Gramofrill.jpg')
RV_EDIT('Pickadactyl','family',"recolour it so it belongs with the baby it evolves from (image 2): slate-blue hide with amber-orange rock plates and wing membranes and a pale tan beak and crest. The body and pose stay the same.",ref2='briefs/boki-art/cards/Chiptero.jpg')
# 8. Forgebrock still has fists that read as iron gauntlets (worn parts).
RV_EDIT('Forgebrock','paws',"its two big grey fists become bare furry bear paws in the same orange-brown fur as its arms, with dark iron-grey claws. No gloves, plates or bands on its arms. Everything else stays the same.")
# 9. Hydrangor is an Ultra legendary but reads as a friendly mid-tier Boki.
RV_NEW('Hydrangor','Hydrangor','final','majestic',False,False,[
 "the same three-headed hydrangea hydra made legendary: far larger and older, three long necks rising high with proud horned heads, great domes of blue and violet hydrangea blooms covering its shoulders and back like storm clouds, a long tail, calm ancient eyes.",
 "the same hydrangea hydra with five heads fanned out like a bouquet, each crowned with a different colour of bloom (blue, violet, pink, white, lilac), a heavy planted body wrapped in leaves, petals drawn as big flat clusters.",
 "the same hydrangea hydra coiled like a great serpent with no legs, three heads rearing from a mound of blooms, bodies wound together like stems, leaves like frills behind each head."])

# 11-10 OWNER on the second review: "good" -> my 1st picks live for Starcap, Medushroom, Dynaboa, Furnacowary, Hydrangor, Fizzlet, Voltalon,
# Phonodrake, Pickadactyl, Forgebrock. Thunderstrich NOT changed ("not sure"; he wants to see the line). Sets from the new cards.
_RV2={'Starcap':('mid','cute',0,0,"drifting sideways, tentacle gills trailing, sleepy eyes on the viewer"),'Medushroom':('final','pretty',0,0,"rising upward, tentacles streaming below, calm"),
 'Dynaboa':('final','sleek',0,1,"mid-leap off its spring legs, copper fins fanned, mane flying"),'Furnacowary':('final','tough',1,0,"striding forward, head low, furnace chest leading"),
 'Hydrangor':('final','majestic',0,0,"all heads raised and fanned out, one looking at the viewer"),'Fizzlet':('baby','cute',0,1,"hopping, tiny wings out, copper coils bouncing"),
 'Voltalon':('final','tough',0,0,"standing its ground on two legs, wings spread wide, screeching"),'Phonodrake':('final','tough',0,0,"rearing its head back, horn-frills flared, mouth open in a roar"),
 'Pickadactyl':('final','tough',0,0,"perched and leaning forward, wings folded, pickaxe crest lowered"),'Forgebrock':('final','tough',0,1,"standing on all fours, head low, forge chest glowing")}
for _n,(_st,_ar,_dk,_fu,_pose) in _RV2.items():
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); V2PORT_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_pose)
    SPECS[_n0]['id']='v2s_'+_n.lower()+'_rv'; SPECS[_n0+1]['id']='v2p_'+_n.lower()+'_rv'; SPECS[_n0+1]['runs']=2
# More Thunderstrich poses for the owner to compare against the line.
for _k,_p in (('t1',"standing tall and still, facing RIGHT in profile, neck stretched straight up, head turned to glare at the viewer, cloud body puffed up, one foot raised"),
              ('t2',"rearing back with both wings of cloud flared wide, facing the viewer, beak open in a screech, lightning forks on the cloud, legs planted wide"),
              ('t3',"crouched low, neck coiled back like a striking snake, facing LEFT, about to peck, cloud body hunched")):
    _n0=len(SPECS); ON_POSE('Thunderstrich',_LM['Thunderstrich']['sheet'],'final','tough',True,True,_p+".",_KEEPALL); SPECS[_n0]['id']='rv_thunderstrich_'+_k; SPECS[_n0]['runs']=2

# ===== 11-10 OWNER: "make options for all of those" (remaining weak spots), "make the legendaries", and look for gaps in the roster. =====
RV_NEW('Chuggamus','Teapotamus','final','tough',False,False,[
 "a huge steam hippo with nothing built on it: its purple-brown hide swells into a round boiler belly, two short horn-like chimneys of its own bone puff flat steam clouds from its back, its nostrils vent steam, thick natural legs, big tusks. Charging.",
 "a massive kettle hippo: the baby's round pot body grown into a great barrel-chested hippo with a curved spout-shaped horn on its nose and a handle-shaped crest of bone along its back, steam whistling from the horn. Planted, mouth open in a roar.",
 "a long locomotive hippo: body stretched like an engine, a row of small bone chimneys along its spine each puffing a flat steam ring, heavy rolling shoulders, glowing orange mouth. Walking forward."])
RV_NEW('Maracoil','Rattlebub','final','tough',False,False,[
 "a giant rattlesnake reared in a tall S with its head high, the same cream and orange diamond scales, its tail a big cluster of five maraca rattles like a bunch of fruit held above its head, a short crest of rattle beads along its neck, narrow fierce eyes and long fangs. No hood.",
 "a thick heavy viper lying in a tight spiral like a coiled drum, head resting on top, the same diamond pattern, with maraca rattles grown at intervals all along its body so the whole snake rattles. Half-lidded dangerous eyes.",
 "a two-rattled sidewinder mid-slither, body in three sharp diagonal waves across the picture, a maraca rattle at the tail and a second one on a horn-like stalk above its head, tongue flicking."])
RV_NEW('Rampartoad','Moatpole','mid','tough',False,False,[
 "a sturdy toad whose warty back has grown into a proper little castle wall with three square battlements and one round tower turret, moss in the cracks, the baby's sandy-tan skin darkened to moss green at the back, the same big yellow eyes. Mid-hop.",
 "a wide toad wearing its wall like a crown: a ring of stone battlements round its head and shoulders grown from its skin, a deep throat pouch puffed out like a drum, sandy and moss-green skin, yellow eyes. Sitting, croaking.",
 "a guard toad standing up on its hind legs behind a curved shield-wall of stone grown from its forearms, peeking over the top with big yellow eyes, moss on the stones."])
RV_NEW('Crofthollow','Crofthorn','final','majestic',False,True,[
 "a great highland bull, far bigger and older: its back carries a whole thatched croft with a round chimney puffing one flat smoke curl, a dry-stone wall running along its spine to the tail, ivy and wild roses on its huge sweeping horns, a long shaggy ginger coat to the ground. Planted, calm.",
 "an ancient cattle giant lying down like a hillside, the cottage and a small garden with a tree grown on its back, horns like old branches, a mossy face with gentle eyes. Massive and still.",
 "a rearing highland bull with horns grown into a tall arch like a gateway, thatch along its neck like a mane, stone wall plates down its back, ivy trailing from its horns."])
RV_NEW('Lanternlong','Lanterloris','final','pretty',False,True,[
 "a long graceful loris-dragon whose body is a string of five round paper lanterns from small to large, each glowing orange through the baby's cream fur, with the baby's round face and big brown eyes, long thin limbs, and a tassel tail. Climbing through the air.",
 "a tall slow loris standing upright, holding its own long tail like a lantern pole with three glowing lanterns hanging from it, a large lantern body, cream fur ruff, big calm eyes.",
 "a festival-dragon loris coiled in a ring, lantern segments all round the loop, face and big eyes at the front, tassels at each joint."])
# Knotwyrm sheet redo (views disagreed); portraits from the sheet for Canvastross and Mossbastion (theirs repeat the card).
SPECS.append({'id':'v2s_knotwyrm_fix','name':'Knotwyrm (sheet redo)','refs':['briefs/boki-art/cards/Knotwyrm.jpg'],'runs':3,'aspect':'16:9','size':'2K',
  'prompt':("Clean flat model sheet of exactly the creature in image 1: a rope snake tied in one big knot round a dark wooden post, lying on the ground. Exactly four views in one single row: front, three-quarter, side and back, "
   "all the same size, all showing the SAME pose as image 1: the same single knot, the same head resting low at one end, the same frayed dark tail raised at the other, the same moss and mushrooms. Do not stand it upright and do not change the knot. "
   "Model-sheet finish: "+LINE_V2+"Flat colour fills only, no shading. Background: one perfectly flat pale grey (#E8E8EE) and nothing else: no floor, no shadow, no text, no extra copies.")})
for _n,_st,_ar,_fu,_pose in (('Canvastross','final','majestic',True,"gliding side-on, facing RIGHT, wings stretched out flat to both sides like sails, legs tucked, mast feather streaming back"),
                             ('Mossbastion','final','majestic',False,"walking side-on, facing RIGHT, head turned toward the viewer, one front leg lifted")):
    _n0=len(SPECS); ON_POSE(_n,_LM[_n]['sheet'],_st,_ar,False,_fu,_pose+".",_KEEPALL); SPECS[_n0]['id']='v2p_'+_n.lower()+'_side'; SPECS[_n0]['runs']=3
# NEW LEGENDARIES (concepts; no reference image, the style is in words). 3 directions x 2 runs. ids leg_<idea>_<a|b|c>.
_LEGRULE=(" A legendary creature for a creature-collecting game: one single animal with one clear idea, every part grown from its own body (nothing built, worn, strapped or carried), "
          "grand and memorable, with an animal face. One creature only. ")
def LEG(idea,arch,dark,furry,opts):
    for _k,_d in zip('abc',opts):
        SPECS.append({'id':'leg_'+idea+'_'+_k,'name':'Legendary concept: '+idea+' '+_k,'refs':[],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':"Draw one single character illustration of a new creature: "+_d+_LEGRULE+"The art style is described in words below, follow it exactly. "+STYLE_V2('final',arch,dark,furry)+FRAME_V2.replace(" Crisp clean edges"," Crisp clean edges")})
LEG('lighthouse','majestic',False,True,[
 "a very tall white heron with red bands round its long neck like a lighthouse tower, its head crowned with a lantern-like crest of clear crystal feathers, one eye bright gold like a lamp, standing on one leg on nothing, wings folded.",
 "a great grey heron whose long neck spirals like a lighthouse stair, with a glowing pale-yellow eye and a cap-shaped crest, wings half open like a keeper's cloak, long legs planted wide.",
 "a stout pelican-heron with a tower-shaped body, a domed head crest that shines pale gold, a long beak, and banded white and navy plumage, calm and watchful."])
LEG('loom','creepy',True,True,[
 "a huge elegant spider with a patterned woven tapestry stretched between its two raised front legs, the cloth pattern grown from its own silk in deep red and gold, a furry indigo body, eight calm eyes.",
 "a great orb-weaver whose abdomen is shaped like a wound ball of thread in many colours, with shuttle-shaped leg tips and a half-woven web patterned like a carpet behind it.",
 "a tall spindly spider standing like a loom frame, its long legs the uprights, threads of gold silk running between them in neat rows, a small wise face with eight eyes."])
LEG('hourowl','majestic',False,True,[
 "an ancient owl whose body is shaped like an hourglass: a broad feathered chest narrowing to a tiny waist and widening again to its tail, with a band of pale gold sand-coloured feathers that seem to pour upward, huge round amber eyes, wings spread.",
 "a round old owl with clock-face rings in its eyes, feathers arranged like the numbers of a dial round its face, and long tail feathers shaped like two clock hands, perched and still.",
 "a tall horned owl with wings patterned like falling sand in bands of gold and brown, a narrow waist, and a pendulum-shaped tail feather, staring straight ahead."])
LEG('volcano','tough',True,False,[
 "a massive tortoise whose shell is a small volcano: a cone of dark basalt plates with a crater of flat orange lava at the top and three lava cracks running down, heavy clawed legs like rock, a blunt old face with ember-orange eyes.",
 "a broad snapping turtle with a shell of cooled black lava in hexagon columns and a glowing orange seam round its rim, a hooked beak, a spiked tail like a cooled lava flow.",
 "a giant tortoise rearing its head high, its shell a ring of five small smoking cones round a lava lake drawn as flat orange and yellow shapes, ash-grey skin, calm eyes."])
LEG('comet','sleek',False,True,[
 "a small swift fox mid-leap with midnight-blue fur and a white chest, its long tail a comet's trail drawn as three flat bands of pale blue, white and gold tapering to a point, a small star-shaped mark on its brow, bright silver eyes.",
 "a slim silver-white fox running, with two long tails streaming behind like a comet's twin tails, dark blue legs and ear tips, tiny flat star shapes in its tail fur.",
 "a little fox curled in mid-air like a falling star, deep violet fur, a blazing white-gold tail wrapped round it in a spiral, one eye open."])
LEG('bell','majestic',False,False,[
 "a long temple dragon whose body is a chain of seven great bronze bells from large to small, each bell a segment of its own bronze-scaled body with a green patina edge, a horned head with long whiskers, coiled upright.",
 "a wingless dragon with a single enormous bell-shaped chest and a clapper-shaped tail tip, bronze and jade-green scales, a mane of red, rearing with its mouth open as if ringing.",
 "a serpent dragon looped in a ring, small bells grown along its spine like a ridge, a broad bell-shaped frill behind its head, old bronze colour with gold inlay lines."])
LEG('blightmoth','creepy',True,True,[
 "a huge pale moth of the Blight: bone-white furry body, wings of deep purple-black with a skull-like eye pattern in bone white and a few violet vein lines, long feathery antennae, calm pinpoint eyes. Unsettling but beautiful.",
 "a great dark stag beetle of the Blight with antler-like jaws of bone white, a purple-black shell cracked with thin violet lines, small bone spurs along its legs, low and heavy.",
 "a tall thin heron-like Blight bird with purple-black feathers, a bone-white skull-shaped beak mask, long legs with bone spurs, and a ragged cloak of wing feathers, standing very still."])

# 11-10 OWNER: "Barostorm should have a small cat T1 evo". Kitten baby built from Barostorm's card (ids baby_barostorm_*). Whether it replaces
# Barokat (a meerkat) or sits before it is the owner's call.
for _k,_d in (('a',"a tiny round kitten sitting, with cream fur and pale blue swirl marks, one small puff of grey cloud fur between its ears like a tuft, a short tail with a tiny gold arrow tip, a small round dial mark on its chest, huge amber eyes."),
              ('b',"a small fluffy kitten mid-pounce, cream fur with pale blue swirls, a little grey cloud collar round its neck, tiny gold horn buds, a gold arrow-tipped tail held high, amber eyes."),
              ('c',"a sleepy kitten curled up with its tail round it, cream fur with pale blue swirl marks, a small grey cloud resting on its back like a blanket of its own fur, one amber eye open, a tiny dial mark on its flank.")):
    SPECS.append({'id':'baby_barostorm_'+_k,'name':'Barostorm baby kitten '+_k,'refs':[_C%'Barostorm'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the BABY form of the creature in image 1, clearly the same animal as a small kitten, with the same cream fur, pale blue swirl markings, grey storm-cloud fur and gold details in baby size: "+_d+" All parts are its own body. Ignore how image 1 is painted. "+_TXT+STYLE_V2('baby','cute',False,True)+FRAME_V2})

# ===== 11-10 OWNER: Crofthollow = 2nd (rv_crofthollow_b_1, lying like a hillside with the cottage and tree) -> live. Chuggamus = 2nd (b_1, the teapot
# idea) "but redo a bit more, it's a bit much". Legendaries: "they don't look nearly epic enough or distinctive; do a pass on the existing ones
# too, like the snake, which don't look legendary enough either".
_n0=len(SPECS); V2SHEET_NEW('Crofthollow','briefs/boki-art/cards/Crofthollow.jpg',_GC,_GN); V2PORT_NEW('Crofthollow','briefs/boki-art/cards/Crofthollow.jpg','final','majestic',_GC,_GN,False,True,"standing up on all four legs, side-on, the cottage and tree on its back tilting as it rises")
SPECS[_n0]['id']='v2s_crofthollow_b'; SPECS[_n0+1]['id']='v2p_crofthollow_b'; SPECS[_n0+1]['runs']=2
for _k,_d in (('t1',"tone it down: the big looping handle on its back becomes a low, thick, curved ridge of bone no taller than its ears, its nose horn becomes a short stubby spout-shaped horn with one small flat steam puff, and its body stays a plain round hippo in purple-brown. Keep its roar."),
              ('t2',"simplify it: remove the tall handle entirely; instead its tail curls up into a small handle-shaped loop, its nose has one short spout horn puffing a single steam curl, and its round belly has one pale band like a teapot's glaze line. Calmer face, mouth closed, standing."),
              ('t3',"make the teapot idea subtle: a round, heavy hippo with a small lid-shaped bump of bone on top of its head with a knob, a short spout horn on its snout, and a low curved back ridge; one small steam puff; purple-brown hide.")):
    SPECS.append({'id':'rv_chuggamus_'+_k,'name':'Chuggamus (teapot hippo, toned down '+_k+')','refs':[_O+'rv_chuggamus_b_1.jpg'],'runs':2,'aspect':'1:1','size':'2K','prompt':_EDIT+_d})
# LEGENDARY-GRADE look: allowed more than normal Boki. Used for an "epic pass" on existing legendaries and for new concepts.
_EPIC=(" LEGENDARY PRESENCE (the whole point): it is seen from a low angle so it towers over the viewer; its signature part is enormous and makes a silhouette no other creature has; "
       "it carries a second, brighter accent colour in bold flat shapes; behind its head or back its own body forms a crown, halo or fan shape; its pose is commanding and still, like a statue of a god. "
       "It may have up to three effects drawn as flat hard-edged shapes attached to its body. Rich, deep colours; nothing cute; no pink cheeks. ")
def EPIC(n,arch,dark,furry,opts,ref=None):
    for _k,_d in zip('ab',opts):
        SPECS.append({'id':'epic_'+n.lower()+'_'+_k,'name':n+' (legendary epic pass '+_k+')','refs':[ref or 'briefs/boki-art/cards/'+n+'.jpg'],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':"Draw one single character illustration of a far more legendary version of the creature in image 1: the same animal, idea and colours, redesigned to look like the rarest and most powerful creature in its world. THE DESIGN: "+_d+_EPIC+"Every part is grown from its own body. Ignore how image 1 is painted. "+_TXT+STYLE_V2('final',arch,dark,furry).replace(FX_V2,"")+FRAME_V2})
EPIC('Sarcobra','majestic',True,False,[
 "a colossal black cobra reared to full height, its hood spread into a vast golden sun-disc fan patterned like a pharaoh's collar in gold, lapis blue and turquoise, a crown crest on its head, coils stacked like the steps of a pyramid, eyes glowing gold.",
 "a great winged cobra: two huge golden falcon wings spread wide from behind its hood, a gold and blue striped hood like a royal headdress, its body rising from a spiral of coils, a forked tongue of gold, a small sun disc between two horn-like crests."])
EPIC('Pavonazar','majestic',False,True,[
 "a majestic peacock displaying a gigantic tail fan that fills the whole frame like a stained-glass window, each eye-feather a jewel in sapphire, emerald and gold, a tall crown crest, chest out, one foot raised.",
 "a celestial peacock with a tail that sweeps round it in a full ring like a halo, feathers tipped with star-shaped eyes in gold and violet, long trailing ribbons, a calm regal face."])
EPIC('Wayshell','majestic',False,False,[
 "an ancient sea turtle the size of an island, its shell a great golden compass rose with eight long points extending past the shell like a star, engraved map lines in teal across its flippers, a wise bearded face, swimming up toward the viewer.",
 "a towering turtle rearing its head high, its shell crowned with a ring of brass gear-teeth and a tall compass needle spire, star-map markings in gold on deep ocean-blue skin, heavy flippers planted."])
EPIC('Ghoulamari','creepy',True,False,[
 "a vast spectral octopus rising up, its mantle a tall crystal-ball dome with a swirling pale mist shape inside, eight long tentacles spread like a throne and ending in curled wisp tips, deep crimson and black with ghost-white accents, hollow glowing eyes.",
 "a giant octopus seated like a fortune-teller on its own coiled tentacles, two tentacles raised holding nothing, a huge luminous orb grown from its head, rows of pale rune-like sucker marks, a wide dark cloak of webbing between its arms."])
EPIC('Cetorgan','majestic',False,False,[
 "a gigantic whale breaching straight up, its back grown into a full cathedral pipe organ of silver pipes rising like a crown from head to tail, baleen like golden grilles, long fins like sweeping cloaks, deep blue with silver and gold.",
 "an immense whale seen from below gliding overhead, rows of tall silver organ pipes along both sides like wings, a gold keyboard-patterned jaw line, a tail like a great fan."])
EPIC('Glacione','pretty',False,False,[
 "a tall, serene frost sea angel, no longer a baby: a long translucent pale-blue body with a glowing silver heart shape inside, six wide wing-fins of clear ice spread like a seraph's, a crown of ice crystals, long trailing ribbons of frost. Calm, half-lidded eyes.",
 "an elegant ice spirit sea angel hovering with four great snowflake-shaped wings, a slim white body, a halo ring of ice shards behind its head, a tail like a long icicle veil."])
EPIC('Cindermaw','creepy',True,True,[
 "a huge Blight hyena-wolf standing over the viewer, its ribcage open and glowing violet between bone bars, a towering mane of black smoke-shaped fur with bone spines, a bone skull mask with long fangs, tail like a burning brand in violet and white.",
 "a gaunt giant Blight beast mid-howl, head thrown back, its whole back a ridge of tall bone spurs like a broken crown, violet fire shapes pouring from its jaws and eye sockets, long thin legs planted wide."])
# New legendary concepts, epic versions of the four ideas that worked, starting from my first-round picks.
EPIC('Cometfox','sleek',True,True,[
 "a comet fox as a celestial spirit: larger and leaner, with NINE comet tails fanned out behind it like a peacock display, each a band of white, pale blue and gold, a crescent crown mark on its brow, midnight-blue fur scattered with a few star shapes, standing on nothing, head high.",
 "a great star-fox leaping in an arc, its body trailing one enormous comet tail that curves all the way round it in a ring, a blazing white-gold chest, star-shaped eyes."],ref=_O+'leg_comet_a_1.jpg')
EPIC('Volcatoise','tough',True,False,[
 "a mountain-sized tortoise with a full erupting volcano for a shell, three peaks with flat lava rivers running down into channels along its legs, a crown of obsidian spikes round its head, a beard of cooled lava, eyes like embers.",
 "a titan tortoise rearing up on its hind legs, its volcano shell split open down the middle with a blazing orange core inside, basalt column plates on its limbs, a long neck with a ridge of black glass spines."],ref=_O+'leg_volcano_a_1.jpg')
EPIC('Lightheron','majestic',False,True,[
 "a towering lighthouse heron: an immensely long red-and-white banded neck rising like a tower, wings spread wide like a storm cloak in white and navy, its crystal head crest blazing with a fan of flat golden light beams, standing on one leg above crashing wave-curl shapes that are its tail feathers.",
 "a great beacon heron in flight seen from below, its eye a huge golden lamp, a crown of crystal lenses, wing feathers edged in gold like rays, long legs trailing."],ref=_O+'leg_lighthouse_a_2.jpg')
EPIC('Blightmoth','creepy',True,True,[
 "an enormous Blight moth with four wings spread, the pattern on its wings forming one huge staring eye in bone white and violet, a furred bone-white body with a ruff, antennae like great feathered horns, thin violet vein lines, long trailing wing tails.",
 "a moth empress of the Blight: tall, upright, wings folded round her like a hooded cloak of purple-black with bone-white edges, a crown of feathered antennae, six thin arms, a pale mask-like face with pinpoint eyes."],ref=_O+'leg_blightmoth_a_2.jpg')

# ===== 11-10 night OWNER: legendary picks (Comet fox = 2nd, Volcano tortoise = 2nd, Blight moth = 3rd, 1st on the others), "we need some more cute
# ones", Barostorm kitten = a new stage 1 (line of three), "for the issue ones and style inconsistency, fix all of them", rework a mushroom family,
# replace weak lines with missing animals. "Make a bunch of changes now."
# Live as cards: Wayshell (epic a_2), Ghoulamari (b_1), Cetorgan (a_1), Cindermaw (b_2), Chuggamus (t1_1), Rampartoad (b_2), Lanternlong (a_2).
# Sarcobra (b_1) and Pavonazar (b_1) were cut off by the frame -> zoomed-out redraws. New Boki cards saved, entries follow with their sets:
# Cometail (comet fox), Calderoise (volcano tortoise), Pharoheron (lighthouse heron), Palloth (Blight moth), Barokit (Barostorm's kitten).
for _n,_s in (('Sarcobra','epic_sarcobra_b_1'),('Pavonazar','epic_pavonazar_b_1')):
    SPECS.append({'id':'fit_'+_n.lower(),'name':_n+' (epic pick, whole creature in frame)','refs':[_O+_s+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':"Redraw the creature in image 1 exactly as it is, the same design, pose, colours, line and flat shading, but zoomed out so the WHOLE creature fits inside the picture: every wing tip, feather tip, coil and tail is complete and nothing touches or is cut by the edges, with about 10 percent empty margin on every side. "+FRAME_V2})
def SETOF(n,stage,arch,dark,furry,pose,tag):
    _n0=len(SPECS); V2SHEET_NEW(n,'briefs/boki-art/cards/'+n+'.jpg',_GC,_GN); V2PORT_NEW(n,'briefs/boki-art/cards/'+n+'.jpg',stage,arch,_GC,_GN,bool(dark),bool(furry),pose)
    SPECS[_n0]['id']='v2s_'+n.lower()+'_'+tag; SPECS[_n0+1]['id']='v2p_'+n.lower()+'_'+tag; SPECS[_n0+1]['runs']=2
for _a in (('Wayshell','final','majestic',0,0,"swimming up toward the viewer, flippers spread, compass shell tilted"),('Ghoulamari','final','creepy',1,0,"rising up, tentacles spread wide, orb glowing"),
           ('Cetorgan','final','majestic',0,0,"breaching, pipes fanned, jaw open"),('Cindermaw','final','creepy',1,1,"stalking forward, head low, bone ridge raised"),
           ('Chuggamus','final','tough',0,0,"charging, head down, steam puffing from its spout horn"),('Rampartoad','mid','tough',0,0,"mid-hop, wall crown bouncing"),('Lanternlong','final','pretty',0,1,"curled in a loose ring, lanterns glowing, looking at the viewer"),
           ('Cometail','final','sleek',1,1,"trotting on nothing, head turned to the viewer, comet tail arching overhead"),('Calderoise','final','tough',1,0,"head raised, roaring, lava cracks blazing"),
           ('Pharoheron','final','majestic',0,1,"standing on one leg, neck straight up like a tower, light beams fanned from its crest"),('Palloth','final','creepy',1,1,"hovering, wings half open, calm"),
           ('Barokit','baby','cute',0,1,"batting at its own cloud tuft with one paw")):
    SETOF(*_a,'n1')
# Epic pass for the other five legendaries, so all of them share the look.
EPIC('Aurostag','majestic',True,True,[
 "a towering stag whose antlers spread into a vast branching crown that fills the top of the frame, hung with ribbons of aurora light in green, violet and pink drawn as flat bands, a deep midnight coat with glowing vein lines, one hoof raised, head high.",
 "a great aurora stag rearing, antlers like a frozen river delta, a curtain of flat aurora bands falling from them like a cloak round its body, star marks on its flanks."])
EPIC('Sphinxblight','majestic',True,True,[
 "a colossal Blight sphinx-lion seated like a monument, wings raised straight up behind it like two blades, a mane of dark spines with violet light between them, a bone crown, one great paw forward, violet eyes.",
 "a winged Blight lion mid-roar on a ledge of nothing, wings spread to both edges, cracks of violet lightning shapes running through its body like veins, a ring of bone spurs round its neck like a collar grown from its hide."])
EPIC('Hydrangor','majestic',False,False,[
 "a towering hydrangea hydra with five long necks rising like a fountain, each head crowned with a great dome of blooms in a different colour, bodies wound together like a tree trunk, leaves like dragon wings spread behind, ancient calm eyes.",
 "a great hydra coiled round a mound of hydrangea blooms the size of a hill, seven heads fanned in a half circle like a peacock's tail, petals drifting as flat shapes attached to its mane."])
EPIC('Siegephant','majestic',False,False,[
 "a mountain of an elephant carrying an entire walled citadel on its back with a tall central keep and banners of its own ear-skin, four huge ram tusks banded with stone, a trunk like a drawbridge chain, amber eyes, seen from below.",
 "an ancient war-elephant rearing, its forehead grown into a great stone gate arch, towers rising from its shoulders, tusks crossed like gate bars, moss and cracks of amber light."])
EPIC('Glaciammoth','majestic',False,False,[
 "a colossal ice musk-ox seen from below, its single blade horn sweeping up like a frozen wave taller than its body, a curtain of icicle hair to the ground, a blazing amber heart shining through its chest, a crown of ice shards along its back.",
 "a glacier titan musk-ox walking, its back a jagged mountain range of ice with small frozen waterfalls, the blade horn like a ship's prow, amber light in its eyes and chest."])
# More CUTE legendaries (owner: only the ice one and the fox are cute). Small, charming, still unmistakably rare. No reference image.
for _i,_opts in (('cloverhare',["a small round hare with soft mint-green fur and enormous four-leaf-clover ears, each leaf a heart shape, a gold coin-shaped tail, tiny gold freckles, huge happy eyes, mid-hop.",
                                "a tiny sleepy leveret curled inside one giant four-leaf clover grown from its own back like a parasol, cream fur, gold nose, lucky horseshoe-shaped mark on its chest."]),
                 ('wishwren',["a tiny round wren with a music-box cylinder pattern down its chest in gold studs, a tail like a wind-up key grown of feathers, pastel blue and cream plumage, a single musical-note crest, singing.",
                              "a very small plump songbird whose wings are shaped like two halves of a locket heart, rose-gold and cream feathers, a keyhole mark on its chest, big shy eyes."]),
                 ('starpup',["a small fluffy white pup with a star-shaped tail tip and star marks on its paws, a crescent mark on its forehead, pale gold ears, floating a little above the ground, tongue out.",
                             "a tiny round seal-pup-like star cub with five stubby limbs like a starfish, cream and pale gold, a glowing soft star on its belly, big dark eyes."])):
    for _k,_d in zip('ab',_opts):
        SPECS.append({'id':'leg_'+_i+'_'+_k,'name':'Cute legendary concept: '+_i+' '+_k,'refs':[],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':"Draw one single character illustration of a new creature: "+_d+" A rare, cute legendary creature for a creature-collecting game: one single small animal with one clear idea, every part grown from its own body, with an animal face. One creature only. The art style is described in words below, follow it exactly. "+STYLE_V2('baby','cute',False,True)+FRAME_V2})

# ----- Lines with no idea behind them: each gets ONE object idea that grows through the stages (same animal, colours and face). 3 runs per stage, ids idea_<name>.
def IDEA(n,stage,arch,dark,furry,text):
    ON_CHANGE(n,'briefs/boki-art/cards/'+n+'.jpg',stage,arch,dark,furry,text,runs=3,tag='_idea'); SPECS[-1]['id']='idea_'+n.lower()
# Rimekit line = SNOW GLOBE
IDEA('Rimekit','baby','cute',False,True,"it is a snow-globe creature: the same round white ice kit, with a small clear dome of ice grown on its back like a snow globe, a tiny pine-tree-shaped crystal and three snowflake shapes inside it. Sitting.")
IDEA('Rimeshrew','mid','cute',False,True,"it is a snow-globe creature: the same white ice shrew, its ice shell now a big clear globe dome with a little frozen village shape and swirling snowflake shapes inside, a ring-shaped base of blue ice round the dome. Trotting.")
IDEA('Rimefang','final','tough',False,True,"it is the final snow-globe beast: a big white frost wolf-shrew carrying a great cracked globe dome on its back with a whole blizzard inside drawn as flat swirl shapes and a small mountain crystal, shards of the dome forming its back spikes, simple clean fur with a few big clumps instead of dense swirls. Planted.")
# Kindlewren line = MATCHSTICK / CANDLE / LIGHTHOUSE-less: a MATCH that becomes a TORCH that becomes a BONFIRE crow
IDEA('Kindlewren','baby','cute',True,True,"it is a matchstick bird: the same small charcoal wren with a rounded red match-head crest on top of its head and one tiny flat flame on its tail tip, a pale wood-coloured beak and legs like matchsticks. Perched.")
IDEA('Embrook','mid','tough',True,True,"it is a torch bird: the same charcoal rook with a tall torch-shaped head crest burning in flat orange and yellow flame shapes, wing feathers like charred kindling sticks with glowing orange tips. Mid-leap.")
IDEA('Pyrraven','final','creepy',True,True,"it is a bonfire raven: the same great black raven whose body is built like a stacked bonfire, crossed log-shaped feathers on its chest glowing orange between them, a crown of flame shapes rising from its back, bone-white skull mask kept. Wings folded like a cloak.")
# Nettlynx line = TOPIARY (clipped hedge)
IDEA('Nettlynx','baby','cute',False,True,"it is a topiary kitten: the same small tan lynx kit with its leaf ears and tail tip clipped into neat round topiary balls, like a little trimmed hedge. Sitting.")
IDEA('Thistlynx','mid','sleek',False,True,"it is a topiary lynx: the same tan lynx with a mane and tail of green hedge clipped into neat geometric shapes, a spiral-clipped tail and a cone on each ear, one purple thistle flower on its chest. Prowling.")
IDEA('Briarlynx','final','tough',False,True,"it is a grand hedge-maze lynx: the same big brown lynx whose bramble mane is a clipped hedge with a maze pattern of paths cut into it across its shoulders and back, rose blooms at the corners, thorn antlers kept. Planted.")
# Lunafin line = MOON PHASES
IDEA('Selenfin','baby','cute',False,False,"it shows the moon's phases: the same round pale moonfish with a thin crescent-shaped body marking and a single row of four small moon-phase marks along its side from new to half. Swimming.")
IDEA('Selenwhale','final','majestic',False,False,"it shows the moon's phases: the same great pale whale with a row of eight moon-phase discs along its side from new moon to full and back, a full-moon dome on its brow, and a tail fluke shaped like two crescents. Breaching.")
# Blotlet line = INK (inkwell, blot, printing press)
IDEA('Blotlet','baby','cute',True,False,"it is an ink creature: the same small black blob sitting in a little round inkwell shape made of its own darker body, with a quill-feather-shaped curl on its head. Purple eyes.")
IDEA('Slog','mid','creepy',True,False,"it is an ink creature: the same dark slug whose back is covered in rows of raised letter-shaped bumps like metal type, leaving no trail, with three eye stalks. One solid body, no drips.")
IDEA('Sloggoth','final','creepy',True,False,"it is the final ink beast: the same hulking dark creature with a broad flat chest like a printing plate covered in rows of raised type shapes, roller-shaped forearms, and a mane of curled paper-ribbon shapes in off-white. Sitting heavy.")
# Kayak line = make the BOAT visible
IDEA('Kayak','baby','cute',False,True,"it is a boat creature: the same fluffy white yak calf with a little kayak-shaped saddle ridge of blue ice grown along its back and two small paddle-shaped horns. Standing.")
IDEA('Prowyak','mid','cute',False,True,"it is a boat creature: the same white yak with a bony ship's prow grown forward from its face like a figurehead, horns swept back like oars, and a keel-shaped ridge of ice down its chest. Trotting.")
IDEA('Dreadnoyak','final','tough',False,True,"it is a warship creature: the same huge frost yak with a hull-shaped chest of blue ice like an icebreaker's bow, two rows of round ice portholes along its flanks, tusks like anchors, and tall ice smokestack horns. Planted, whole body in view.")
# Singles
IDEA('Zephyrak','final','majestic',False,False,"it is a weather-vane serpent: the same teal and white wind serpent, simplified to a few big clean shapes, with a tail tip shaped like a weather vane's arrow, a head crest shaped like a rooster comb, and four small compass-point fins along its body. One loose open S-curve.")
IDEA('Hivara','final','sleek',False,False,"it is a honeycomb accordion wasp: the same amber wasp-mantis drawn in the flat cartoon style with a big simple face, its abdomen a stretchy accordion bellows of honeycomb cells, two fold-out comb-shaped wings. Rearing.")
# Pebblamb gets an evolution (owner: "should probably get a T2, something interesting"): the pebble wool becomes a rock garden.
for _k,_d in (('a',"a calm grown ram whose pebble wool has become a Japanese rock garden: its back is a flat bed of pale raked-sand ripples with three large mossy stones, big curled horns of polished river stone, soft sage-green and cream. Standing still."),
              ('b',"a sturdy ram whose wool is a stack of balanced river stones along its back like a row of cairns, largest at the shoulders, horns shaped like skipping-stone spirals, grey-blue and cream. Walking."),
              ('c',"a round heavy ewe with wool of big smooth pebbles in a mosaic pattern of blue, grey and cream like a pebble path, a horn crown of stacked stones, a tail like a rolling boulder. Sitting.")):
    SPECS.append({'id':'evo_pebblamb_'+_k,'name':'Pebblamb evolution '+_k,'refs':[_C%'Pebblamb'],'runs':2,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the EVOLVED form of the lamb in image 1, clearly the same animal grown up with the same face and colours: "+_d+" All parts are its own body. Ignore how image 1 is painted. "+_TXT+STYLE_V2('final','majestic',False,True)+FRAME_V2})
# One mushroom family fewer: Fawnshroom > Hatstag becomes a HAT line (the name already says it): caps become hat shapes of velvet and horn.
IDEA('Fawngus','baby','cute',False,True,"it is a hat creature, not a mushroom one: the same little fawn, with its two big cap ears reshaped into one soft beanie-shaped tuft of velvet between small ear nubs. No mushrooms.")
IDEA('Hatstag','final','majestic',False,True,"it is a hat-stand stag, not a mushroom one: the same tall stag whose branching antlers end in different hat-shaped tips of velvet and horn (a top hat, a bowler, a beret, a wide brim), with a ruff like a scarf of its own fur. No mushrooms.")
# Style outlier: Glassolotl's line is much thinner and paler than the rest.
SPECS.append({'id':'line_glassolotl','name':'Glassolotl (line weight to match the roster)','refs':['briefs/boki-art/cards/Glassolotl.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"redraw its outline in the same bold, even line as a flat cel-shaded cartoon: a clear dark rose-plum silhouette line, thinner inner lines, and flat pastel fills with one hard shade. It stays translucent-looking through colour, not through faint lines."})
# Jerbolt: new pose (owner).
for _k,_p in (('a',"mid-leap high off its coiled spring legs, body stretched in an arc, facing RIGHT, static fur crest standing on end, tail whipping"),('b',"crouched low on all fours, facing LEFT, ears flat, about to spring, fur crest bristling like a brush")):
    _n0=len(SPECS); ON_POSE('Jerbolt',_LM['Jerbolt']['sheet'],'mid','sleek',False,True,_p+".",_KEEPALL); SPECS[_n0]['id']='pose2_jerbolt_'+_k; SPECS[_n0]['runs']=2
# NEW LINES from animals the roster lacks: babies first (2 directions x 2 runs, no reference); later stages are built from the picked baby.
for _i,_opts in (('pinguin',["a round penguin chick shaped like a bowling pin: white body with two red neck stripes, tiny flippers, a wobble, big eyes.","a chubby penguin chick with a glossy black round belly like a bowling ball with three finger-hole spots, short neck, proud stance."]),
                 ('sawshark',["a small cute sawshark pup whose long nose is a little wood file with tiny teeth, sandy-brown and cream like sanded wood, a pencil-shaped tail fin.","a tiny round shark pup with a nose shaped like a carpenter's plane, wood-grain stripes down its back, a curl of wood shaving on its head."]),
                 ('postroo',["a small joey with a round red body, a letter-slot-shaped pouch across its belly, stamp-shaped ears with scalloped edges, big feet.","a tiny kangaroo joey shaped like a little brown parcel with string-patterned fur markings, a postage-stamp tail tip, peeking eyes."]),
                 ('xylocroc',["a small crocodile hatchling whose back scutes are five flat coloured bars like a toy xylophone from long to short, a round mallet-shaped tail tip, a big grin.","a tiny round croc hatchling with rainbow bar scales down its back and a rattle-shaped tail, sitting upright."]),
                 ('carousel',["a small foal with a pastel cream and pink coat, a short twisted candy-stripe horn like a carousel pole on its forehead, a scalloped canopy-shaped mane, mid-prance.","a tiny round pony foal with a gold spiral pole-shaped tail, a ribbon-striped mane, painted-looking rosy cheeks, one hoof raised."])):
    for _k,_d in zip('ab',_opts):
        SPECS.append({'id':'new_'+_i+'_'+_k,'name':'New line baby: '+_i+' '+_k,'refs':[],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':"Draw one single character illustration of a new creature: "+_d+" A baby creature for a creature-collecting game: one single small animal with one clear idea, every part grown from its own body (nothing built, worn or carried), with an animal face. One creature only. The art style is described in words below, follow it exactly. "+STYLE_V2('baby','cute',False,False)+FRAME_V2})

# ===== 11-10 late: picks from the big round are live as cards (list in CHANNEL). Sets for all of them; generic pose wording, since the card stays the hero.
_GP="in a clearly different pose from image 1, turned to face the other way, caught mid-movement"
_R4={'Sarcobra':('final','majestic',1,0),'Pavonazar':('final','majestic',0,1),'Aurostag':('final','majestic',1,1),'Sphinxblight':('final','majestic',1,1),'Hydrangor':('final','majestic',0,0),
 'Siegephant':('final','majestic',0,0),'Glaciammoth':('final','majestic',0,0),'Rimekit':('baby','cute',0,1),'Rimeshrew':('mid','cute',0,1),'Rimefang':('final','tough',0,1),
 'Kindlewren':('baby','cute',1,1),'Embrook':('mid','tough',1,1),'Pyrraven':('final','creepy',1,1),'Nettlynx':('baby','cute',0,1),'Thistlynx':('mid','sleek',0,1),'Briarlynx':('final','tough',0,1),
 'Selenfin':('baby','cute',0,0),'Selenwhale':('final','majestic',0,0),'Blotlet':('baby','cute',1,0),'Slog':('mid','creepy',1,0),'Sloggoth':('final','creepy',1,0),'Kayak':('baby','cute',0,1),
 'Dreadnoyak':('final','tough',0,1),'Zephyrak':('final','majestic',0,0),'Hivara':('final','sleek',0,0),'Glassolotl':('mid','pretty',0,0),'Luckhop':('baby','cute',0,1)}
for _n,(_st,_ar,_dk,_fu) in _R4.items(): SETOF(_n,_st,_ar,_dk,_fu,_GP,'r4')
_n0=len(SPECS); V2SHEET_NEW('Jerbolt','briefs/boki-art/cards/Jerbolt.jpg',_GC,_GN); SPECS[_n0]['id']='v2s_jerbolt_r4'
_n0=len(SPECS); V2SHEET_NEW('Rampartoad','briefs/boki-art/cards/Rampartoad.jpg',_GC,_GN); SPECS[_n0]['id']='v2s_rampartoad_r4'
# Pebblamb's evolution (pick a_1, the rock-garden ram) and the five new lines: later stages built FROM the picked baby, 3 runs each.
def NEXT(idn,baby_stem,stage,arch,text):
    SPECS.append({'id':idn,'name':idn,'refs':[_O+baby_stem+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':"Draw one single character illustration of the "+("MIDDLE" if stage=='mid' else "FINAL")+" evolution of the creature in image 1, clearly the same animal grown up with the same colours, face and idea: "+text+" Every part is grown from its own body: nothing built, worn, tied on or carried. Draw it exactly the way image 1 is drawn. "+STYLE_V2(stage,arch,False,False)+FRAME_V2})
NEXT('new_pinguin_mid','new_pinguin_a_1','mid','cute',"a bigger penguin with a round, glossy black belly like a bowling ball with three round spots like finger holes, the same red neck stripes, sliding forward on its belly.")
NEXT('new_pinguin_final','new_pinguin_a_1','final','tough',"a tall proud emperor penguin with a crown of ten small pin-shaped crest feathers fanned on its head like a rack of pins, red neck stripes grown into a chest band, a round ball-shaped belly, one flipper swung back like a bowler mid-throw.")
NEXT('new_sawshark_mid','new_sawshark_a_2','mid','sleek',"a sleek young sawshark with a longer, sharper saw nose, wood-grain stripes along its back, a dorsal fin shaped like a set-square, swimming fast.")
NEXT('new_sawshark_final','new_sawshark_a_2','final','tough',"a great sawshark with a long two-edged saw blade nose, a back fin like a plane's handle, a broad chisel-shaped tail fin, sanded-wood colours with dark grain lines, a calm craftsman's stare.")
NEXT('new_postroo_mid','new_postroo_a_2','mid','cute',"a young kangaroo standing upright, the same red coat, a wider letter-slot pouch with a small joey's ears peeking out, stamp-edged ears, a tail tip shaped like an envelope flap, mid-hop.")
NEXT('new_postroo_final','new_postroo_a_2','final','tough',"a big strong kangaroo built like a pillar postbox: a tall rounded red body with a domed head crest like a postbox cap, a wide letter-slot pouch, heavy stamping feet, stamp-edged ears, arms crossed.")
NEXT('new_xylocroc_mid','new_xylocroc_a_2','mid','sleek',"a longer young crocodile with eight coloured xylophone-bar scutes down its back from long to short, two mallet-shaped tail tips, mid-stride, grinning.")
NEXT('new_xylocroc_final','new_xylocroc_a_2','final','tough',"a huge crocodile with a double row of big tuned bar scutes down its back in deep rainbow colours, jaws lined with teeth like piano keys, a heavy mallet tail raised to strike its own back, planted.")
NEXT('new_carousel_mid','new_carousel_a_2','mid','pretty',"a prancing young horse with a taller twisted candy-stripe horn, a scalloped canopy mane in pink and cream, a ribbon tail, gold hoof tips, one foreleg raised.")
NEXT('new_carousel_final','new_carousel_a_2','final','majestic',"a grand stallion whose mane spreads into a full round carousel canopy over its back with small lantern-shaped tufts round the rim, a long twisted gold-and-pink pole horn, a streaming ribbon tail, rearing.")

# 11-10 OWNER: "Briarlynx's fur colour is a bit too different from its line" (it is dark brown; Nettlynx and Thistlynx are warm tan).
SPECS.append({'id':'fur_briarlynx','name':'Briarlynx (fur matches its line)','refs':['briefs/boki-art/cards/Briarlynx.jpg','briefs/boki-art/cards/Thistlynx.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"recolour its fur to the same warm sandy-tan as the lynx in image 2, with the same cream muzzle, chest and paws and the same green eyes, in place of the dark brown. Take only the fur colours from image 2. Its body, hedge-maze mane, roses, thorn antlers and pose stay exactly the same."})

# 11-10 OWNER: Briarlynx fur -> tan like its line (fur_briarlynx_1, live). Pebblamb's evolution = the pebble MOSAIC ewe (evo_pebblamb_c_1), named
# Tesselamb; he does not want more "rocks/trees on a creature" designs (we have many). The not-changed ones stay not changed (Prowyak, Fawnshroom line).
# More cute legendaries are welcome: Twinklup (star pup, leg_starpup_a_2) and Lockwren (locket bird, leg_wishwren_b_2) join Luckhop.
SPECS[:]=[s for s in SPECS if s['id'] not in ('v2s_briarlynx_r4','v2p_briarlynx_r4')]
for _a in (('Briarlynx','final','tough',0,1,_GP),('Tesselamb','final','majestic',0,1,"standing up and walking, head turned to the viewer"),('Twinklup','baby','cute',0,1,"rolling on its back, paws up, star tail wagging"),('Lockwren','baby','cute',0,1,"fluttering just off the ground, wings open like a locket")):
    SETOF(*_a,'r5')

# ===== 11-10 OWNER: "not all these legendaries are clearly legendary: they need something that makes them clearly unique, even as cute Boki".
# A shared LEGENDARY MARK that every legendary carries, cute or epic, so the tier reads at a glance. Two candidate marks, tried on the seven weakest
# (ids mark_<name>_<h|s>, 2 runs each). h = halo crown, s = star mark and gold. The owner picks one mark; then all 19 get it.
_MARKS={'h':"give it the mark every legendary creature has: a HALO CROWN, a ring shape floating just behind and above its head, made of the same material as its own signature part (leaves, ice, feathers, flame, stone), with five small points on the ring; plus thin gold line markings on its brow and limbs, and eyes whose white highlight is a four-point star shape.",
        's':"give it the mark every legendary creature has: a glowing four-point STAR MARK on its forehead in pale gold, the same star shape repeated small on its chest, gold tips on its ears, horns, wings or tail, and three small pieces of its own element (leaves, ice shards, sparks, embers, feathers) floating in a slow ring round its body."}
for _n in ('Luckhop','Twinklup','Lockwren','Glacione','Cometail','Calderoise','Palloth'):
    for _k,_t in _MARKS.items():
        SPECS.append({'id':'mark_'+_n.lower()+'_'+_k,'name':_n+' (legendary mark '+_k+')','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':_EDIT+_t+" It stays the same creature in the same pose, as cute or as fierce as it is now, and the whole creature with its mark fits inside the frame."})

# ===== 11-10 OWNER: "go with all the first / your choices". LEGENDARY MARK = the HALO CROWN, on all 19 legendaries. Live on Luckhop, Twinklup, Lockwren,
# Glacione, Cometail, Calderoise. Queued for the other 13 (ids halo_<name>, 3 runs). Palloth gets a brighter ring.
_HALO=(_MARKS['h']+" The ring is NOT metal jewellery: it is made of the creature's own material and floats, touching nothing. If the creature already has a crown, halo or fan shape behind its head, turn that into this ring. "
       "It stays the same creature in the same pose, and the whole creature with its ring fits inside the frame with empty margin on every side.")
for _n in ('Sarcobra','Pavonazar','Wayshell','Ghoulamari','Cetorgan','Cindermaw','Aurostag','Sphinxblight','Hydrangor','Siegephant','Glaciammoth','Pharoheron'):
    SPECS.append({'id':'halo_'+_n.lower(),'name':_n+' (legendary halo crown)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K','prompt':_EDIT+_HALO})
SPECS.append({'id':'halo_palloth','name':'Palloth (legendary halo crown, bright)','refs':['briefs/boki-art/cards/Palloth.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+_HALO+" On this dark creature the ring is bright bone-white with five small violet points, clearly visible above its head against the pale background."})
# NEW LINES. Penguin and sawshark are added now (cards saved: Pinguin > Rollguin > Kingpinguin, Filefin > Carpenjaw > Sawright). The other three get
# better MIDDLE stages first (the first tries were the baby again), and the kangaroo baby is redrawn so it reads as a kangaroo.
for _a in (('Pinguin','baby','cute',0,0,"waddling, flippers out, wobbling like a pin about to fall"),('Rollguin','mid','cute',0,0,"sliding forward on its round belly"),('Kingpinguin','final','tough',0,0,"mid-throw, one flipper swung forward"),
           ('Filefin','baby','cute',0,0,"swimming in a little loop, nose up"),('Carpenjaw','mid','sleek',0,0,"darting forward, saw nose slicing"),('Sawright','final','tough',0,0,"turning in a slow arc, saw nose raised")):
    SETOF(*_a,'nl')
SPECS.append({'id':'new_postroo_baby2','name':'Postbox kangaroo baby (reads as a kangaroo)','refs':[_O+'new_postroo_a_2.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':"Draw one single character illustration of a baby kangaroo in exactly the colours and finish of image 1: the same postbox-red fur, cream belly, big stamp-edged ears and letter-slot-shaped pouch. But it is clearly a little KANGAROO: a small head with a soft muzzle, short front paws held up, big long hind feet, and a thick tail it leans on. Sitting upright, cute. "+STYLE_V2('baby','cute',False,True)+FRAME_V2})
NEXT('new_xylocroc_mid2','new_xylocroc_a_2','mid','sleek',"a young crocodile twice the baby's length, long and low with a narrower snout and real teeth showing, eight xylophone bars down its back, its tail split into two mallet tips held up over its back like drumsticks, mid-stride. Not round and not baby-faced.")
NEXT('new_carousel_mid2','new_carousel_a_2','mid','pretty',"a leggy young horse, twice the foal's height with long slim legs and a longer neck, its canopy mane grown into two scalloped tiers down its neck, a longer twisted striped horn, a long ribbon tail, cantering. Not chubby and not baby-faced.")

# 11-10: halo crown live on all 19 legendaries. Three more new lines saved as cards: Stamproo > Postroo > Pillaroo (postbox kangaroo),
# Xylogator > Marimbite > Glockodile (xylophone crocodile), Foalaround > Canopony > Carrousteed (carousel horse). Sets for the new lines and for
# the legendaries whose card changed with the halo (sheet + portrait must show it too).
for _a in (('Stamproo','baby','cute',0,1),('Postroo','mid','cute',0,1),('Pillaroo','final','tough',0,1),('Xylogator','baby','cute',0,0),('Marimbite','mid','sleek',0,0),('Glockodile','final','tough',0,0),
           ('Foalaround','baby','cute',0,1),('Canopony','mid','pretty',0,1),('Carrousteed','final','majestic',0,1)): SETOF(*_a,_GP,'nl')
for _n in ('Sarcobra','Pavonazar','Wayshell','Ghoulamari','Cetorgan','Cindermaw','Aurostag','Sphinxblight','Hydrangor','Siegephant','Glaciammoth','Pharoheron','Palloth','Luckhop','Twinklup','Lockwren','Glacione','Cometail','Calderoise'):
    _st,_ar,_dk,_fu=_R4.get(_n,('final','majestic',0,0)) if _n in _R4 else (('baby','cute',0,1) if _n in ('Luckhop','Twinklup','Lockwren','Glacione') else ('final','majestic',0,0))
    SETOF(_n,_st,_ar,_dk,_fu,_GP+", its halo ring floating above its head",'halo')

# ===== 11-10 night OWNER: "change a mushroom family to something else, run a bunch of options. No camel. Review everything again and try alts for
# the ones you think need it." Fourth pass over all 259.
# GLOMWORT > GLOMBULUS stops being a mushroom line: same mustard-yellow blob creature and face, new idea. 4 ideas x (baby, final) x 2 runs. ids glom_<idea>_<b|f>.
_GL={'honey':("a honey creature: a round amber-gold blob of honey with a small dipper-shaped curl on its head and a few hexagon honeycomb cells showing through its back, a drip-shaped tail",
              "a great honey beast: a tall heap of amber honey with big honeycomb plates along its back, two dipper-spiral horns, a wide happy grin, and thick slow arms of honey, all one body"),
     'wax':("a candle-wax creature: a round cream-yellow blob of soft wax with a tiny wick curl on its head and two melted drips down its sides like little arms",
            "a great wax beast: a towering heap of layered melted wax in cream and mustard with three wick horns (no flames), drip-shaped fringes all round, and a calm sleepy face"),
     'paint':("a paint creature: a round blob of thick yellow paint with a swirl of two other colours (teal and coral) folded into its back like marbling, a brush-tip-shaped tail",
              "a great paint beast: a tall swirling heap of thick paint in marbled yellow, teal, coral and violet bands, with a broad brush-stroke crest and big splat-shaped paws"),
     'custard':("a pudding creature: a wobbly round custard blob with a darker caramel top like a cap of its own body and a little curl like whipped cream, mid-jiggle",
                "a great pudding beast: a tall tiered wobbling custard with a glossy caramel crown running down in three points, a wide grin, short stout legs")}
for _k,(_b,_f) in _GL.items():
    ON_CHANGE('Glomwort',_C%'Glomwort','baby','cute',False,False,"the same small mustard-yellow blob creature with the same face, eyes and stubby legs, but it is no longer a mushroom creature: no mushrooms anywhere. It is "+_b+".",runs=2,tag='_x'); SPECS[-1]['id']='glom_'+_k+'_b'
    ON_CHANGE('Glomworth',_C%'Glomworth','final','creepy',False,False,"the same big yellow blob creature with the same face and eyes, but it is no longer a mushroom creature: no mushrooms anywhere and no drips falling off it. It is "+_f+".",runs=2,tag='_x'); SPECS[-1]['id']='glom_'+_k+'_f'
# ALTS for designs that read as worn or built after the last round (edits of the live card, 3 runs each; ids alt_<name>).
def ALT(n,text): SPECS.append({'id':'alt_'+n.lower(),'name':n+' (alt)','refs':['briefs/boki-art/cards/'+n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K','prompt':_EDIT+text})
ALT('Kindlewren',"the red cap on its head reads as a beret: replace it with a small rounded crest of red-tipped feathers shaped like a match head, clearly growing from its head feathers, the same red.")
ALT('Blotlet',"it sits in a pot that looks like a separate object: remove the pot. It is one round black ink-drop body sitting on the ground, with a wider, flatter base like a blot, keeping the quill-shaped curl on its head.")
ALT('Sloggoth',"its arms end in roller drums and it has tank-like treads, which look built: its forearms become thick, heavy arms of the same dark ink body with broad flat paws, and its lower body is a plain heavy seated mass. It keeps the raised letter shapes on its chest and the paper-curl mane.")
ALT('Dreadnoyak',"it looks built: remove the smoking chimneys, the smoke and the anchor. Its horns are tall, plain ice horns swept back, its chest is a broad wedge of blue ice like an icebreaker's bow, and one row of round frost marks runs along its flank.")
ALT('Kingpinguin',"the pins on its head read as a headdress: replace them with a tall natural penguin crest of white feathers tipped red, like a rockhopper's, fanned in a row of ten. Everything else stays the same.")
ALT('Pillaroo',"it reads as a postbox, not an animal: give it a real kangaroo head with a longer muzzle, a clear neck, strong hind legs and a thick tail it leans on, and remove the postbox cap from its head, replacing it with a small rounded tuft of red fur. It keeps its red coat, stamp-edged ears and letter-slot pouch.")
ALT('Tesselamb',"the stack of flat stones on its head reads as a hat: remove it, leaving a soft tuft of pebble wool between its ears.")
# Sawshark line: all three stages swim the same way. New pose for the final.
_n0=len(SPECS); ON_POSE('Sawright',_LM['Sawright']['sheet'] if 'Sawright' in _LM else 'briefs/boki-art/cards/Sawright.jpg','final','tough',False,False,"breaching straight up, body vertical, saw nose pointing to the sky, tail curled, seen from the side facing LEFT.",_KEEPALL); SPECS[_n0]['id']='alt_sawright_pose'

# 11-10 fourth-review picks live (they only remove worn or built-looking parts): Kindlewren (comb crest, not a beret), Blotlet (no pot), Dreadnoyak (no
# chimneys, smoke or anchor), Pillaroo (real kangaroo head and legs), Tesselamb (no stone hat), Sawright (breaching pose). Sets from the new cards.
for _a in (('Kindlewren','baby','cute',1,1),('Blotlet','baby','cute',1,0),('Dreadnoyak','final','tough',0,1),('Pillaroo','final','tough',0,1),('Tesselamb','final','majestic',0,1),('Sawright','final','tough',0,0)): SETOF(*_a,_GP,'r6')
# Second tries where the alt failed: Kingpinguin's alt became a feathered war bonnet (rejected), Sloggoth's kept its treads.
ALT('Kingpinguin',"remove everything from the top of its head: it has a smooth round penguin head with two long yellow-and-red brow plumes sweeping back, like a macaroni penguin. Its bowling idea is carried by its body instead: a white chest with a red band and three dark round spots on its belly like a bowling ball's finger holes."); SPECS[-1]['id']='alt2_kingpinguin'
ALT('Sloggoth',"its lower body must not look like a machine: remove the tank treads and roller drums completely. It sits on a broad, smooth, heavy slug-like base of its own dark body, with two thick soft arms ending in round paws. It keeps the raised letter shapes on its chest and its curled paper-ribbon mane."); SPECS[-1]['id']='alt2_sloggoth'

# ===== 11-10 OWNER: Glomwort line = my pick (PAINT; glom_paint_b_1 / glom_paint_f_1 live). "Do a full review again and look for style breaks / any
# other issues." Fifth pass = a MEASURED AUDIT of every card, sheet, portrait and hero (outline weight, soft shading, detail density, backdrop, cropping,
# sheet view count, hero holes), then the flagged ones by eye. Found and fixed here:
# (a) cards still drawn softer, glossier or more realistic than the roster -> same design, redrawn in the house style (ids sty_<name>, 3 runs).
for _n,_st,_ar,_dk,_fu,_fx in (('Scoopsy','baby','cute',0,1,"a bold dark outline like the rest of the roster; flat fills"),('Spanglin','baby','cute',0,0,"a bold dark outline; each mirror tile one flat pale shape"),
    ('Pinster','baby','cute',0,0,"no chrome gloss or reflections: flat silver-grey plates with one lighter band each"),('Harvantis','final','sleek',0,0,"flat cartoon finish, a simpler friendlier insect face with big eyes"),
    ('Chainipede','final','creepy',1,0,"no dripping venom at all; flat fills; chain links drawn as a few big simple shapes"),('Moundlet','baby','cute',0,0,"drawn larger in the frame, with a bold dark outline"),
    ('Lyrewing','final','majestic',0,1,"a bolder outline and flat fills; about eight harp strings per wing")):
    SPECS.append({'id':'sty_'+_n.lower(),'name':_n+' (house style)','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K','prompt':RS_CARD_TEXT(_n,_st,_ar,_GC,_GN,bool(_dk),bool(_fu),_fx)})
# (b) too much fine detail for the style / a human face.
ALT('Terrasloth',"its scales carry far too much tiny painted detail: each scale becomes one plain pale cream shape with a single small green leaf mark, and only every third scale has a pink dot. About twenty big scales, bold outline. Same pose and face."); SPECS[-1]['id']='sty_terrasloth'
ALT('Bonsolith',"its scales carry far too much tiny painted detail: each scale becomes one plain pale cream-green shape, with about twenty big scales and a simple blossom tree drawn as five pink flower clusters. Bold outline. Same pose and face."); SPECS[-1]['id']='sty_bonsolith'
ALT('Mortarfly',"its face is a human face, which breaks the rule that every creature has an animal face: give it a moth's face, a rounded furry marble-white head with two large gold compound eyes and feathery gold antennae. Its wings become simpler: clean marble panels in a gold frame with a few bold lines. Same pose."); SPECS[-1]['id']='sty_mortarfly'
# (c) sheets: Spirevark and Pagoguana show three views, Snapler has a ground line.
for _n in ('Spirevark','Pagoguana','Snapler'):
    _n0=len(SPECS); V2SHEET_NEW(_n,'briefs/boki-art/cards/'+_n+'.jpg',_GC,_GN); SPECS[_n0]['id']='v2s_'+_n.lower()+'_fix5'
# sets for this round's new cards
for _a in (('Glomwort','baby','cute',0,0),('Glomworth','final','creepy',0,0),('Kingpinguin','final','tough',0,0),('Sloggoth','final','creepy',1,0)): SETOF(*_a,_GP,'r7')

# 11-10 audit picks live: style redraws for Scoopsy, Spanglin, Pinster, Harvantis, Moundlet, Lyrewing, Terrasloth, Bonsolith, Mortarfly (moth face,
# no human face). Chainipede kept: all three redraws still dripped. Sets for the three whose look changed most.
for _a in (('Terrasloth','mid','cute',0,0),('Bonsolith','final','majestic',0,0),('Mortarfly','final','majestic',0,0)): SETOF(*_a,_GP,'r8')
SPECS.append({'id':'nodrip_chainipede','name':'Chainipede (no venom drips)','refs':['briefs/boki-art/cards/Chainipede.jpg'],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':_EDIT+"erase the green liquid dripping from its mouth and the drops below it completely; its mouth is closed and dry, with two clean fangs. Nothing else changes."})

# 11-10: review upgrades (owner: "do all of this"). Sheet-vs-card colour check found Pillaroo's sheet and portrait still on the old postbox design.
SETOF('Pillaroo','final','tough',0,1,_GP,'r9')

# ===== 11-10 OWNER: the scripted pixel icons are "not good pixels: look at Pokemon pixels, it's not just a pixelized version". Right: a real sprite is
# REDRAWN for the grid (simplified shapes, bigger head and eyes, clean one-pixel outline, a small palette with deliberate shading). TEST: the image
# model redraws the sprite from the card; a script then snaps it to a true pixel grid. Two looks x 12 Boki x 2 runs. ids px_<look>_<name>.
_PXA=("Redraw the creature in image 1 as a classic 16-bit handheld RPG monster battle sprite, hand-pixelled on a 64 by 64 pixel grid and shown enlarged so every pixel is a crisp square. "
      "It is a NEW drawing for the small grid, not a shrunken copy: simplify it to its most recognisable shapes, make the head and eyes a little bigger, drop small details, and keep its signature part bold. "
      "A clean dark one-pixel outline, about twelve flat colours in total, two or three shades per colour placed in deliberate clusters, a few highlight pixels on the eyes. No anti-aliasing, no blur, no gradients, no dithering noise. "
      "Front three-quarter battle stance, facing left, whole body in frame and centred. Plain flat white background, nothing else: no ground, no shadow, no text, no border.")
_PXB=("Redraw the creature in image 1 as a tiny chunky 8-bit menu icon sprite, hand-pixelled on a 32 by 32 pixel grid and shown enlarged so every pixel is a crisp square. "
      "It is a NEW drawing for the tiny grid: reduce it to a big head, a small body and its one signature part, with large simple eyes; drop everything else. "
      "A dark one-pixel outline, at most eight flat colours, no anti-aliasing, no blur, no gradients. Facing left, whole body in frame and centred. Plain flat white background, nothing else.")
for _n in ('Vespyx','Mycroll','Prismander','Ermink','Pinguin','Jerbit','Kitlet','Xylogator','Sarcobra','Calderoise','Aurostag','Chainipede'):
    for _k,_p in (('a',_PXA),('b',_PXB)):
        SPECS.append({'id':'px_'+_k+'_'+_n.lower(),'name':_n+' (pixel sprite test '+_k+')','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':2,'aspect':'1:1','size':'1K','prompt':_p})

# 11-10 pixel sprite test, round 2: same chunky look for every Boki, anchored on a pixel style reference (image 2).
_PXC=("Redraw the creature in image 1 as a retro handheld RPG monster sprite. Image 2 shows the exact pixel art style to match: "
 "big chunky square pixels, the whole creature only about 48 pixels tall, a dark one-pixel outline, flat colours with one shade tone, "
 "at most 12 colours, no anti-aliasing, no gradients, no dithering, no glow. Do not copy the creatures in image 2, only their pixel size and style. "
 "This is a redesign for small size, not a shrunken copy: simplify the creature to its 3 or 4 most recognisable features, make the head and eyes a little larger, "
 "drop small patterns and thin details, keep its main colours. Every part belongs to its body; add no clothing, scarf, hat or held item. "
 "Three-quarter view facing left, whole body in frame, centred, filling most of the image. "
 "Pure flat white background, nothing else: no ground, no shadow, no text, no border, no grid lines.")
for _n in ('Vespyx','Mycroll','Prismander','Ermink','Pinguin','Jerbit','Kitlet','Xylogator','Sarcobra','Calderoise','Aurostag','Chainipede','Lockatara','Chuggamus','Palloth','Hydrangor'):
    SPECS.append({'id':'px_c_'+_n.lower(),'name':_n+' (pixel sprite test c)','refs':['briefs/boki-art/cards/'+_n+'.jpg','briefs/boki-art/style_refs/pixel_sprite_ref_v1.png'],'runs':2,'aspect':'1:1','size':'1K','prompt':_PXC})

# 11-10 pixel sprite test, round 3: owner picked reference styles 5/6 (DS-era battle sprite) and 7 (menu icon).
_PXTAIL=(" Every part belongs to its body; add no clothing, scarf, hat or held item; body stripes stay body markings. "
 "Pure flat white background, nothing else: no ground, no shadow, no text, no border, no grid lines, one creature only.")
_PX5=("Redraw the creature in image 1 as a hand-pixelled front battle sprite from a 2008 Nintendo DS monster-collecting RPG. "
 "The sprite is drawn on an 80 by 80 pixel canvas and shown enlarged with crisp square pixels, each sprite pixel a clearly visible block. "
 "Dark coloured one-pixel outline (a dark shade of the local colour, black only in the darkest places), about 15 colours in total, "
 "each colour area has a base tone, one shadow tone and a small highlight, clean clusters of pixels, no anti-aliasing blur, no gradients, no dithering, no glow. "
 "Redesign it for this size like a sprite artist would: bold clear silhouette, slightly larger head and eyes, keep the 4 or 5 features that make it recognisable, drop tiny patterns and thin lines. "
 "Lively three-quarter front pose facing left, whole body in frame, centred, filling most of the image.")
_PX6=("Redraw the creature in image 1 as a hand-pixelled front battle sprite from a 2010 Nintendo DS monster-collecting RPG. "
 "The sprite is drawn on a 96 by 96 pixel canvas and shown enlarged with crisp square pixels, each sprite pixel a visible block. "
 "Dark coloured one-pixel outline, about 16 colours in total, each colour area has a base tone, a shadow tone and a highlight, careful pixel clusters, "
 "no anti-aliasing blur, no gradients, no dithering, no glow. "
 "Keep the full design and its signature parts but simplify small patterns so every detail is at least two pixels wide; bold clear silhouette. "
 "Dynamic three-quarter front pose facing left, whole body in frame, centred, filling most of the image.")
_PX7=("Redraw the creature in image 1 as a tiny party-menu icon sprite from a classic handheld monster-collecting RPG. "
 "The icon is drawn on a 32 by 32 pixel canvas and shown hugely enlarged, so every sprite pixel is a big obvious square block about 30 screen pixels wide; the whole creature is only about 26 blocks tall. "
 "Dark outline one block thick, at most 8 flat colours, no shading beyond one darker tone, no anti-aliasing, no gradients, no dithering. "
 "Extreme simplification: just the head and body shape, two-block eyes, and the one or two features that identify it; no small patterns at all. Big head, tiny body. "
 "Side-on or three-quarter view facing left, centred.")
for _n in ('Vespyx','Mycroll','Prismander','Ermink','Pinguin','Jerbit','Kitlet','Xylogator','Sarcobra','Calderoise','Aurostag','Chainipede'):
    for _k,_p in (('5',_PX5),('6',_PX6),('7',_PX7)):
        SPECS.append({'id':'px'+_k+'_'+_n.lower(),'name':_n+' (pixel sprite style '+_k+')','refs':['briefs/boki-art/cards/'+_n+'.jpg'],'runs':2,'aspect':'1:1','size':'1K','prompt':_p+_PXTAIL})

# 11-10 owner: "i dont like how all the legendaries have light up eyes, remove that". Plain eyes on all 19, nothing else changes.
_NOGLOW=("the eyes. Remove the glowing white star-shaped eyes and every star sparkle or glint drawn on the eyes or between the eyes. "
 "Draw ordinary living animal eyes instead: a coloured iris that suits the creature, a dark pupil and one small plain highlight dot, same eye size and position, same expression. No glow, no light, no stars in or around the eyes.")
for _n in [k for k,v in _LM.items() if v.get('legendary_tier')]:
    _x=''
    if _n=='Siegephant': _x=" Also make all four legs easy to see: the far hind leg stands clearly apart from the near one, and the legs are a slightly lighter brown than the body shadow."
    if _n=='Palloth': _x=" Keep the face eerie: dull pale eyes with small dark pupils."
    if _n=='Cindermaw': _x=" Its skull face keeps dark eye sockets with a small dull purple iris, not a glowing light."
    RV_EDIT(_n,'eyes',_NOGLOW+_x,runs=2)
# Dreadnoyak: owner does not get the ice bowl under it, and it reads too close to Glaciammoth (both white shaggy ice beasts).
ON_CHANGE('Dreadnoyak',_C%'Dreadnoyak','final','tough',True,True,"remove the ice bowl or boat shape under its belly completely: it stands on its own four legs on nothing. It is a battleship of a yak: its coat is now dark storm navy and gunmetal grey (not white), with a pale frost mane only along the spine. Its chest and brow carry a heavy pointed prow of dark horn like the bow of an icebreaker, and its two horns sweep forward. Thick, low and armoured, head down, pushing forward.",runs=3,tag='_d1')
ON_CHANGE('Dreadnoyak',_C%'Dreadnoyak','final','tough',True,True,"remove the ice bowl or boat shape under its belly completely: it stands on its own four legs on nothing. Its coat is now deep slate blue with a pale icy underbelly (not white all over). Along its back grows a single tall row of blunt horn towers like the funnels and turrets of a warship, biggest in the middle, and its skull has a broad flat ram plate of horn across the forehead. Standing side-on, facing left, head raised, proud.",runs=3,tag='_d2')

# 11-10 owner: Sawright is Carpenjaw in a new pose, not a new creature. Three real finals, all from Carpenjaw.
_n0=len(SPECS)
RV_NEW('Sawright','Carpenjaw','final','tough',False,False,[
 "twice as big and much heavier, a broad hammerhead: its head has widened into a wide flat mallet shape with an eye at each end, and the saw nose juts out from the middle of it, shorter and thicker with big teeth. Rich dark walnut brown with pale wood-grain rings on its sides and a cream belly. Its back fin is now a round toothed disc like a circular saw blade made of fin. Cruising toward the viewer in a three-quarter view facing right, head swung to one side.",
 "a huge thick-bodied giant, barrel-shaped like a tree trunk, with rough dark bark plates along its back and pale cut-wood rings showing on its flanks. Its saw nose has become a broad long blade with heavy teeth running all the way round the edge. Pale curled wood shavings grow as whiskers at its jaw and as the trailing edges of its fins. Deep red-brown mahogany with a cream belly. Seen side-on facing left, mouth open, slow and massive.",
 "a long powerful master of the shoal with TWO saw blades: its saw nose is longer and now its tail fin is a second toothed saw blade, and three tall triangular set-square back fins stand in a row down its back, biggest first. Dark walnut brown above with fine gold-tan inlay stripes along the sides and a cream belly, heavy brow ridges and a stern face. Body curved in a strong S, seen from above and the side, facing right."])
for _s in SPECS[_n0:]: _s['id']=_s['id'].replace('rv_sawright_','saw3_')

# 11-10 owner: "xylogator line looks pretty comicy, not really in line with the rest of the designs". Clip-art gator + toy rainbow bars.
# Two directions for the whole line; bars become grown back scutes, no toy rainbow, three different bodies.
_XA=("Colours: deep teal-green hide with a pale sand belly; the back bars are its own wide flat back scutes of warm rosewood brown, graded from honey at the neck to dark chocolate at the tail, never rainbow. The tail ends in a rounded club of pale bone, part of the tail. Designed like a real fantasy creature, not a toy or clip-art: defined scales on the legs, a ridged brow, a characterful face. ")
_XB=("Colours: dusky slate-blue hide with a cream belly; the back bars are its own flat back scutes of pale jade stone, graded from mint at the neck to deep sea-green at the tail, each with a thin gold edge, never rainbow. The tail ends in a rounded club of jade, part of the tail. Designed like a real fantasy creature, not a toy or clip-art: defined scales on the legs, a ridged brow, a characterful face. ")
for _k,_x in (('a',_XA),('b',_XB)):
    ON_CHANGE('Xylogator',_C%'Xylogator','baby','cute',False,False,_x+"A stubby hatchling with a short blunt snout and only five small back bars, sitting up on its haunches, club tail curled round in front, looking up at the viewer.",runs=2,tag='_xy'+_k)
    ON_CHANGE('Marimbite',_C%'Marimbite','mid','sleek',False,False,_x+"A lean long-legged young crocodile with a long thin gharial snout, walking tall with its body held off the ground, about nine back bars in a single row and short hollow tube spines hanging under the bars along its flanks like marimba pipes. Its tail splits into two slim club tips. Side-on facing left, snout raised, mid-stride.",runs=2,tag='_xy'+_k)
    ON_CHANGE('Glockodile',_C%'Glockodile','final','tough',False,False,_x+"A massive heavy old crocodile, twice the bulk, with a broad armoured head and jaw. Its back bars have grown tall and stand up in a curved fan along its spine like a sail, biggest in the middle, with long resonator tube spines beneath them. One huge club tail raised over its back. Jaws wide open in a roar with normal crocodile teeth (no piano keys). Three-quarter view facing right, front legs planted.",runs=2,tag='_xy'+_k)

# 11-10 owner: Canopony too similar to Foalaround; Carrousteed too basic, reads as a stage 2. Both rebuilt from Foalaround.
_n0=len(SPECS)
RV_NEW('Canopony','Foalaround','mid','pretty',False,True,[
 "a leggy young horse, twice the size, frozen mid-leap like a carousel horse with front legs tucked and back legs stretched. Its mane now stands up stiff in a scalloped crest striped in two colours like the edge of a fairground canopy, and its tail has become one long rigid twisted spiral, striped like a barber pole, held straight up behind it. Side-on facing left.",
 "a leggy young horse, twice the size, trotting with head high and neck arched. A short twisted spiral pole of horn, striped like a barber pole, grows straight up from its shoulders, and its mane and tail are long flat ribbon streamers in two colours that curl and trail. Dappled spots on its flanks. Three-quarter view facing right."])
RV_NEW('Carrousteed','Foalaround','final','majestic',False,True,[
 "a big powerful stallion, four times the size, rearing on its hind legs. Around its neck and shoulders its mane has grown into a huge round scalloped frill that stands open like a striped big-top canopy (a frill of its own stiff hair, like a frilled lizard's), with gold-tipped tassels of hair at each scallop. Its tail is a long twisted spiral striped like a barber pole with a golden tuft. Richer deeper colours than the foal with gold markings on the legs. Three-quarter view facing left.",
 "a big powerful SIX-legged stallion, four times the size, caught in full gallop so its six legs fan out like the horses of a spinning merry-go-round. Its mane and tail are long two-coloured ribbon streamers swirling in a full circle around its body like a ring. A tall twisted spiral crest striped like a barber pole rises from its shoulders. Deeper richer colours than the foal, gold hooves. Side-on facing right.",
 "a huge heavy draught stallion, four times the size, standing proud with one front hoof raised. Thick fringes of feathered hair hang over its hooves, its mane is a row of upright hollow reeds of hair like fairground organ pipes, tallest in the middle, and a broad scalloped striped mantle of its own long hair drapes over its back and flanks like a canopy. Deeper richer colours than the foal with gold dapples. Three-quarter view facing left."])
for _s in SPECS[_n0:]: _s['id']=_s['id'].replace('rv_','car3_')

# 11-10 owner: Pinguin line "too comical"; review recent additions against the rest of the game art. Side-by-side check: the 11-10 new lines
# (Pinguin, Stamproo; also Xylogator, Foalaround, Sawright queued above) are sticker/clip-art simple next to Mycroll, Lockatara, Chuggamus.
_HOUSE=("Match the main roster's look: a properly designed fantasy creature with believable animal anatomy and some texture (fur tufts, feather layers or scales drawn as a few clear shapes), "
 "a palette of three or four related natural tones plus one accent colour. It must not look like a sticker, mascot, emoji, toy or clip-art, and not a plain real animal either. ")
_n0=len(SPECS)
ON_CHANGE('Pinguin',_C%'Pinguin','baby','cute',False,True,_HOUSE+"A fluffy penguin chick with real penguin anatomy: downy ivory-grey feathers, slate-blue back and flippers, small webbed feet, a short beak. Its body is tall and narrow-necked like a bowling pin, and two crimson bands of feathers ring its neck as natural markings (feather markings, not a scarf). Waddling, flippers out for balance, three-quarter view facing right.",runs=2,tag='_h')
ON_CHANGE('Rollguin',_C%'Pinguin','mid','cute',False,True,_HOUSE+"This is the evolved form: a bigger, round, heavy penguin tobogganing forward on its belly, body nearly a ball. Dark slate-blue feathered back with three pale round spots in a triangle (like a bowling ball's holes, as feather markings), ivory belly, the same two crimson neck bands, a short swept-back head tuft. Sliding toward the left, flippers tucked back, feet up behind.",runs=2,tag='_h')
ON_CHANGE('Kingpinguin',_C%'Kingpinguin','final','tough',False,True,_HOUSE+"A tall proud emperor-sized penguin, three times the chick's size, standing upright with chest out and one flipper raised. Layered slate and navy back feathers, ivory chest with three dark round spots in a triangle, broad crimson neck bands, and a crown of long gold and crimson brow plumes sweeping back. Sharp beak, stern eyes, strong clawed feet. Three-quarter view facing left.",runs=2,tag='_h')
ON_CHANGE('Stamproo',_C%'Stamproo','baby','cute',False,True,_HOUSE+"A small joey with real kangaroo anatomy: long hind feet, short forearms, thick tail, soft brick-red fur with a cream chest and navy ear tips. Its big ears have neatly notched perforated edges like a postage stamp, and one round navy ring marking like a postmark sits on its flank. Mid-hop, ears flying, side-on facing left.",runs=2,tag='_h')
ON_CHANGE('Postroo',_C%'Postroo','mid','sleek',False,True,_HOUSE+"A lean fast young kangaroo in a full bounding leap, body stretched long. Brick-red fur with a cream chest and navy socks, notched stamp-edge ears swept back, two navy postmark ring markings on its haunch. The tip of its long tail is a flat cream diamond tuft of fur with a darker V marking like a sealed envelope (fur, part of the tail). Side-on facing right.",runs=2,tag='_h')
ON_CHANGE('Pillaroo',_C%'Pillaroo','final','tough',False,True,_HOUSE+"A huge muscular red kangaroo with a real kangaroo head and long muzzle, propped back on its thick tail with both hind feet raised to kick. Deep pillar-box red fur, cream chest, navy forearms, big notched stamp-edge ears. Its chest and belly are broad and barrel-shaped, and its pouch opening is a wide dark horizontal slot. A heavy ridge of darker fur caps its head like a domed lid. Animal stance, no crossed arms, no clothes. Three-quarter view facing left.",runs=2,tag='_h')
for _s in SPECS[_n0:]: _s['id']=_s['id'].replace('on_','hs_')

# 11-10 owner: a better OG (link preview) image for the Bokidex than Boki pasted on a plain card. Key-art scenes; refs = two boards of live cards.
_OGR=['briefs/boki-art/style_refs/og_ref_board_a.jpg','briefs/boki-art/style_refs/og_ref_board_b.jpg']
_OGS=("Images 1 and 2 are character sheets showing twelve creatures called Boki. Draw them faithfully: same designs, colours, faces and signature parts, each creature exactly once, no new creatures invented in the foreground. "
 "Art style: the same clean flat cel-shaded cartoon look as the references, bold dark coloured outlines, flat colours with one shade tone, no gradients on the characters, no glow, no sparkles. "
 "Wide 16:9 key-art illustration for a website link preview: it must read clearly as a small thumbnail, with big shapes and strong contrast. No text, no letters, no logo, no border, no UI. ")
for _k,_t in (('hill',"Scene: a sunny grassy hilltop at golden hour with a simple flat-colour sky and a few soft clouds. The three small cute ones (the mushroom hedgehog, the purple scorpion-tailed fox and the pink striped axolotl) stand together front and centre looking at the viewer, happy. The other creatures are gathered behind and around them at different depths, the large ones (hippo, stag, key-tailed lizard) at the back, the hawk flying overhead and the little kite dragon in the air. Keep the top left third of the picture as calm empty sky for a title to be added later."),
              ('book',"Scene: a big open field-guide book lying on a wooden desk, seen at a three-quarter angle, its pages showing simple ink sketches of creature silhouettes. The Boki are bursting up out of the pages in a joyful swirl, small ones tumbling at the front, large ones rising behind, the hawk and the kite dragon flying out at the top. Warm desk-lamp light, simple flat background. Keep the upper left area calm and empty for a title to be added later."),
              ('lineup',"Scene: a bold graphic line-up on a deep indigo background. In the front row, six of the Boki stand side by side in full colour on a simple pale floor line, the three small cute ones in the middle. Behind them, rows of many more creature shapes fade back as flat dark indigo mystery silhouettes of different sizes with only tiny white eye dots, suggesting hundreds more to discover. Keep a calm band of plain indigo across the top for a title to be added later.")):
    SPECS.append({'id':'og_'+_k,'name':'Bokidex OG image ('+_k+')','refs':_OGR,'runs':3,'aspect':'16:9','size':'2K','prompt':_OGS+_t})

# 11-10 owner: Hatstag bugged on the dex page; the floating stuff over its head should change. Antlers are drawn detached above the head with
# dangling hooks; the old portraits/cutout file is a stale different drawing.
_n0=len(SPECS)
ON_CHANGE('Hatstag',_C%'Hatstag','final','majestic',False,True,"the antlers. They now grow firmly out of the top of its skull on two thick clear stems, fully attached to the head with no gap anywhere, and nothing floats. Each antler rises like the branching arms of a hat stand, with upturned tines, and a single mushroom cap sits on the tip of each tine like a hat on a peg: about eight caps in cream, sage green and tan, a big one in the middle. Remove every dangling hook, anchor, key or hanging piece. Same body, moss ruff, face and colours.",runs=3,tag='_fix1')
ON_CHANGE('Hatstag',_C%'Hatstag','final','majestic',False,True,"the antlers. Replace them with one simpler, bolder idea: two tall upright antlers attached solidly to the skull, each a straight main beam with short upturned side pegs like a hat stand, and each antler is topped by one very large wide mushroom cap like a broad-brimmed hat, with two or three small caps on the pegs below. Nothing floats and nothing dangles: no hooks, anchors or hanging pieces. Head lowered a little and turned to the viewer, standing side-on facing right. Same body, moss ruff, face and colours.",runs=3,tag='_fix2')
for _s in SPECS[_n0:]: _s['id']=_s['id'].replace('on_hatstag','hat')
# OG round 2: owner showed the live OG (logo + "Meet the Boki." on the left over a dark starry navy sky, Boki on the right). Same layout, V2 art, a real scene.
for _k,_t in (('night',"Scene: night. A very dark navy-black sky with a few tiny soft coloured stars fills the whole picture. The LEFT HALF of the picture is completely empty dark sky, nothing in it at all (a logo goes there later). In the RIGHT HALF, the Boki are gathered on a small moonlit grassy hilltop that rises from the bottom right corner: the three small cute ones (mushroom hedgehog, purple scorpion-tailed fox, pink striped axolotl) at the front looking at the viewer, the big ones behind them, the stag at the top with its crown ring, the hawk and the little kite dragon flying above. Soft rim light on the creatures so they pop against the dark."),
              ('nightline',"Scene: night. A very dark navy-black sky with a few tiny soft coloured stars fills the whole picture. The LEFT HALF of the picture is completely empty dark sky, nothing in it at all (a logo goes there later). In the RIGHT HALF: six of the Boki in full colour in a tight friendly group at the bottom right, the three small cute ones in front, and rising behind them a crowd of many more creature shapes as flat dark indigo mystery silhouettes with tiny white eye dots, fading up into the sky, suggesting hundreds more to discover.")):
    SPECS.append({'id':'og_'+_k,'name':'Bokidex OG image ('+_k+')','refs':_OGR,'runs':3,'aspect':'16:9','size':'2K','prompt':_OGS+_t})

# 11-10 promoted: legendary cards without star eyes (rv_<n>_eyes_1), house-look Pinguin + Stamproo lines, Xylogator line A (rosewood),
# Sawright A (hammerhead), Canopony b_1, Carrousteed a_1, Dreadnoyak d1_1. Matching sheets + portraits from the new cards (tag e1).
for _a in (('Glaciammoth','final','majestic',0,1,"head lowered, great tusk swept forward, striding"),('Hydrangor','final','majestic',0,0,"heads fanned out, each looking a different way"),
 ('Sarcobra','final','majestic',1,0,"hood flared, reared high, looking down at the viewer"),('Pavonazar','final','majestic',0,1,"tail fan half folded, stepping forward, head turned"),
 ('Aurostag','final','majestic',1,1,"mid-stride, head high, aurora mane streaming"),('Cetorgan','final','majestic',0,0,"breaching, pipes fanned, jaw open"),
 ('Cindermaw','final','creepy',1,1,"stalking forward, head low, bone ridge raised"),('Ghoulamari','final','creepy',1,0,"rising up, tentacles spread wide"),
 ('Siegephant','final','tough',0,0,"walking forward, trunk raised, all four legs clearly apart"),('Sphinxblight','final','majestic',1,1,"lying like a sphinx, wings folded, head up"),
 ('Wayshell','final','majestic',0,0,"swimming up toward the viewer, flippers spread"),('Glacione','final','cute',0,0,"floating, wings open, head tilted"),
 ('Cometail','final','sleek',1,1,"trotting on nothing, head turned to the viewer, comet tail arching overhead"),('Calderoise','final','tough',1,0,"head raised, roaring"),
 ('Pharoheron','final','majestic',0,1,"standing on one leg, neck straight up like a tower, wings half open"),('Palloth','final','creepy',1,1,"hovering, wings half open, calm"),
 ('Luckhop','final','cute',0,1,"sitting up, ears forward, clover crown tilted"),('Twinklup','final','cute',0,1,"sitting, head tilted, tail curled round"),('Lockwren','final','cute',0,1,"perched, wings slightly lifted, looking up"),
 ('Pinguin','baby','cute',0,1,"sitting down with a bump, flippers up"),('Rollguin','mid','cute',0,1,"standing up, round as a ball, flippers on its belly"),('Kingpinguin','final','tough',0,1,"marching forward, chest out, plumes streaming"),
 ('Stamproo','baby','cute',0,1,"sitting on its tail, ears up, looking at the viewer"),('Postroo','mid','sleek',0,1,"standing alert on hind legs, tail out, ears turned"),('Pillaroo','final','tough',0,1,"standing tall on hind legs like a real kangaroo, chest out, tail planted"),
 ('Xylogator','baby','cute',0,0,"walking on all fours, club tail held up"),('Marimbite','mid','sleek',0,0,"head raised, jaw open, tail swung to the side"),('Glockodile','final','tough',0,0,"walking forward, mouth closed, sail tall, club tail raised"),
 ('Sawright','final','tough',0,0,"turning in a slow arc, head swung wide"),('Canopony','mid','pretty',0,1,"rearing a little, ribbons flying"),('Carrousteed','final','majestic',0,1,"trotting, neck arched, frill open"),
 ('Dreadnoyak','final','tough',1,1,"standing side-on, head raised, horns high")):
    SETOF(*_a,'e1')
# Rollguin: the red neck bands came out as a folded scarf. Feather bands only.
RV_EDIT('Rollguin','bands',"the red band round its neck. It must not look like a scarf or cloth: no folds, no knot, no loose ends. Redraw it as two flat crimson stripes of feathers lying flush on the neck, exactly like colour markings on its plumage.",runs=2)
# Foalaround: bring the baby in line with the house look and the new Canopony / Carrousteed (cream, rose and maroon, real foal anatomy).
ON_CHANGE('Foalaround',_C%'Foalaround','baby','cute',False,True,_HOUSE+"A wobbly long-legged newborn foal with real foal anatomy, cream coat with soft rose patches and maroon lower legs, a short fluffy mane that stands up in a small scalloped crest striped rose and cream, a tiny spiral nub of a horn, and a short tail that is one tight barber-pole twist. Standing splay-legged, head tilted, three-quarter view facing left.",runs=3,tag='_h'); SPECS[-1]['id']='hs_foalaround_h'

# 11-10 round e2. Promoted: Hatstag hat_fix1_2, Rollguin rv_rollguin_bands_2, Foalaround hs_foalaround_h_2, 29 e1 sets (clean sheets only; a
# faded ghost row keeps appearing above haloed designs, tools/topclean.py removes it when there is a clean gap). Still needed:
_NOGHOST=" IMPORTANT: draw each view exactly once. The top quarter of the image is empty plain background: no second row, no faded or partial copies of the creature or of its crown ring anywhere."
for _a in (('Hatstag','final','majestic',0,1,"head lowered to graze, antlers tilted toward the viewer"),('Rollguin','mid','cute',0,1,"standing up, round as a ball, flippers on its belly"),
           ('Foalaround','baby','cute',0,1,"mid-prance, front legs lifted, tail twist bouncing"),('Calderoise','final','tough',1,0,"head raised, roaring"),('Marimbite','mid','sleek',0,0,"head raised, jaw open, tail swung to the side")):
    _n0=len(SPECS); SETOF(*_a,'e2'); SPECS[_n0]['prompt']+=_NOGHOST
    if _a[0]=='Rollguin': SPECS[_n0]['prompt']+=" The red marks on its neck are flat stripes of feather colour, never a scarf: no cloth, folds, knot or loose ends."; SPECS[_n0+1]['prompt']+=" The red marks on its neck are flat stripes of feather colour, never a scarf."
    if _a[0] in ('Calderoise','Marimbite'): SPECS.pop()   # portraits already promoted
# Kingpinguin: same scarf problem as Rollguin.
RV_EDIT('Kingpinguin','bands',"the red band round its neck and shoulders. It must not look like a scarf or cloth: no folds, no knot, no loose ends, no flap. Redraw it as three flat crimson stripes of feathers lying flush on the neck and chest, colour markings on its plumage, in the same style as flat stripes on a bird.",runs=2)
# Pillaroo: the new card and sheet read as a muscular person in a kangaroo suit. A real kangaroo, big and heavy.
ON_CHANGE('Pillaroo',_C%'Postroo','final','tough',False,True,_HOUSE+"This is the evolved form of the creature in image 1, three times its size: a huge old boomer red kangaroo with a REAL kangaroo body, never a human build: long heavy hind legs with huge feet, small forearms held in front of the chest, a long muzzle, a very thick tail. No human muscles, no abs, no shoulders like a person, no fists. Deep pillar-box red fur, cream chest and belly, navy forearms and feet, big notched stamp-edge ears, three navy postmark rings on its haunch. Its body is tall and round like a pillar box, its pouch opening is a wide dark horizontal slot, and a domed cap of darker fur tops its head. Standing upright on hind legs and tail the way kangaroos stand, calm and proud, three-quarter view facing left.",runs=3,tag='_h2'); SPECS[-1]['id']='hs_pillaroo_h2'
# Cute legendaries that read as common babies (reviewer + owner "not all clearly legendary"): same creature, rarer and more regal, house look.
for _n,_t in (('Twinklup',"The same white and gold star puppy, but older and rarer looking: a slim elegant young hound with a long feathered tail that arcs overhead like a shooting star and ends in a five-point star tuft, a crescent moon marking on its brow, gold-tipped ears, and small star-shaped markings scattered along its back like a constellation joined by thin gold lines. Calm, wise expression, mouth closed. Sitting tall, three-quarter view facing left."),
              ('Lockwren',"The same rosy wren with the heart-shaped lock on its chest, but rarer and more regal: sleeker body, a long tail of two streamer feathers that end in key-shaped tips, a small crest, and fine gold filigree markings on its wings like engraving. The heart lock is a raised part of its own chest plumage in rose-gold. Calm proud pose, wings half open, three-quarter view facing right."),
              ('Luckhop',"The same mint green lucky hare, but older and rarer: a tall slender hare, long ears whose tips are four-leaf clovers, a ruff of clover leaves round its neck, gold fleck markings along its back and a round tail patterned like a gold coin (fur, part of the body). Calm knowing expression. Standing upright on hind legs, alert, one forepaw raised, three-quarter view facing left.")):
    ON_CHANGE(_n,_C%_n,'final','majestic',False,True,_HOUSE+_t+" Keep its floating crown ring above the head, clear and bright, made of its own material. Ordinary eyes with a dark pupil and one small highlight, no star eyes, no glow.",runs=3,tag='_leg2')

# OG round 3. Owner: "why does the og image look so bad? i want it ai gen to be cool". Rounds 1-2 were flat sticker groups. Now: cinematic
# game-cover key art, few characters, real lighting and depth. Refs = individual cards.
_OGC=lambda *n: ['briefs/boki-art/cards/%s.jpg'%x for x in n]
_OGK=("Epic cinematic key art for a creature-collecting adventure game, the quality of a AAA game cover or an animated feature film poster: dramatic lighting, strong rim light, deep atmospheric perspective, volumetric light rays, rich saturated colour, a painterly detailed environment, a bold dynamic composition with a clear focal point. "
 "The creatures come from the reference images: keep each one on-model (same design, colours, face and signature parts) but render them fully lit and integrated into the scene with the scene's light and shadow on them, not as flat stickers. Each creature appears once. "
 "Wide 16:9. The left 40 percent of the picture is darker and calmer with no characters, so a logo can sit there. No text, no letters, no logo, no border, no UI. ")
for _k,_r,_t in (
 ('vista',_OGC('Mycroll','Vespyx','Prismander','Aurostag','Cetorgan'),"Scene: dusk on a high cliff edge. In the right foreground the three small creatures (mushroom hedgehog from image 1, purple scorpion-tailed fox from image 2, pink striped axolotl from image 3) stand together seen from a low three-quarter angle, looking out with wonder over a vast glowing valley of forests, rivers and floating islands. Far off, the giant star stag from image 4 stands on a distant peak with its aurora mane streaming across the whole sky as northern lights, and the great whale from image 5 swims through the clouds. Sense of huge scale and adventure about to begin."),
 ('egg',_OGC('Mycroll','Vespyx','Prismander','Kitlet','Kestrike'),"Scene: a dark mossy forest clearing at night. On the right, a large cracked egg glows from within with brilliant teal and magenta light, shards floating, light rays bursting through the cracks and lighting the mist. The three small creatures (mushroom hedgehog, purple scorpion-tailed fox, pink striped axolotl) gather round it, faces lit by the glow, excited and curious; the little kite dragon from image 4 hovers above and the hawk from image 5 swoops in. Fireflies, deep shadows, magical."),
 ('titan',_OGC('Mycroll','Vespyx','Prismander','Calderoise'),"Scene: a dramatic low-angle shot. In the right foreground the three small creatures (mushroom hedgehog, purple scorpion-tailed fox, pink striped axolotl) stand bravely side by side on dark volcanic rock, seen partly from behind. Towering over them in the middle distance, the colossal volcano tortoise from image 4 rises out of smoke and ember-lit clouds, lava glowing in the cracks of its shell, looking down at them. Embers drift through the air, orange light from the lava against a deep blue night sky. David-and-Goliath scale."),
 ('aurora',_OGC('Aurostag','Mycroll','Vespyx','Prismander'),"Scene: deep night in a snowy pine valley. On the right, the majestic star stag from image 1 stands on a rocky rise, head high, its long aurora mane flowing up into the sky and becoming real northern lights in green, teal and violet that sweep across the whole picture. In the foreground below it, small and lit by the aurora glow, the mushroom hedgehog, the purple scorpion-tailed fox and the pink striped axolotl look up at it in awe. Stars, drifting snow, reflections on a frozen lake.")):
    SPECS.append({'id':'ogk_'+_k,'name':'Bokidex OG key art ('+_k+')','refs':_r,'runs':3,'aspect':'16:9','size':'2K','prompt':_OGK+_t})
