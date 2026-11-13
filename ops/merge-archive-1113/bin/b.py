import json
L=json.load(open('/tmp/ma/lines.json')); tips={t['br']:t for t in json.load(open('/tmp/ma/tips.json'))}
for r in sorted(L,key=lambda r:r['br']):
    tot=r['app']+r['rew']+r['pend']
    if tot==0 or (r['app']+r['rew'])/tot<0.6: continue
    t=tips.get(r['br'])
    print(r['br'], 'B%02d I%d'%(t['b'],t['I']) if t else 'carried', 'app%d rew%d pend%d art n%d p%d o%d on%d f%d'%(r['app'],r['rew'],r['pend'],r['art_new'],r['art_pend'],r['art_over'],r['art_on'],r['files']))
