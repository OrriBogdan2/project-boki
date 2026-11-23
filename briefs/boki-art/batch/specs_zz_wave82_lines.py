# Tick 04:05 ET 11-09: open line fixes.
# Thistlynx kept a realistic lynx face in 3 rounds -> edit the live new Nettlynx (cartoon face) into its older middle form.
# Briarlynx -> fresh finals from the new Nettlynx so the line shares one face. Galleotter + Scythant were owner-rejected -> redo.
_P82=[]; _NL='briefs/boki-art/turnarounds/Nettlynx.jpg'
_FACE2=" Keep exactly the same cartoon face as image 1 (same eye shape and size, same nose, same fang, same nettle-leaf ears), only older."
for _k,_b in (('e1',"Edit image 1 into its older middle form: the same kitten face and leaf ears, but a longer, leaner body on longer legs in a low prowl, a spiky mane of round thistle-burr puffs around the neck, and a long tail ending in a spiky thistle ball."),
              ('e2',"Edit image 1 into its older middle form: same face and ears, a slim young lynx body mid-pounce, a ridge of thistle spines down its back, burr-puff cheek tufts, and a whip tail tipped with stinging hairs.")):
    SPECS.append({'id':'c_thistlynx_'+_k,'name':'Thistlynx (from new Nettlynx)','refs':[_NL],'runs':4,'aspect':'1:1','size':'2K',
      'prompt':("Creature-collector concept art, soft hand-painted style exactly like image 1. "+_b+_FACE2+" ONE creature, full body, three-quarter view, centred, plain flat pale grey background, no shadow, no text, no effects.")}); _P82.append('c_thistlynx_'+_k)
for _k,_b in (('f1',"The grown final: a big, heavy lynx braced wide, a thick mane of coiling briar vines wrapping its shoulders, curved thorn fangs, a long thorn-whip tail; the same round cartoon face shape and big green eyes as image 1, now fierce."),
              ('f2',"The grown final: a huge briar beast-lynx with a dense thicket of thorny briar along its back and a crown of thorn spikes behind its big round head, venom-lime thorn tips, planted and looming, keeping image 1's cartoon face shape."),
              ('f3',"The grown final: a powerful lynx with long legs, its body wrapped in braided briar armour (grown, not worn), huge tufted nettle-leaf ears now edged in thorns, a long bramble tail, and image 1's big-eyed cartoon face made fierce.")):
    VC('briarlynx_'+_k,'Briarlynx',_NL,'final',_b+" One clear idea, few parts.","big fierce green eyes and a fanged snarl","tawny brown and briar green, with a toxic lime accent","a realistic lynx face, flowers, standing upright, a busy design",'venom','tough'); _P82.append('c_briarlynx_'+_k)
PRIORITY=_P82+PRIORITY
# Owner rejected the current Galleotter (final of Oarlet > Oarter > Galleotter) and Scythant (middle of Marchleaf > Scythant >
# Reapant, which is now a ninja ant). Fresh directions with the surprise rule.
import os as _o82
_OA=next(f'briefs/boki-art/{d}/Oarter.jpg' for d in ('turnarounds','evolutions') if _o82.path.exists(HERE.parent/d/'Oarter.jpg'))
for _k,_b in (('g1',"A huge war-galley sea otter floating on its back like a ship, its belly a broad wooden deck, a row of long oars grown from its sides, a tall carved figurehead crest on its brow, and a sail-fin rising from its chest."),
              ('g2',"A massive armoured otter-dreadnought braced on all fours, bronze ram horn on its brow, overlapping hull-plank armour, two rows of oar-fins rowing along its flanks, and a heavy rudder tail, menacing and planted."),
              ('g3',"A towering otter admiral rearing up out of the water on its tail, chest plated in brass-banded planks, long oar-blade forearms, a mast-like crest with a tattered pennant fin, and a fierce grin.")):
    VC('galleotter_'+_k,'Galleotter',_OA,'final',_b+" One clear idea, few parts.","fierce, confident dark eyes and a toothy grin","sea-otter brown and timber, with a bronze accent","a ship it rides, a rider, held oars, standing upright like a person, a busy design",'tide','tough'); _P82.append('c_galleotter_'+_k)
_ML=next(f'briefs/boki-art/{d}/Marchleaf.jpg' for d in ('turnarounds','evolutions') if _o82.path.exists(HERE.parent/d/'Marchleaf.jpg'))
for _k,_b in (('n1',"A young leaf-ant ninja-in-training: lean, quick, a short dark eye-mask marking, two small leaf-blade forelegs held ready, a short leaf-frond scarf, crouched low on six legs, still a little scrappy and cute."),
              ('n2',"A scrappy soldier ant mid-dash, one leaf-blade foreleg raised, a bandana-like dark band of markings across its eyes, fern antennae swept back by speed, a small split leaf tail."),
              ('n3',"A sneaky leaf ant peeking from a low crouch, its body patterned like layered leaves for camouflage, two folded leaf-sickle forelegs, a dark mask stripe, curious and cheeky.")):
    VC('scythant_'+_k,'Scythant',_ML,'mid',_b+" The middle step between a leaf ant and a ninja ant final. One clear idea, few parts.","bright, cheeky compound eyes in a dark mask band","leaf green and dark bark brown, with a lime accent","a mantis, a person, clothes, held weapons, standing upright, a busy design",'swarm','fast'); _P82.append('c_scythant_'+_k)
PRIORITY=[i for i in _P82 if i not in PRIORITY]+PRIORITY
