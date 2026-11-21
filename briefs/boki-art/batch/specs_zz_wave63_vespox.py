# Owner 03:32 ET 11-09: "vespox needs regenerations to have more similar color scheme to the line". Vespox is light lilac with
# pale fur; Vespyx (image 2) is deep plum with dark plum-brown segmented tail and lime venom. Recolour edits of Vespox's sheet,
# card and portrait to Vespyx's palette, design untouched. Owner un-locks Vespox.
import os as _o63
_VY='briefs/boki-art/cards/Vespyx.jpg'; _P63=[]
_RC=("Recolour image 1 to match the colour scheme of image 2 exactly, and change nothing else: same creature, design, pose, every"
     " part, layout, outline and background. Use image 2's palette: deep plum-purple fur (not lilac or pale violet), a soft light"
     " lilac-cream chest and muzzle like image 2, dark plum-brown glossy segmented tail and chitin plates like image 2's tail,"
     " the same lime-green eyes and lime venom. Same soft hand-painted style.")
for _id,_src,_runs in (('ta_vespox_recolor','briefs/boki-art/evolutions/Vespox.jpg',4),('vespox_card7','briefs/boki-art/cards/Vespox.jpg',3)):
    SPECS.append({'id':_id,'name':'Vespox (recolour)','refs':[_src,_VY],'runs':_runs,'aspect':'16:9' if _id.startswith('ta_') else '1:1','size':'2K','prompt':_RC}); _P63.append(_id)
_vp=next((f'briefs/boki-art/portraits/{d}Vespox.jpg' for d in ('light/','') if _o63.path.exists(HERE.parent/'portraits'/(d+'Vespox.jpg'))),None)
if _vp: SPECS.append({'id':'portrait_vespox_recolor','name':'Vespox (portrait recolour)','refs':[_vp,_VY],'runs':3,'aspect':'1:1','size':'2K','prompt':_RC}); _P63.append('portrait_vespox_recolor')
PRIORITY=_P63+PRIORITY
