import sys,glob
from PIL import Image
out=sys.argv[1];fs=sys.argv[2:];ims=[Image.open(f).convert('RGB') for f in fs]
w,h=ims[0].size;cols=6;rows=(len(ims)+cols-1)//cols
M=Image.new('RGB',(w*cols,h*rows),'white')
for i,im in enumerate(ims):M.paste(im,((i%cols)*w,(i//cols)*h))
M.save(out,quality=85)
