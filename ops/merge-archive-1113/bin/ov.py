import json
F=json.load(open('/tmp/ma/allfiles.json')); tips=json.load(open('/tmp/ma/tips.json')); a=json.load(open('/tmp/ma/anc.json'))
EX={5,9,21,8,11,7,20,6,10,13}
top=set(t['br'] for t in tips if t['b'] in EX)|set(a['theirs'])
scope=[l.split()[0] for l in open('/tmp/ma/scope.txt')]
res={}
for x in scope:
    fx=set(F[x]['files'])
    if not fx or len(fx)>60: continue
    best=[]
    for y in top:
        fy=set(F[y]['files'])
        if len(fy)>200 or not fy: continue
        ov=len(fx&fy)/len(fx)
        if ov>=0.8 and F[y]['last']>F[x]['last']: best.append((round(ov,2),y,len(fy)))
    if best: res[x]=sorted(best,reverse=True)[:3]
json.dump(res,open('/tmp/ma/ov.json','w'))
print(len(res))
for k,v in res.items(): print(k,len(F[k]['files']),v)
