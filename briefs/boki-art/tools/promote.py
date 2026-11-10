# usage: promote.py Name card_stem sheet_stem portrait_stem [declutter]
import sys,os,json,shutil
sys.path.insert(0,'briefs/boki-art/tools'); sys.path.insert(0,'briefs/boki-art/batch')
import bload,cutout
from declutter import declutter
A='briefs/boki-art/'; import tempfile; S=tempfile.gettempdir()
def backup(f):
    if not os.path.exists(f): return
    b,e=os.path.splitext(f); i=1
    while True:
        t=f"{b}_old{'' if i==1 else i}{e}"
        if not os.path.exists(t): shutil.copy2(f,t); return
        i+=1
N,c,s,p=sys.argv[1:5]; dc=len(sys.argv)>5
m=json.load(open(A+'LIVE_MANIFEST.json'))
f=A+f'cards/{N}.jpg'
if c!='-': backup(f); bload.load(c).save(f,quality=93)
f=m.get(N,{}).get('sheet') or A+f'turnarounds/{N}.jpg'; backup(f); bload.load(s).save(f,quality=93)
for q in (f'portraits/light/{N}.jpg',f'portraits/dark/{N}.jpg',f'portraits/cutout/{N}.png'): backup(A+q)
im=bload.load(p)
if dc: im,r=declutter(im); print('declutter removed',r)
t=S+'/tmp_port.jpg'; im.save(t,quality=95); cutout.make_all(t,N,A+'portraits'); os.remove(t)
print('promoted',N)
