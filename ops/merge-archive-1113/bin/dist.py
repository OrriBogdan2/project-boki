import json,collections
L=json.load(open('/tmp/ma/lines.json'))
c=collections.Counter()
for r in L:
    tot=r['app']+r['rew']+r['pend']
    art=r['art_new']+r['art_pend']
    if tot==0: c['notext art=%d'%bool(art)]+=1; continue
    fa=r['app']/tot; fr=r['rew']/tot; fp=r['pend']/tot
    k='app>=.6' if fa>=.6 else 'rew>=.5' if fr>=.5 else 'app+rew>=.6' if fa+fr>=.6 else 'pend'
    c[k+(' +art' if art else '')]+=1
for k,v in sorted(c.items()): print(v,k)
