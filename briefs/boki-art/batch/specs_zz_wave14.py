# Round 14 (22:15 ET 11-08): first three-seat panel results (groups 1-2, 14 jobs, 0 passes). Near-misses -> edits of the best run;
# the rest -> new prompts from the panel's consensus fixes. V jobs no longer send the second style ref (it leaked other Boki into sheets).
O='briefs/boki-art/batch/out/'
def XE(i,n,src,instr): X(i,n,O+src,instr,runs=3)
ONE=" Exactly four views (front, three-quarter, side, back) in one clean row, one creature only, no ghost or faded copies, no shadows under the feet."
# --- edits (panel average 7.8-8.1)
XE('briarlynx_e','Briarlynx','briarlynx_2.jpg',"turn the vine sleeves on its legs into thorns growing out of the fur with tawny fur showing between them, grow the briar hide over the hind legs too, and give it large serrated briar-leaf lynx ears.")
XE('chandelotl_e','Chandelotl','chandelotl_x_1.jpg',"lay it out as four views in one row (front, three-quarter, side, back) with a true back view, remove the rainbow trail effects, give the body a little more mass and the head a bigger, more characterful face with narrowed eyes and a sly grin, and push the pink and rainbow prism colours stronger.")
XE('blossmink_e','Blossmink','blossmink_x_1.jpg',"put the front view on all four legs like the side view, give it Ermink's ivory-and-ink face mask and belly, grow the blossoms out of moss clusters instead of loose petals, and add black ink-tipped claws and a hint of fang.")
XE('amanitusk_e','Amanitusk','amanitusk_x_2.jpg',"remove the faded duplicate legs and shadows under the feet, merge the caps into one forward-swept spear-wedge across the shoulders, and replace the realistic pig face with a stylised battering-ram head of overlapping fungal plates with big tusks and a cocky grin.")
XE('arcestrel_e','Arcestrel','arcestrel_x_3.jpg',"make the crest a clear forked copper rod, turn the wing tips into solid copper conductor fins with banded coil joints, run a copper rod down the tail spine, enlarge the head with big orange eyes and a fierce grin, and show its talons tucked under the body in every view.")
# --- new prompts
V('bellowlet_r','Bellowlet',T+'Bellowary.jpg','baby',
 "A near-spherical fluffy soot-black chick, its head as big as its body, tiny stub legs barely showing, almost no neck, the bellows as glowing ember ribs in its round belly, a little nozzle beak puffing sparks and a small brass nub crest."+ONE,
 "big orange eyes and a cocky little grin","soot black and brass, with an ember-orange accent","long legs, a long neck, a box or harness on its chest",'ember','cute')
V('bucketmander_r','Bucketmander',T+'Barrelmander.jpg','baby',
 "A tiny tadpole-like salamander larva with a soft round body and a big head, no back legs yet, feathery gills, only a few short wooden stave plates on its back, a stubby stave-tipped tail fin and a thumb-sized raincloud puff above its head. No full barrel and no hoops around the body or limbs."+ONE,
 "tiny beady eyes and a big lazy grin","wood brown and slate grey, with a yellow accent","a barrel body, hoops or bands, a bucket it sits in",'storm','cute')
B('buckleron_r2','Buckleron',
 "A flat, wide sea limpet whose low domed shield shell grows straight out of its body with no brim or lip, cracked stone and iron plates with rivets and barnacles flowing down onto a thick plated snail-like foot, one big boss spike as the shell's peak, and two long eye stalks with a stubborn little face at the front."+ONE,
 "grumpy round eyes on stalks and a puffed, stubborn mouth","dark iron and sea grey, with a barnacle-white and sea-green accent","a helmet, a brim, legs, a toad face",'stone','tough')
V('chandelapi_r2','Chandelapi',T+'Snuffapi.jpg','final',
 "A gaunt, towering spectral okapi with a long, drooping swan-like neck, its front half solid and its rear half dissolving into drifting violet smoke so it floats on its front legs, its antlers and ribcage one twisted wrought-iron chandelier frame growing from its skull and chest with wax candles fused in and violet flames, wax-drip stripes on its legs."+ONE,
 "calm, glowing violet eyes and a wry, eerie smile","deep brown and wrought-iron black, with a violet flame accent","chains above its head, a hanging frame, ankle cuffs, a realistic okapi",'shadow','majestic')
V('chimelop_r2','Chimelop',T+'Echolop.jpg','final',
 "A long-limbed silver hare twice the size of image 1, caught mid-leap in every view with its body stretched and arched in the air, its ears swept back as huge scalloped silver bell-mouth flares like wings, a flared bell-shaped tail, much longer hind legs and silver ripple patterns down its back."+ONE,
 "calm, proud violet eyes and a gentle smile","pale lavender and silver, with a moonlight accent","crouching like image 1, hanging bells, clappers, sitting up like a person",'echo','pretty')
V('cisternmander_r2','Cisternmander',T+'Barrelmander.jpg','final',
 "A huge, low, wide salamander three times the size of image 1, whose back is an open cistern basin full of storm water with lightning arcing across it, its flanks plated with wooden stave ribs fused into its body (no hoops on its limbs or belly), a heavy wide jaw with a prow-like snout ridge, storm-charged fin spines along its tail."+ONE+ALL4,
 "tiny eyes and a wide, slow, toothy grin","wood brown and slate grey, with an electric-yellow accent","hoops or bands around the legs or belly, a bucket on its back, standing upright",'storm','tough')
V('coolatee_r','Coolatee',T+'Frigatee.jpg','baby',
 "A tiny manatee calf curled up like a round bean, mostly head, with stubby little flippers and a small frosted lid-shell patch grown between its shoulders, no latch."+ONE,
 "big, sleepy, sweet eyes and a tiny whiskery smile","cream and frost blue, with a brass accent","other creatures, the latch plate of image 1, looking like image 1",'frost','cute')
V('anchorbill_r2','Anchorbill',SR,'mid',
 "A squat, wide, low ground hornbill crouched on heavy iron-plated talons, whose casque IS the iron shank of an anchor growing out of the skull with no band, rim, ring or crown, its bill tip splitting into the two curved anchor flukes, anchor-fluke shapes repeated on its wing tips and tail, ivory and teal plumage and small rocks floating around it."+ONE,
 "heavy-lidded, stern sea-blue eyes and a grim, immovable frown","ivory white and teal, with a dark iron accent","a helmet, a crown, a band around the head, a perching upright bird, black feathers",'gravity','tough')
# Bellowary female: tiara problem
X('bellowary_f2','Bellowary (female)',T+'Bellowary.jpg',"make it the female form: keep the brass chimney crest but make it shorter and slimmer, flared like a fluted brass trumpet growing straight from the skull (no tiara, crown or filigree), give it a warmer, paler blue-and-orange neck and a softer tail glow, and keep the brass leg spurs.",runs=3)
PRIORITY=PRIORITY+['briarlynx_e','chandelotl_e','blossmink_e','amanitusk_e','arcestrel_e','bellowlet_r','bucketmander_r','buckleron_r2','chandelapi_r2','chimelop_r2','cisternmander_r2','coolatee_r','anchorbill_r2','bellowary_f2']
