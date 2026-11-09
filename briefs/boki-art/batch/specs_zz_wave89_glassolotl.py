# 04:52 ET 11-09 owner (again): Glassolotl needs a different FACE and ANGLE/POSE from her t1 Prismander.
# f1-f3 kept Prismander's left-facing low crawl and round smiling face. These force a new view, pose and face,
# bridging toward Chandelotl d1 (four-legged crystal candy salamander with a rainbow sugar-glass sail).
_C='briefs/boki-art/cards/'
_G=[("facing RIGHT in a clean side-on profile, mid-leap off the ground with all four legs stretched, body arched",
     "A lanky teenage crystal-candy axolotl-salamander with longer legs than the baby, a longer narrower snout, swept-back frilly gills and a small rainbow sugar-glass fin starting to grow along the spine.",
     "narrow, sharp, confident eyes and a cocky open-mouthed grin showing small teeth"),
    ("seen from the front-left, rearing up on its hind legs with front paws raised and tail swinging behind for balance",
     "A sleek, slimmer crystal-candy salamander with an elongated neck, an angular head with a pointed snout, short stubby gills, and jagged crystal shards on its shoulders.",
     "half-lidded, mischievous eyes and a sideways smirk"),
    ("viewed from above at a three-quarter angle facing RIGHT, swimming fast through the air with legs tucked and tail whipping in an S-curve",
     "A streamlined, eel-like crystal-candy salamander with a long tail fin of clear sugar glass, slim body and a wedge-shaped head.",
     "focused, determined eyes with a fierce little frown")]
for _k,(_view,_b,_f) in enumerate(_G,1):
    SPECS.append({'id':f'c_glassolotl_g{_k}','name':'Glassolotl (concept)','refs':[_C+'Glassolotl.jpg',SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 shows this creature's current design: keep its candy-stripe pink, red and mint crystal palette and translucent sugar-glass look, but give it a NEW face, NEW proportions and a NEW pose. "
        "Image 2 is the style reference only (soft hand-painted shading, clean thin dark outline, big glossy eyes); never copy its creatures. "
        f"ONE creature only, full body, {_view}, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
        +CORE+LESSONS+desc(_b+" Do NOT repeat the baby's round head, big round eyes, gentle smile or low left-facing crawl. One clear idea, few parts.",_f,"candy pink, red and mint stripes, with rainbow crystal glints","the baby's face and pose, a left-facing crawl, held objects, other creatures",'prism','majestic'))})
