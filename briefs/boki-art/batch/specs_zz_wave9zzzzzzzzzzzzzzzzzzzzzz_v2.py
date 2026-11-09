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
