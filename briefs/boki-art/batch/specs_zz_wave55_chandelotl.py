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
for _i in _P55: [s for s in SPECS if s['id']=='c_'+_i[2:] or s['id']==_i][-1]['runs']=4
PRIORITY=_P55+PRIORITY
