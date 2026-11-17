# Owner 03:42 ET 11-09: "umbrathere should have more bones to him and maybe even try some umbrella stuff where it comes from him
# (like his tail or out his back) and its very boney"; "lyrewing needs her wings to be the instrument, not just tied to it - and look
# way more majestic". Both un-locked. (Umbrathere portrait stays owner-locked until a new sheet replaces it.)
import os as _o75
def _s75(n): return next(f'briefs/boki-art/{d}/{n}.jpg' for d in ('turnarounds','evolutions') if _o75.path.exists(HERE.parent/d/f'{n}.jpg'))
_P75=[]
_AVU2="a held umbrella, a cloth umbrella, gore, a scary skeleton, standing upright like a person, a busy design"
for _k,_b in (('u1',"A large sloth whose long tail rises up behind it and opens into a big umbrella canopy made of its own long rib bones with dark leathery skin stretched between them, visible bony spine ridge down its back, bony claws, hanging pose."),
              ('u2',"A big sloth with a visible bony ribcage pattern on its chest and an open umbrella of long curved bone ribs fanning out of its back like a bat-wing parasol, thin membrane between the ribs, a bony skull-like brow, long hook claws."),
              ('u3',"A tall gaunt sloth with exposed bone-white ribs along its sides, a long bony tail ending in a curved umbrella-handle hook, and two big bone-ribbed umbrella wings that fold around its body like a closed parasol."),
              ('u4',"A big sloth hanging from its bony hooked tail, its back sprouting a domed umbrella canopy of fused bone ribs with ragged dark membrane, bone plates down its spine, and long bony fingers.")):
    VC('umbrathere_'+_k,'Umbrathere',_s75('Umbrathere'),'redo_of',"Same creature and colours as image 1 but far more bony, with the umbrella grown out of his own body: "+_b+" One clear idea, few parts.","calm, heavy-lidded violet eyes and a sly smile","charcoal grey and bone white, with a dusky violet accent",_AVU2,'shadow','creepy'); _P75.append('c_umbrathere_'+_k)
_AVL2="a harp it holds, strings tied onto normal wings, music notes, standing upright like a person, a busy design"
for _k,_b in (('l1',"A majestic lyrebird whose two great wings ARE harps: each wing is a curved golden lyre frame with shining silver strings stretched across it instead of feathers, swept up high, and a long elegant tail of curling silver plumes, standing tall and proud."),
              ('l2',"A grand lyrebird spreading its wings into a huge golden harp shape: the wing bones form the curved harp frame and silver string-feathers run between them, a crown crest like tuning pegs, a cascading tail of lyre-shaped plumes."),
              ('l3',"A regal lyrebird with its tail fanned into a giant lyre: two curved golden outer tail feathers form the lyre frame and fine silver string-feathers fill it, wings folded like a royal cloak with string-like flight feathers, head held high."),
              ('l4',"An elegant, majestic lyrebird with wings raised overhead like the arms of a concert harp, gold frames with taut glowing silver strings as feathers, a long sweeping tail of curled golden plumes, poised on one foot like a dancer.")):
    VC('lyrewing_'+_k,'Lyrewing',_s75('Lyrewing'),'redo_of',"Same creature and palette as image 1 but its wings ARE the instrument (not tied to it) and it is far more majestic: "+_b+" One clear idea, few parts.","bright, proud, graceful eyes","iridescent green and silver, with a gold accent",_AVL2,'echo','majestic'); _P75.append('c_lyrewing_'+_k)
PRIORITY=_P75+PRIORITY
