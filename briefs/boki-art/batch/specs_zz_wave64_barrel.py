# Owner 03:34 ET 11-09: "barrelmander and cisternmander need to lose the lightning cloud and have some other gimmick" (another
# character already has a rain cloud). Owner un-locks Cisternmander. Three line-wide gimmicks (A/B/C) for all three stages so the
# line stays consistent; the art session picks one letter for the whole line. Cisternmander must also be a real step up, not
# Barrelmander made longer.
_BR='briefs/boki-art/turnarounds/Barrelmander.jpg'; _P64=[]
_AVB="a cloud, a storm cloud, rain, lightning bolts in the air, a separate object it carries, a building, a ladder, standing upright, a busy design"
_G={'A':("hydro power: a little wooden paddle water-wheel grown into its tail that spins and throws small sparks",
         "hydro power: a big wooden paddle water-wheel built into its tail and copper turbine fins along its sides, crackling with sparks",
         "hydro power: a huge water-wheel tail and a dam-like plank collar of copper turbines, water churning and sparking through it"),
    'B':("a battery: copper and zinc terminal nubs on top of its barrel body with a tiny spark jumping between them",
         "a battery: its barrel body is a wet-cell battery with two big copper terminal posts on its back joined by an arcing spark, copper wire bands instead of iron hoops",
         "a giant battery: its body is a huge wooden storage tank cell with a tall copper coil tower on its back crackling with a contained arc, copper wire bands"),
    'C':("a spigot: a little brass tap on its side that drips glowing charged water",
         "spigots: brass taps and copper pipes on its barrel body, one tap spraying an arc of glowing charged water",
         "a pump house: a big brass pump handle-crest on its back and copper pipes along its body, spraying jets of glowing charged water from its taps")}
for _L,(_b1,_b2,_b3) in _G.items():
    VC('bucketmander_g'+_L.lower(),'Bucketmander',_BR,'baby',"A small chubby salamander larva with feathery gills whose body is a little wooden bucket of staves with one iron hoop, and its gimmick is "+_b1+". One clear idea, few parts.","tiny beady eyes and a big lazy grin","wood brown and slate grey, with an electric-yellow accent",_AVB,'storm','cute'); _P64.append('c_bucketmander_g'+_L.lower())
    SPECS.append({'id':'c_barrelmander_g'+_L.lower(),'name':'Barrelmander (gimmick '+_L+')','refs':[_BR],'runs':4,'aspect':'1:1','size':'2K',
      'prompt':("Creature-collector monster concept art, soft hand-painted style exactly like image 1. This is Barrelmander from image 1: keep its"
       " face, wooden barrel body, iron-or-copper hoops, salamander legs and tail and colours, but REMOVE the storm cloud and lightning above it"
       " completely, and give it a new gimmick: "+_b2+". ONE creature only, full body, gentle three-quarter view, centred with about 8 percent"
       " margin, plain flat pale grey background, no shadow, no text, no cloud, no rain.")}); _P64.append('c_barrelmander_g'+_L.lower())
    VC('cisternmander_g'+_L.lower(),'Cisternmander',_BR,'final',"A giant, towering salamander, a real step up from image 1 (not the same barrel body made longer): a tall, broad body built like a big wooden water tank on thick planted legs, a huge heavy head and a broad flat tail, and its gimmick is "+_b3+". One clear idea, few parts.","small, calm yellow eyes and a wide, slow grin","wood brown and slate grey, with copper and an electric-yellow accent",_AVB,'storm','tough'); _P64.append('c_cisternmander_g'+_L.lower())
PRIORITY=_P64+PRIORITY
