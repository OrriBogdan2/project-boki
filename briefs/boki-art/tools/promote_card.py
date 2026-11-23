# usage: promote_card.py Name:stem[:dc] ...   (card only; backs up the old card)
import sys,os,shutil
sys.path.insert(0,'briefs/boki-art/tools')
import bload
from declutter import declutter
A='briefs/boki-art/'
for a in sys.argv[1:]:
    p=a.split(':'); N,stem=p[0],p[1]; f=A+f'cards/{N}.jpg'
    if os.path.exists(f):
        b,e=os.path.splitext(f); i=1
        while os.path.exists(f"{b}_old{'' if i==1 else i}{e}"): i+=1
        shutil.copy2(f,f"{b}_old{'' if i==1 else i}{e}")
    im=bload.load(stem)
    if len(p)>2: im,r=declutter(im); print(N,'declutter removed',r)
    im.save(f,quality=93)
