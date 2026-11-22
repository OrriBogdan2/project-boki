# 04:52 ET 11-09 owner: "new vespox looks too much like vespyx". Mid stage (in motion, grubbier, surprise turn) between
# baby Vespyx (round plum fox kit, scorpion tail, green venom bead) and final Glaivyx (tall long-legged blade-tail fox).
# Keep the line palette (plum, lilac, acid green); change the body plan and face clearly.
_C='briefs/boki-art/cards/'
_V=[("A scrappy, lanky adolescent desert jackal-fox mid-stride, ribs showing, with dark glossy chitin plates growing over its back and shoulders like a half-formed shell, and TWO short curled stinger tails dripping green venom.",
     "narrow, wary eyes and a snaggle-toothed snarl, longer muzzle than the baby"),
    ("A low, crouching, prowling fox wearing a grown scorpion-shell hood over its head and neck like a cowl, long whiskers, oversized pincer-like claws on its front paws, and a long segmented stinger tail arched over its back.",
     "half-hidden glowing eyes under the shell hood and a sly sneer"),
    ("A wiry, mangy-looking fox running fast on long thin legs, with a spiky chitin ridge down its spine, ragged ears notched like a fighter, and a thin whip-like stinger tail streaming venom droplets behind it.",
     "fierce, hungry eyes and a toothy grin, sharper face than the baby")]
for _k,(_b,_f) in enumerate(_V,1):
    VC(f'vespox_v{_k}','Vespox',_C+'Vespyx.jpg','mid',_b+" It must NOT look like a bigger copy of Vespyx: different proportions, head shape, posture and silhouette. One clear idea, few parts.",
       _f,"plum purple and lilac, with an acid-green venom accent","the baby's round cute body and face, a sitting pose, held objects, effects, text",'venom','tough')
