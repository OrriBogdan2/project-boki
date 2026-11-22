# Owner 03:16 ET 11-09: "barokat looks great but has same mink bodytype still". Keep the whole design (meerkat, built-in barometer
# belly dial, brass horn ears, little rain cloud, lightning-rod tail) and change only the body type, away from the long slim
# upright stoat/mink build used by the Ermink branches.
_BK='briefs/boki-art/turnarounds/Barokat.jpg'; _P59=[]
_BKBASE=("Creature-collector monster concept art for a fantasy action game, soft hand-painted style exactly like image 1 (clean, fairly thin dark outline,"
 " painterly shading, big glossy eyes). This is Barokat from image 1: keep its face, colours, brass horn ears, the barometer dial built into its belly,"
 " the little rain cloud above its head and its lightning-rod tail exactly, but give it a completely different body type: ")
_BKEND=(" Never the long, slim, upright stoat or mink build of image 1. ONE creature only, full body, gentle three-quarter view with the head turned toward"
 " the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no extra effects.")
for _k,_b in (('b1',"a short, round, pear-shaped little meerkat, much chubbier and squatter, with a big round head, a plump round belly that is the barometer dial, short stubby legs and tiny paws, sitting back on its haunches like a lookout."),
              ('b2',"a compact, chunky meerkat standing low on all four short, sturdy legs like a little badger, broad round body with the barometer dial on its side, big round head lifted and alert, thick short tail with the lightning-rod tip held up."),
              ('b3',"a round, fluffy ball-shaped meerkat perched on its short hind legs with its stubby front paws folded over the round barometer belly, a very big head and short neck, wide hips, almost egg-shaped overall.")):
    SPECS.append({'id':'c_barokat_'+_k,'name':'Barokat (body redo)','refs':[_BK],'runs':4,'aspect':'1:1','size':'2K','prompt':_BKBASE+_b+_BKEND}); _P59.append('c_barokat_'+_k)
PRIORITY=_P59+PRIORITY
# Owner Dex rating notes still open (sheets re-marked redo after the last tries):
#  sporcupine-2d: "the mushrooms are too high and kind of weird, maybe if they were spiky or something"
#  teapotamus-2d: "Can be cuter"
import os as _o59
def _sh59(n): return 'briefs/boki-art/'+next(d for d in ('turnarounds','evolutions') if _o59.path.exists(HERE.parent/d/f'{n}.jpg'))+f'/{n}.jpg'
for _n,_k,_b in (('Sporcupine','s1',"keep the porcupine and its colours, but its quills are now short, spiky mushroom spines lying close along its back (pointed conical caps like quills, low, not tall stalks), so it reads as a porcupine first."),
                 ('Sporcupine','s2',"keep the porcupine and its colours, but replace the tall mushrooms with a dense coat of short spiky fungal quills, each a thin pointed spore spike with a tiny cap, raised in a low fan along its back and tail."),
                 ('Teapotamus','t1',"make it much cuter: a smaller, rounder baby hippo with a bigger head, huge glossy eyes, tiny stubby legs, rosy cheeks and a tiny teapot-spout snout, its round teapot body softer and smoother, sitting with a happy little puff of steam."),
                 ('Teapotamus','t2',"make it much cuter: a chubby baby hippo shaped like a round little teapot, big round head with huge sparkling eyes and a big happy smile, little lid on its head like a cap, tiny curled handle tail, bouncing on stubby legs.")):
    SPECS.append({'id':'c_'+_n.lower()+'_'+_k,'name':_n+' (owner note redo)','refs':[_sh59(_n)],'runs':4,'aspect':'1:1','size':'2K',
      'prompt':_BKBASE.replace('This is Barokat from image 1: keep its face, colours, brass horn ears, the barometer dial built into its belly, the little rain cloud above its head and its lightning-rod tail exactly, but give it a completely different body type: ','This is '+_n+' from image 1, redesigned per the owner: ')+_b+_BKEND.replace(' Never the long, slim, upright stoat or mink build of image 1.','')})
    _P59.append('c_'+_n.lower()+'_'+_k)
PRIORITY=[i for i in _P59 if i not in PRIORITY]+PRIORITY
