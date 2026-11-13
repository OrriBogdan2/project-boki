import re,sys,json
batches={};cur=None;tips=[]
for l in open('/tmp/ma/MERGE_TRIAGE_1113.md'):
    m=re.match(r'### B(\d+) ',l)
    if m: cur=int(m.group(1)); continue
    if l.startswith('## ') : cur=None
    m=re.match(r"- `(ext/[^`]+)` I(\d+) H(\d+) (\d+)cf(.*)",l)
    if m and cur is not None:
        c=re.search(r'\+(\d+) carried',m.group(5))
        tips.append(dict(b=cur,br=m.group(1),I=int(m.group(2)),H=int(m.group(3)),cf=int(m.group(4)),carried=int(c.group(1)) if c else 0,pretag='pre-tagged' in m.group(5)))
json.dump(tips,open('/tmp/ma/tips.json','w'))
EX={5,9,21,8,11,7,20,6,10,13}
print(len(tips), sum(t['b'] not in EX for t in tips), sum(t['b'] in EX for t in tips))
