# Owner 03:10 ET 11-09: "Chandelotl prob needs to move away from the chandelier thing and look more distinct / epic from the t2
# evolution". Three final-form directions from the live Glassolotl v3 (rock candy, crystal gills/tail). Each is a big planted
# final stance (never rearing upright), stays rock candy, and must not overlap Geodelotl (low, heavy, chunky crystal crust, club tail).
_GV='briefs/boki-art/evolutions/Glassolotl.jpg'; _P55=[]
_AV="a chandelier, hanging drops, crowns, candles, chains, standing upright on its hind legs, a chunky crystal crust on the back, a club tail, rainbow effects, a busy design"
VC('chandelotl_d1','Chandelotl',_GV,'final',
 "An epic sugar-glass dragon axolotl: a long, powerful body planted wide on four strong legs with its chest raised and head held high, a tall translucent spun-sugar sail fin running from the back of its head to the tail tip like stained candy glass, and its gills grown into a long sweeping mane of spun sugar. The candy-cane stripe spirals along the whole body. One clear idea, few parts.",
 "fierce, confident glossy eyes and a proud closed-mouth smile","strawberry pink and clear sugar white, with a mint-green accent and a hint of gold in the sail",
 _AV,'prism','majestic'); _P55.append('c_chandelotl_d1')
VC('chandelotl_d2','Chandelotl',_GV,'final',
 "An epic candy-cane serpent axolotl: a long thick coiled body braced on four short powerful legs, its front half raised like a cobra with the gills spread into a wide hood of sugar-glass frills behind its head, a bold red-and-mint candy-cane spiral running the full length, and the tail curling around its feet. One clear idea, few parts.",
 "sharp, regal glossy eyes and a sly grin","strawberry red and clear sugar white, with a bold mint-green spiral",
 _AV,'prism','majestic'); _P55.append('c_chandelotl_d2')
VC('chandelotl_d3','Chandelotl',_GV,'final',
 "An epic crystal-candy wyrm axolotl: a sleek, muscular body striding forward on four planted legs, two long rock-candy crystal horns swept back from where the gills were (the gills now short frills around them), a single row of tall clear sugar-crystal blades down the spine, and a long tail ending in a wide faceted sugar-crystal fan fin. One clear idea, few parts.",
 "bold, determined glossy eyes and a toothy grin","clear sugar white and strawberry pink, with mint-green stripes and a faint violet glint in the crystals",
 _AV,'prism','majestic'); _P55.append('c_chandelotl_d3')

# Owner 03:14: "make like 10 variations in the queue and pick the best ones" -> 7 more directions (10 total).
_MORE=[
 ('d4',"An epic stained-candy-glass leviathan axolotl: a broad, long body planted wide and low-chested on four strong legs, head raised high, its sides set with large translucent panels of coloured sugar glass framed by thin pink candy lines like a stained-glass window, gills grown into long flowing ribbons of sugar glass.","serene, wise glossy eyes and a soft knowing smile","clear sugar white and strawberry pink, with mint, lemon and soft violet glass panels"),
 ('d5',"An epic lollipop-maned lion axolotl: a powerful four-legged body in a proud planted stance with chest out, its gills grown into a big round mane of swirled lollipop discs ringing its head, the candy-cane stripe spiralling down its strong tail.","bold, proud glossy eyes and a big confident grin","strawberry pink and sugar white, with mint and raspberry swirls in the mane"),
 ('d6',"An epic spun-sugar winged axolotl: a strong four-legged body planted firmly with its head raised, two large translucent spun-sugar fin-wings half spread from its shoulders (fin-like, not feathered, no flying), gills swept back into long glassy streamers, faceted sugar-crystal tail fin.","bright, fearless glossy eyes and an excited open grin","clear sugar white and strawberry pink, with mint-green wing veins"),
 ('d7',"An epic sugar-crystal kirin axolotl: an elegant long-legged body standing tall and planted on four slender legs like a noble deer, its gills grown into branching rock-candy crystal antlers, a long flowing spun-sugar tail fin, the candy-cane stripe winding along its neck and body.","calm, regal glossy eyes and a gentle smile","clear sugar white and strawberry pink, with mint-green stripes and pale gold antler tips"),
 ('d8',"An epic candy sea-dragon axolotl: a long, flowing body planted on four legs with its neck arched proudly, leafy fronds of translucent sugar glass growing all along its back, legs and tail like a leafy seadragon, gills grown into larger frond-like plumes.","curious, graceful glossy eyes and a small smile","strawberry pink and clear sugar white, with mint and soft lemon frond tips"),
 ('d9',"An epic peppermint titan axolotl: a huge broad-chested body standing tall and planted on four thick pillar legs, big round polished peppermint-candy discs set into its shoulders and hips like armour, gills grown into thick candy-cane horns curling forward, a long powerful striped tail.","fierce, steady glossy eyes and a tough grin","peppermint red and sugar white, with a mint-green accent"),
 ('d10',"An epic molten-caramel glass drake axolotl: a muscular body in a low, powerful planted stance ready to pounce, its body clear amber hard caramel glass with the pink candy stripe glowing through, gills grown into long dripping caramel-glass spikes swept back, and a broad faceted caramel tail fin.","intense, fiery glossy eyes and a fanged grin","clear amber caramel and strawberry pink, with a cream and mint accent"),
]
for _k,_b,_f,_c in _MORE:
    VC('chandelotl_'+_k,'Chandelotl',_GV,'final',_b+" One clear idea, few parts.",_f,_c,_AV,'prism','majestic'); _P55.append('c_chandelotl_'+_k)
for _i in _P55: [s for s in SPECS if s['id']=='c_'+_i[2:] or s['id']==_i][-1]['runs']=4
PRIORITY=_P55+PRIORITY
