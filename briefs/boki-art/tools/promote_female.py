"""Female art (run from the repo root): python3 briefs/boki-art/tools/promote_female.py Name card_stem sheet_stem portrait_stem
Use '-' to skip a part. Saves cards/<Name>_female.jpg, evolutions/<Name>_female.jpg, portraits/{light,dark,cutout}/<Name>_female.*
(old files backed up as *_old*), and records the paths and hashes in manifest[Name]['female']."""
import sys,os,json,shutil,hashlib,tempfile
sys.path.insert(0,'briefs/boki-art/tools'); sys.path.insert(0,'briefs/boki-art/batch')
import bload,cutout
A='briefs/boki-art/'
def bk(f):
    if not os.path.exists(f): return
    b,e=os.path.splitext(f); i=1
    while os.path.exists(f"{b}_old{'' if i==1 else i}{e}"): i+=1
    shutil.copy2(f,f"{b}_old{'' if i==1 else i}{e}")
N,c,s,p=sys.argv[1:5]; m=json.load(open(A+'LIVE_MANIFEST.json')); fe=m[N].setdefault('female',{}); m[N]['sex_forms']=True
if c!='-': f=A+f'cards/{N}_female.jpg'; bk(f); bload.load(c).save(f,quality=93); fe['card']=f
if s!='-': f=A+f'evolutions/{N}_female.jpg'; bk(f); bload.load(s).save(f,quality=93); fe['sheet']=f
if p!='-':
    for q in (f'portraits/light/{N}_female.jpg',f'portraits/dark/{N}_female.jpg',f'portraits/cutout/{N}_female.png'): bk(A+q)
    t=tempfile.gettempdir()+'/fp.jpg'; bload.load(p).save(t,quality=95); cutout.make_all(t,N+'_female',A+'portraits'); fe['portrait']=A+f'portraits/light/{N}_female.jpg'
if fe.get('card'):
    sys.path.insert(0,'briefs/boki-art/batch'); from herocut import hero as _hero
    _h=A+f'portraits/cutout_v2/{N}_female.png'; _hero(fe['card']).save(_h,optimize=True); fe['hero']=fe['cutout']=_h
fe.pop('note',None); fe['hash']={k:hashlib.sha1(open(fe[k],'rb').read()).hexdigest()[:12] for k in ('card','sheet','portrait','hero') if fe.get(k) and os.path.exists(fe[k])}
json.dump(m,open(A+'LIVE_MANIFEST.json','w'),indent=1); print('female',N,sorted(fe['hash']))
