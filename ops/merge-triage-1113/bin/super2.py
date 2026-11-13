import json,re,subprocess,collections
exec(open('/tmp/mt/bin/super.py').read().split('fams=collections')[0].split('def contained')[0])
d=json.load(open('/tmp/mt/super.json')); sup=d['sup']
txt=open('/tmp/mt/e2m_arch.md').read()+open('/tmp/mt/e2m.md').read()
bad=0
for b,(c,why) in list(sup.items()):
    if not why.startswith('READY'): continue
    ok=False
    for line in txt.split('\n'):
        if not re.match(r'^(?:- )?READY '+re.escape(c)+' ',line): continue
        for k in re.finditer(r'supersede[sd]?',line,re.I):
            seg=re.split(r'[;)]',line[k.end():k.end()+300])[0]
            if b in re.findall(r'ext/[A-Za-z0-9._/-]*[A-Za-z0-9]',seg) and not re.search(r'nothing|part|half|not ',seg[:seg.find(b)]): ok=True
    if ok and c in S and not set(S[b]['files'])<=set(S[c]['files']) and subprocess.run(['git','merge-base','--is-ancestor',S[b]['sha'],S[c]['sha']]).returncode: ok=False
    if not ok: del sup[b]; bad+=1
# newer family sibling already merged in main
MERGED=set(l.split()[0] for l in open('/tmp/mt/ready_live.txt'))-set(S)
mf=collections.defaultdict(list)
for m in MERGED: mf[fam(m)].append(m)
sib={b:mf[fam(b)] for b in S if b not in sup and mf.get(fam(b))}
d['sup']=sup; d['merged_sibling']=sib
json.dump(d,open('/tmp/mt/super.json','w'),indent=0)
print('dropped',bad,'sup',len(sup),'with merged sibling',len(sib))
