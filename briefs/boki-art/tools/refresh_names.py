"""Light manifest refresh: python3 briefs/boki-art/tools/refresh_names.py Name1 Name2 ...   (run from the repo root)
Rebuilds portraits/cutout_v2 and the LIVE_MANIFEST.json/.md entries for ONLY the named Boki, so no other entry's hash moves.
(The full refresh_manifest.py re-cuts all heroes; on a machine with another OpenCV version that changes every hero hash.)"""
import sys,os,json,hashlib,re
sys.path.insert(0,'briefs/boki-art/batch')
from cutout_v2 import cutout,frame
from PIL import Image
A='briefs/boki-art/'; p=A+'LIVE_MANIFEST.json'; m=json.load(open(p))
for n in sys.argv[1:]:
    e=m.setdefault(n,{})
    if not (e.get('sheet') and os.path.exists(e['sheet'])):
        for c in (A+f'evolutions/{n}.jpg',A+f'turnarounds/{n}.jpg'):
            if os.path.exists(c): e['sheet']=c; break
    e['card']=A+f'cards/{n}.jpg'; e['portrait']=A+f'portraits/light/{n}.jpg'
    c=A+f'portraits/cutout_v2/{n}.png'; frame(cutout(Image.open(e['card']))).save(c,optimize=True); e['cutout']=e['hero']=c
    e['hash']={k:hashlib.sha1(open(e[k],'rb').read()).hexdigest()[:12] for k in ('sheet','card','portrait','hero') if e.get(k) and os.path.exists(e[k])}
    print(n,e['hash'])
json.dump(m,open(p,'w'),indent=1)
md=A+'LIVE_MANIFEST.md'; L=open(md).read().split('\n'); head=[l for l in L if not l.startswith('| ') or l.startswith('| Boki')]; 
ok=lambda v:'✓' if v and os.path.exists(v) else '–'
rows=[f"| {n}{' ('+e['display_name']+')' if e.get('display_name') else ''} | {ok(e.get('sheet'))} | {ok(e.get('card'))} | {ok(e.get('portrait'))} |" for n,e in sorted(m.items()) if isinstance(e,dict)]
full=sum(1 for e in m.values() if isinstance(e,dict) and all(e.get(k) and os.path.exists(e[k]) for k in ('sheet','card','portrait')))
head=[re.sub(r'^\d+ Boki, \d+ with all three\.',f'{len(rows)} Boki, {full} with all three.',l) for l in head if l.strip()]
i=next(k for k,l in enumerate(head) if l.startswith('| Boki'))
open(md,'w').write('\n'.join(head[:i]+['']+head[i:i+1]+['|---|---|---|---|']+rows)+'\n')
