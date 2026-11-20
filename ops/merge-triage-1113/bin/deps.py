import json,subprocess,re
c=json.load(open('/tmp/mt/final.json'));S=json.load(open('/tmp/mt/scan.json'))
D=[b for b,v in c.items() if v[0] in ('d','c?') and b!='ext/agent-briefs']
sha2b={}
for b in D: sha2b.setdefault(S[b]['sha'],[]).append(b)
anc={}  # Y -> list of X (X ancestor of Y)
for y in D:
    r=subprocess.run(['git','rev-list',S[y]['sha'],'^origin/main'],capture_output=True,text=True).stdout.split()
    xs=[x for h in r for x in sha2b.get(h,[]) if x!=y]
    if xs: anc[y]=xs
json.dump(anc,open('/tmp/mt/anc.json','w'))
print(len(anc), sum(len(v) for v in anc.values()))
