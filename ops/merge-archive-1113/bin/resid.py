import json,subprocess,re
from multiprocessing import Pool
R='/home/boki/cj/20261113-173508-a3/tree'
def g(*a): return subprocess.run(['git','-C',R]+list(a),capture_output=True).stdout.decode('utf8','replace')
def sig(l):
    s=l.strip(); return s if len(s)>=8 else None
F=json.load(open('/tmp/ma/allfiles.json')); C=json.load(open('/tmp/ma/cover.json')); tips=json.load(open('/tmp/ma/tips.json')); a=json.load(open('/tmp/ma/anc.json'))
heads=dict(l.split() for l in open('/tmp/ma/dheads.txt'))
EX={5,9,21,8,11,7,20,6,10,13}
top=sorted(set(t['br'] for t in tips if t['b'] in EX)|set(a['theirs']))
cache={}
def L(ref,p):
    k=(ref,p)
    if k not in cache: cache[k]=set(filter(None,(sig(x) for x in g('show',ref+':'+p).splitlines())))
    return cache[k]
def work(x):
    sha=heads[x]; mb=g('merge-base','origin/main',sha).strip()
    fs=F[x]['files']
    if not fs: return x,None
    d=g('diff','-U0','--no-renames',mb,sha,'--',*fs)
    add={};rem={};cur=None;old=None
    for l in d.splitlines():
        if l.startswith('--- '): old=l[6:] if l.startswith('--- a/') else None; continue
        if l.startswith('+++ '): cur=l[6:] if l.startswith('+++ b/') else None; continue
        if l.startswith('+') and cur:
            s=sig(l[1:]); 
            if s: add.setdefault(cur,set()).add(s)
        elif l.startswith('-') and old:
            s=sig(l[1:])
            if s: rem.setdefault(old,set()).add(s)
    ma={p:ss-L('origin/main',p) for p,ss in add.items()}
    ma={p:v for p,v in ma.items() if v}
    mr={}
    for p,ss in rem.items():
        xs=L(sha,p); keep=(ss-xs)&L('origin/main',p)   # removal not yet on main
        if keep: mr[p]=keep
    n=sum(map(len,ma.values()))+sum(map(len,mr.values()))
    cands=[c[1] for c in C[x]['cov']] if C.get(x) and C[x]['cov'] else []
    # widen: all top branches touching >=70% of the missing files
    fx=set(ma)|set(mr)
    for y in top:
        if y in cands: continue
        fy=set(F[y]['files'])
        if fx and len(fx&fy)>=0.7*len(fx): cands.append(y)
    best=None
    for y in cands:
        r=0; rf={}
        for p,v in ma.items():
            k=len(v-L(heads[y],p)); r+=k
            if k: rf[p]=rf.get(p,0)+k
        for p,v in mr.items():
            k=len(v&L(heads[y],p)); r+=k
            if k: rf[p]=rf.get(p,0)+k
        if best is None or r<best[0]: best=(r,y,sorted(rf.items(),key=lambda t:-t[1])[:3])
        if r==0: break
    return x,dict(n=n,best=best)
if __name__=='__main__':
    scope=[l.split()[0] for l in open('/tmp/ma/scope.txt')]
    with Pool(28) as p: out=dict(p.map(work,scope,chunksize=1))
    json.dump(out,open('/tmp/ma/resid.json','w'))
