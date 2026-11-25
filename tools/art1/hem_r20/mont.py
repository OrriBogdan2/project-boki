import sys
from PIL import Image
out=sys.argv[1]; fs=sys.argv[2:]; cols=int(__import__('os').environ.get('COLS',len(fs)))
ims=[Image.open(f).convert('RGB') for f in fs]; w,h=ims[0].size; rows=(len(ims)+cols-1)//cols
o=Image.new('RGB',(w*cols,h*rows))
for i,im in enumerate(ims): o.paste(im.resize((w,h)),((i%cols)*w,(i//cols)*h))
o.save(out,quality=88)
