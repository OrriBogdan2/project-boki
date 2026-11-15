import json,os
heads={}
for l in open('/tmp/ma/dheads.txt'):
    b,s=l.split(); heads[b]=s
sha2b={}
for b,s in heads.items(): sha2b.setdefault(s,[]).append(b)
contains={}
for b in heads:
    cs=set(open('/tmp/ma/rl/'+b.replace('/','_')).read().split())
    contains[b]=sorted(x for s in cs if s in sha2b for x in sha2b[s] if x!=b)
tips=json.load(open('/tmp/ma/tips.json')); tipset={t['br'] for t in tips}
EX={5,9,21,8,11,7,20,6,10,13}
carriedby={}
for t in tips:
    for x in contains.get(t['br'],[]): carriedby.setdefault(x,[]).append(t['br'])
nontip=[b for b in heads if b not in tipset]
tb={t['br']:t['b'] for t in tips}
theirs=[b for b in nontip if any(tb[x] in EX for x in carriedby.get(b,[]))]
mine=[b for b in nontip if b not in theirs and carriedby.get(b)]
orphan=[b for b in nontip if not carriedby.get(b)]
print('heads',len(heads),'tips',len(tipset),'tips missing heads',len(tipset-set(heads)),'nontip',len(nontip),'carried by top10',len(theirs),'carried only by mine',len(mine),'orphan',orphan[:5],len(orphan))
json.dump(dict(contains=contains,carriedby=carriedby,mine_carried=mine,theirs=theirs),open('/tmp/ma/anc.json','w'))
