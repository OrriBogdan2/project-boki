import json,subprocess,re,sys,os
from multiprocessing import Pool
R='/home/boki/cj/20261113-173508-a3/tree'
def g(*a,inp=None):
    return subprocess.run(['git','-C',R]+list(a),capture_output=True,input=inp).stdout
NOISE=re.compile(r'(\.uid$|\.import$|^briefs/|^docs/shots/|^docs/.*shots|tools/check_registry\.gd$|docs/wiki/Rules\.md$|docs/DEBT\.md$|tools/style_baseline\.json$|^ops/)')
ART=re.compile(r'\.(glb|gltf|png|jpg|jpeg|webp|wav|ogg|mp3|blend|fbx|exr|tres|res)$',re.I)
def sig(l):
    s=l.strip(); return s if len(s)>=8 else None
mainc={}
def mainlines(p):
    if p not in mainc:
        b=g('show','origin/main:'+p)
        mainc[p]=None if not b and not exists(p) else set(filter(None,(sig(x) for x in b.decode('utf8','replace').splitlines())))
    return mainc[p]
ex={}
def exists(p):
    return bool(g('ls-tree','origin/main','--',p).strip())
def an(item):
    b,sha=item
    mb=g('merge-base','origin/main',sha).decode().strip()
    ns=g('diff','--name-status','--no-renames',mb,sha).decode().splitlines()
    res=dict(br=b,sha=sha,files=0,noise=0,art_new=0,art_on=0,art_over=0,art_pend=0,app=0,rew=0,pend=0,newfile_pend=0,paths=[])
    textfiles=[]
    for l in ns:
        st,p=l.split('\t',1)
        if NOISE.search(p): res['noise']+=1; continue
        res['files']+=1; res['paths'].append(p)
        if ART.search(p):
            mbb=g('rev-parse','-q','--verify',mb+':'+p).strip(); brb=g('rev-parse','-q','--verify',sha+':'+p).strip(); mnb=g('rev-parse','-q','--verify','origin/main:'+p).strip()
            if brb==mnb: res['art_on']+=1
            elif not mnb and not mbb: res['art_new']+=1
            elif mnb!=mbb: res['art_over']+=1
            else: res['art_pend']+=1
        else: textfiles.append((st,p))
    if textfiles:
        d=g('diff','-U2','--no-renames',mb,sha,'--',*[p for _,p in textfiles]).decode('utf8','replace')
        cur=None; hunks=[]
        for l in d.splitlines():
            if l.startswith('+++ '): cur=l[6:] if l.startswith('+++ b/') else None; continue
            if l.startswith('--- ') or l.startswith('diff ') or l.startswith('index ') or l.startswith('new file') or l.startswith('deleted file'): continue
            if l.startswith('@@'): hunks.append([cur,[],[],[]]); continue
            if not hunks or cur is None and not l.startswith('-'): 
                if hunks and l[:1] in ' -' : pass
                else: continue
            h=hunks[-1]
            k={'+':1,'-':2,' ':3}.get(l[:1])
            if k: s=sig(l[1:]); 
            if k and s: h[k].append(s)
        for p,add,rem,ctx in hunks:
            if p is None or not add: continue
            ml=mainlines(p)
            n=len(add)
            if ml is None:
                res['newfile_pend']+=n; res['pend']+=n; res['miss']=res.get('miss',0)+n; res.setdefault('mf',{}).setdefault(p,0); res['mf'][p]+=n; res.setdefault('pf',{}).setdefault(p,0); res['pf'][p]+=n; continue
            a=sum(x in ml for x in add)/n
            mi=sum(x not in ml for x in add); res['miss']=res.get('miss',0)+mi
            if mi: res.setdefault('mf',{}).setdefault(p,0); res['mf'][p]+=mi
            old=rem+ctx
            o=sum(x in ml for x in old)/len(old) if old else None
            if a>=0.6: res['app']+=n
            elif old and o<0.4: res['rew']+=n
            else: res['pend']+=n; res.setdefault('pf',{}).setdefault(p,0); res['pf'][p]+=n
    res['date']=g('log','-1','--format=%cI',sha).decode().strip()
    res['ndiffstat']=len(ns)
    return res
if __name__=='__main__':
    items=[l.split() for l in open(sys.argv[1])]
    with Pool(16) as pl:
        out=pl.map(an,items,chunksize=4)
    json.dump(out,open(sys.argv[2],'w'))
