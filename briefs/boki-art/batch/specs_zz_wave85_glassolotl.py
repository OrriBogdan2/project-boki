# Owner 04:15 ET 11-09 (note): "glassolotl needs a slightly different face and way of posing than the one before (Prismander), it's
# the same face and angle right now". Keep the approved rock-candy v3 design; change face and pose so it reads as the older middle form.
_GO='briefs/boki-art/batch/out/c_glassolotl_v3_3.jpg'; _PR='briefs/boki-art/turnarounds/Prismander.jpg'; _P85=[]
for _k,_b in (('f1',"a slightly older, more confident face: narrower almond eyes with a sly half-lidded look, a small closed-mouth smirk instead of the open grin, a slightly longer snout; posed mid-stride in a low prowl with its head turned back over its shoulder toward the viewer and the tail curving up behind it"),
              ('f2',"a cheeky older face: one eye winking, a lopsided grin showing one small tooth, slightly longer snout and sharper gill tips; caught mid-leap with front paws reaching forward and the body stretched long, seen from a lower side angle"),
              ('f3',"a focused, determined face: brows angled, eyes narrowed and looking ahead, mouth set; posed side-on in a sleek swimming glide with legs tucked and the long tail streaming behind, head slightly raised")):
    SPECS.append({'id':'c_glassolotl_'+_k,'name':'Glassolotl (new face and pose)','refs':[_GO,_PR],'runs':4,'aspect':'1:1','size':'2K',
      'prompt':("Creature-collector concept art, soft hand-painted style exactly like image 1. Keep the creature in image 1 exactly the same design"
       " (rock-candy body, crystal gills, candy stripes, crystal tail tip, colours) but give it "+_b+". It must clearly NOT have the same round-eyed open-mouth"
       " face or the same three-quarter standing angle as image 2 (its baby form). ONE creature, full body, centred, plain flat pale grey background, no shadow, no text.")})
    _P85.append('c_glassolotl_'+_k)
PRIORITY=_P85+PRIORITY
