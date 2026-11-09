# Round 13 (21:55 ET 11-08): owner rule "evolutions must be fundamental changes" (21:48). Strict audit failed 20 approved evolutions.
# All rebuilt with REL 'mid'/'final' (which now demand a new body plan) + the audit's direction. Parents are the current sheets;
# the face, eyes and palette carry the family resemblance.
F=" Its body plan, silhouette and pose must be fundamentally different from image 1, not image 1 with parts added."
def RX(i,n,ref,rel,body,face,cols,avoid,el,arch): V(i+'_x',n,ref,rel,body+F,face,cols,avoid,el,arch)
RX('sporcupine','Sporcupine',T+'Mycroll.jpg','mid',
 "A low, long porcupine-like creature whose quills have fused into one big domed toadstool cap over its whole back that it can raise like a hood, short sturdy legs underneath, so it reads as a huge mushroom cap on legs."+ALL4,
 "sleepy, stubborn eyes and a small grumpy pout","earthy brown and mint, with a pale cream cap accent","tall mushroom stalks, a hedgehog ball",'spore','tough')
RX('amanitusk','Amanitusk',E+'Sporcupine.jpg','final',
 "A heavy, low-slung charging boar built forward, three times the size of image 1, its red-and-white spotted fungal caps lying back into one solid spear-wedge across its shoulders, its head a battering ram of overlapping fungal plates with two curved tusks."+ALL4,
 "small, furious eyes and a tusked snarl","toadstool red and cream, with an earthy brown accent","a tall crown of stalks, standing upright",'spore','tough')
RX('vespox','Vespox',E+'Vespox.jpg','mid',
 "A low, wide, crab-walking scorpion-fox whose forelegs have become two big pincers, a segmented armoured back plate and a curled stinger tail, with a wide flat sideways stance."+ALL4,
 "sharp, mischievous green eyes and a sly grin","dusky violet and plum, with a toxic-green accent","an upright fox body, standing like image 1",'venom','fast')
RX('lashyx','Lashyx',E+'Vespox.jpg','final',
 "A whip-thin, near-legless serpentine runner twice the length of image 1, a long ribbon of fur and chitin moving sidewinder-style in a low S, with tiny claw legs and a very long three-pronged sting tail as its longest feature."+DIFF,
 "narrow, cold green eyes and a thin, cruel smile","dark violet and black, with a toxic-green accent","a fox body, four long legs, standing like image 1",'venom','fast')
RX('puffamus','Puffamus',E+'Teapotamus.jpg','mid',
 "A squat, boxy hippo whose whole body has become a cast-iron pot-belly stove: a square body on four stubby cast-iron legs, its wide mouth the glowing fire door, a short chimney growing straight out of its spine and rivets along its seams."+ALL4,
 "small brass-rimmed porthole eyes and a stubborn, huffy pout","plum grey and black iron, with a furnace-orange accent","a band or belt, a hippo wearing a stove, a hat",'ember','tough')
RX('seamwyrm','Seamwyrm',T+'Zippelith.jpg','final',
 "A huge serpent three times the size of image 1 whose whole body unzips down its length into one giant gaping mouth lined with zipper teeth, rearing forward on many small zipper-tooth legs, so its silhouette is a wide splitting maw."+DIFF,
 "glowing eyes on the tips of the zipper halves and a wide, toothy grin","denim blue and brass, with a teal glow accent","an upright worm like image 1, horns",'wyrm','majestic')
RX('galleotter','Galleotter',E+'Oarlet.jpg','final',
 "A long, low otter three times the length of image 1 whose body has become a war galley hull with plank-like fur, banks of oar-legs rowing along both sides, a carved ram prow for a head and a high stern tail fin."+DIFF,
 "proud, bright eyes and a cocky, toothy grin","river brown and honey wood, with a sea-blue accent","strapped barrels, a helmet, held oars",'tide','tough')
RX('dribbara','Dribbara',T+'Soakybara.jpg','baby',
 "A tiny capybara pup half sunk in a floating lily-pad bowl of water, only its round head and two little paws showing over the rim, a tiny sprout on its head.",
 "huge, sleepy eyes and a happy little smile","warm brown and lily green, with a pond-blue accent","a mini adult capybara with a pool on its back",'tide','cute')
RX('tinbrock','Tinbrock',T+'Anvilbrock.jpg','baby',
 "A round, dented tin-can badger cub that rolls: its body a little dented tin pot on four stubby legs, a tin-cup snout and a small bent tin-lid tail.",
 "big, bold eyes and a scrappy little grin","black and tin silver, with a warm orange accent","an anvil, a mini adult badger",'ember','cute')
RX('arcestrel','Arcestrel',T+'Kestrike.jpg','mid',
 "A long-winged falcon built like a lightning rod: a narrow, needle-shaped body diving at a steep angle, its wings swept back into long copper conductor fins and a forked copper crest."+DIFF,
 "fierce, narrowed amber eyes with dark teardrop stripes","slate blue and rust red, with a copper and electric-yellow accent","a round kestrel body like image 1, a perch",'storm','fast')
RX('eclipsowl','Eclipsowl',T+'Lunowl.jpg','final',
 "A tall, hunched great owl twice the size of image 1 whose huge moth wings wrap fully around its body like a cowled robe, its face one big round eclipse disc mask with a thin glowing ring of light around it, long talons peeking out below."+DIFF,
 "two glowing gold eyes in the dark disc and a silent, eerie stare","midnight indigo and black, with a corona-gold accent","a round owl like image 1, horns",'lunar','majestic')
RX('gongrowl','Gongrowl',T+'Gongibbon.jpg','final',
 "A massive knuckle-walking silverback ape three times the bulk of image 1, low and wide, whose shoulders and back have grown into a heavy bronze gong frame with a big round gong hanging in it, its long arms ending in mallet-headed fists."+DIFF+ALL4,
 "deep-set, fierce eyes and a booming roar","dark grey and bronze, with a gold accent","a lanky gibbon, a gong on its head, a held mallet",'echo','tough')
RX('lanternmit','Lanternmit',E+'Jarmit.jpg','mid',
 "A crab that has grown tall: long thin stilt legs lift its body high, and its shell has stretched up into a tall lantern stalk with a glowing lantern cage at the top, like a walking street lamp lit from above.",
 "small, proud eyes on stalks and a smug little smile","dark iron and warm amber, with a soft gold glow","a crab under a jar, a held lantern",'ember','pretty')
RX('stormit','Stormit',E+'Jarmit.jpg','mid',
 "A crab fused with a glass bottle into a tall tesla-coil body, standing upright on one big claw like a pedestal, copper coils wrapping its glass shell and two long arcing antennae crackling at the top.",
 "wide, jittery eyes and a nervous grin","glass green and copper, with an electric-yellow accent","a crab under a bottle, a held bottle",'storm','fast')
RX('terrarimit','Terrarimit',E+'Jarmit.jpg','mid',
 "A wide, low walking garden: the crab has spread out into a flat moss-covered island with a broken glass terrarium dome on top, ferns and flowers sprouting from its legs and back, tiny stones and a little pond on its shell.",
 "calm, kind eyes on short stalks and a gentle smile","moss green and earthy brown, with a flower-pink accent","a jar on a crab, a tall dome",'bloom','tough')
_INK2=" Its body plan, pose and silhouette must be clearly different from image 1 and from every other Ink form, not a recolour of image 1."
RX('flarmink','Flarmink',E+'Ermink.jpg','final',
 "A low, long fire weasel whose whole body is one sweeping brushstroke of flame that tapers into a long burning tail, its legs short flicks of ink-fire, racing forward."+_INK2,
 "bright, cocky orange eyes and a wide grin","ink black and flame orange, with a yellow accent","standing upright like image 1",'ember','fast')
RX('rimink','Rimink',E+'Ermink.jpg','final',
 "A tall, angular arctic stalker on long splayed snowshoe paws, with a big ice-crystal ruff around its neck and shoulders, a lean, high-shouldered body and a tail of hanging icicles, prowling through snow."+_INK2+ALL4,
 "cold, calm ice-blue eyes and a faint, sly smile","snow white and ice blue, with an ink-black accent","sitting like a cat, standing upright like image 1",'frost','sleek')
RX('umbrink','Umbrink',E+'Ermink.jpg','final',
 "A shapeless ink-shadow creature: a spreading pool of glossy black ink on the ground with only two glowing eyes, a wide grin and a few grasping ink tendrils and a stoat-like ear tuft rising out of it."+_INK2,
 "two glowing violet eyes and a wide, sharp grin","ink black and deep purple, with a violet glow accent","a stoat body, legs, standing upright like image 1",'shadow','creepy')
RX('lunink','Lunink',E+'Ermink.jpg','final',
 "A floating moth-stoat drifting through the air, broad crescent moth wings in place of its forelegs as its main shape, a small furry body and a long brush tail trailing behind like a comet's tail of silver ink."+_INK2,
 "dreamy, silver-lilac eyes and a soft smile","lilac and silver, with a moon-white accent","sitting like a cat, standing upright like image 1",'lunar','pretty')
RX('wyrmink','Wyrmink',E+'Ermink.jpg','final',
 "A long, near-limbless ink dragon whose body is one coiling calligraphy brushstroke curling through the air in a big S, a stoat face with long whiskers and small horns, and four tiny claws."+_INK2,
 "proud, glowing red eyes and a confident smile","ink black and cream, with a vermilion accent","standing upright like image 1, a stoat body",'wyrm','majestic')
PRIORITY=PRIORITY+[x+'_x' for x in ['sporcupine','vespox','arcestrel','puffamus','lanternmit','stormit','terrarimit','dribbara','tinbrock',
 'amanitusk','lashyx','seamwyrm','galleotter','eclipsowl','gongrowl','flarmink','rimink','umbrink','lunink','wyrmink']]
# Hold female looks for lines being redesigned (remake from the new sheets later).
HOLD={'gongrowl_f','eclipsowl_f','arcestrel_f','voltalon_f','portrait_sporcupine','portrait_vespox','portrait_lashyx','portrait_gongrowl','portrait_eclipsowl'}
SPECS[:]=[s for s in SPECS if s['id'] not in HOLD and s['id'][:-2] not in HOLD]
