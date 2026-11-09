# Owner 00:27 ET 11-09: "Glassolotl is way too busy, Prismander should be more interesting." Prismander is a starter, so
# 3 concept directions for the owner to pick; the approved art stays until he picks. Glassolotl (and its finals) follow the pick,
# with one clear idea and far fewer parts.
def _PD(tag,look,face,cols,avoid):
    SPECS.append({'id':'c_prismander_'+tag,'name':'Prismander (direction '+tag.upper()+')','refs':[SR],'runs':3,'aspect':'1:1',
      'prompt':CONCEPT_CORE+LESSONS+"Concept: a starter baby axolotl of the Crystal and Water types. Look: "+look+" It is a baby starter: small, round, big head, short stubby legs, very appealing and simple enough to read as a tiny icon. Face: "+face+". Colours: "+cols+". Avoid: "+avoid+", a busy design, many spikes, rainbow effects, sparkles."})
_PD('a',"A round baby axolotl made of glossy hard rock candy: its feathery gills are three short rock-candy sugar-crystal sticks on each side, its body a translucent swirled boiled-sweet with a candy-cane stripe spiralling down its tail, and a few sugar-crystal clusters along its spine.",
    "huge, happy dark eyes and a wide open-mouth grin","strawberry pink and clear sugar white, with a mint-green swirl accent","a lollipop stick, a wrapper, held candy")
_PD('b',"A round baby axolotl whose whole body is a stained-glass window: bold dark lead lines divide its skin into a few big coloured glass panes, its gills are six glass petals in different colours, and light glows softly through the panes.",
    "big, curious glossy eyes and a small cheeky smile","cobalt blue, rose and amber glass panes, with dark lead-line outlines","a window frame, a church, a mosaic of tiny tiles")
_PD('c',"A round baby axolotl made of frosted sea glass worn smooth by the tide: soft frosted translucent skin with a few rounded sea-glass pebble patches, short smooth sea-glass shard gills, and a flat paddle tail like a polished piece of beach glass.",
    "big, sleepy-happy eyes and a soft little smile","frosted seafoam green and pale aqua, with a cobalt blue pebble accent","sharp crystals, shells, sand, a bottle")
PRIORITY=['c_prismander_a','c_prismander_b','c_prismander_c']+PRIORITY
