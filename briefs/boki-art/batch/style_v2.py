# V2 style blocks, copied verbatim from RERENDER_PROMPTS.md sections 2, 3 and 5 (owner approved 11-09 17:23 ET).
# exec'd by specs that need them: exec(open(HERE/'style_v2.py').read())
RENDER_V2=("Rendering: flat cel-shaded 2D game art, like a hand-inked model sheet coloured with flat fills. "
 "Every colour area is one flat fill plus exactly one hard-edged shade shape in a darker, slightly cooler tone of the same colour. The shade shapes are large, simple and connected, and sit on the lower right of each form, because the single light comes from the top left. "
 "Matte finish everywhere. The only crisp highlights are one white highlight in each eye and one highlight shape on anything truly wet or glassy (slime, venom, polished gems, glass); metal shows one flat lighter band. "
 "No gradients, no airbrush, no soft blending, no glossy shine on fur, skin, feathers or scales, no surface texture, no sparkles, no glow halo. ")
LINE_V2=("Line: a bold, clean inked outline in three weights: the outer silhouette line is the heaviest, the lines between body parts are half as thick, and small detail lines are a quarter as thick. Each line keeps an even thickness along its length. "
 "Every line is a very dark shade of the colour it borders (deep plum round purple, dark umber round brown and gold, deep slate blue round white and ice), always clearly darker than the fill beside it. One clean line. ")
LINE_FINAL=LINE_V2.replace("the outer silhouette line is the heaviest,","the outer silhouette line is very heavy and bold,")  # finals and legendaries (5:2:1)
BUDGET_V2=("Detail budget: detail lives in three places only: the face, the signature part and one pattern. Every other area is a quiet, plain flat shape. Repeated things are drawn few and large: fur as a few big clumps along its edges, and scales, facets, rivets, spots and crystals as a handful of big shapes. Nothing is drawn smaller than the highlight in its eye. ")
FX_V2=("Effects: at most one small effect, attached to the body and drawn as flat hard-edged shapes. Anything that glows is simply the brightest flat colour on the creature with a lighter flat shape inside it; the air around the creature is empty. ")
DARK_V2=("This creature is dark, and it must stay dark: its dark areas stay near black, as dark as in image 1. On the dark areas the second tone is a lighter one: one hard-edged lit shape on the upper left, a little lighter than the dark base, and the inner lines on dark areas are drawn in that lighter tone so they show. Keep a strong split between its dark, middle and light areas. ")
FUR_V2=("Its fur is drawn as big clumps: the edge between the two fur tones is a row of large pointed clumps, with a few more clump shapes at the mane, shoulders, elbows, haunches and tail, and plain flat fur between them. ")
FACE_V2={
 'cute':"Face: big round eyes set low and wide apart, each with a coloured iris, a dark pupil, one large crisp white highlight and one small one; tiny brows or none; a small mouth. ",
 'pretty':"Face: large almond eyes with one to three lash flicks, a coloured iris, one large and one small crisp white highlight; a soft arched brow; a small, poised mouth. ",
 'sleek':"Face: narrow almond eyes tilted up at the outer corners, a coloured iris and one crisp white highlight; the flat upper lid works as the brow; a cool, knowing smirk. ",
 'tough':"Face: small eyes set deep under a heavy, straight brow ridge, a coloured iris and one small crisp white highlight; a wide jaw with an underbite, tusks or bared teeth. ",
 'creepy':"Face: round staring eyes with pinpoint pupils and at most one tiny highlight, no brows; a flat, unreadable mouth; unsettlingly calm. ",
 'majestic':"Face: calm, level, half-lidded eyes with a coloured iris and one crisp white highlight; a long straight brow; a closed, composed mouth; quiet power. "}
FACE_V2['fast']=FACE_V2['sleek']
FACE_KEEP="Keep this species' own expression from image 1. The eyes are the most finished, most contrasty spot in the image, and the face is drawn as flat and simplified as the body. "
def CHEEKS_V2(stage,arch):
    if stage=='baby' or (stage=='mid' and arch=='cute'): return "Cheeks: two small flat pink ovals with hard edges. "
    return "Cheeks: plain, the same flat colour as the rest of the face: no blush, no pink cheek marks. "
FRAME_V2=("Framing: exactly one creature, whole body in frame, centred, with about 8 percent empty margin on every side. "
 "Background: one perfectly flat pale grey (#E8E8EE) from edge to edge and nothing else: no gradient, no floor, no cast shadow, no contact shadow, no reflection, no halo, no text. Crisp clean edges all round so it can be cut out. ")
def STYLE_V2(stage,arch,dark=False,furry=False):
    return (RENDER_V2+(LINE_FINAL if stage=='final' else LINE_V2)+BUDGET_V2+(DARK_V2 if dark else "")+(FUR_V2 if furry else "")
            +FACE_V2[arch]+FACE_KEEP+CHEEKS_V2(stage,arch)+FX_V2)
SRV2='briefs/boki-art/style_refs/v2/anchor_%s.png'   # % face template; 'fast' uses the sleek anchor

def RS_CARD(name,stage,arch,cols,counts,dark=False,furry=False,fix=''):
    return ("Redraw the creature in image 1 as one single character illustration: "+name+". "
     "Image 1 is the design and the pose: keep exactly the same creature, body plan, proportions, pose, view, facing direction, face, markings and signature parts. Add nothing, remove nothing, move nothing. "
     "Ignore how image 1 is painted: its soft shading, gloss, highlights, glow and texture are not to be copied. "
     "Its colours must not change: "+cols+". Its parts, counted, must match image 1: "+counts+". "
     "Image 2 is the style guide only: match its line, flat shading, eye finish and amount of detail exactly, but never copy its creature, face, colours or pose. "
     "Change ONLY how it is drawn. "+STYLE_V2(stage,arch,dark,furry)
     +(("One construction cleanup is allowed, and nothing else about the design changes: "+fix+" ") if fix else "")+FRAME_V2)

def RS_CARD_B(name,stage,arch,cols,counts,pose,dark=False,furry=False,fix=''):
    return ("Draw one single character illustration of "+name+", the creature shown from four sides in image 1. "
     "Image 1 is the design only: keep exactly the same creature, body plan, proportions, face, markings and signature parts, with nothing added or removed. Ignore how image 1 is painted, and do not copy its layout: draw the creature once. "
     "Its colours must not change: "+cols+". Its parts, counted: "+counts+". "
     "Image 2 is the style guide only: match its line, flat shading, eye finish and amount of detail exactly, but never copy its creature, face, colours or pose. "
     "Pose: "+pose+", in a three-quarter view with both eyes showing. "+STYLE_V2(stage,arch,dark,furry)
     +(("One construction cleanup is allowed, and nothing else about the design changes: "+fix+" ") if fix else "")+FRAME_V2)

def RS_SHEET(name,cols,counts):
    return ("Redraw the turnaround sheet in image 1 as a clean flat model sheet of "+name+". "
     "Image 1 is the layout and the design: keep exactly its four views in one single row (front, three-quarter, side, back), their order, poses, scale and spacing, and every part of the creature. "
     "Image 2 is the same creature in the final art style, and it is the truth for colours, eyes, face and part counts: every view must agree with image 2 and with the other views. "
     "Colours: "+cols+". Parts, the same in every view: "+counts+". "
     "Model-sheet finish: "+LINE_V2+"Flat colour fills only, using the base colours of image 2, with no shading at all, in even neutral light. The only highlight is one crisp white highlight in each eye. "
     "All four views are the same height with the feet on one invisible baseline; the front, side and back are true front, side and back views. "
     "Background: one perfectly flat pale grey (#E8E8EE) and nothing else: no floor, no cast shadow, no text, no extra or faded copies of the creature.")

def RS_PORTRAIT(name,stage,arch,cols,counts,dark=False,furry=False):
    return ("Redraw the creature portrait in image 1: "+name+". Image 1 is the pose: keep its pose, view and framing. "
     "Image 2 is the same creature in the final art style, and it is the truth for design, colours, eyes, face, part counts and finish: draw image 1's pose exactly the way image 2 is drawn. "
     "Colours: "+cols+". Parts: "+counts+". "+STYLE_V2(stage,arch,dark,furry).replace(FX_V2,"The air around the creature is empty: nothing drifts, sparks or trails. ")+FRAME_V2)

ELEM_V2={
'ember':'ember, shown by bright orange cracks drawn as flat shapes and one or two small flat flames',
'bloom':'bloom, shown by living leaves, petals or moss growing from its body, fresh green',
'storm':'storm, shown by a few bold yellow zig-zag markings and one small flat lightning fork',
'frost':'frost, shown by a few big pale ice-blue crystals drawn as flat facets and frosted white tips',
'venom':'venom, shown by lime-green markings and one glossy venom bead with a single crisp highlight',
'swarm':'swarm, shown by a honeycomb pattern and insect-like segments, amber gold',
'tempest':'tempest, shown by wind-swept streamer shapes and sky-blue swirl markings',
'stone':'stone, shown by a few big rough rock plates with one or two bold cracks',
'shadow':'shadow, shown by inky black edges ending in a few solid flat wisp shapes, with a violet accent',
'spore':'spore, the type the Blight touches: appealing and healthy-looking, with the Blight palette only as a small accent (purple-black gills or vein lines on its caps, a few small bone-spur quills)',
'prism':'prism, shown by a few big glassy facets, with two or three flat pastel planes on its signature part only',
'lunar':'lunar, shown by pale silver crescent markings',
'echo':'echo, shown by ridges and ring shapes on its body, with bell, horn or pipe forms',
'gravity':'gravity, shown by heavy dark iron shapes and at most three chunky pebbles floating close to its body, deep indigo',
'titan':'titan, shown by a few massive plates grown from its hide and a powerful, grounded build',
'tide':'tide, shown by flowing fin shapes, wave-curl crests and foam-white tips, sea blue-green',
'wyrm':'wyrm, shown by small horns, a few big scale plates and a ridge of spines, old gold and deep crimson',
'wild':'wild, shown by natural earthy colours and a plain, honest animal look'}
