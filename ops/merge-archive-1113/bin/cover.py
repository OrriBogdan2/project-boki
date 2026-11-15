import json,subprocess,re
from multiprocessing import Pool
R='/home/boki/cj/20261113-173508-a3/tree'
NOISE=re.compile(r'(\.uid$|\.import$|^briefs/|^docs/shots/|^docs/.*shots|tools/check_registry\.gd$|docs/wiki/Rules\.md$|docs/DEBT\.md$|tools/style_baseline\.json$|^ops/|^answer\.md$|MERGE_REPORT)')
def g(*a): return subprocess.run(['git','-C',R]+list(a),capture_output=True).stdout.decode('utf8','replace')
def sig(l):
    s=l.strip(); return s if len(s)>=8 else None
F=json.load(open('/tmp/ma/allfiles.json')); tips=json.load(open('/tmp/ma/tips.json')); a=json.load(open('/tmp/ma/anc.json'))
heads=dict(l.split() for l in open('/tmp/ma/dheads.txt'))
EX={5,9,21,8,11,7,20,6,10,13}
top=sorted(set(t['br'] for t in tips if t['b'] in EX)|set(a['theirs']))
merged=set()
def lines_of(ref,p):
    return set(filter(None,(sig(x) for x in g('show',ref+':'+p).splitlines())))
def work(x):
    sha=heads[x]; mb=g('merge-base','origin/main',sha).strip()
    d=g('diff','-U0','--no-renames',mb,sha,'--',*F[x]['files']) if F[x]['files'] else ''
    add={}; cur=None
    for l in d.splitlines():
        if l.startswith('+++ '): cur=l[6:] if l.startswith('+++ b/') else None; continue
        if l.startswith('+') and cur:
            s=sig(l[1:])
            if s: add.setdefault(cur,set()).add(s)
    miss={}
    for p,ss in add.items():
        ml=lines_of('origin/main',p); m=ss-ml
        if m: miss[p]=m
    n=sum(len(v) for v in miss.values())
    if n==0: return x,dict(n=0,cov=[])
    fx=set(miss)
    cov=[]
    for y in top:
        fy=set(F[y]['files'])
        if not fx&fy: continue
        ov=sum(len(miss[p]) for p in fx&fy)/n
        if ov<0.7: continue
        hit=0
        for p in fx&fy:
            yl=lines_of(heads[y],p); hit+=len(miss[p]&yl)
        if hit/n>=0.7: cov.append((round(hit/n,2),y))
    return x,dict(n=n,cov=sorted(cov,reverse=True)[:3])
if __name__=='__main__':
    scope=[l.split()[0] for l in open('/tmp/ma/scope.txt')]
    with Pool(24) as p: out=dict(p.map(work,scope,chunksize=2))
    json.dump(out,open('/tmp/ma/cover.json','w'))
    c=[k for k,v in out.items() if v['cov']]
    print(len(c))
