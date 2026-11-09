#!/usr/bin/env python3
"""Builds jobs.json from compact specs. Existing jobs are kept; new ids are appended."""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
SR='briefs/boki-art/style_refs/boki_style_ref_v2.png'
SR3='briefs/boki-art/style_refs/boki_style_ref_v3.jpg'
SRA='briefs/boki-art/style_refs/boki_style_ref_2d.png'  # the ONE style anchor (Vespyx + Mycroll), owner 2026-11-09; v2/v3 are retired
_EXIST={j['id'] for j in json.loads((HERE/'jobs.json').read_text())} if (HERE/'jobs.json').exists() else set()  # ids that already exist keep their old refs and prompt, so nothing re-queues or changes
STYLE2="Image 2 is a style guide only: match the finish, line weight, shading and colour treatment of the creatures in image 2 exactly, but never copy their designs, faces or colours. "
T='briefs/boki-art/turnarounds/'; E='briefs/boki-art/evolutions/'
ELEM={
'ember':'ember, shown clearly by glowing orange-red ember cracks and a few rising sparks',
'bloom':'bloom, shown clearly by living leaves, petals or moss growing from its body, fresh green',
'storm':'storm, shown clearly by crackling electric-yellow sparks and small lightning arcs',
'frost':'frost, shown clearly by translucent ice-blue crystals and a faint cold mist',
'venom':'venom, shown clearly by dripping lime-green venom and a toxic glossy shine',
'swarm':'swarm, shown clearly by insect-like segments and a faint shimmer of many small wings',
'tempest':'tempest, shown clearly by wind-swept streamers and sky-blue swirl markings',
'stone':'stone, shown clearly by rough rock plates, cracks and pebbles',
'shadow':'shadow, shown clearly by inky black edges that fade into smoke, with a violet glow',
'spore':'spore, the type the Blight touches: still appealing and healthy-looking, with the Blight palette only as a small accent (purple-black gills or vein lines on its caps, a faint purple inner glow in its spores, a few small bone-spur quills), never green slime, never gross, rotting or sad',
'prism':'prism, shown clearly by glassy crystal facets that throw rainbow glints',
'lunar':'lunar, shown clearly by a soft pale moonlight glow and crescent markings',
'echo':'echo, shown clearly by gold sound rings rippling out from its body',
'gravity':'gravity, shown clearly by small rocks floating around it and a faint dark purple warp',
'titan':'titan, shown clearly by massive, heavy armour and a powerful, grounded build',
'tide':'tide, shown clearly by water droplets, ripples and a sea-blue sheen',
'wyrm':'wyrm, shown clearly by dragon horns, serpent scales and a shimmering gold glow',
'wild':'wild, shown clearly by natural earthy colours and a plain, honest animal look',
}
ARCH={'cute':'cute: round soft shapes, a big head and short limbs','tough':'tough: blocky, wide and heavy, with a low stance','fast':'fast: lean and forward-leaning, with swept-back shapes','sleek':'sleek: long smooth lines and a streamlined shape','pretty':'pretty: graceful curves and an elegant shape','creepy':'creepy and weird: odd proportions and an unsettling calm','majestic':'majestic: big and upright, with crown-like features and calm power'}
SHEET=("Turnaround sheet: exactly four views in one row at the same scale, all four the same size (front, three-quarter, side, back), flat even light, plain pale grey background, whole body in frame, no floor, no shadow, no reflection, no faded or duplicate copies, no text. ")
CORE=("A stylised animal, not a realistic one: simple bold shapes, a slightly oversized head, a strong iconic silhouette that reads even as a solid shadow, a memorable face with its own expression, and some bite: teeth, claws, spikes, or even real weapons grown out of its body as if it was born with them, never held or strapped on. The idea runs through the whole body: the object's material and shapes repeat across its limbs, back, tail and face, never one thing sitting on, hanging from or strapped to another. Clearly an animal: no clothes, no human posture, no standing upright like a person, nothing held. ")
RENDER="Render it exactly like image 1: soft hand-painted shading with a clean, fairly thin dark outline, not thick cartoon outlines, not flat cel shading, not realistic. "
STYLE_A="Image 1 is the style guide only (two example creatures; ignore their dark backdrop and glow): match the finish, line weight, soft hand-painted shading, eye treatment and colour treatment of those creatures exactly, but never copy their designs, faces or colours. "
RENDER_A="Render it exactly in the style of the style-guide image: soft hand-painted shading with a clean, fairly thin dark outline, big glossy eyes, not thick cartoon outlines, not flat cel shading, not realistic. "
LESSONS=" ".join(l.strip() for l in open(HERE/'LESSONS.txt') if l.strip() and not l.startswith('#'))+" "
def base(d,new=False):
    return ("Creature-collector monster design for a fantasy action game: an endearing but dangerous creature built from one clear idea, a real animal fused with an object so that the object is part of its body. "+CORE+(LESSONS.replace('Image 2 is only','Image 1 is only') if new else LESSONS)+(RENDER_A if new else RENDER)+"Do not copy image 1's creatures, faces or colours. "+SHEET+d)
REL={'baby':"This creature is the baby first form that later grows up into the creature in image 1: the same species and family, keeping its face shape, eye colour, main colours and core idea so anyone can tell they are related, but clearly a baby: much smaller, rounder and softer, with a bigger head, bigger eyes and short stubby limbs, and its object in a smaller, simpler, earlier form. It must not be image 1 shrunk down: a different, simpler body shape of its own.  Stance (owner rule: every stage of a line stands differently): as a baby it sits or bounces in a round, compact, playful stance, never the same stance as the grown forms.",
'mid':"This creature is the middle form of the creature in image 1's family, bigger and older, and clearly not yet a final form. It must be a fundamental transformation, like a real creature-collector evolution, never the same creature with extra parts added or recoloured: change its body plan and proportions (for example round to long, low to tall, four legs to serpentine, ground to winged, small head to big horned head), give it a new main silhouette and a new pose, and turn its object or idea into something new and more developed rather than more of the same pieces. Keep only the family resemblance: the face shape, eye colour and palette.  Stance (owner rule: every stage of a line stands differently): as a middle form it is caught in motion, a low prowl, stride, dash, glide or coil, never the same stance as the baby or the final.",
'final':"This creature is the final evolved form of the creature in image 1's family: much bigger, stronger and more impressive, clearly a final form. It must be a fundamental transformation, like a real creature-collector evolution, never the same creature with extra parts added or recoloured: change its body plan and proportions (for example round to long, low to tall, four legs to serpentine, ground to winged, small head to big horned head), give it a new main silhouette and a new pose, and turn its object or idea into something new and more developed rather than more of the same pieces. Keep only the family resemblance: the face shape, eye colour and palette.  Stance (owner rule: every stage of a line stands differently): as a final form it is big and planted in a commanding stance, rearing, looming, towering or braced wide, never the same stance as the earlier forms.",
'female':"This creature is the female form of the creature in image 1: the same species at the same stage, keeping its face shape, core idea and overall build so anyone can tell they are the same species, but with a few clear differences in build, crest or tail shape, the size of its signature part and colour tint. ",
'redo_of':""}
def evo(rel,d,new=False):
    if new: return ("Creature-collector monster design for a fantasy action game. "+REL[rel]+"Do not copy image 1's pose, and ignore image 1's background. Image 2 is the style guide only (two example creatures; ignore their dark backdrop and glow): match the finish, line weight and shading of image 2 exactly, but never copy its designs, faces or colours. "+CORE+LESSONS+"Render it in the style of image 2: soft hand-painted shading with a clean, fairly thin dark outline, big glossy eyes, not thick cartoon outlines, not flat cel shading, not realistic. "+SHEET+d)
    return ("Creature-collector monster design for a fantasy action game. "+REL[rel]+"Do not copy image 1's pose, and ignore image 1's background. "+CORE+LESSONS+RENDER+SHEET+d)
def desc(body,face,cols,avoid,el,arch):
    return f"{body} Face: {face}. Main colours: {cols}. Avoid: {avoid}. Element: {ELEM[el]}. Archetype: {ARCH[arch]}."
SPECS=[]
def B(i,n,body,face,cols,avoid,el,arch):
    if i in _EXIST: SPECS.append({'id':i,'name':n,'refs':[SR,SR3],'prompt':base(STYLE2+desc(body,face,cols,avoid,el,arch))})  # legacy: unchanged
    else: SPECS.append({'id':i,'name':n,'refs':[SRA],'prompt':base(STYLE_A+desc(body,face,cols,avoid,el,arch),new=True)})
def U(i,n,ref): SPECS.append({'id':i+'_4k','name':n,'refs':[ref],'runs':1,'size':'4K','prompt':"Re-render image 1 at full quality: keep it exactly the same, the same creature, design, colours, every detail, the same views in the same layout and the same plain background. Only increase the sharpness and finish. Do not change, add or remove anything."})
def X(i,n,ref,instr,runs=3): SPECS.append({'id':i,'name':n,'refs':[ref],'runs':runs,'prompt':"Edit image 1: keep everything exactly the same, the same creature, the same four views in one row, pose, colours, style and plain pale grey background. Only change this: "+instr+" Do not add anything else."})
def V(i,n,ref,rel,body,face,cols,avoid,el,arch):
    new=i not in _EXIST  # new ids get the anchor as image 2; existing ids stay as they were
    SPECS.append({'id':i,'name':n,'refs':[ref,SRA] if new else [ref],'prompt':evo(rel,desc(body,face,cols,avoid,el,arch),new=new),'runs':4})

# Hero card (one image per species in the canon, see STYLE_CANON.md). Image 1 = the species' own design (identity), image 2 = style anchor.
CARD_VIEW=("View: a gentle three-quarter view, the body turned about 30 degrees to one side (never straight-on front, never a pure side profile), the head turned slightly toward the viewer so both eyes show. ")
CARD_STAGE={'baby':"Proportions: this is a baby form, so keep it small, round and soft, with a clearly oversized head, big eyes and short stubby limbs. ",
'mid':"Proportions: this is a young or middle form, so keep a big head and rounded body but a little more defined shapes and slightly longer limbs. ",
'final':"Proportions: this is a final form, so keep it more defined, bigger and more powerful, with a proportionally smaller head, bolder shapes, longer limbs and a stronger stance, but still cute and appealing, never realistic. "}
def CARD(name,stage,pose):
    return ("Single character illustration of one Boki (a stylised, cute, endearing but slightly dangerous creature-collector monster): "+name+", the creature in image 1, redrawn in the Boki house style of image 2. "
    "Image 1 is the identity reference only: keep exactly the same creature, design, body plan, face, markings, colours and the object or idea fused into its body, with nothing added, removed or redesigned; ignore its pose, view, size, background, lighting and finish. "
    "Image 2 is the style reference only (two example creatures on a dark backdrop; ignore the backdrop, its glow and its floor shadow): match their soft hand-painted shading, clean fairly thin dark outline, big glossy eyes with a bright highlight, soft blush, rounded toy-like shapes and overall finish exactly, but never copy their designs, faces or colours. "
    +CARD_VIEW+"Pose: "+pose+", a characterful pose that shows its personality (a head tilt, a playful lean, a curious or cocky look, a weight shift), lively but grounded with its feet on the floor, never stiff, never posed like a passport photo, not an attack pose, not upright like a person, nothing held. "+CARD_STAGE[stage]+
    "Lighting: one soft key light from the top left, light shading falling to the lower right, no coloured rim light. "
    "Framing: exactly one creature, the whole body in frame from the top of the head or highest part to the feet and tail, centred, with about 8 percent empty margin on every side, its feet resting on one imaginary flat floor line. "
    "Background: one plain, flat, pale grey (#E8E8EE) background, no gradient, no floor texture, no cast shadow, no contact shadow blob, no reflection, no glow halo, no vignette, no text, no props, no other creatures. Keep every edge of the creature clean so it can be cut out easily."+"Most important (critics' top notes on the first 80 cards): absolutely NO shadow of any kind under or behind it, NO glow or halo around it; the face is the focal point, big, glossy, expressive and full of personality; keep every signature part of image 1 exactly (tail, wings, horns, markings), nothing changed or dropped; the creature is big in the frame. ")
def C(i,n,stage,pose,inp,runs=2):
    SPECS.append({'id':i+'_card','name':n+' (hero card)','refs':['briefs/boki-art/card_inputs/'+inp,SRA],'runs':runs,'aspect':'1:1','size':'2K','prompt':CARD(n,stage,pose)})
import glob
for _f in sorted(glob.glob(str(HERE/'specs_*.py'))): exec(open(_f).read())
jobs=json.loads((HERE/'jobs.json').read_text()) if (HERE/'jobs.json').exists() else []
import subprocess as _sp2
_made={l.split('/')[-1].rsplit('_',1)[0] for l in _sp2.run(['git','ls-tree','--name-only','HEAD',str(HERE/'out')+'/'],capture_output=True,text=True,cwd=HERE).stdout.split()}
_spec={s['id']:s for s in SPECS}
for j in jobs:  # jobs not started yet pick up prompt changes
    if j['id'] not in _made and j['id'] in _spec: j['prompt']=_spec[j['id']]['prompt']
have={j['id'] for j in jobs}
for s in SPECS:
    if s['id'] in have: continue
    s.setdefault('runs',4); s.setdefault('aspect','16:9'); s.setdefault('size','2K'); jobs.append(s)
_pri=globals().get('PRIORITY',[])
jobs.sort(key=lambda j: (_pri.index(j['id']) if j['id'] in _pri else len(_pri), 1 if j['id'].startswith('relic_') else 0))  # relics run after all Boki
(HERE/'jobs.json').write_text(json.dumps(jobs,indent=2))
print(len(jobs),'jobs')
