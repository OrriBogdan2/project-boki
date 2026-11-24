import sys,glob; from PIL import Image,ImageDraw
pre=sys.argv[1]; out=sys.argv[2]; fs=sorted(glob.glob(pre+'_*.png'))
rows={}
for f in fs: k=f[len(pre)+1:-4].rsplit('_',1); rows.setdefault(k[0],[]).append(f)
R=list(rows); C=max(len(v) for v in rows.values()); W=200
c=Image.new('RGB',(W*C,W*len(R)),'white')
for r,k in enumerate(R):
    for i,f in enumerate(rows[k]): im=Image.open(f).convert('RGB').resize((W,W)); c.paste(im,(i*W,r*W)); ImageDraw.Draw(c).text((i*W+3,r*W+3),k+' '+f.rsplit('_',1)[1][:-4],fill='black')
c.save(out)
