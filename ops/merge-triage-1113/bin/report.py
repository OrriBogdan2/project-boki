import json,collections,re,subprocess,time,math
c=json.load(open('/tmp/mt/final.json'));S=json.load(open('/tmp/mt/scan.json'));anc=json.load(open('/tmp/mt/anc.json'))
mt={l.split()[0]:(l.split()[2],l.split()[3:]) for l in open('/tmp/mt/mtree.txt')}
tagged=set(open('/tmp/mt/um_tagged.txt').read().split())
txt=open('/tmp/mt/e2m_arch.md').read().split('\n')+open('/tmp/mt/e2m.md').read().split('\n')
rt={}
for line in txt:
    m=re.match(r'^(?:- )?READY (ext/\S+) [0-9a-f]{7,40}\s*\(?(.*)',line)
    if m: rt[m.group(1)]=m.group(2)
GOD=('home.gd','hud.gd','hunter.gd','main.gd','match.gd','models.gd','world.gd')
D=[b for b,v in c.items() if v[0] in ('d','c?') and b!='ext/agent-briefs']
carried=set(x for v in anc.values() for x in v)
tips=[b for b in D if b not in carried]
INTEG=re.compile(r'integ|stuck|^ext/mc-|batch|merge-|release|w0246')
LANES=[('integ',INTEG),('tech',r'^ext/(perf|checks?|verify|split|no-|remote|bot|net|style|types|suite|health|fix-|status|hardcode|overlay|save)'),
 ('kits',r'^ext/(parity|kit|combat|ttk|ult|kael|meeko|vex|sable|lace|grimble|albert|tenzo|neve|motley|scrapking|mantle|cinder|sparkle|hem|tarek|dredge|archer|mage|thief|juggernaut|bulwark|gunslinger|hero|hunter-kit|recast|summon-pve|heal|rank|wisp)'),
 ('feel',r'^ext/(feel|move|dash|glide|knock|cooldown|air|aim|reticle|hit|wallmove|swim|carry)'),
 ('anim',r'^ext/(anim|idle|gait|pose|rig)'),('vfx',r'^ext/(vfx|telegraph|fx)'),('audio',r'^ext/(sfx|audio|music|voice)'),
 ('tutorial',r'^ext/(tut|tutorial|first|farm-tut|training|prologue|npc|hob)'),('ui',r'^ext/(ui|hud|hunter|title|menu|settings|creator|dex|market)'),
 ('farm',r'^ext/(farm|garden|boki|fold|clans|soul|early|camp|map|ways|extra|pitch|legend|toy|raising|hatch|egg|kin)')]
def lane(b):
    for n,p in LANES:
        if re.search(p,b): return n
    fs=S[b]['files']; top=collections.Counter(f.split('/')[1] if f.startswith('scripts/') and '/' in f[8:] else f.split('/')[0] for f in fs).most_common(1)
    t=top[0][0] if top else ''
    return {'heroes':'kits','match':'kits','ui':'ui','home':'farm','audio':'audio','art':'anim','docs':'docs'}.get(t,'misc')
now=time.time()
def gdlines(b):
    o=subprocess.run(['git','diff','--numstat',S[b]['mb'],S[b]['sha'],'--','*.gd','*.gdshader','*.json'],capture_output=True,text=True).stdout
    return sum(int(a)+int(d) for a,d,*_ in (l.split('\t') for l in o.splitlines()) if a!='-')
rows=[]
for b in tips:
    t=rt.get(b,''); age=(now-S[b]['ct'])/86400
    st,cf=mt[b]; hot=[f for f in cf if f.split('/')[-1] in GOD]
    L=gdlines(b); n=len(anc.get(b,[]))
    imp=3+(2 if re.search(r'owner',t,re.I) else 0)+(1 if re.search(r'priority|blocker|crash|broken|bug|regress|fix',t,re.I) else 0)+min(3,int(math.log10(L+1)))+(1 if n>=5 else 0)-(1 if age>7 else 0)
    hard=1+min(6,len(cf)//5)+min(3,len(hot))
    if INTEG.search(b): hard=min(10,hard+2)
    rows.append(dict(b=b,lane=lane(b),imp=max(1,min(9,imp)),hard=min(10,hard),age=round(age,1),st=st,ncf=len(cf),hot=hot,n=n,L=L,tag=b in tagged,stk=bool(re.search(r'STACKED|BASED ON|merge that first',t,re.I)),t=t[:110]))
json.dump(rows,open('/tmp/mt/rows.json','w'))
print(collections.Counter(r['lane'] for r in rows))
print('clean',sum(r['st']=='clean' for r in rows),'age>7',sum(r['age']>7 for r in rows),'pretagged',sum(r['tag'] for r in rows))
