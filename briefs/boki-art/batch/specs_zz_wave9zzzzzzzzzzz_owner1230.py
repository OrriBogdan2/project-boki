# 12:30 ET 11-09 owner (chat 12:30): Gongrowl must face the camera more, stand up higher, and beat its chest more aggressively.
# The shared CARD() text forbids front views, attack poses and upright stances, which is why gongrowl_cardc only turned a little,
# so this card prompt is written without those three lines (a gorilla rearing up to beat its chest is natural behaviour).
_O='briefs/boki-art/batch/out/'
def _GC(i,pose):
    SPECS.append({'id':i,'name':'Gongrowl (hero card, chest beat)','refs':[_O+'gongrowl_cardb_1.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one Boki (a stylised creature-collector monster): Gongrowl, the huge gorilla-like creature in image 1, redrawn in the Boki house style of image 2. "
        "Image 1 is the identity reference only: keep exactly the same creature, face, fur colours, scars and the bronze gong grown into its chest, with nothing added, removed or redesigned; ignore its pose and camera angle. "
        "Image 2 is the style reference only (ignore its dark backdrop and floor shadow): match its soft hand-painted shading, clean fairly thin dark outline and big glossy eyes, never its designs. "
        "Pose (most important): "+pose+" "
        "Framing: exactly one creature, the whole body in frame from the top of the head to the feet, centred, with about 8 percent margin, big in the frame. "
        "Background: one plain, flat, pale grey (#E8E8EE) background, no ground, no rocks, no shadow, no glow halo, no shockwave rings, no motion lines, no text.")})
_GC('gongrowl_cardx',"reared up tall on its hind legs like a real gorilla beating its chest, body facing the viewer almost straight on (no more than 15 degrees turned), head up and roaring right at the viewer with its mouth wide open, both fists mid-swing pounding the bronze gong on its chest hard, shoulders hunched forward with raw aggression. Viewed from a slightly low angle so it looms over the viewer.")
_GC('gongrowl_cardy',"standing upright at full height facing the viewer head-on, chest thrust out, one fist slamming into the bronze chest gong and the other drawn back for the next blow, roaring at the viewer, feet planted wide. A furious, intimidating display, like a silverback warning off a rival.")
P('gongrowl_px','Gongrowl',_O+'gongrowl_cardb_1.jpg','reared up on its hind legs facing the viewer, roaring and pounding the bronze gong on its chest with both fists')
