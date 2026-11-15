import shutil,os
H="/home/boki/meshy/"
L={"motley_turn.jpg":"splash-r2-1113/work_r2/refs/motley_turn.jpg","motley_master.jpg":"splash-r2-1113/work_r2/refs/motley_master.jpg",
"motley_v2_master_sheet.jpg":"splash-recreate-all-1114/refs/motley_v2_master_sheet.jpg","ostra_turnaround.jpg":"review-1111/hunters/ref/ostra_turnaround.jpg",
"kael_v2_turnaround.jpg":"kael-elephant-1115/refs/kael_v2_turnaround.jpg","kael_v2_master_sheet.jpg":"kael-elephant-1115/refs/kael_v2_master_sheet.jpg",
"lace_turnaround.jpg":"lace-grey-eyes-1115/out/lace_turnaround.jpg","lace_master_sheet.jpg":"lace-grey-eyes-1115/out/lace_master_sheet.jpg",
"mossy_turnaround.jpg":"albert-clean-shape-1115/refs/turnaround.jpg","mossy_master_sheet.jpg":"albert-100-1115/refs/mossy_v2_master_sheet.jpg",
"motley_cardsA.png":"motley-cards-1115/final/A.png","albert_bw_sheet.jpg":"albert-bw-1115/sheet.jpg"}
os.makedirs("out",exist_ok=True)
for k,v in L.items():
    try: shutil.copy(H+v,"out/"+k); print("ok",k,os.path.getsize("out/"+k))
    except Exception as e: print("MISSING",k,e)
for n in ["Albert","Kael","Motley"]:
    for f in ["current.json"]: pass
import glob
for p in glob.glob(H+"v95/*/current.json"): print(p, open(p).read().replace("\n"," ")[:200])
