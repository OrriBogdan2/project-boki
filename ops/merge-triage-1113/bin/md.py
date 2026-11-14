import json,re,collections
rows=json.load(open('/tmp/mt/rows.json')); R={r['b']:r for r in rows}
c=json.load(open('/tmp/mt/final.json')); anc=json.load(open('/tmp/mt/anc.json'))
txt=open('/tmp/mt/e2m_arch.md').read().split('\n')+open('/tmp/mt/e2m.md').read().split('\n')
dep=collections.defaultdict(set)
for line in txt:
    m=re.match(r'^(?:- )?READY (ext/\S+) ',line)
    if not m or m.group(1) not in R: continue
    for x in re.findall(r'(?:STACKED on|BASED ON|builds on|on top of)\s+(?:origin/)?(ext/[A-Za-z0-9._/-]*[A-Za-z0-9])',line,re.I):
        if x in R and x!=m.group(1): dep[m.group(1)].add(x)
ORDER=['tech','kits','feel','anim','vfx','audio','ui','tutorial','farm','misc','docs','integ']
key=lambda r:(ORDER.index(r['lane']),-r['imp'],r['hard'],r['b'])
seq=[];done=set()
def place(b,stack=()):
    if b in done or b in stack: return
    for x in sorted(dep.get(b,())): place(x,stack+(b,))
    done.add(b); seq.append(b)
clean=sorted([r for r in rows if r['st']=='clean' and r['lane']!='integ'],key=key)
for r in clean: place(r['b'])
b0=list(seq)
for r in sorted(rows,key=key): place(r['b'])
batches=[('B00 clean merges (no conflict with main)',b0)]
rest=seq[len(b0):]; cur=[];curl=None
for b in rest:
    l=R[b]['lane']
    if cur and (len(cur)==40 or (l!=curl and len(cur)>=25) or (l=='integ')!=(curl=='integ')):
        batches.append((None,cur)); cur=[]
    cur.append(b); curl=l
if cur: batches.append((None,cur))
out=[]
for i,(name,bs) in enumerate(batches):
    lanes=collections.Counter(R[b]['lane'] for b in bs)
    nm=name or 'B%02d %s'%(i,'+'.join(l for l,_ in lanes.most_common()))
    imp=sum(R[b]['imp'] for b in bs)/len(bs); hd=sum(R[b]['hard'] for b in bs)/len(bs)
    carried=sum(R[b]['n'] for b in bs)
    hot=collections.Counter(f for b in bs for f in R[b]['hot']).most_common(3)
    out.append((nm,bs,imp,hd,carried,hot))
json.dump([(o[0],o[1]) for o in out],open('/tmp/mt/batches.json','w'))
L=[]
for nm,bs,imp,hd,carried,hot in out:
    L.append(f"\n### {nm}: {len(bs)} merges (+{carried} stacked branches carried), avg impact {imp:.1f}/10, avg hard {hd:.1f}/10"+(f"; god-file conflicts: "+', '.join(f'{f.split("/")[-1]} x{n}' for f,n in hot) if hot else ''))
    L.append('')
    for b in bs:
        r=R[b]; d=' after '+','.join(sorted(dep[b])) if dep.get(b) else ''
        L.append(f"- `{b}` I{r['imp']} H{r['hard']} {r['ncf']}cf{(' +'+str(r['n'])+' carried') if r['n'] else ''}{' pre-tagged' if r['tag'] else ''}{d}")
open('/tmp/mt/batches.md','w').write('\n'.join(L)+'\n')
print(len(out), [len(o[1]) for o in out]); print(sum(len(o[1]) for o in out))
