# Owner decisions 02:25 ET 11-09: Glassolotl (rock candy, 8.33) and Bucketmander concept sent back for redo (no notes). Fresh tries.
# Owner 02:28-02:29: keep the rock-candy Glassolotl STYLE, but try different versions of it, because it is a bit plain.
_GA='briefs/boki-art/batch/out/c_glassolotl_a_2.jpg'
def _GV(tag,change):
    SPECS.append({'id':'c_glassolotl_'+tag,'name':'Glassolotl (variant '+tag+')','refs':[_GA,SR],'runs':3,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art. Image 1 is the current design of this creature: keep its species, rock-candy material, "
       "palette, face shape and overall look so it is clearly the same creature, but make it less plain and more striking: "+change+
       " Image 2 is the style reference only; never copy its creatures. ONE creature only, full body, gentle three-quarter view with the head "
       "toward the viewer, centred, plain flat pale grey background, no shadow, no text, no effects. "+LESSONS)})
_GV('v1',"give it a bolder spiral candy-cane stripe pattern wrapping its whole body, a short frilled crest of clear sugar-glass along its back, and a confident lunging pose.")
_GV('v2',"make its gills into longer, flowing, glossy hard-candy ribbons with two-tone swirls, add a translucent jelly-candy tail fin with tiny sugar crystals inside, and give it a playful twisting swim pose.")
_GV('v3',"make it chunkier with a bigger head and more expressive face, add a few large faceted rock-candy crystals growing from its shoulders and tail tip, and a cheeky open-mouth grin.")
VC('bucketmander_o','Bucketmander',SR,'baby',
 "A tiny round tadpole larva with a big head and a soft round body, no legs, a long tail fin made of a few small wooden barrel staves joined like a fan, short stubby gill nubs, and a thumb-sized raincloud tuft growing from the top of its head.",
 "tiny beady eyes and a big lazy grin","wood brown and slate grey, with a yellow accent","legs, a barrel body, hoops, bands, a bucket, axolotl gill fans, a second creature",'storm','cute')
PRIORITY=['c_glassolotl_v1','c_glassolotl_v2','c_glassolotl_v3','c_bucketmander_o']+PRIORITY
