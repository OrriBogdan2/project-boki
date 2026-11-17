# Owner 01:24 ET 11-09: keep the sea-glass look from Prismander direction C as its own new Boki, in a different shape.
# Three body shapes; Claude picks one (owner overrides). Water + Crystal, image 2 = the sea-glass axolotl (look, palette, face only).
_SG='briefs/boki-art/concepts/SeaGlass_ref.jpg'
def _SGQ(tag,body):
    SPECS.append({'id':'c_seaglass_'+tag,'name':'Sea-glass Boki ('+tag+')','refs':[SR,_SG],'runs':3,'aspect':'1:1',
      'prompt':CONCEPT_CORE+LESSONS+("Image 2 shows the material, palette and face to keep: frosted, tide-worn translucent sea glass in seafoam green and pale aqua with "
       "rounded cobalt-blue pebble patches, big sleepy-happy eyes and a soft little smile. Make a brand-new creature in exactly that material and palette, "
       "but a completely different animal and body shape from image 2 (it must not be an axolotl): "+body+" A baby: small, round, chunky, big head, short limbs, "
       "simple enough to read as a tiny icon. Water and Crystal types. Avoid: an axolotl, sharp crystals, shells, sand, a bottle, sparkles, rainbow effects.")})
_SGQ('ray',"a round baby manta ray gliding low, its wide wing-fins frosted sea glass edged like smooth broken beach glass, two little cephalic fins curled by its face, a short paddle tail.")
_SGQ('otter',"a chubby sea otter pup floating on its back with its paws folded on its tummy, its fur turned into smooth frosted sea-glass pebbles, a flat rounded tail like a polished piece of beach glass.")
_SGQ('slug',"a plump sea slug (nudibranch) creeping along, its back crowned with soft rounded sea-glass frills like worn glass petals, two little rhinophore horns.")
PRIORITY=['c_seaglass_ray','c_seaglass_otter','c_seaglass_slug']+PRIORITY

# Owner 01:36: "we already have an otter and manta ray is boring, let's do a non-typically aquatic character". Land animals in sea glass.
_SGQ('lamb',"a fluffy baby lamb standing on short stubby legs, its whole curly fleece made of round frosted sea-glass pebbles of different sizes, little rounded sea-glass hooves and ear tips.")
_SGQ('koala',"a chubby baby koala sitting and hugging itself, its big round fluffy ears and fur made of smooth frosted sea glass, a big round cobalt-blue sea-glass nose.")
_SGQ('redpanda',"a round baby red panda sitting up on its haunches like an animal, its thick ringed tail made of alternating frosted seafoam and cobalt sea-glass bands, its fur smooth frosted glass.")
for _k in ('ray','otter','slug'): SPECS[:]=[x for x in SPECS if x['id']!='c_seaglass_'+_k]
PRIORITY=['c_seaglass_lamb','c_seaglass_koala','c_seaglass_redpanda']+PRIORITY
