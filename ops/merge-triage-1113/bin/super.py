import json, re, subprocess, collections
def run(*a): return subprocess.run(['git',*a],capture_output=True,text=True)
S=json.load(open('/tmp/mt/scan.json'))
SUF=re.compile(r'(-(rebased|rb|v\d+|r\d+|retry\d*|redo|again|final|fix|fixes|deep|take\d+|\d{3,4}[a-z]?|\d))$')
def fam(b):
    n=b[4:].lower()
    while True:
        m=SUF.search(n)
        if not m or len(n)-len(m.group(0))<3: return n
        n=n[:m.start()]
def contained(b,c):
    if run('merge-base','--is-ancestor',S[b]['sha'],S[c]['sha']).returncode==0: return 'ancestor'
    r=run('merge-tree','--write-tree','--no-messages',S[c]['sha'],S[b]['sha'])
    if r.returncode==0 and r.stdout.split()[0]==run('rev-parse',S[c]['sha']+'^{tree}').stdout.strip(): return 'merge-noop'
    return None
fams=collections.defaultdict(list)
for b in S: fams[fam(b)].append(b)
out={}
for f,bs in fams.items():
    if len(bs)<2: continue
    bs.sort(key=lambda x:S[x]['ct'])
    for i,b in enumerate(bs):
        for c in reversed(bs[i+1:]):
            if c in out: continue
            how=contained(b,c)
            if how: out[b]=(c,'family '+how); break
# explicit READY supersedes
MERGED=set(l.split()[0] for l in open('/tmp/mt/ready_live.txt'))-set(S)
txt=open('/tmp/mt/e2m_arch.md').read()+open('/tmp/mt/e2m.md').read()
exp={}
for line in txt.split('\n'):
    m=re.match(r'^(?:- )?READY (ext/\S+) ([0-9a-f]{7,40})',line)
    if not m: continue
    c=m.group(1)
    for k in re.finditer(r'supersede[sd]?',line):
        seg=re.split(r'[;)]',line[k.end():k.end()+300])[0]
        for x in re.findall(r'ext/[A-Za-z0-9._/-]*[A-Za-z0-9]',seg):
            if x!=c and x in S: exp.setdefault(x,c)
for b,c in exp.items():
    if b in out: continue
    if c in MERGED: out[b]=(c,'READY-says-supersedes; superseder merged in main')
    elif c in S and S[c]['ct']>=S[b]['ct']: out[b]=(c,'READY-says-supersedes')
# containment in integ/batch branches (not archived; noted)
integ=[b for b in S if re.search(r'integ|batch|stuck|merge',b)]
car={}
for b in S:
    if b in out or b in integ: continue
    cs=[c for c in integ if run('merge-base','--is-ancestor',S[b]['sha'],S[c]['sha']).returncode==0]
    if cs: car[b]=cs
json.dump(dict(sup=out,carried=car),open('/tmp/mt/super.json','w'),indent=0)
print(len(fams), len(out), collections.Counter(v[1].split(';')[0] for v in out.values()), len(car))
