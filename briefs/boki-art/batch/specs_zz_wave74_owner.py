# Owner 03:41 ET 11-09: "parasolth needs to be way cuter and tinier"; "i dont like ribbonwyrm's wings, i think it needs a rerun"
# (flat diamond kite panels look stuck on). Kerchick: owner reports it is bugged in the Bokidex (main's page) - flagged to main.
_P74=[]
for _k,_b in (('p1',"A tiny, round baby sloth like a fuzzy ball, huge sleepy eyes, wrapped in a little closed umbrella-rib bat-wing cape like a cocoon with only its face peeking out."),
              ('p2',"A tiny baby sloth hanging upside down by its little hook claws from its own tail, its small umbrella-rib wings folded like a mini closed parasol around its round body, huge eyes."),
              ('p3',"A minuscule chubby sloth baby curled up with a little open umbrella-rib wing held over its head like a parasol, tiny stubby limbs, rosy cheeks and a sleepy smile."),
              ('p4',"A tiny, plush baby sloth sitting in a ball, its two small bat-wing umbrella flaps draped over its shoulders like a tiny poncho, enormous dark eyes and a tiny smile.")):
    VC('parasolth_'+_k,'Parasolth','briefs/boki-art/evolutions/Parasolth.jpg','redo_of',"Same idea as image 1 but WAY cuter and much tinier, clearly a baby: "+_b+" One clear idea, few parts.","enormous soft violet eyes and a sleepy little smile","charcoal grey and cream, with a soft violet accent","bones that look scary, a skeleton, standing upright, held umbrella, a busy design",'shadow','cute'); _P74.append('c_parasolth_'+_k)
_RWA="flat diamond kite panels for wings, kite frames, wings stuck onto the back, standing upright, held objects, a busy design"
for _k,_b in (('w1',"A slender ribbon dragon with NO wings: its long body ripples like a dancing ribbon, long silk ribbon streamers flowing from its shoulders, elbows and tail in loops, a fluffy fringe mane, gliding in an S-curve."),
              ('w2',"A slender kite dragon whose wings are long, thin, flowing silk ribbon fins that grow from its shoulders and trail behind it in curls, a tail ending in a bow of ribbons, mid-glide."),
              ('w3',"A slim serpentine dragon with two pairs of small, soft, rounded fin-wings made of layered silk ribbons like a festival streamer, a long trailing ribbon tail with knotted bows, swimming through the air."),
              ('w4',"A playful ribbon dragon coiling in loops, its back lined with a single long frilled silk fin like a ribbon dancer's streamer, small paws, a long tail tied with little bows, no separate wings.")):
    VC('ribbonwyrm_'+_k,'Ribbonwyrm','briefs/boki-art/evolutions/Ribbonwyrm.jpg','redo_of',"Same creature, colours and face as image 1 but new wings: "+_b+" One clear idea, few parts.","bright, cheeky amber eyes and a playful grin","cream and coral red, with a gold accent",_RWA,'tempest','pretty'); _P74.append('c_ribbonwyrm_'+_k)
PRIORITY=_P74+PRIORITY
