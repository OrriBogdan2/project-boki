# Round 32 (00:55 ET 11-09): panel results for round-29 fixes (groups s8-s10). Same auto rules as round 29;
# automatically from the panel's own fixes: 'edit' (avg >= 7.9) -> edit of the most-picked run; 'new' -> the original
# prompt again with the panel fixes appended as hard requirements. Source: panel_w30.json.
import json as _j, re as _r
_O='briefs/boki-art/batch/out/'
_JOBS={j['id']:j for j in _j.load(open(HERE/'jobs.json'))}
def _clean(f):
    f=_r.sub(r'^(EDIT|New prompt|Re-run the edit stronger|Relayout|Keep run \d+)[:;,]?\s*','',f or '',flags=_r.I)
    return _r.sub(r'^on run \d+,?\s*','',f,flags=_r.I).strip()
_W30=[]
for _d in _j.load(open(HERE/'panel_w30.json')):
    i=_d['id']; j=_JOBS.get(i)
    base=_r.sub(r'_w2\d$','',i)
    if not j: continue
    fx=[_clean(f) for f in _d['fixes'] if f and not _r.match(r'^(ship|keep run|none)',f.strip(),_r.I)]
    fx=list(dict.fromkeys([f for f in fx if len(f)>8]))
    if not fx: fx=['fix the problems: '+'; '.join(v for v in _d['veto'])] if _d['veto'] else ['make the face more characterful and keep everything clean']
    nid=base+'_w30'; asp=j.get('aspect','16:9')
    if i.startswith('portrait_') and _d['decision']=='new':
        nm=_r.sub(r'^portrait_|_(pe|p2|p|r)$','',base).capitalize()
        sh=next((f'briefs/boki-art/{d}/{nm}.jpg' for d in ('evolutions','turnarounds') if (HERE.parent/d/f'{nm}.jpg').exists()),None)
        if sh:
            P(nid[len('portrait_'):],nm,sh,"its body turned about 30 degrees toward the viewer, head toward the viewer with both eyes visible, a characterful grounded pose. "+" Also: ".join(fx))
            SPECS[-1]['runs']=4; _W30.append(nid); continue
    if _d['decision']=='edit' and _d['pick']:
        src=_O+i+'_'+str(_d['pick'])+'.jpg'
        if asp=='1:1':
            p=("Edit image 1: keep the same creature, design, colours and style, centred and filling about 85 percent of the square on a plain flat pale grey background, "
               "no effects, no shadows, no glow. Make all of these changes: "+" Also: ".join(fx))
        else:
            p=("Edit image 1: keep the same creature, design, colours and style, exactly four views (front, three-quarter, side, back) in ONE clean row on a plain flat pale grey "
               "background, no shadows, no ghost copies. Make all of these changes: "+" Also: ".join(fx))
        SPECS.append({'id':nid,'name':j['name'],'refs':[src],'runs':3,'aspect':asp,'prompt':p})
    else:
        SPECS.append({'id':nid,'name':j['name'],'refs':list(j['refs']),'runs':4,'aspect':asp,
          'prompt':j['prompt']+" The last attempt failed review. These panel fixes are hard requirements: "+" Also: ".join(fx)})
    _W30.append(nid)
PRIORITY=PRIORITY+_W30
# Stuck after 3+ rounds (reskin or pasted copies every time): concept-first with no parent sheet in the prompt image,
# so the model can't copy the parent's body. Parent only as a palette note in words.
VC('chimelop_v','Chimelop',SR,'final',
 "A big, long-limbed silver hare-beast caught mid-leap with its whole body airborne and stretched, its two enormous ears grown into wide scalloped silver bell-mouth flares that sweep back like wings, a flared bell-shaped tail and very long hind legs; much bigger and grander than a small hare. Pale lavender and silver like its earlier form Echolop (a crouching bat-eared hare), but a completely different body plan and pose.",
 "calm, proud violet eyes and a gentle smile","pale lavender and silver, with a moonlight accent","standing, crouching, sitting, hanging bells, clappers, a held bell, bat wings",'echo','pretty')
VC('chandelapi_v','Chandelapi',SR,'final',
 "A gaunt, towering spectral okapi floating on its two front legs only, its rear half dissolving into drifting violet smoke, a long drooping swan-like neck, and a wrought-iron chandelier frame grown as its antlers and ribcage with wax candles fused in and small violet flames; wax-drip stripes on its front legs. Its earlier form Snuffapi is a standing candle-antlered okapi: this must look nothing like a standing deer.",
 "calm, glowing violet eyes and a wry, eerie smile","deep brown and wrought-iron black, with a violet flame accent","four legs on the ground, a standing deer or okapi, chains, a hanging frame, cuffs",'shadow','majestic')
VC('bucketmander_v','Bucketmander',SR,'baby',
 "A tiny legless tadpole-like salamander larva with a soft round body, a big head, short stubby gill nubs, a long finned tail whose fin is made of a few small wooden staves, and a thumb-sized raincloud puff growing from the top of its head like a tuft.",
 "tiny beady eyes and a big lazy grin","wood brown and slate grey, with a yellow accent","legs, a barrel body, hoops, bands, a bucket, axolotl gill fans, a second creature",'storm','cute')
CN('Tootle',"A round little baby frilled lizard sitting low on all fours, whose big neck frill is brass-coloured skin that curls forward around its face into one short flared bell shape, like the bell of a horn, framing its face from behind; its own face with puffed cheeks is fully visible in front, nothing in its mouth, a plain grooved cone tail.",
   "a trumpet in its mouth, a horn held, a cone collar, a mask over the face, rings or bands")
SPECS[-1]['id']='c_tootle_v'
PRIORITY=PRIORITY+['c_chimelop_v','c_chandelapi_v','c_bucketmander_v','c_tootle_v']
