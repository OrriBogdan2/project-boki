# run from repo root: rebuild cutout_v2 for all live cards, refresh LIVE_MANIFEST.json/.md (keeps display_name/extra keys)
import json,os,glob,subprocess,time
A='briefs/boki-art/'; CUT={'Coolatee','Frigatee','Glaciatee','Amanitusk','Bellowary','Frothisk','Geodelotl','Lashyx','Puffamus'}
p=A+'LIVE_MANIFEST.json'; m=json.load(open(p))
for n in sorted({os.path.basename(f)[:-4] for f in glob.glob(A+'cards/*.jpg') if '_' not in os.path.basename(f)}-CUT):
  e=m.setdefault(n,{})
  if not (e.get('sheet') and os.path.exists(e['sheet'])):
    for c in (A+f'evolutions/{n}.jpg',A+f'turnarounds/{n}.jpg'):
      if os.path.exists(c): e['sheet']=c; break
  e['card']=A+f'cards/{n}.jpg'
  if os.path.exists(A+f'portraits/light/{n}.jpg'): e['portrait']=A+f'portraits/light/{n}.jpg'
for n in CUT: m.pop(n,None)
json.dump(m,open(p,'w'),indent=1)
subprocess.run(['python3',A+'batch/cutout_v2.py'],check=True)
m=json.load(open(p))
for n,e in m.items():
  c=A+f'portraits/cutout_v2/{n}.png'
  if isinstance(e,dict) and os.path.exists(c): e['cutout']=e['hero']=c
import hashlib
for n,e in m.items():
  if isinstance(e,dict):
    h={}
    for k in ('sheet','card','portrait','hero'):
      v=e.get(k)
      if v and os.path.exists(v): h[k]=hashlib.sha1(open(v,'rb').read()).hexdigest()[:12]
    e['hash']=h
json.dump(m,open(p,'w'),indent=1)
ok=lambda v: '✓' if v and os.path.exists(v) else '–'
rows=[f"| {n}{' ('+e['display_name']+')' if e.get('display_name') else ''} | {ok(e.get('sheet'))} | {ok(e.get('card'))} | {ok(e.get('portrait'))} |" for n,e in sorted(m.items()) if isinstance(e,dict)]
full=sum(1 for e in m.values() if isinstance(e,dict) and all(e.get(k) and os.path.exists(e[k]) for k in ('sheet','card','portrait')))
missing=[n for n,e in sorted(m.items()) if isinstance(e,dict) and not all(e.get(k) and os.path.exists(e[k]) for k in ('sheet','card','portrait'))]
h=[f"# Boki art live manifest (regenerated {time.strftime('%H:%M')} UTC 11-09)",
"Card = main image, sheet = turnaround, portrait = Bokidex portrait. Bokidex hero = \"hero\" in LIVE_MANIFEST.json (portraits/cutout_v2, cut from the current card). Proposed new names in brackets (NAME_CHANGES.md). JSON: LIVE_MANIFEST.json.",
"Cut: "+', '.join(sorted(CUT))+". Renamed: Orbeetle -> Orbitle; old Pyrraven art is now Embrook.",
f"{len(rows)} Boki, {full} with all three. Missing something: {', '.join(missing)}","","| Boki | Sheet | Card | Portrait |","|---|---|---|---|"]
open(A+'LIVE_MANIFEST.md','w').write('\n'.join(h+rows)+'\n')
json.dump(missing,open('/tmp/missing.json','w'))
print(len(rows),full,len(missing))
