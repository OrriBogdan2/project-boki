# Round 11 (21:15 ET 11-08): rerolls from grader batch B (all 5 rejected).
ONEROW=" A single row of four views only, nothing above or below them, no faded duplicate."
B('puffamus_r3','Puffamus',
 "A stout young hippo, half grown, whose whole hide has become black iron plates with rows of rivets and glowing orange seams between them, a round firebox door grown into its chest glowing from inside, and two short chimney-horn vents growing from its brow that puff steam. No barrel shape, no band or ring around it, no hat."+ALL4,
 "small brass-rimmed porthole eyes and a stubborn, huffy pout, steam from its nostrils","plum grey and black iron, with a brass and furnace-orange accent",
 "a band or belt around its middle, a stove barrel, a top hat, a locomotive, anything rolling, standing upright",'ember','tough')
V('kayak_r','Kayak',T+'Prowyak.jpg','baby',
 "A tiny, round, fluffy yak calf half the size of image 1, with a small pale bone-and-ice ridge grown from the fur on its forehead like the start of a boat's prow, stubby legs, a puffy tail and frost crystals in its fluff."+DIFF+ONEROW,
 "big, curious eyes and a determined little huff","frost white and pale grey, with an ice-blue accent",
 "a dark helmet plate, a boat, a rider, a ghost row",'frost','cute')
V('howlop_r','Howlop',T+'Echolop.jpg','final',
 "A massive, predatory bat-hare three times the size of image 1, its long, low, heavy body crouched flat in a stalking pose on all fours with its head thrust forward, huge bat-wing ears swept back like blades, a heavy shoulder hump, sabre fangs, sound-ring ripples rolling off its ears and a long whip tail."+DIFF+NOCOPY+ALL4,
 "glowing violet eyes and a wide, fanged snarl","dusky plum and black, with a violet accent",
 "the slim rabbit body of image 1, flying, sitting up like a person",'echo','fast')
V('thunderstrich_r','Thunderstrich',T+'Boltstrich.jpg','final',
 "A hulking storm ostrich twice as bulky and much taller than image 1, mid-stride, whose body is a towering dark thundercloud with lightning flickering inside, a crown crest of copper lightning-rod plumes, a thick neck with copper vein-ridges growing from inside it, and wings spread wide like thunderheads."+DIFF+NOCOPY,
 "wild, blazing eyes and a manic shriek","storm grey and copper, with an electric-yellow accent",
 "rings or coils around its neck, the poses of image 1, a realistic ostrich, a rider",'storm','majestic')
V('wickapi_r','Wickapi',T+'Snuffapi.jpg','baby',
 "A tiny, round chibi okapi fawn half the size of image 1, with a huge head, stubby legs and a little round body, a dripping-wax pattern in its striped fur on its forehead that rises into one small grown wick with a violet flame, and soft wax-drip stripes on its legs."+DIFF+NOCOPY,
 "big, shy eyes and a soft smile","deep brown and cream, with a violet flame accent",
 "a realistic okapi, long legs, a candle stuck on its head, gold bands, antlers",'shadow','cute')
# Batch A grades: Chandelapi pass (C); Fizzlet B is close but its copper ankle cuffs read as worn bands -> edit job; 3 rerolls.
X('fizzlet_e','Fizzlet',E+'Fizzlet_draft.jpg',
 "turn the copper rings around its ankles into small copper scales that are part of its feet, with no cuffs or bands around the legs, and keep the yellow sparks fewer and smaller.",runs=3)
P('chandelapi','Chandelapi',E+'Chandelapi.jpg','standing tall and proud, head turned, its candelabra crown lit')
U('chandelapi','Chandelapi',E+'Chandelapi.jpg')
V('chimelop_r','Chimelop',T+'Echolop.jpg','final',
 "A long-legged, slender hare twice the size of image 1, caught mid-leap, whose long ears grow into scalloped silver flares shaped like bells, with no separate hanging bells, a bell-shaped fluffy tail and fine silver ripples in its fur."+DIFF+NOCOPY,
 "calm, dreamy violet eyes and a gentle smile","pale lavender and silver, with a moonlight accent",
 "hanging bells, crouching like image 1, sitting up like a person, a held bell",'echo','pretty')
V('cisternmander_r','Cisternmander',T+'Barrelmander.jpg','final',
 "A giant, long, low, wide salamander three times the size of image 1, sprawled on all four legs in every view, whose whole torso is one stretched-out horizontal cistern of dark wooden staves, its head emerging from the front end like a ship's prow, the iron hoops grown as raised bony ridges, an open hatch midway along its back with a small storm cloud rumbling above it, and a long finned tail."+DIFF+NOCOPY+ALL4,
 "tiny eyes and a wide, slow grin","wood brown and slate grey, with an electric-yellow accent",
 "a bucket on its back, a helmet, standing upright, standing on its knuckles, a building, a ladder",'storm','tough')
V('dreadnoyak_r','Dreadnoyak',T+'Prowyak.jpg','final',
 "A mountain-sized yak three times the size of image 1, with a huge hunched shoulder hump of layered ice-armoured iron plates grown into its back, a split icebreaker ram jutting forward from its brow, tusk-like ram horns sweeping forward and a long icicle-crusted coat dragging on the ground."+DIFF+NOCOPY+ALL4+ONEROW,
 "small, unstoppable eyes and a deep, stubborn glare","frost white and dark iron, with an ice-blue accent",
 "the flat shield face plate of image 1, a harness, straps, a ship, a figurehead, a rider",'frost','tough')
