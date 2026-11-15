exec(open("/home/boki/cj/20261115-193602-a3/tree/ops_tmp_grimble/common.py").read())
import sys
for _a in sys.argv:
    if "=" in _a and _a.split("=")[0].isupper(): os.environ[_a.split("=")[0]]=_a.split("=",1)[1]
load(os.environ["SRC"]); tag=os.environ["TAG"]; out="out"; os.makedirs(out,exist_ok=True)
sc,cam=setup_render(900); sc.display.shading.color_type='TEXTURE'; sc.view_settings.view_transform='Standard'
for a in (20,45,70): shot(sc,cam,f"{out}/{tag}_mz_{a}.png",a,(0.10,-0.34,0.24),0.13)
