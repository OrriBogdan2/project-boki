import sys,csv,collections
best=collections.defaultdict(lambda:(0,''))
for r in csv.DictReader(open(sys.argv[1]),delimiter='\t'):
    k=(r['clip'],r['pair']);d=float(r['depth_cm'])
    if d>best[k][0]:best[k]=(d,r['frame'])
for (c,p),(d,f) in sorted(best.items(),key=lambda x:-x[1][0])[:int(sys.argv[2]) if len(sys.argv)>2 else 14]:print(f'{c:22s} {p:28s} {d:.2f} f{f}')
