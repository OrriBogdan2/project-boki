import json,re,collections
tips=json.load(open('/tmp/ma/tips.json')); a=json.load(open('/tmp/ma/anc.json'))
L={r['br']:r for r in json.load(open('/tmp/ma/lines.json'))}
EX={5,9,21,8,11,7,20,6,10,13}
top=set(t['br'] for t in tips if t['b'] in EX)|set(a['theirs'])
merged=set(open('/tmp/ma/merged.txt').read().split())
heads=dict(l.split() for l in open('/tmp/ma/dheads.txt'))
cover=top|merged
# READY supersede statements
sup=collections.defaultdict(set)
for l in open('/tmp/ma/e2m.md'):
    m=re.match(r'\s*-?\s*READY (ext/[^\s]+)',l)
    if not m: continue
    y=m.group(1)
    for mm in re.finditer(r'[Ss][Uu][Pp][Ee][Rr][Ss][Ee][Dd][Ee][Ss]:?\s+(?:READY\s+)?(?:the\s+)?(ext/[A-Za-z0-9._/-]+)',l):
        x=mm.group(1).rstrip('.,:;)')
        if x!=y: sup[x].add(y)
def base(b):
    s=b
    while True:
        t=re.sub(r'(-rebased|-v\d+|-\d{1,2}|-rest|-slice|-redo|-fix|-deep|-1[01]\d\d[a-z]?|-0\d\d\d)$','',s)
        if t==s: return s
        s=t
fam=collections.defaultdict(set)
for b in list(heads)+list(merged): fam[base(b)].add(b)
out={}
for x in L:
    why=[]
    for y in sup.get(x,()):
        if y in cover: why.append(('ready',y,'top10' if y in top else 'merged'))
    for y in fam[base(x)]:
        if y!=x and y in cover: why.append(('family',y,'top10' if y in top else 'merged'))
    if why: out[x]=why
json.dump(out,open('/tmp/ma/sup.json','w'))
print(len(out)); [print(k,v) for k,v in list(out.items())[:400]]
