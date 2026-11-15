import subprocess,sys
R='/home/boki/cj/20261113-173508-a3/tree'
def g(*a): return subprocess.run(['git','-C',R]+list(a),capture_output=True).stdout.decode('utf8','replace')
def sig(l):
    s=l.strip(); return s if len(s)>=8 else None
def L(ref,p): return set(filter(None,(sig(x) for x in g('show',ref+':'+p).splitlines())))
x,y=sys.argv[1],sys.argv[2]
X='origin/'+x; Y='origin/'+y
mb=g('merge-base','origin/main',X).strip()
fs=[p for p in g('diff','--name-only',mb,X).split() if not p.endswith(('.uid','.import')) and not p.startswith(('briefs/','docs/shots'))]
tot=res=0; ex=[]
for p in fs:
    xs=L(X,p); a=xs-L(mb,p)-L('origin/main',p); r=a-L(Y,p); tot+=len(a); res+=len(r); ex+=[(p,l) for l in list(r)[:2]]
print(x,'vs',y,'unmerged',tot,'not in successor',res); [print('  ',p,':',l[:100]) for p,l in ex[:6]]
