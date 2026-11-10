
import sys,json,os,re,subprocess
SP='/tmp'; A='briefs/boki-art/'
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__))); sys.path.insert(0,A+'batch')
from bload import load
from cutout import make_all
tag=sys.argv[1]
subprocess.run(['python3',SP+'/combine.py',tag,'--solo'],capture_output=True)
D=json.load(open(f'{SP}/panel/out/{tag}_decisions.json'))
EVO=set(os.path.splitext(x)[0] for x in os.listdir(A+'evolutions'))
def name(i):
    n=re.sub(r'^(ta_|c_|portrait_stance2_|portrait_|relic_)','',i)
    n=re.sub(r'_(w\d\d)$','',n); n=re.sub(r'_(card\d*|cardo81|full|pick|recolor|tailfix|b3|u2|p79|p83|p86|r86|p88|r88|gap|card91|p93|r93|card93|p95|r95|card95|p96|card96|p99|card99|card100|pz|cardz|rz|py|cardy|ry|px|cardx|rx|cardw|pb|cardb|pc|cardc|p89|card89|bat|o81|stance\d?|flat|v2|a2|a|n|v|e2|e|r2|r3|r|pe|p2|p|f2|f_e|x|fix|bite)$','',n)
    n=re.sub(r'_(card\d?|e2|e|r2|r|pe|p2|p)$','',n)
    return n.capitalize()
lines=[]
for d in D:
    i,dec,p=d['id'],d['decision'],d['pick']
    if dec not in ('pass','owner') or not p: continue
    N=name(i); stem=f'{i}_{p}'; sc=d['avg']
    kind='card' if '_card' in i else 'portrait' if i.startswith('portrait_') else 'concept' if i.startswith('c_') else 'relic' if i.startswith('relic_') else 'turnaround'
    female='_f_' in i or i.startswith(('kestrike_f','lunowl_f','murmurling_f','bellowary_f','gongibbon_f'))
    live = dec=='pass' or (kind=='card' and sc>=8.0) or (re.search(r'_stance\d?$',i) and sc>=8.0) or (kind=='turnaround' and i.startswith('ta_') and sc>=8.0 and not female)
    if live and not female and kind in ('card','turnaround') and not i.startswith('relic_'):
        sub='cards' if kind=='card' else ('evolutions' if N in EVO else 'turnarounds')
        f=f'{A}{sub}/{N}.jpg'
        if os.path.exists(f) and kind=='turnaround' and not os.path.exists(f'{A}{sub}/{N}_old.jpg'): os.rename(f,f'{A}{sub}/{N}_old.jpg')
        load(stem).save(f,quality=93); path=f'briefs/boki-art/{sub}/{N}.jpg'; st=''
    elif live and kind=='portrait' and 'stance' not in i:
        t=SP+'/tmp_pass.jpg'; load(stem).save(t,quality=95); make_all(t,N,A+'portraits'); path=f'briefs/boki-art/portraits/light/{N}.jpg'; st=''
    else:
        path=f'briefs/boki-art/batch/out/{stem}.jpg'; st=' status=owner-review'
    if i.startswith('relic_'): lines.append(f"ART relic {N.lower()} {path} grade {sc}/10{st}")
    else: lines.append(f"ART {N.lower()} {sc} {path} kind={kind}{' form=female' if female else ''}{st}")
print('\n'.join(lines))
