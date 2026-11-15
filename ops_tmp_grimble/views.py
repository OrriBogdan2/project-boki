exec(open("/home/boki/cj/20261115-193602-a3/tree/ops_tmp_grimble/common.py").read())
import sys
for _a in sys.argv:
    if "=" in _a and _a.split("=")[0].isupper(): os.environ[_a.split("=")[0]]=_a.split("=",1)[1]
src=os.environ["SRC"]; tag=os.environ["TAG"]; out="out"; os.makedirs(out,exist_ok=True)
load(src)
sc,cam=setup_render(1000); sc.display.shading.color_type='TEXTURE'; sc.view_settings.view_transform='Standard'
sc.display.shading.light='FLAT'
for a in (-35,0,35): shot(sc,cam,f"{out}/{tag}_face_{a}.png",a,(0.0,0,0.28),0.62)
for a in (-60,60): shot(sc,cam,f"{out}/{tag}_mouth_{a}.png",a,(0.08,-0.3,0.25),0.4)
shot(sc,cam,f"{out}/{tag}_full.png",0,(0,0,0),2.1)
if os.environ.get("TURN")=="1":
    sc.render.resolution_x=640; sc.render.resolution_y=640
    for i in range(72):
        shot(sc,cam,f"{out}/turn_{i:03d}.png",i*5,(0,0,0),2.1)
