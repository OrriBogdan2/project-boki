# Owner 03:16 ET 11-09: "nettlynx evolution line looks the same throughout and face is very ai cat" and
# "boltstrich thunderstrich also no diff between t2 and t3". Owner un-locks Thistlynx and Thunderstrich.
import os as _o58
def _sh(n): return 'briefs/boki-art/'+next(d for d in ('turnarounds','evolutions') if _o58.path.exists(HERE.parent/d/f'{n}.jpg'))+f'/{n}.jpg'
_FACE=(" Face: a stylised, cartoony creature-collector face with simple bold shapes, big glossy eyes and a small nose,"
       " never a realistic cat face, no realistic fur texture or detailed whiskers.")
_P58=[]
# Nettlynx line: one shared design language (tawny + nettle green + lime venom) but three clearly different silhouettes.
_AVL="a realistic lynx or house cat face, flowers, the same body shape as image 1, standing upright, a busy design"
for _k,_n,_rel,_ref,_b,_f in (
 ('a','Nettlynx','baby','Thistlynx',"A tiny round fuzzy kitten-ball covered in soft nettle fuzz, two oversized nettle-leaf ears, a short stubby tail ending in a little tuft of stinging hairs, sitting in a round bouncy pose.","huge round glossy green eyes and a tiny cheeky fang"),
 ('b','Nettlynx','baby','Thistlynx',"A small chubby lynx kitten with a big round head, nettle-leaf ear tufts, a soft collar of nettle leaves round its neck, and a curled tail tipped with a small green stinging bud, mid-bounce with its paws tucked.","big glossy green eyes and a mischievous grin"),
 ('a','Thistlynx','mid','Nettlynx',"A lean, long-legged young lynx caught in a low prowl, its neck ringed with a spiky mane of round thistle-burr puffs, tall pointed thistle ear tufts, and a long tail ending in a big spiky thistle-ball.","sharp, narrowed green eyes and a sly smirk"),
 ('b','Thistlynx','mid','Nettlynx',"A sleek young lynx mid-pounce, stretched long and low, with rows of thistle spines running down its back like a ridge, burr-ball cheek tufts framing its face, and a whip-like tail tipped with stinging hairs.","eager, bright green eyes and an open grin"),
 ('a','Briarlynx','final','Thistlynx',"A huge, heavy sabre-toothed lynx braced wide and planted, a thick mane of coiling briar vines wrapping its shoulders and forelegs like armour, two long curved thorn sabre fangs, and a long thorn-vine whip tail.","fierce, deep green eyes and a calm, dangerous look"),
 ('b','Briarlynx','final','Thistlynx',"A towering briar beast-lynx rearing tall on its back legs with front paws raised and claws out, its whole back a dense thicket of thorny briar, a crown of thorn spikes behind its head, and venom-lime thorn tips on its shoulders.","blazing green eyes and a fanged roar"),
):
    VC(_n.lower()+'_l'+_k,_n,_sh(_ref),_rel,_b+_FACE+" One clear idea, few parts.",_f,"tawny brown and nettle green, with a toxic lime accent",_AVL,'venom','cute' if _rel=='baby' else ('fast' if _rel=='mid' else 'tough'))
    _P58.append('c_'+_n.lower()+'_l'+_k)
# Thunderstrich: a clearly different final from Boltstrich (which runs as a grey cloud ostrich).
_AVT="the same body as image 1, a plain ostrich with wings added, running, flying, effects that cover the body, a rider, a saddle, a busy design"
for _k,_b,_f in (
 ('a',"A huge storm thunderbird ostrich braced wide and planted, its body puffed into one great dark thundercloud with a crackling silver underside, two thick copper lightning-rod legs, a short powerful neck and a big head with a tall crest of forked copper lightning-rod feathers.","fierce yellow eyes and an open-beaked war cry"),
 ('b',"A towering storm ostrich standing tall and proud, its long neck coiled like a copper storm-coil spring, small cloud-puff wings raised wide like shields, its tail a huge fan of dark storm-cloud plumes with copper tips, and big clawed copper feet planted apart.","proud, crackling yellow eyes and a stern glare"),
 ('c',"A massive armoured storm ostrich lowered into a charging-bull stance, head down and forward, its body plated in overlapping dark cloud-feathers like storm armour, a heavy copper beak like a battering ram, and three tall forked copper plumes on its head.","narrow, stubborn yellow eyes"),
):
    VC('thunderstrich_l'+_k,'Thunderstrich',_sh('Boltstrich'),'final',_b+" One clear idea, few parts.",_f,"storm grey and copper, with an electric-yellow accent",_AVT,'storm','tough')
    _P58.append('c_thunderstrich_l'+_k)
PRIORITY=_P58+PRIORITY
