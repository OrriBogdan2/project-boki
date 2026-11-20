import json,subprocess,sys
sys.path.insert(0,'/tmp/mabin')
R='/home/boki/cj/20261113-173508-a3/tree'
def g(*a): return subprocess.run(['git','-C',R]+list(a),capture_output=True).stdout.decode('utf8','replace')
def sig(l):
    s=l.strip(); return s if len(s)>=8 else None
heads=dict(l.split() for l in open('/tmp/ma/dheads.txt'))
RS=json.load(open('/tmp/ma/resid.json'))
def L(ref,p): return set(filter(None,(sig(x) for x in g('show',ref+':'+p).splitlines())))
for x in sys.argv[1:]:
    y=RS[x]['best'][1]; sha=heads[x]; mb=g('merge-base','origin/main',sha).strip()
    for p,_ in RS[x]['best'][2]:
        xs=L(sha,p); ms=L('origin/main',p); ys=L(heads[y],p); bs=L(mb,p)
        for l in sorted(xs-bs-ms-ys)[:4]: print(x.split('/')[1][:28],'+',p,':',l[:110])
        for l in sorted((bs-xs)&ms&ys)[:4]: print(x.split('/')[1][:28],'-',p,':',l[:110])
