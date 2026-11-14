import json,re
L=json.load(open('/tmp/ma/lines.json'))
DOC=re.compile(r'^(docs/|tools/|content/rules/tuning\.json$|.*\.md$)')
old=[r for r in L if r['first']<'2026-11-08T17:35']
print('old',len(old))
d=[r for r in old if all(DOC.match(p) for p in r['paths'])]
print('old docs/tools-only',len(d))
for r in d: print(r['br'],r['first'][:10],r['last'][:10],r['app'],r['rew'],r['pend'],len(r['paths']),r['paths'][:3])
