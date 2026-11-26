# sheet30.py OUT KIND LABEL=DIR=BORDER ... : owner sheet (OWNER SHEET RULE: verdict = border colour only, grey live / green better /
# red worse; letters only, no verdict words). KIND match = game camera <DIR>/archer/<clip>_<k>.jpg cropped to the body;
# KIND y270_eye / y90_knee ... = close four-yaw shots <DIR>/archer/y<deg>/<clip>_<k>_<eye|knee>.jpg (whole frame).
# Rows = clips, each row = every candidate's 3 frames side by side in its border colour; header row = letters.
import sys,os
from PIL import Image,ImageDraw,ImageFont
out,kind=sys.argv[1:3]; C=[a.split('=') for a in sys.argv[3:]]
COL={'grey':(150,150,150),'green':(30,190,60),'red':(220,40,40)}
clips=['idle','run','dash','jump','attack','hit']
if kind=='match': tw,th=200,230; crop=(230,200,560,580)
else: tw,th=230,230; crop=None; yd,view=kind.split('_')
try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',26)
except OSError: font=ImageFont.load_default()
B=6; G=18; LW=90; HH=40; gw=3*tw+2*B
W=LW+len(C)*(gw+G); H=HH+len(clips)*(th+2*B+8)
S=Image.new('RGB',(W,H),(255,255,255)); d=ImageDraw.Draw(S)
for ci,(lab,dr,bc) in enumerate(C):
    x0=LW+ci*(gw+G); d.text((x0+gw//2-10,6),lab,fill=(0,0,0),font=font)
    for ri,cl in enumerate(clips):
        y0=HH+ri*(th+2*B+8); d.rectangle([x0,y0,x0+gw-1,y0+th+2*B-1],fill=COL[bc])
        if ci==0: d.text((6,y0+th//2),cl,fill=(0,0,0),font=font)
        for k in range(3):
            p=os.path.join(dr,'archer',f'{cl}_{k}.jpg') if kind=='match' else os.path.join(dr,'archer',yd,f'{cl}_{k}_{view}.jpg')
            if not os.path.exists(p): continue
            im=Image.open(p).convert('RGB'); im=im.crop(crop) if crop else im
            S.paste(im.resize((tw,th)),(x0+B+k*tw,y0+B))
S.save(out,quality=90); print('sheet',out,S.size)
