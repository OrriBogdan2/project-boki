exec(open("/home/boki/cj/20261115-193602-a3/tree/ops_tmp_grimble/common.py").read())
import sys
out="out"; os.makedirs(out,exist_ok=True)
ob=load(os.environ.get("SRC","/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb"))
sc,cam=setup_render(900); sc.display.shading.color_type='TEXTURE'
sc.display.shading.light='FLAT'
for a in (-30,0,30,60): shot(sc,cam,f"{out}/z_{a}.png",a,(0.115,-0.38,0.22),0.24)
