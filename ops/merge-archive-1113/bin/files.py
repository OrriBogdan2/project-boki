import json,subprocess,re,sys
from multiprocessing import Pool
R='/home/boki/cj/20261113-173508-a3/tree'
NOISE=re.compile(r'(\.uid$|\.import$|^briefs/|^docs/shots/|^docs/.*shots|tools/check_registry\.gd$|docs/wiki/Rules\.md$|docs/DEBT\.md$|tools/style_baseline\.json$|^ops/|^answer\.md$|MERGE_REPORT)')
def g(*a): return subprocess.run(['git','-C',R]+list(a),capture_output=True,text=True).stdout
def f(it):
    b,s=it; mb=g('merge-base','origin/main',s).strip()
    fs=[p for p in g('diff','--name-only','--no-renames',mb,s).split('\n') if p and not NOISE.search(p)]
    last=max(g('log','--no-merges','--format=%aI',s,'^origin/main').split() or [''])
    return b,dict(files=fs,last=last)
heads=[l.split() for l in open('/tmp/ma/dheads.txt')]
with Pool(16) as p: out=dict(p.map(f,heads,chunksize=8))
json.dump(out,open('/tmp/ma/allfiles.json','w'))
