# Combine screener + 3 seats for a group TAG -> decisions (pass / edit / new) by the GRADES.md rule.
import json,sys,glob,collections
S='/tmp/panel/out/'
tag=sys.argv[1]; solo='--solo' in sys.argv; seats={}
for st in 'ABC':
    try: seats[st]={x['id']:x for x in json.load(open(f'{S}{tag}_{st}.json'))}
    except Exception: pass
ids=sorted(set().union(*[set(v) for v in seats.values()])) if seats else []
out=[]
for i in ids:
    rs=[seats[s][i] for s in seats if i in seats[s]]
    picks=collections.Counter(r.get('pick') for r in rs if r.get('pick'))
    pick=picks.most_common(1)[0][0] if picks else None
    g=[float(r.get('grades',{}).get(str(pick),r.get('grade') or 0) or 0) for r in rs] if pick else [float(r.get('grade') or 0) for r in rs]
    avg=round(sum(g)/len(g),2) if g else 0
    veto=[r.get('veto') for r in rs if r.get('veto')]
    ok=(not veto and avg>=8.5) if solo else (len(rs)==3 and not veto and min(g)>=8.0 and avg>=8.5 and picks.most_common(1)[0][1]>=2)
    dec='pass' if ok else ('owner' if not veto and (solo or len(rs)==3) and avg>=7.5 and pick else None) or ('edit' if avg>=7.9 and pick else 'new')
    out.append({'id':i,'pick':pick,'avg':avg,'seats':g,'decision':dec,'fixes':[r.get('fix') for r in rs],'veto':veto})
json.dump(out,open(f'{S}{tag}_decisions.json','w'),indent=1)
for o in out: print(o['decision'],o['id'],o['pick'],o['avg'],o['seats'])
