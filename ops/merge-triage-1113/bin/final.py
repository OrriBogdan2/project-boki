import json,re,collections,time
S=json.load(open('/tmp/mt/scan.json')); d=json.load(open('/tmp/mt/super.json'))
sup=d['sup']; car=d['carried']
# break mutual cycles: keep newest
for b in list(sup):
    c=sup.get(b,[None])[0]
    if c in sup and sup[c][0]==b:
        newer=b if S[b]['ct']>=S[c]['ct'] else c
        sup.pop(newer,None)
im={l.split()[0]:l.split()[2:] for l in open('/tmp/mt/inmain.txt')}
mt={l.split()[0]:(l.split()[2],l.split()[3:]) for l in open('/tmp/mt/mtree.txt')}
ART=re.compile(r'\.(png|jpe?g|webp|gif|glb|gltf|fbx|blend|obj|wav|ogg|mp3|mp4|webm|import|svg|ttf|otf|exr|hdr)$|^(docs|briefs|footage|shots)/|\.md$', re.I)
cls={}
for b in S:
    t=im[b]; notin=[x[2:] for x in t if x[0] in 'NB']
    if not notin: cls[b]=('a','all touched files equal main or hunks already on main')
    elif b in sup: cls[b]=('b','superseded by '+sup[b][0]+' ('+sup[b][1]+')')
    elif b in d['merged_sibling'] and re.search(r'-rebased',d['merged_sibling'][b][0]) and not b.endswith('rebased'):
        cls[b]=('b','superseded by '+d['merged_sibling'][b][0]+' (newer rebased copy already merged in main)')
    elif all(ART.search(f) for f in S[b]['files']): cls[b]=('c?','art/docs-only, %d/%d files not on main'%(len(notin),len(t)))
    else: cls[b]=('d','%d/%d files not on main'%(len(notin),len(t)))
json.dump(cls,open('/tmp/mt/final.json','w'),indent=0)
print(collections.Counter(v[0] for v in cls.values()))
